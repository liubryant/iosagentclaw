import Foundation

struct GeneratedDocumentSaveResult {
    let displayContent: String
    let documents: [GeneratedDocument]
}

final class GeneratedDocumentStore {
    private let fileManager: FileManager
    private let baseDirectoryName = "AgentClaw/Exports"

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
