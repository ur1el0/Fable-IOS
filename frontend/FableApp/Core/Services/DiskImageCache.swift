import CryptoKit
import Foundation
import UIKit

@MainActor
public final class DiskImageCache {
    public static let shared = DiskImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let cacheDirectoryURL: URL
    private var inFlightDownloads: [URL: Task<Data?, Never>] = [:]
    private let maximumConcurrentDownloads = 4

    private init() {
        cacheDirectoryURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("FableMangaCache", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(
                "FableMangaCache",
                isDirectory: true
            )
        memoryCache.totalCostLimit = 96 * 1024 * 1024
        memoryCache.name = "FableMangaCache"
    }

    public func image(for url: URL) -> UIImage? {
        if let cachedImage = memoryCache.object(forKey: url as NSURL) {
            return cachedImage
        }

        guard
            let data = try? Data(contentsOf: cacheFileURL(for: url), options: .mappedIfSafe),
            let image = UIImage(data: data)
        else {
            return nil
        }

        cacheInMemory(image, for: url)
        return image
    }

    public func store(_ image: UIImage, for url: URL) async {
        guard let data = image.jpegData(compressionQuality: 0.88) ?? image.pngData() else {
            return
        }

        cacheInMemory(image, for: url)
        await write(data, for: url)
    }

    public func prefetch(urls: [URL]) async {
        var seen = Set<URL>()
        let uncachedURLs = urls.filter { url in
            guard
                let scheme = url.scheme?.lowercased(),
                scheme == "https" || scheme == "http",
                seen.insert(url).inserted
            else {
                return false
            }

            return image(for: url) == nil
        }

        guard !uncachedURLs.isEmpty else {
            return
        }

        for batchStart in stride(
            from: 0,
            to: uncachedURLs.count,
            by: maximumConcurrentDownloads
        ) {
            let batchEnd = min(batchStart + maximumConcurrentDownloads, uncachedURLs.count)
            let batch = Array(uncachedURLs[batchStart..<batchEnd])
            var pendingDownloads: [(URL, Task<Data?, Never>)] = []

            for url in batch {
                let task = inFlightDownloads[url] ?? Task.detached(priority: .utility) {
                    await downloadImageData(from: url)
                }
                inFlightDownloads[url] = task
                pendingDownloads.append((url, task))
            }

            for (url, task) in pendingDownloads {
                guard
                    let data = await task.value,
                    let image = UIImage(data: data)
                else {
                    inFlightDownloads[url] = nil
                    continue
                }

                if memoryCache.object(forKey: url as NSURL) == nil {
                    cacheInMemory(image, for: url)
                    await write(data, for: url)
                }
                inFlightDownloads[url] = nil
            }
        }
    }

    private func cacheFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectoryURL.appendingPathComponent(filename, isDirectory: false)
    }

    private func cacheInMemory(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    private func write(_ data: Data, for url: URL) async {
        let directoryURL = cacheDirectoryURL
        let destinationURL = cacheFileURL(for: url)

        await Task.detached(priority: .utility) {
            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
                try data.write(to: destinationURL, options: .atomic)
            } catch {
                return
            }
        }.value
    }
}

private func downloadImageData(from url: URL) async -> Data? {
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard
            let response = response as? HTTPURLResponse,
            (200..<300).contains(response.statusCode),
            !data.isEmpty
        else {
            return nil
        }

        return data
    } catch {
        return nil
    }
}
