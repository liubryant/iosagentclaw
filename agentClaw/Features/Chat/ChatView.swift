import SwiftUI
import Photos
import UIKit
import AVKit
import AVFoundation

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    var onRequestImagePicker: (() -> Void)? = nil
    @State private var activeDocumentSheet: DocumentSheet?
    @State private var inputFocusToken = 0
    @State private var showPickerOverlay = false
    @State private var activePickerSource: ImagePickerSource? = nil
    @State private var activeCameraPickerSource: ImagePickerSource? = nil
    @State private var pickerAlert: PickerAlertMessage?
    @State private var copyMenuMessageID: String?
    @State private var copiedMessageID: String?
    @State private var activeVideoPlayback: VideoPlaybackItem?
    @State private var videoSaveStatus = ""
    @State private var hotspots: [TodayHotspotItem] = []

    private enum ImagePickerSource: Identifiable {
        case camera, gallery
        var id: Int { self == .camera ? 0 : 1 }
    }

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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                content

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                composer
            }
            .background(Color.white)

            if showPickerOverlay {
                ImagePickerOptionsOverlay(
                    cameraAvailability: ImageCaptureAvailability.camera,
                    onDismiss: { withAnimation { showPickerOverlay = false } },
                    onCamera: { presentImagePicker(.camera) },
                    onGallery: { presentImagePicker(.gallery) }
                )
            }
        }
        .onAppear {
            loadHotspots()
        }
        .sheet(item: $activeDocumentSheet) { sheet in
            switch sheet {
            case .preview(let document):
                DocumentPreviewView(url: viewModel.generatedDocumentStore.fileURL(for: document))
            case .export(let document):
                DocumentExportView(url: viewModel.generatedDocumentStore.fileURL(for: document))
            }
        }
        .sheet(item: $activePickerSource) { source in
            ImagePickerView(
                sourceType: source == .camera ? .camera : .photoLibrary,
                onImagePicked: { image in viewModel.attachImage(image) }
            )
        }
        .fullScreenCover(item: $activeCameraPickerSource) { source in
            ImagePickerView(
                sourceType: source == .camera ? .camera : .photoLibrary,
                onImagePicked: { image in viewModel.attachImage(image) }
            )
        }
        .alert(item: $pickerAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("知道了")))
        }
        .chatFullScreenCover(item: $activeVideoPlayback) { item in
            FullScreenGeneratedVideoView(item: item, saveStatus: $videoSaveStatus)
        }
    }

    private func presentImagePicker(_ source: ImagePickerSource) {
        withAnimation { showPickerOverlay = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if source == .camera {
                ImageCaptureAvailability.requestCameraAccessIfNeeded { availability in
                    guard availability.isAvailable else {
                        pickerAlert = PickerAlertMessage(title: "无法拍照", message: availability.message)
                        return
                    }
                    activeCameraPickerSource = source
                }
            } else {
                activePickerSource = source
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
                        AgentThinkingIndicator()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
        }
    }

    private var welcomeState: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#7658F7"), Color(hex: "#C85CC7")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Circle()
                    .stroke(Color.white.opacity(0.75), lineWidth: 2)
                    .padding(4)
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                Image(systemName: "sparkles")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 13, y: -13)
            }
            .frame(width: 48, height: 48)
            .shadow(color: Color(hex: "#7658F7").opacity(0.22), radius: 8, x: 0, y: 4)

            Text("7x24小时，随时随地召唤的全能电脑AI助手")
                .font(.system(size: 12))
                .foregroundColor(AgentClawDesign.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            VStack(spacing: 8) {
                ForEach(displayPrompts) { item in
                    Button(action: {
                        viewModel.resetToDefaultMode()
                        viewModel.draft = item.prompt
                    }) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .lineLimit(1)

                                Text(item.subtitle)
                                    .font(.system(size: 12))
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
        // 图生图响应偶尔会回显作为输入的 data:image/...;base64 数据。
        // 只在助手消息的展示层清理，保留原始响应和发送逻辑不变。
        let mediaContent = message.role == .assistant
            ? ChatMediaParser.stripEmbeddedInputImages(from: message.content)
            : message.content
        let imageURL = message.role == .assistant ? ChatMediaParser.firstImageURL(in: mediaContent) : nil
        let videoURL = message.role == .assistant ? ChatMediaParser.firstVideoURL(in: mediaContent) : nil
        let videoCoverURL = message.role == .assistant ? ChatMediaParser.firstVideoCoverURL(in: mediaContent) : nil
        let displayContent = (imageURL == nil && videoURL == nil)
            ? mediaContent
            : ChatMediaParser.stripMedia(from: mediaContent)
        let copyText = displayContent.isEmpty ? "..." : displayContent
        let hasImage = imageURL != nil
        let hasVideo = videoURL != nil
        let hasDocuments = message.generatedDocuments.isEmpty == false
        let uploadedImages = message.role == .user
            ? message.attachedImageData.compactMap(UIImage.init(data:))
            : []

        // 图片和文档使用更大的宽度，左右间距相等（各18）
        let mediaMaxWidth = availableWidth - 36
        return HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 72)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                Text(message.role == .user ? "我" : "Agent")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AgentClawDesign.secondaryText)

                ForEach(Array(uploadedImages.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: min(220, mediaMaxWidth * 0.72), maxHeight: 240)
                        .background(Color.black.opacity(0.035))
                        .cornerRadius(10)
                }

                if displayContent.isEmpty == false || (!hasImage && !hasVideo) {
                    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 0) {
                        Text(copyText)
                            .font(.system(size: 16))
                            .foregroundColor(AgentClawDesign.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 11)
                            .padding(.top, 8)
                            .padding(.bottom, copyMenuMessageID == message.id || copiedMessageID == message.id ? 6 : 8)

                        if copyMenuMessageID == message.id || copiedMessageID == message.id {
                            Button(action: {
                                UIPasteboard.general.string = copyText
                                withAnimation(.easeOut(duration: 0.12)) {
                                    copiedMessageID = message.id
                                    copyMenuMessageID = nil
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                    if copiedMessageID == message.id {
                                        withAnimation(.easeOut(duration: 0.12)) {
                                            copiedMessageID = nil
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: copiedMessageID == message.id ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(copiedMessageID == message.id ? "已复制" : "复制")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(message.role == .user ? AgentClawDesign.accent : Color(hex: "#2E3138"))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Color.white.opacity(message.role == .user ? 0.72 : 0.95))
                                .cornerRadius(17)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .background(message.role == .user ? Color(red: 0.88, green: 0.93, blue: 1.0) : AgentClawDesign.controlSurface)
                    .cornerRadius(8)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onLongPressGesture {
                        withAnimation(.easeOut(duration: 0.16)) {
                            copiedMessageID = nil
                            copyMenuMessageID = message.id
                        }
                    }
                }

                if let imageURL = imageURL {
                    GeneratedImageView(url: imageURL, maxWidth: mediaMaxWidth)
                }

                if let videoURL = videoURL {
                    GeneratedVideoView(
                        url: videoURL,
                        coverURL: videoCoverURL,
                        maxWidth: mediaMaxWidth,
                        onPlay: { openGeneratedVideo(url: videoURL, coverURL: videoCoverURL) }
                    )
                }

                ForEach(message.generatedDocuments) { document in
                    generatedDocumentCard(document, maxWidth: mediaMaxWidth)
                }
            }

            if message.role != .user {
                // AI消息右边只保留少量间距
                Spacer(minLength: (hasImage || hasVideo || hasDocuments) ? 0 : 20)
            }
        }
    }

    private func openGeneratedVideo(url: URL, coverURL: URL?) {
        videoSaveStatus = "正在保存到文件管理…"
        activeVideoPlayback = VideoPlaybackItem(url: url, coverURL: coverURL)
        viewModel.saveGeneratedVideo(from: url) { result in
            switch result {
            case .success:
                videoSaveStatus = "已保存到文件管理"
            case .failure(let error):
                videoSaveStatus = "保存失败：\(error.localizedDescription)"
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
                    Text("已保存到 Agent/Exports")
                        .font(.system(size: 11))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: { activeDocumentSheet = .preview(document) }) {
                    Text("预览")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 80, height: 32)
                }
                .buttonStyle(DocumentActionButtonStyle())

                Button(action: { activeDocumentSheet = .export(document) }) {
                    Text("分享")
                        .font(.system(size: 12, weight: .medium))
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
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") || lower.hasSuffix(".heic") {
            return "photo.fill"
        }
        if lower.hasSuffix(".html") || lower.hasSuffix(".htm") {
            return "safari"
        }
        if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") {
            return "doc.text"
        }
        return "doc"
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
                .font(.system(size: 12))
                .lineLimit(2)
            Spacer()
        }
        .foregroundColor(Color(red: 0.72, green: 0.12, blue: 0.12))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(red: 1.0, green: 0.93, blue: 0.93))
    }

    // MARK: - Composer (matches Android fragment_shell_chat.xml composerCard structure)

    private var composer: some View {
        VStack(spacing: 0) {
            // Entry mode chips row (chatEntryButtonsRow)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    entryButton(icon: "photo", title: "AI图文", mode: .image)
                    entryButton(icon: "video", title: "AI视频", mode: .video)
                }
                .padding(.horizontal, 4)
            }
            .padding(.top, 8)
            .padding(.bottom, 6)

            // composerInner: #F7F8FA card, 12dp corners
            VStack(spacing: 0) {
                // imageThumbnailRow: shows when image is attached (80×80, 10dp corners)
                if !viewModel.attachedImages.isEmpty {
                    HStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.attachedImages[0])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(10)
                            Button(action: { viewModel.removeAttachedImage(at: 0) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .offset(x: 2, y: -2)
                        }
                        Spacer()
                    }
                    .padding(.leading, 10)
                    .padding(.top, 10)
                }

                // Input row: EditText full-width, buttons overlaid at bottom-right
                ZStack(alignment: .bottomTrailing) {
                    // Text input (full width, paddingBottom leaves room for buttons)
                    ZStack(alignment: .topLeading) {
                        MultilineTextInput(
                            text: $viewModel.draft,
                            focusToken: inputFocusToken,
                            onReturn: {
                                if canSend { viewModel.send() }
                            }
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 96)

                        if viewModel.draft.isEmpty {
                            Text(composerHint)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#A6A6A6"))
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.bottom, 44)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { inputFocusToken += 1 }

                    // Bottom-right buttons (height: 58dp, matches Android LinearLayout gravity=bottom|end)
                    HStack(spacing: 0) {
                        if viewModel.selectedEntryMode == .image {
                            Button(action: {
                                hideKeyboard()
                                if let onRequestImagePicker = onRequestImagePicker {
                                    onRequestImagePicker()
                                } else {
                                    withAnimation { showPickerOverlay = true }
                                }
                            }) {
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#111111"))
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Button(action: {
                            hideKeyboard()
                            viewModel.send()
                        }) {
                            Image(systemName: viewModel.isSending ? "stop.fill" : "paperplane.fill")
                                .font(.system(size: 22))
                                .foregroundColor(canSend ? Color(hex: "#111111") : Color(hex: "#111111").opacity(0.35))
                                .frame(width: 46, height: 46)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!canSend)
                    }
                    .frame(height: 48)
                    .padding(.trailing, 4)
                    .padding(.bottom, 2)
                }
            }
            .background(Color(hex: "#F7F8FA"))
            .cornerRadius(12)
            .padding(.horizontal, 2)

            // Disclaimer
            Text("内容由AI生成，仅供参考")
                .font(.system(size: 12))
                .foregroundColor(AgentClawDesign.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .background(Color.white)
    }

    private var canSend: Bool {
        (viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || viewModel.attachedImages.isEmpty == false)
        && viewModel.isSending == false
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
        let isSelected = viewModel.selectedEntryMode == mode
        let selectedColor = mode == .image ? Color(hex: "#7658F7") : Color(hex: "#1598A8")
        return Button(action: {
            // 反选：再次点击已选中的模式时切回默认模式，但仍然新建一个对话
            let targetMode: ChatEntryMode = isSelected ? .default : mode
            viewModel.createSession(entryMode: targetMode)
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(isSelected ? selectedColor : AgentClawDesign.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(isSelected ? selectedColor.opacity(0.11) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? selectedColor.opacity(0.78) : Color.clear, lineWidth: 1.2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadHotspots() {
        TodayHotspotService.shared.load { result in
            if case .success(let items) = result {
                DispatchQueue.main.async { self.hotspots = items }
            }
        }
    }

    // 动态提示：热点可用时替换静态 quickPrompts，保持相同卡片样式，图片和背景按索引循环复用
    private var displayPrompts: [QuickPrompt] {
        guard !hotspots.isEmpty else { return quickPrompts }
        return hotspots.enumerated().map { index, hotspot in
            let base = quickPrompts[index % quickPrompts.count]
            return QuickPrompt(
                title: hotspot.title,
                subtitle: hotspot.subtitle,
                prompt: hotspot.prompt,
                imageName: base.imageName,
                background: base.background
            )
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

// MARK: - Agent Thinking Indicator
// 复刻安卓 AgentStatusRotator：等待首个助手文本期间，循环展示“Agent 思考过程”状态提示。
// 文案与安卓 chat_agent_thinking_statuses（中文 values-zh）保持一致，切换节奏 4 秒/条，
// 标签切换用淡出上移 + 淡入下移的过渡动画，容器首次出现淡入上移。
private struct AgentThinkingIndicator: View {
    // 顺序与安卓 string-array 完全一致
    private static let statuses = [
        "思考中…",
        "正在理解你的需求…",
        "正在规划任务步骤…",
        "正在调用Search Skill…",
        "搜索相关信息…",
        "正在查询可用结果…",
        "正在分析关键信息…",
        "正在生成回答…"
    ]

    private static let interval: TimeInterval = 4.0
    private static let exitDuration: TimeInterval = 0.14
    private static let enterDuration: TimeInterval = 0.20
    private static let containerDuration: TimeInterval = 0.22

    @State private var index = 0
    @State private var labelOpacity: Double = 1
    @State private var labelOffset: CGFloat = 0
    @State private var containerOpacity: Double = 0
    @State private var containerOffset: CGFloat = 6
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AgentClawDesign.accent))
                .scaleEffect(0.72)
            Text(Self.statuses[index])
                .font(.system(size: 13))
                .foregroundColor(AgentClawDesign.primaryText)
                .opacity(labelOpacity)
                .offset(y: labelOffset)
        }
        .padding(.vertical, 8)
        .opacity(containerOpacity)
        .offset(y: containerOffset)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        index = 0
        labelOpacity = 1
        labelOffset = 0
        // 容器淡入上移
        containerOpacity = 0
        containerOffset = 6
        withAnimation(.easeOut(duration: Self.containerDuration)) {
            containerOpacity = 1
            containerOffset = 0
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { _ in
            advance()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        // 当前文案淡出并上移
        withAnimation(.easeIn(duration: Self.exitDuration)) {
            labelOpacity = 0
            labelOffset = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.exitDuration) {
            index = (index + 1) % Self.statuses.count
            // 新文案从下方淡入
            labelOffset = 4
            withAnimation(.easeOut(duration: Self.enterDuration)) {
                labelOpacity = 1
                labelOffset = 0
            }
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
            .font(.system(size: 12))
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
        try? GeneratedDocumentStore().saveGeneratedImage(image, remoteURL: url)

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

private struct GeneratedVideoView: View {
    let url: URL
    let coverURL: URL?
    let maxWidth: CGFloat
    let onPlay: () -> Void
    @State private var coverImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Button(action: onPlay) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#191A24"), Color(hex: "#303449")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                }

                if isLoading {
                    CompatProgressView()
                }

                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.58))
                        .frame(width: 58, height: 58)
                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 1)
                        .frame(width: 58, height: 58)
                    Image(systemName: "play.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(.white)
                        .offset(x: 2)
                }

                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "video.fill")
                        Text("点击全屏播放")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(14)
                    .padding(10)
                }
            }
            .frame(width: maxWidth, height: min(260, maxWidth * 9 / 16))
            .clipped()
            .cornerRadius(10)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: loadCover)
    }

    private func loadCover() {
        guard coverImage == nil else { return }
        isLoading = true
        if let coverURL = coverURL {
            URLSession.shared.dataTask(with: coverURL) { data, _, _ in
                let image = data.flatMap(UIImage.init(data:))
                DispatchQueue.main.async {
                    if let image = image {
                        coverImage = image
                        isLoading = false
                    } else {
                        loadVideoThumbnail()
                    }
                }
            }.resume()
            return
        }

        loadVideoThumbnail()
    }

    private func loadVideoThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 800, height: 500)
            let time = CMTime(seconds: 0.2, preferredTimescale: 600)
            let image = (try? generator.copyCGImage(at: time, actualTime: nil)).map(UIImage.init(cgImage:))
            DispatchQueue.main.async {
                coverImage = image
                isLoading = false
            }
        }
    }
}

private struct VideoPlaybackItem: Identifiable {
    let url: URL
    let coverURL: URL?
    var id: String { url.absoluteString }
}

private struct FullScreenGeneratedVideoView: View {
    let item: VideoPlaybackItem
    @Binding var saveStatus: String
    @Environment(\.presentationMode) private var presentationMode
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let player = player {
                ChatVideoPlayerController(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                CompatProgressView()
            }

            VStack {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 48)

                Spacer()

                if !saveStatus.isEmpty {
                    Text(saveStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Color.black.opacity(0.62))
                        .cornerRadius(17)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            let nextPlayer = AVPlayer(url: item.url)
            player = nextPlayer
            nextPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }
}

private struct ChatVideoPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
        controller.player?.replaceCurrentItem(with: nil)
        controller.player = nil
    }
}

private extension View {
    @ViewBuilder
    func chatFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        if #available(iOS 14.0, *) {
            fullScreenCover(item: item, content: content)
        } else {
            sheet(item: item, content: content)
        }
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
    private static let videoCoverPattern = #"(?im)^\s*(?:视频封面|cover_image_url|cover image)\s*[:：]\s*(https?://\S+)\s*$"#
    private static let videoCoverJSONPattern = #"\"cover_image_url\"\s*:\s*\"(https?://[^\"]+)\""#
    private static let markdownDataImagePattern = #"!\[[^\]]*]\(data:image/[^)\s]+\)"#
    private static let rawDataImagePattern = #"data:image/[A-Za-z0-9.+-]+;base64,[A-Za-z0-9+/=_-]+"#

    static func stripEmbeddedInputImages(from content: String) -> String {
        let withoutMarkdownDataImages = replacingMatches(
            pattern: markdownDataImagePattern,
            in: content,
            with: ""
        )
        let withoutRawDataImages = replacingMatches(
            pattern: rawDataImagePattern,
            in: withoutMarkdownDataImages,
            with: ""
        )

        return replacingMatches(pattern: #"\n{3,}"#, in: withoutRawDataImages, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstImageURL(in content: String) -> URL? {
        let markdownURLs = matches(pattern: markdownImagePattern, in: content, captureGroup: 1)
        let directURLs = matches(pattern: genericURLPattern, in: content, captureGroup: 0)
        let coverURLs = Set(videoCoverURLs(in: content))
        return (markdownURLs + directURLs)
            .map(normalizeMediaURL)
            .first { isImageURL($0) && !coverURLs.contains($0) }
            .flatMap(URL.init(string:))
    }

    static func firstVideoURL(in content: String) -> URL? {
        matches(pattern: genericURLPattern, in: content, captureGroup: 0)
            .map(normalizeMediaURL)
            .first { isVideoURL($0) }
            .flatMap(URL.init(string:))
    }

    static func firstVideoCoverURL(in content: String) -> URL? {
        videoCoverURLs(in: content)
            .first
            .flatMap(URL.init(string:))
    }

    private static func videoCoverURLs(in content: String) -> [String] {
        let lineURLs = matches(pattern: videoCoverPattern, in: content, captureGroup: 1)
        let jsonURLs = matches(pattern: videoCoverJSONPattern, in: content, captureGroup: 1)
        return (lineURLs + jsonURLs).map(normalizeMediaURL)
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
                    line.hasPrefix("视频封面") == false &&
                    line.hasPrefix("Video cover") == false &&
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
        guard isVideoURL(lower) == false else { return false }
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

// MARK: - Image Picker (iOS 13 compatible via UIImagePickerController, supports camera + gallery)

struct ImagePickerOptionsOverlay: View {
    let cameraAvailability: ImageCaptureAvailability
    let onDismiss: () -> Void
    let onCamera: () -> Void
    let onGallery: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 38, height: 4)
                    .padding(.top, 10)

                Text("选择图片")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color(hex: "#17171D"))
                    .padding(.top, 16)

                Text("请选择图片来源")
                    .font(.system(size: 14))
                    .foregroundColor(AgentClawDesign.secondaryText)
                    .padding(.top, 5)

                HStack(spacing: 12) {
                    optionButton(
                        icon: "camera.fill",
                        colors: [Color(hex: "#4DADF7"), Color(hex: "#617CF4")],
                        label: "拍照",
                        isEnabled: cameraAvailability.isAvailable,
                        action: onCamera
                    )
                    optionButton(
                        icon: "photo.on.rectangle",
                        colors: [Color(hex: "#FF9A68"), Color(hex: "#F16BA5")],
                        label: "从相册选择",
                        isEnabled: true,
                        action: onGallery
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                if !cameraAvailability.isAvailable {
                    Text(cameraAvailability.message)
                        .font(.system(size: 13))
                        .foregroundColor(AgentClawDesign.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 32)
            .frame(
                maxWidth: .infinity,
                minHeight: cameraAvailability.isAvailable ? 300 : 350,
                maxHeight: cameraAvailability.isAvailable ? 300 : 350,
                alignment: .top
            )
            .background(Color(hex: "#FAF9FC"))
            .cornerRadius(24, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.14), radius: 20, x: 0, y: -6)
        }
        .edgesIgnoringSafeArea(.all)
        .transition(.opacity)
    }

    private func optionButton(
        icon: String,
        colors: [Color],
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 11) {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 54, height: 54)
                        .cornerRadius(17)
                        .shadow(color: (colors.first ?? .clear).opacity(0.22), radius: 8, x: 0, y: 4)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#222229"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(Color.white)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "#ECEAF1"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct ImageCaptureAvailability {
    let isAvailable: Bool
    let message: String

    static var camera: ImageCaptureAvailability {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return ImageCaptureAvailability(isAvailable: false, message: "当前设备不支持拍照，请从相册选择图片。")
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            return ImageCaptureAvailability(isAvailable: true, message: "")
        case .denied, .restricted:
            return ImageCaptureAvailability(isAvailable: false, message: "相机权限未开启，请在系统设置中允许访问相机，或从相册选择图片。")
        @unknown default:
            return ImageCaptureAvailability(isAvailable: false, message: "当前无法访问相机，请从相册选择图片。")
        }
    }

    static func requestCameraAccessIfNeeded(completion: @escaping (ImageCaptureAvailability) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            completion(ImageCaptureAvailability(isAvailable: false, message: "当前设备不支持拍照，请从相册选择图片。"))
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted
                        ? ImageCaptureAvailability(isAvailable: true, message: "")
                        : ImageCaptureAvailability(isAvailable: false, message: "相机权限未开启，请在系统设置中允许访问相机，或从相册选择图片。"))
                }
            }
        default:
            DispatchQueue.main.async {
                completion(camera)
            }
        }
    }
}

struct PickerAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
