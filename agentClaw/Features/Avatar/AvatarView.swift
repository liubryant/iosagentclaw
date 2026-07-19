import SwiftUI
import UIKit

struct AvatarView: View {
    @ObservedObject var viewModel: AvatarViewModel
    @StateObject private var digitalHuman = DuixDigitalHumanController.shared
    @State private var waveAnimating = false
    @State private var revealLiveDigitalHuman = false
    @State private var showVip = false
    @State private var showLogin = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            VStack(spacing: 0) {
                avatarStage(topInset: topInset)
                    .frame(height: max(430, proxy.size.height * 0.58 + topInset))
                    .ignoresSafeArea(.container, edges: .top)

                conversationPanel

                composer
            }
            .background(Color.white)
        }
        .background(Color.white)
        .sheet(isPresented: $viewModel.showUpgrade) {
            VipUpgradeSheet(type: .avatar, onGoVip: { showVip = true })
        }
        .vipFullScreenCover(isPresented: $showVip) {
            VipView(isPresented: $showVip, onLoginRequired: { showLogin = true })
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onDisappear {
            viewModel.stopAll()
        }
    }

    private func avatarStage(topInset: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.15, blue: 0.48),
                        Color(red: 0.48, green: 0.35, blue: 0.70),
                        Color(red: 0.62, green: 0.55, blue: 0.80)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image("avatar_agent_portrait")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(revealLiveDigitalHuman ? 0 : 1)
                    .clipped()
                    .animation(.easeOut(duration: 0.28), value: revealLiveDigitalHuman)

                DuixDigitalHumanView(controller: digitalHuman)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(revealLiveDigitalHuman ? 1 : 0)

                LinearGradient(
                    colors: [Color.clear, Color.clear, Color.white.opacity(0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(spacing: 10) {
                    Text("AI数字人")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.27, green: 0.76, blue: 0.98),
                                    Color(red: 0.56, green: 0.57, blue: 0.98),
                                    Color(red: 0.96, green: 0.45, blue: 0.78)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("LILY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.24))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal, 17)
                .padding(.top, topInset + 65)
                .frame(maxHeight: .infinity, alignment: .top)

                if viewModel.isSpeaking || viewModel.isListening || viewModel.isThinking {
                    avatarActivityOverlay
                        .padding(.bottom, 18)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("长按试一试")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: viewModel.canPlayGreeting
                            ? [Color(red: 0.72, green: 0.64, blue: 0.94), Color(red: 0.86, green: 0.73, blue: 0.96)]
                            : [Color(red: 0.66, green: 0.67, blue: 0.70), Color(red: 0.75, green: 0.76, blue: 0.78)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(6)
                .padding(.trailing, 14)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.55) {
                guard viewModel.canPlayGreeting else { return }
                viewModel.playRandomGreeting()
            }
        }
        .onChange(of: digitalHuman.state) { state in
            guard state.isReady else {
                revealLiveDigitalHuman = false
                return
            }
            // Keep the poster visible until Duix has had time to submit its first frame.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                guard digitalHuman.state.isReady else { return }
                revealLiveDigitalHuman = true
            }
        }
        .onAppear {
            if digitalHuman.state.isReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    revealLiveDigitalHuman = digitalHuman.state.isReady
                }
            }
        }
    }

    private var avatarActivityOverlay: some View {
        HStack(spacing: 7) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(Color(red: 0.13, green: 0.44, blue: 0.95))
                    .frame(width: 4, height: activityBarHeight(at: index))
                    .scaleEffect(y: waveAnimating ? 1.0 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.38 + Double(index % 3) * 0.08)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.045),
                        value: waveAnimating
                    )
            }
        }
        .frame(width: 96, height: 62)
        .background(Color.white.opacity(0.88))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
        .onAppear {
            waveAnimating = false
            DispatchQueue.main.async {
                waveAnimating = true
            }
        }
        .onDisappear {
            waveAnimating = false
        }
    }

    private func activityBarHeight(at index: Int) -> CGFloat {
        let heights: [CGFloat] = [16, 30, 21, 34, 24, 30, 18]
        return heights[index]
    }

    private var legacyAvatarHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
                Text("AI数字人")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(viewModel.statusText)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.88))
                Text(digitalHuman.state.message)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.78))
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(viewModel.mood.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AgentClawDesign.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.82))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch viewModel.mood {
        case .idle: return Color.gray
        case .listening: return Color.green
        case .thinking: return Color.orange
        case .speaking: return AgentClawDesign.accent
        case .happy: return Color(red: 0.1, green: 0.65, blue: 0.38)
        case .error: return Color.red
        }
    }

    private var conversationPanel: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 10) {
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(error)
                                .lineLimit(2)
                            Spacer()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color.red)
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                    }

                    ForEach(viewModel.turns) { turn in
                        AvatarTurnBubble(
                            turn: turn,
                            highlightedRange: viewModel.highlightedTurnID == turn.id ? viewModel.highlightedSpeechRange : nil,
                            canReadAloud: !viewModel.isThinking && !viewModel.isListening,
                            onReadAloud: { viewModel.readAloud(turn) }
                        )
                            .id(turn.id)
                    }

                    if viewModel.isThinking {
                        AvatarThinkingIndicator()
                            .id("avatar-thinking")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.turns.count) { _ in
                if let last = viewModel.turns.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        reader.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.highlightedTurnID) { turnID in
                guard let turnID = turnID else { return }
                // A newly appended answer is initially positioned at its bottom.
                // Before the first speech range arrives, reveal its first line.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        reader.scrollTo(turnID, anchor: .top)
                    }
                }
            }
            .onChange(of: viewModel.highlightedSpeechRange?.location) { _ in
                if let turnID = viewModel.highlightedTurnID,
                   let location = viewModel.highlightedSpeechRange?.location {
                    // Wait for the bubble to rebuild its highlighted sentence,
                    // then center that sentence rather than the whole message.
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.2)) {
                            reader.scrollTo(
                                avatarSpeechScrollID(turnID: turnID, location: location),
                                anchor: .center
                            )
                        }
                    }
                }
            }
            .onChange(of: viewModel.isThinking) { thinking in
                if thinking {
                    withAnimation(.easeOut(duration: 0.2)) {
                        reader.scrollTo("avatar-thinking", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: viewModel.toggleListening) {
                    ZStack {
                        Circle()
                            .fill(
                                viewModel.isListening
                                    ? Color(red: 0.96, green: 0.31, blue: 0.36)
                                    : Color(red: 0.35, green: 0.58, blue: 0.94)
                            )
                            .frame(width: 38, height: 38)
                        Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                TextField("和智能体说点什么", text: $viewModel.draft)
                    .focused($inputFocused)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color(red: 0.96, green: 0.97, blue: 0.98))
                    .cornerRadius(8)

                Button(action: {
                    inputFocused = false
                    viewModel.submitDraft()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.canSubmit ? AgentClawDesign.accent : Color.gray.opacity(0.35))
                            .frame(width: 42, height: 42)
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!viewModel.canSubmit)
            }

            if viewModel.isSpeaking || viewModel.isThinking || viewModel.isListening {
                Button(action: viewModel.stopAll) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("停止当前会话")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AgentClawDesign.secondaryText.opacity(0.68))
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.white)
    }

    private func motionChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(AgentClawDesign.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
    }
}

private struct DigitalHumanPlaceholder: View {
    let mood: AvatarMood
    let motion: AvatarMotion
    let isSpeaking: Bool
    let isListening: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: 170, height: 28)
                .offset(y: 116)

            VStack(spacing: 0) {
                head
                    .offset(y: headOffset)
                torso
                    .offset(y: bodyOffset)
            }
            .animation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true), value: motion)
        }
        .frame(height: 260)
    }

    private var head: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.82, blue: 0.68), Color(red: 0.95, green: 0.68, blue: 0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 116, height: 116)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)

            HStack(spacing: 30) {
                eye
                eye
            }
            .offset(y: -10)

            mouth
                .offset(y: 22)

            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 18, height: 18)
                .offset(x: -34, y: -32)
        }
    }

    private var eye: some View {
        Capsule()
            .fill(Color(red: 0.16, green: 0.18, blue: 0.22))
            .frame(width: 11, height: mood == .happy ? 5 : 15)
    }

    private var mouth: some View {
        Group {
            if isSpeaking {
                Capsule()
                    .fill(Color(red: 0.38, green: 0.12, blue: 0.16))
                    .frame(width: 28, height: 18)
                    .scaleEffect(y: motion == .talk ? 1.28 : 0.85)
            } else if mood == .happy {
                ArcSmile()
                    .stroke(Color(red: 0.38, green: 0.12, blue: 0.16), lineWidth: 4)
                    .frame(width: 34, height: 18)
            } else {
                Capsule()
                    .fill(Color(red: 0.38, green: 0.12, blue: 0.16))
                    .frame(width: 24, height: 4)
            }
        }
    }

    private var torso: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.46, green: 0.35, blue: 0.97),
                            Color(red: 0.28, green: 0.70, blue: 0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 138)

            HStack(spacing: 128) {
                arm(rotation: leftArmRotation)
                arm(rotation: rightArmRotation)
            }
            .offset(y: -12)

            Image(systemName: isListening ? "waveform" : "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .offset(y: -8)
    }

    private func arm(rotation: Double) -> some View {
        Capsule()
            .fill(Color(red: 0.46, green: 0.35, blue: 0.97).opacity(0.88))
            .frame(width: 22, height: 96)
            .rotationEffect(.degrees(rotation), anchor: .top)
    }

    private var headOffset: CGFloat {
        switch motion {
        case .listen: return isListening ? -5 : 0
        case .think: return -3
        case .talk: return isSpeaking ? -6 : 0
        case .nod: return 6
        case .wave: return -4
        case .idle: return 0
        }
    }

    private var bodyOffset: CGFloat {
        motion == .talk ? 3 : 0
    }

    private var leftArmRotation: Double {
        motion == .wave ? -54 : -24
    }

    private var rightArmRotation: Double {
        switch motion {
        case .listen: return 28
        case .think: return 44
        case .talk: return 34
        case .wave: return 58
        default: return 24
        }
    }

    private var animationDuration: Double {
        isSpeaking ? 0.28 : 0.9
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(20),
            endAngle: .degrees(160),
            clockwise: false
        )
        return path
    }
}

private struct AvatarTurnBubble: View {
    let turn: AvatarConversationTurn
    let highlightedRange: NSRange?
    let canReadAloud: Bool
    let onReadAloud: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            if turn.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(turn.role == .user ? "我" : "智能体")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AgentClawDesign.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(textSegments) { segment in
                        Text(segment.text)
                            .font(.system(size: 17))
                            .foregroundColor(AgentClawDesign.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, segment.isHighlighted ? 5 : 0)
                            .padding(.vertical, segment.isHighlighted ? 3 : 0)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(segment.isHighlighted ? Color(red: 0.86, green: 0.92, blue: 1.0) : Color.clear)
                            )
                            .id(
                                segment.isHighlighted
                                    ? avatarSpeechScrollID(
                                        turnID: turn.id,
                                        location: highlightedRange?.location ?? 0
                                    )
                                    : "avatar-text-\(turn.id)-\(segment.id)"
                            )
                    }
                }
                .textSelection(.enabled)
                .contextMenu {
                    Button(action: onReadAloud) {
                        Label("朗读", systemImage: "speaker.wave.2.fill")
                    }
                    .disabled(!canReadAloud)

                    Button {
                        UIPasteboard.general.string = turn.content
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
            }
            .padding(10)
            .background(
                turn.role == .user
                    ? Color(red: 0.88, green: 0.93, blue: 1.0)
                    : Color(red: 0.95, green: 0.96, blue: 0.98)
            )
            .cornerRadius(8)

            if turn.role != .user {
                Spacer(minLength: 40)
            }
        }
    }

    private struct TextSegment: Identifiable {
        let id: Int
        let text: String
        let isHighlighted: Bool
    }

    private var textSegments: [TextSegment] {
        guard turn.role == .assistant, let highlightedRange else {
            return [TextSegment(id: 0, text: turn.content, isHighlighted: false)]
        }
        let nsText = turn.content as NSString
        guard highlightedRange.location != NSNotFound, NSMaxRange(highlightedRange) <= nsText.length else {
            return [TextSegment(id: 0, text: turn.content, isHighlighted: false)]
        }
        var result: [TextSegment] = []
        if highlightedRange.location > 0 {
            result.append(TextSegment(id: 0, text: nsText.substring(to: highlightedRange.location), isHighlighted: false))
        }
        result.append(TextSegment(id: 1, text: nsText.substring(with: highlightedRange), isHighlighted: true))
        if NSMaxRange(highlightedRange) < nsText.length {
            result.append(TextSegment(id: 2, text: nsText.substring(from: NSMaxRange(highlightedRange)), isHighlighted: false))
        }
        return result
    }
}

private func avatarSpeechScrollID(turnID: String, location: Int) -> String {
    "avatar-speech-\(turnID)-\(location)"
}

private struct AvatarThinkingIndicator: View {
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

    @State private var index = 0
    @State private var opacity: Double = 1
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AgentClawDesign.accent))
                .scaleEffect(0.72)
            Text(Self.statuses[index])
                .font(.system(size: 13))
                .foregroundColor(AgentClawDesign.primaryText)
                .opacity(opacity)
                .offset(y: offset)
        }
        .padding(.vertical, 8)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        index = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in advance() }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        withAnimation(.easeIn(duration: 0.14)) {
            opacity = 0
            offset = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            index = (index + 1) % Self.statuses.count
            offset = 4
            withAnimation(.easeOut(duration: 0.20)) {
                opacity = 1
                offset = 0
            }
        }
    }
}
