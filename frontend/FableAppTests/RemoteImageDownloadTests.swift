import Foundation
import XCTest
@testable import FableApp

final class RemoteImageDownloadTests: XCTestCase {
    func testBoundedDownloaderAcceptsValidHTTPSImage() async throws {
        let imageData = try XCTUnwrap(
            Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==")
        )
        ImageDownloadStubURLProtocol.setResponse(
            statusCode: 200,
            mimeType: "image/png",
            body: imageData
        )

        let data = await makeLoader(maximumBytes: imageData.count + 1)
            .load(URL(string: "https://images.example.test/cover.png")!)

        XCTAssertEqual(data, imageData)
    }

    func testBoundedDownloaderRejectsOversizedImageBody() async throws {
        let imageData = try XCTUnwrap(
            Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==")
        )
        ImageDownloadStubURLProtocol.setResponse(
            statusCode: 200,
            mimeType: "image/png",
            body: imageData,
            includeContentLength: false
        )

        let result = await makeLoader(maximumBytes: imageData.count - 1)
            .load(URL(string: "https://images.example.test/large.png")!)

        XCTAssertNil(result)
    }

    func testBoundedDownloaderRejectsNonImageResponse() async throws {
        let payload = Data("not an image".utf8)
        ImageDownloadStubURLProtocol.setResponse(
            statusCode: 200,
            mimeType: "application/json",
            body: payload
        )

        let result = await makeLoader(maximumBytes: 1_024)
            .load(URL(string: "https://images.example.test/response")!)

        XCTAssertNil(result)
    }

    func testImagePolicyRejectsUnsafeURLsAndOversizedDimensions() {
        XCTAssertFalse(RemoteImagePayloadPolicy.allows(url: URL(string: "http://images.example.test/cover.png")!))
        XCTAssertFalse(RemoteImagePayloadPolicy.allows(url: URL(string: "https://user:pass@images.example.test/cover.png")!))
        XCTAssertTrue(RemoteImagePayloadPolicy.allowsImageDimensions(width: 4_000, height: 4_000))
        XCTAssertFalse(RemoteImagePayloadPolicy.allowsImageDimensions(width: 8_193, height: 1))
        XCTAssertFalse(RemoteImagePayloadPolicy.allowsImageDimensions(width: 8_000, height: 8_000))
        XCTAssertFalse(RemoteImagePayloadPolicy.canAppend(
            currentByteCount: RemoteImagePayloadPolicy.maximumResponseBytes,
            incomingByteCount: 1,
            maximumBytes: RemoteImagePayloadPolicy.maximumResponseBytes
        ))
    }

    override func tearDown() {
        ImageDownloadStubURLProtocol.clearResponse()
        super.tearDown()
    }

    private func makeLoader(maximumBytes: Int) -> BoundedImageDataLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageDownloadStubURLProtocol.self]
        return BoundedImageDataLoader(configuration: configuration, maximumBytes: maximumBytes)
    }
}

private final class ImageDownloadStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let responseStorage = ImageDownloadStubResponseStorage()

    static func setResponse(
        statusCode: Int,
        mimeType: String,
        body: Data,
        includeContentLength: Bool = true
    ) {
        responseStorage.set(ImageStubResponse(
            statusCode: statusCode,
            mimeType: mimeType,
            body: body,
            includeContentLength: includeContentLength
        ))
    }

    static func clearResponse() {
        responseStorage.set(nil)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "images.example.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let stub = Self.responseStorage.get(),
              let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        var headers = ["Content-Type": stub.mimeType]
        if stub.includeContentLength {
            headers["Content-Length"] = String(stub.body.count)
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct ImageStubResponse: Sendable {
    let statusCode: Int
    let mimeType: String
    let body: Data
    let includeContentLength: Bool
}

private final class ImageDownloadStubResponseStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var response: ImageStubResponse?

    func set(_ response: ImageStubResponse?) {
        lock.lock()
        self.response = response
        lock.unlock()
    }

    func get() -> ImageStubResponse? {
        lock.lock()
        defer { lock.unlock() }
        return response
    }
}
