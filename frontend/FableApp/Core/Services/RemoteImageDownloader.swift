import Foundation
import ImageIO

enum RemoteImagePayloadPolicy {
    static let maximumResponseBytes = 20 * 1024 * 1024
    static let maximumDimension = 8_192
    static let maximumPixelCount = 16_000_000

    static func allows(url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host?.isEmpty == false
            && url.user == nil
            && url.password == nil
    }

    static func allows(statusCode: Int, mimeType: String?, expectedContentLength: Int64) -> Bool {
        guard (200..<300).contains(statusCode),
              let mimeType,
              mimeType.lowercased().hasPrefix("image/") else {
            return false
        }
        return expectedContentLength < 0 || expectedContentLength <= maximumResponseBytes
    }

    static func canAppend(currentByteCount: Int, incomingByteCount: Int, maximumBytes: Int) -> Bool {
        incomingByteCount >= 0
            && currentByteCount >= 0
            && currentByteCount <= maximumBytes
            && incomingByteCount <= maximumBytes - currentByteCount
    }

    static func allowsImageDimensions(width: Int, height: Int) -> Bool {
        guard width > 0,
              height > 0,
              width <= maximumDimension,
              height <= maximumDimension else {
            return false
        }
        return width <= maximumPixelCount / height
    }

    static func containsDecodableImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              allowsImageDimensions(width: width, height: height) else {
            return false
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }
}

enum RemoteImageDownloader {
    static func downloadData(from url: URL) async -> Data? {
        guard RemoteImagePayloadPolicy.allows(url: url) else {
            return nil
        }
        return await BoundedImageDataLoader().load(url)
    }
}

final class BoundedImageDataLoader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let maximumBytes: Int
    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    private var receivedData = Data()
    private var continuation: CheckedContinuation<Data?, Never>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var isFinished = false

    init(
        configuration: URLSessionConfiguration = .ephemeral,
        maximumBytes: Int = RemoteImagePayloadPolicy.maximumResponseBytes
    ) {
        self.configuration = configuration
        self.maximumBytes = maximumBytes
        super.init()
    }

    func load(_ url: URL) async -> Data? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.lock()
                guard !isFinished else {
                    lock.unlock()
                    continuation.resume(returning: nil)
                    return
                }
                self.continuation = continuation
                lock.unlock()

                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue(
                    "Fable/1.0 (iOS client; https://github.com/ur1el0/Fable-IOS)",
                    forHTTPHeaderField: "User-Agent"
                )
                let task = session.dataTask(with: request)

                lock.lock()
                self.session = session
                self.task = task
                let shouldStart = !isFinished
                lock.unlock()

                if shouldStart {
                    task.resume()
                } else {
                    task.cancel()
                    session.invalidateAndCancel()
                }
            }
        } onCancel: {
            finish(with: nil)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let redirectURL = request.url,
              RemoteImagePayloadPolicy.allows(url: redirectURL) else {
            completionHandler(nil)
            finish(with: nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse,
              RemoteImagePayloadPolicy.allows(
                statusCode: response.statusCode,
                mimeType: response.mimeType,
                expectedContentLength: response.expectedContentLength
              ) else {
            completionHandler(.cancel)
            finish(with: nil)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        let canAppend = RemoteImagePayloadPolicy.canAppend(
            currentByteCount: receivedData.count,
            incomingByteCount: data.count,
            maximumBytes: maximumBytes
        )
        if canAppend {
            receivedData.append(data)
        }
        lock.unlock()

        if !canAppend {
            finish(with: nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let data = error == nil ? receivedData : nil
        lock.unlock()

        guard let data,
              data.count <= maximumBytes,
              RemoteImagePayloadPolicy.containsDecodableImage(data) else {
            finish(with: nil)
            return
        }
        finish(with: data)
    }

    private func finish(with data: Data?) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        let session = self.session
        let task = self.task
        self.continuation = nil
        self.session = nil
        self.task = nil
        receivedData.removeAll(keepingCapacity: false)
        lock.unlock()

        if data == nil {
            task?.cancel()
            session?.invalidateAndCancel()
        } else {
            session?.finishTasksAndInvalidate()
        }
        continuation?.resume(returning: data)
    }
}
