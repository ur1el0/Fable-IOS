import CryptoKit
import Foundation
import UIKit

@MainActor
public final class DiskImageCache {
    public static let shared = DiskImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let cacheDirectoryURL: URL
    private let diskStorage: DiskImageCacheStorage
    private var inFlightDownloads: [URL: Task<Data?, Never>] = [:]
    private let maximumConcurrentDownloads = 4

    private init() {
        let directoryURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("FableMangaCache", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(
                "FableMangaCache",
                isDirectory: true
            )
        cacheDirectoryURL = directoryURL
        let storage = DiskImageCacheStorage(
            directoryURL: directoryURL,
            maximumUsageBytes: 256 * 1024 * 1024
        )
        diskStorage = storage
        memoryCache.totalCostLimit = 96 * 1024 * 1024
        memoryCache.name = "FableMangaCache"
        Task { await storage.enforceLimit() }
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

    public func diskUsageInBytes() async -> Int64 {
        await diskStorage.diskUsageInBytes()
    }

    public func clearCache() async throws {
        inFlightDownloads.values.forEach { $0.cancel() }
        inFlightDownloads.removeAll()
        memoryCache.removeAllObjects()
        try await diskStorage.clear()
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
                    !task.isCancelled,
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
        await diskStorage.write(data, to: cacheFileURL(for: url))
    }
}

private actor DiskImageCacheStorage {
    private let directoryURL: URL
    private let maximumUsageBytes: Int64

    init(directoryURL: URL, maximumUsageBytes: Int64) {
        self.directoryURL = directoryURL
        self.maximumUsageBytes = maximumUsageBytes
    }

    func write(_ data: Data, to destinationURL: URL) {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try data.write(to: destinationURL, options: .atomic)
            evictOldestFilesIfNeeded()
        } catch {
            return
        }
    }

    func enforceLimit() {
        evictOldestFilesIfNeeded()
    }

    func diskUsageInBytes() -> Int64 {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        return urls.reduce(Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: directoryURL)
    }

    private func evictOldestFilesIfNeeded() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var files = urls.compactMap { url -> (url: URL, size: Int64, modifiedAt: Date)? in
            guard
                let values = try? url.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isRegularFileKey
                ]),
                values.isRegularFile == true,
                let size = values.fileSize
            else {
                return nil
            }
            return (url, Int64(size), values.contentModificationDate ?? .distantPast)
        }
        files.sort { $0.modifiedAt < $1.modifiedAt }

        var usage = files.reduce(Int64(0)) { $0 + $1.size }
        for file in files where usage > maximumUsageBytes {
            do {
                try FileManager.default.removeItem(at: file.url)
                usage -= file.size
            } catch {
                continue
            }
        }
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
