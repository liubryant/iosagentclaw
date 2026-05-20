import SwiftUI
import Photos
import UIKit

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var activeDocumentSheet: DocumentSheet?
    @State private var inputFocusToken = 0

    private let quickPrompts = [
        QuickPrompt(
            title: "安装你的第一个Skill",
            subtitle: "一键解锁自动化超能力",
            prompt: "帮我规划并安装第一个适合日常自动化的 Skill，需要包含用途、安装步骤和验证方式。",
            imageName: "img_chat_idea_skill",
            background: LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.98),
                    Color(red: 0.90, green: 0.96, blue: 0.98).opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        ),
        QuickPrompt(
            title: "自动化生活助手",
            subtitle: "自动下载应用、淘宝购物",
            prompt: "打开应用宝帮我下载 应用名称：",
            imageName: "img_chat_idea_life",
            background: LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.95),
                    Color(red: 0.98, green: 0.96, blue: 0.95).opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        ),
        QuickPrompt(
            title: "办公文档生成",
            subtitle: "一句话写竞品分析、会议纪要",
            prompt: "帮我生成一份办公文档助手模板，支持竞品分析、会议纪要和待办事项输出。",
            imageName: "img_chat_idea_docs",
            background: LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.98),
                    Color(red: 0.98, green: 0.97, blue: 0.98).opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            content

            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }

            composer
        }
        .background(Color.white)
        .sheet(item: $activeDocumentSheet) { sheet in
            switch sheet {
            case .preview(let document):
                DocumentPreviewView(url: viewModel.generatedDocumentStore.fileURL(for: document))
            case .export(let document):
                DocumentExportView(url: viewModel.generatedDocumentStore.fileURL(for: document))
            }
        }
    }

    private var content: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        welcomeState
                            .padding(.top, 8)
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message, availableWidth: geometry.size.width)
                        }
                    }

                    if viewModel.isSending {
                        thinkingIndicator
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
        }
    }

    private var welcomeState: some View {
        VStack(spacing: 0) {
            Image("img_chat_lobster")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 60)

            Text("Agent Claw")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .padding(.top, 22)

            Text("7x24小时，随时随地召唤的全能电脑AI助手")
                .font(.system(size: 12))
                .foregroundColor(AgentClawDesign.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            VStack(spacing: 8) {
                ForEach(quickPrompts) { item in
                    Button(action: {
                        viewModel.draft = item.prompt
                    }) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .lineLimit(1)

                                Text(item.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(AgentClawDesign.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 30)
                        }
                        .padding(10)
                        .frame(height: 100)
                        .background(item.background)
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func messageBubble(_ message: ChatMessage, availableWidth: CGFloat) -> some View {
        let imageURL = message.role == .assistant ? ChatMediaParser.firstImageURL(in: message.content) : nil
        let displayContent = imageURL == nil ? message.content : ChatMediaParser.stripMedia(from: message.content)
        let hasImage = imageURL != nil
        let hasDocuments = message.generatedDocuments.isEmpty == false

        // 图片和文档使用更大的宽度，左右间距相等（各18）
        let mediaMaxWidth = availableWidth - 36
        // 普通文本消息保持原有布局
        let textMaxWidth = availableWidth - 36 - 72

        return HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 72)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                Text(message.role == .user ? "我" : "AgentClaw")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AgentClawDesign.secondaryText)

                if displayContent.isEmpty == false || imageURL == nil {
                    Text(displayContent.isEmpty ? "..." : displayContent)
                        .font(.system(size: 13))
                        .foregroundColor(AgentClawDesign.primaryText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(message.role == .user ? Color(red: 0.88, green: 0.93, blue: 1.0) : AgentClawDesign.controlSurface)
                        .cornerRadius(8)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let imageURL = imageURL {
                    GeneratedImageView(url: imageURL, maxWidth: mediaMaxWidth)
                }

                ForEach(message.generatedDocuments) { document in
                    generatedDocumentCard(document, maxWidth: mediaMaxWidth)
                }
            }

            if message.role != .user {
                // 如果有图片或文档，右边间距设为0，让内容占满可用宽度
                Spacer(minLength: (hasImage || hasDocuments) ? 0 : 72)
            }
        }
    }

    private func generatedDocumentCard(_ document: GeneratedDocument, maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: documentIcon(for: document.displayName))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AgentClawDesign.accent)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AgentClawDesign.primaryText)
                        .lineLimit(1)
                    Text("已保存到 AgentClaw/Exports")
                        .font(.system(size: 9))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: { activeDocumentSheet = .preview(document) }) {
                    Text("预览")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 80, height: 32)
                }
                .buttonStyle(DocumentActionButtonStyle())

                Button(action: { activeDocumentSheet = .export(document) }) {
                    Text("导出")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 80, height: 32)
                }
                .buttonStyle(DocumentActionButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AgentClawDesign.divider, lineWidth: 1)
        )
    }

    private func documentIcon(for fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".html") || lower.hasSuffix(".htm") {
            return "safari"
        }
        if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") {
            return "doc.text"
        }
        return "doc"
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            CompatProgressView()
                .scaleEffect(0.72)
            Text("思考中")
                .font(.system(size: 11))
                .foregroundColor(AgentClawDesign.secondaryText)
        }
        .padding(.vertical, 8)
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
                .font(.system(size: 10))
                .lineLimit(2)
            Spacer()
        }
        .foregroundColor(Color(red: 0.72, green: 0.12, blue: 0.12))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(red: 1.0, green: 0.93, blue: 0.93))
    }

    private var composer: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    entryButton(icon: "photo", title: "AI图文", mode: .image)
                    entryButton(icon: "video", title: "AI视频", mode: .video)
                }
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    MultilineTextInput(
                        text: $viewModel.draft,
                        focusToken: inputFocusToken,
                        onReturn: {
                            if canSend {
                                viewModel.send()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 118)

                    if viewModel.draft.isEmpty {
                        Text(composerHint)
                            .font(.system(size: 13))
                            .foregroundColor(Color.black.opacity(0.34))
                            .padding(.horizontal, 13)
                            .padding(.top, 15)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    inputFocusToken += 1
                }
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AgentClawDesign.divider, lineWidth: 1)
                )

                Button(action: viewModel.send) {
                    Image(systemName: viewModel.isSending ? "stop.fill" : "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(canSend ? AgentClawDesign.accent : Color.gray.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(canSend == false)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(AgentClawDesign.controlSurface)
    }

    private var canSend: Bool {
        viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && viewModel.isSending == false
    }

    private var composerHint: String {
        switch viewModel.selectedEntryMode {
        case .image:
            return "输入描述你想要的图片"
        case .video:
            return "输入描述你想要的视频"
        case .default:
            return "描述任务或提问任何问题"
        }
    }

    private func entryButton(icon: String, title: String, mode: ChatEntryMode) -> some View {
        Button(action: {
            viewModel.createSession(entryMode: mode)
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(AgentClawDesign.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(viewModel.selectedEntryMode == mode ? AgentClawDesign.accent.opacity(0.16) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.selectedEntryMode == mode ? AgentClawDesign.accent.opacity(0.55) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private enum DocumentSheet: Identifiable {
    case preview(GeneratedDocument)
    case export(GeneratedDocument)

    var id: String {
        switch self {
        case .preview(let document):
            return "preview-\(document.id)"
        case .export(let document):
            return "export-\(document.id)"
        }
    }
}

private struct GeneratedImageView: View {
    let url: URL
    let maxWidth: CGFloat
    @State private var previewImage: UIImage?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var loadFailed = false
    @State private var alertMessage: String?

    var body: some View {
        Button(action: saveToPhotos) {
            ZStack {
                if let previewImage = previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    placeholder(loadFailed ? "图片加载失败" : "图片加载中...")
                }

                if isSaving {
                    CompatProgressView()
                        .scaleEffect(0.82)
                        .padding(10)
                        .background(Color.white.opacity(0.86))
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: maxWidth, maxHeight: maxWidth)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AgentClawDesign.divider, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: loadPreviewImage)
        .alert(isPresented: Binding(
            get: { alertMessage != nil },
            set: { if $0 == false { alertMessage = nil } }
        )) {
            Alert(
                title: Text("图片保存"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("确定"))
            )
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(AgentClawDesign.secondaryText)
            .frame(width: min(220, maxWidth * 0.85), height: min(150, maxWidth * 0.6))
            .background(Color.white)
    }

    private func saveToPhotos() {
        guard isSaving == false else {
            return
        }
        isSaving = true

        if let previewImage = previewImage {
            saveImageToPhotos(previewImage)
            return
        }

        downloadImage { result in
            switch result {
            case .success(let image):
                saveImageToPhotos(image)
            case .failure(let error):
                finishSave(message: "图片下载失败：\(error.localizedDescription)")
            }
        }
    }

    private func loadPreviewImage() {
        guard previewImage == nil, isLoading == false else {
            return
        }
        isLoading = true
        loadFailed = false

        downloadImage { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let image):
                    previewImage = image
                    loadFailed = false
                case .failure:
                    loadFailed = true
                }
            }
        }
    }

    private func downloadImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(GeneratedImageError.invalidImageData))
                return
            }
            completion(.success(image))
        }.resume()
    }

    private func saveImageToPhotos(_ image: UIImage) {
        requestPhotoAuthorization { status in
            guard isPhotoAuthorizationGranted(status) else {
                finishSave(message: "没有相册写入权限")
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    DispatchQueue.main.async {
                        isSaving = false
                        openPhotosApp()
                    }
                } else {
                    finishSave(message: "图片保存失败：\(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }

    private func requestPhotoAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14.0, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: completion)
        } else {
            PHPhotoLibrary.requestAuthorization(completion)
        }
    }

    private func isPhotoAuthorizationGranted(_ status: PHAuthorizationStatus) -> Bool {
        if status == .authorized {
            return true
        }
        if #available(iOS 14.0, *) {
            return status == .limited
        }
        return false
    }

    private func finishSave(message: String) {
        DispatchQueue.main.async {
            isSaving = false
            alertMessage = message
        }
    }

    private func openPhotosApp() {
        guard let url = URL(string: "photos-redirect://") else {
            return
        }
        UIApplication.shared.open(url)
    }
}

private struct DocumentActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AgentClawDesign.primaryText)
            .background(configuration.isPressed ? Color.black.opacity(0.08) : AgentClawDesign.controlSurface)
            .cornerRadius(6)
    }
}

private enum GeneratedImageError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "图片数据无效"
        }
    }
}

private enum ChatMediaParser {
    private static let markdownImagePattern = #"!\[[^\]]*]\((https?://[^)\s]+)\)"#
    private static let genericURLPattern = #"https?://\S+"#

    static func firstImageURL(in content: String) -> URL? {
        let markdownURLs = matches(pattern: markdownImagePattern, in: content, captureGroup: 1)
        let directURLs = matches(pattern: genericURLPattern, in: content, captureGroup: 0)
        return (markdownURLs + directURLs)
            .map(normalizeMediaURL)
            .first { isImageURL($0) }
            .flatMap(URL.init(string:))
    }

    static func stripMedia(from content: String) -> String {
        let withoutMarkdownImages = replacingMatches(
            pattern: markdownImagePattern,
            in: content,
            with: ""
        )

        let cleanedLines = withoutMarkdownImages
            .components(separatedBy: .newlines)
            .map { line -> String in
                replacingMatches(pattern: genericURLPattern, in: line, with: "") { match in
                    let url = normalizeMediaURL(match)
                    return isImageURL(url) || isVideoURL(url) ? "" : match
                }.trimmingCharacters(in: .whitespaces)
            }
            .filter { line in
                line.isEmpty == false &&
                    line.hasPrefix("图片链接") == false &&
                    line.hasPrefix("Image link") == false &&
                    line.hasPrefix("视频链接") == false &&
                    line.hasPrefix("Video link") == false
            }
            .joined(separator: "\n")

        return replacingMatches(pattern: #"\n{3,}"#, in: cleanedLines, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matches(pattern: String, in text: String, captureGroup: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > captureGroup,
                  let range = Range(match.range(at: captureGroup), in: text)
            else {
                return nil
            }
            return String(text[range])
        }
    }

    private static func replacingMatches(
        pattern: String,
        in text: String,
        with replacement: String,
        transform: ((String) -> String)? = nil
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let transform = transform else {
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
        }

        var result = text
        regex.matches(in: text, range: range).reversed().forEach { match in
            guard let range = Range(match.range, in: result) else {
                return
            }
            let matchedText = String(result[range])
            result.replaceSubrange(range, with: transform(matchedText))
        }
        return result
    }

    private static func normalizeMediaURL(_ url: String) -> String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;)]>"))
    }

    private static func isImageURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains(".png") ||
            lower.contains(".jpg") ||
            lower.contains(".jpeg") ||
            lower.contains(".webp") ||
            lower.contains(".gif") ||
            lower.contains("ufileos.com/")
    }

    private static func isVideoURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains(".mp4") ||
            lower.contains(".mov") ||
            lower.contains(".m4v") ||
            lower.contains(".webm") ||
            lower.contains(".m3u8")
    }
}

private struct QuickPrompt: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
    let imageName: String
    let background: LinearGradient
}
