import Foundation
import UIKit
import AVFoundation

enum CreationAssetType {
    case image, video
}

struct CreationAsset: Identifiable {
    let id: String
    let filename: String
    let type: CreationAssetType
    let promptZh: String
    var aspectRatio: CGFloat = 1.0
}

private struct CreationPromptItem: Decodable {
    let image: String
    let promptZh: String

    enum CodingKeys: String, CodingKey {
        case image
        case promptZh = "prompt_zh"
    }
}

final class CreationAssetLoader: ObservableObject {
    static let shared = CreationAssetLoader()

    @Published var images: [CreationAsset] = []
    @Published var videos: [CreationAsset] = []

    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbCache = NSCache<NSString, UIImage>()
    private let launchOrderSalt = UUID().uuidString

    private static let imageExts = ["png", "jpg", "jpeg"]
    private static let videoExts = ["mp4"]
    private static let imageDir = "creation/images"
    private static let videoDir = "creation/videos"
    private static let imagePromptsFile = "image_prompts_zh"

    init() {
        imageCache.totalCostLimit = 30 * 1024 * 1024
        thumbCache.totalCostLimit = 10 * 1024 * 1024
        Task { await loadAll() }
    }

    @MainActor
    func loadAll() async {
        let prompts = Self.loadImagePrompts()
        let imgs = await Task.detached(priority: .utility) {
            Self.enumerate(dir: Self.imageDir, exts: Self.imageExts, type: .image, prompts: prompts)
        }.value
        let vids = await Task.detached(priority: .utility) {
            Self.enumerate(dir: Self.videoDir, exts: Self.videoExts, type: .video, prompts: [:])
        }.value
        images = launchOrdered(imgs)
        videos = vids
    }

    private static func loadImagePrompts() -> [String: String] {
        guard let url = Bundle.main.url(
            forResource: imagePromptsFile,
            withExtension: "json",
            subdirectory: "creation"
        ), let data = try? Data(contentsOf: url),
           let items = try? JSONDecoder().decode([CreationPromptItem].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.image, $0.promptZh) })
    }

    private static func enumerate(
        dir: String,
        exts: [String],
        type: CreationAssetType,
        prompts: [String: String]
    ) -> [CreationAsset] {
        guard let resourceURL = Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: dir) else {
            // Try listing all bundle resources matching the dir prefix
            return enumerateFallback(dir: dir, exts: exts, type: type, prompts: prompts)
        }
        return (try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil))
            .map { urls in
                urls.filter { url in exts.contains(url.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                    .map { url in
                        let name = url.deletingPathExtension().lastPathComponent
                        var asset = CreationAsset(
                            id: name,
                            filename: url.lastPathComponent,
                            type: type,
                            promptZh: prompts[url.lastPathComponent] ?? ""
                        )
                        if type == .image, let img = UIImage(contentsOfFile: url.path) {
                            asset.aspectRatio = img.size.width > 0 ? img.size.height / img.size.width : 1
                        }
                        return asset
                    }
            } ?? []
    }

    private static func enumerateFallback(
        dir: String,
        exts: [String],
        type: CreationAssetType,
        prompts: [String: String]
    ) -> [CreationAsset] {
        guard let allURLs = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: dir) else {
            return []
        }
        return allURLs
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                let name = url.deletingPathExtension().lastPathComponent
                var asset = CreationAsset(
                    id: name,
                    filename: url.lastPathComponent,
                    type: type,
                    promptZh: prompts[url.lastPathComponent] ?? ""
                )
                if type == .image, let img = UIImage(contentsOfFile: url.path) {
                    asset.aspectRatio = img.size.width > 0 ? img.size.height / img.size.width : 1
                }
                return asset
            }
    }

    func loadImage(_ asset: CreationAsset) async -> UIImage? {
        let key = asset.id as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let url = Bundle.main.url(forResource: asset.id, withExtension: URL(fileURLWithPath: asset.filename).pathExtension, subdirectory: "creation/images")
                    ?? Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "creation/images").flatMap({ base in
                        try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil).first { $0.lastPathComponent == asset.filename }
                    }) else { return nil as UIImage? }
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            let thumb = self?.downsampled(image: image, maxDimension: 800) ?? image
            self?.imageCache.setObject(thumb, forKey: key, cost: Int(thumb.size.width * thumb.size.height * 4))
            return thumb
        }.value
    }

    func loadVideoThumbnail(_ asset: CreationAsset) async -> UIImage? {
        let key = (asset.id + "_thumb") as NSString
        if let cached = thumbCache.object(forKey: key) { return cached }
        return await Task.detached(priority: .utility) { [weak self] in
            guard let url = Bundle.main.url(forResource: asset.id, withExtension: URL(fileURLWithPath: asset.filename).pathExtension, subdirectory: "creation/videos")
                    ?? Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "creation/videos").flatMap({ base in
                        try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil).first { $0.lastPathComponent == asset.filename }
                    }) else { return nil as UIImage? }
            let avAsset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: avAsset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 400, height: 400)
            let time = CMTime(seconds: 0.75, preferredTimescale: 600)
            guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
            let thumb = UIImage(cgImage: cgImage)
            self?.thumbCache.setObject(thumb, forKey: key, cost: Int(thumb.size.width * thumb.size.height * 4))
            return thumb
        }.value
    }

    private func downsampled(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return result
    }

    func videoURL(for asset: CreationAsset) -> URL? {
        Bundle.main.url(forResource: asset.id, withExtension: URL(fileURLWithPath: asset.filename).pathExtension, subdirectory: "creation/videos")
        ?? Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "creation/videos").flatMap { base in
            try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil).first { $0.lastPathComponent == asset.filename }
        }
    }

    func shuffled(_ items: [CreationAsset]) -> [CreationAsset] {
        guard items.count > 1 else { return items }
        let shuffled = items.shuffled()
        return shuffled.first?.id == items.first?.id ? Array(items.dropFirst()) + [items[0]] : shuffled
    }

    private func launchOrdered(_ items: [CreationAsset]) -> [CreationAsset] {
        guard items.count > 1 else { return items }
        return items.sorted { lhs, rhs in
            let left = "\(launchOrderSalt)-\(lhs.id)".hashValue
            let right = "\(launchOrderSalt)-\(rhs.id)".hashValue
            if left == right { return lhs.id < rhs.id }
            return left < right
        }
    }
}
