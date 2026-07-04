import Foundation
import UIKit

struct GeneratedDocumentSaveResult {
    let displayContent: String
    let documents: [GeneratedDocument]
}

final class GeneratedDocumentStore {
    private let fileManager: FileManager
    private let baseDirectoryName = "Agent/Exports"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var exportsDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(baseDirectoryName, isDirectory: true)
    }

    func fileURL(for document: GeneratedDocument) -> URL {
        exportsDirectory.appendingPathComponent(document.relativePath)
    }

    func saveGeneratedImage(_ image: UIImage, remoteURL: URL?) throws -> GeneratedDocument {
        createExportsDirectoryIfNeeded()
        let fileName = imageFileName(from: remoteURL)
        let destination = uniqueURL(for: fileName)
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(
                domain: "GeneratedDocumentStore.Image",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "图片编码失败"]
            )
        }
        try data.write(to: destination, options: .atomic)
        return GeneratedDocument(
            displayName: destination.lastPathComponent,
            relativePath: destination.lastPathComponent,
            mimeType: "image/jpeg"
        )
    }

    func allExportedFiles() -> [GeneratedDocument] {
        createExportsDirectoryIfNeeded()
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .contentModificationDateKey]
        let urls = (try? fileManager.contentsOfDirectory(
            at: exportsDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile != false else { return nil }
            return GeneratedDocument(
                id: url.lastPathComponent,
                displayName: url.lastPathComponent,
                relativePath: url.lastPathComponent,
                mimeType: mimeType(for: url.pathExtension),
                createdAt: values?.creationDate ?? values?.contentModificationDate ?? Date()
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func saveGeneratedDocuments(from assistantContent: String, fallbackTitle: String) -> GeneratedDocumentSaveResult {
        let blocks = parseFileBlocks(in: assistantContent)
        guard blocks.isEmpty == false else {
            return GeneratedDocumentSaveResult(displayContent: assistantContent, documents: [])
        }

        createExportsDirectoryIfNeeded()
        let saved = blocks.compactMap { block -> GeneratedDocument? in
            let fileName = sanitizedFileName(block.fileName, fallbackTitle: fallbackTitle, language: block.language)
            let url = uniqueURL(for: fileName)
            do {
                try Data(block.content.utf8).write(to: url, options: .atomic)
                return GeneratedDocument(
                    displayName: url.lastPathComponent,
                    relativePath: url.lastPathComponent,
                    mimeType: mimeType(for: url.pathExtension)
                )
            } catch {
                return nil
            }
        }

        let display = removeFileBlocks(from: assistantContent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDisplay = saved.isEmpty ? assistantContent : "已生成 \(saved.count) 个文件。"
        return GeneratedDocumentSaveResult(
            displayContent: display.isEmpty ? fallbackDisplay : display,
            documents: saved
        )
    }

    func downloadAndSaveMedia(
        from remoteURL: URL,
        defaultPrefix: String,
        mimeType: String,
        completion: @escaping (Result<GeneratedDocument, Error>) -> Void
    ) {
        createExportsDirectoryIfNeeded()
        let fileName = mediaFileName(from: remoteURL, defaultPrefix: defaultPrefix, mimeType: mimeType)
        let destination = exportsDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destination.path) {
            completion(.success(GeneratedDocument(
                displayName: destination.lastPathComponent,
                relativePath: destination.lastPathComponent,
                mimeType: mimeType
            )))
            return
        }

        URLSession.shared.downloadTask(with: remoteURL) { [weak self] temporaryURL, response, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(NSError(
                    domain: "GeneratedDocumentStore.Media",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "视频下载失败（HTTP \(httpResponse.statusCode)）"]
                )))
                return
            }
            guard let temporaryURL = temporaryURL else {
                completion(.failure(NSError(
                    domain: "GeneratedDocumentStore.Media",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "视频下载失败"]
                )))
                return
            }

            do {
                self.createExportsDirectoryIfNeeded()
                if self.fileManager.fileExists(atPath: destination.path) == false {
                    try self.fileManager.moveItem(at: temporaryURL, to: destination)
                }
                let resolvedMime = (response as? HTTPURLResponse)?.mimeType ?? mimeType
                completion(.success(GeneratedDocument(
                    displayName: destination.lastPathComponent,
                    relativePath: destination.lastPathComponent,
                    mimeType: resolvedMime
                )))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private struct FileBlock {
        let language: String
        let fileName: String?
        let content: String
    }

    private func parseFileBlocks(in text: String) -> [FileBlock] {
        let pattern = #"```([A-Za-z0-9_-]+)([^\n`]*)\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard
                let languageRange = Range(match.range(at: 1), in: text),
                let metaRange = Range(match.range(at: 2), in: text),
                let contentRange = Range(match.range(at: 3), in: text)
            else {
                return nil
            }

            let language = String(text[languageRange]).lowercased()
            guard ["file", "html", "md", "markdown", "txt", "text"].contains(language) else {
                return nil
            }

            let meta = String(text[metaRange])
            let content = String(text[contentRange]).trimmingCharacters(in: .newlines)
            let fileName = extractFileName(from: meta)
            guard fileName != nil || ["html", "md", "markdown", "txt", "text"].contains(language) else {
                return nil
            }
            return FileBlock(language: language, fileName: fileName, content: content)
        }
    }

    private func removeFileBlocks(from text: String) -> String {
        let pattern = #"```(?:file|html|md|markdown|txt|text)[^\n`]*\n[\s\S]*?```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private func extractFileName(from metadata: String) -> String? {
        let patterns = [
            #"path\s*=\s*"([^"]+)""#,
            #"filename\s*=\s*"([^"]+)""#,
            #"file\s*=\s*"([^"]+)""#,
            #"path\s*=\s*([^\s]+)"#,
            #"filename\s*=\s*([^\s]+)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(metadata.startIndex..<metadata.endIndex, in: metadata)
            guard
                let match = regex.firstMatch(in: metadata, range: range),
                match.numberOfRanges > 1,
                let valueRange = Range(match.range(at: 1), in: metadata)
            else {
                continue
            }
            return String(metadata[valueRange])
        }
        return nil
    }

    private func sanitizedFileName(_ proposed: String?, fallbackTitle: String, language: String) -> String {
        let raw = proposed?.split(separator: "/").last.map(String.init)
            ?? "\(fallbackTitle)-\(timestamp()).\(defaultExtension(for: language))"
        let cleaned = raw
            .replacingOccurrences(of: #"[\\/:*?"<>|]"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "document-\(timestamp()).\(defaultExtension(for: language))"
        let named = cleaned.isEmpty ? fallback : cleaned
        return named.contains(".") ? named : "\(named).\(defaultExtension(for: language))"
    }

    private func uniqueURL(for fileName: String) -> URL {
        let base = exportsDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: base.path) else {
            return base
        }
        let name = base.deletingPathExtension().lastPathComponent
        let ext = base.pathExtension
        var index = 2
        while true {
            let candidateName = ext.isEmpty ? "\(name)-\(index)" : "\(name)-\(index).\(ext)"
            let candidate = exportsDirectory.appendingPathComponent(candidateName)
            if fileManager.fileExists(atPath: candidate.path) == false {
                return candidate
            }
            index += 1
        }
    }

    private func mediaFileName(from remoteURL: URL, defaultPrefix: String, mimeType: String) -> String {
        let remoteName = remoteURL.lastPathComponent
            .replacingOccurrences(of: #"[\\/:*?\"<>|]"#, with: "_", options: .regularExpression)
        let fallbackExtension = mimeType == "video/mp4" ? "mp4" : "bin"
        if !remoteName.isEmpty, remoteName.contains(".") {
            return remoteName
        }
        let stableID = stableIdentifier(for: remoteURL.absoluteString)
        return "\(defaultPrefix)-\(stableID).\(fallbackExtension)"
    }

    private func imageFileName(from remoteURL: URL?) -> String {
        guard let remoteURL = remoteURL else {
            return "generated-image-\(timestamp()).jpg"
        }
        let stableID = stableIdentifier(for: remoteURL.absoluteString)
        return "generated-image-\(stableID).jpg"
    }

    private func stableIdentifier(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func createExportsDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
    }

    private func defaultExtension(for language: String) -> String {
        switch language {
        case "html":
            return "html"
        case "md", "markdown":
            return "md"
        default:
            return "txt"
        }
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm":
            return "text/html"
        case "md", "markdown":
            return "text/markdown"
        case "txt":
            return "text/plain"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        default:
            return "application/octet-stream"
        }
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
