import SwiftUI
import UIKit

enum VipUpgradeType: Identifiable {
    case image, video, avatar

    var id: Int {
        switch self {
        case .image: return 0
        case .video: return 1
        case .avatar: return 2
        }
    }
}

struct CreationGalleryView: View {
    var onLaunchImageChat: ((String) -> Void)?
    var onLaunchVideoChat: (() -> Void)?

    @ObservedObject private var loader = CreationAssetLoader.shared
    @State private var selectedTab: Tab = .image
    @State private var viewerAsset: CreationAsset? = nil
    @State private var showUpgrade: VipUpgradeType? = nil
    @State private var showVip = false
    @State private var showLogin = false

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private func fs(_ size: CGFloat) -> CGFloat { isPad ? ceil(size * 1.16) : size }

    enum Tab { case image, video }
    var body: some View {
        ZStack {
            Color(hex: "#FFFDFD").edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                creationHeader
                pillTabBar
                ScrollView {
                    VStack(spacing: 0) {
                        featureCards
                            .padding(.top, 16)
                        inspirationHeader
                        galleryGrid
                            .padding(.bottom, 24)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(horizontalPageSwipe)
            }
        }
        .creationFullScreenCover(item: $viewerAsset) { asset in
            CreationViewerView(asset: asset, onCreateSame: { selectedAsset in
                switch selectedAsset.type {
                case .image: tryLaunchImageChat(prompt: selectedAsset.promptZh)
                case .video: tryLaunchVideoChat()
                }
            })
        }
        .sheet(item: $showUpgrade) { type in
            VipUpgradeSheet(type: type, onGoVip: { showVip = true })
        }
        .vipFullScreenCover(isPresented: $showVip) {
            VipView(isPresented: $showVip, onLoginRequired: { showLogin = true })
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onAppear {
            Task { await CreationAssetLoader.shared.loadAll() }
        }
    }

    private var horizontalPageSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.25, abs(horizontal) > 48 else { return }

                if horizontal < 0, selectedTab == .image {
                    selectTab(.video)
                } else if horizontal > 0, selectedTab == .video {
                    selectTab(.image)
                }
            }
    }

    private func selectTab(_ tab: Tab) {
        guard selectedTab != tab else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.26)) {
            selectedTab = tab
        }
    }

    // MARK: - Header (gradient title, matches Android GradientTextView 27sp)

    private var creationHeader: some View {
        gradientText("今天用AI创作什么？", size: fs(30))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isPad ? 28 : 20)
            .padding(.top, isPad ? 52 : 44)
            .padding(.bottom, isPad ? 32 : 26)
    }

    private func gradientText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(.clear)
            .overlay(
                LinearGradient(
                    colors: [Color(hex: "#7558F7"), Color(hex: "#D06BCB")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .mask(
                Text(text)
                    .font(.system(size: size, weight: .bold))
            )
    }

    // MARK: - Pill Tab Bar (bg_creation_tabs: #F0F0F5, selected gradient #7557F6→#A451EE)

    private var pillTabBar: some View {
        HStack(spacing: 4) {
            pillTabButton(title: "图片", tab: .image)
            pillTabButton(title: "视频", tab: .video)
        }
        .padding(4)
        .background(Color(hex: "#F0F0F5"))
        .cornerRadius(18)
        .padding(.horizontal, isPad ? 28 : 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    private func pillTabButton(title: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: {
            selectTab(tab)
        }) {
            Text(title)
                .font(.system(size: fs(15), weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#696B76"))
                .frame(maxWidth: .infinity)
                .frame(height: isPad ? 50 : 44)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [Color(hex: "#7557F6"), Color(hex: "#A451EE")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        } else {
                            LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .cornerRadius(15)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Feature Cards (104dp, gradient colored, bottom-aligned content)

    private var featureCards: some View {
        HStack(spacing: 12) {
            if selectedTab == .image {
                gradientFeatureCard(
                    title: "文生图",
                    hint: "一句灵感，生成视觉作品",
                    icon: "sparkles",
                    isPrimary: true,
                    action: { tryLaunchImageChat() }
                )
                gradientFeatureCard(
                    title: "图生图",
                    hint: "上传参考图，重新设计",
                    icon: "square.stack",
                    isPrimary: false,
                    action: { tryLaunchImageChat() }
                )
            } else {
                gradientFeatureCard(
                    title: "文生视频",
                    hint: "让文字灵感动起来",
                    icon: "sparkles",
                    isPrimary: true,
                    action: tryLaunchVideoChat
                )
                gradientFeatureCard(
                    title: "图生视频",
                    hint: "让静态画面自然流动",
                    icon: "square.stack",
                    isPrimary: false,
                    action: tryLaunchVideoChat
                )
            }
        }
        .padding(.horizontal, isPad ? 28 : 16)
        .animation(.default, value: selectedTab)
    }

    private func gradientFeatureCard(
        title: String,
        hint: String,
        icon: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            ZStack(alignment: .bottomLeading) {
                // Gradient background
                (isPrimary
                    ? LinearGradient(
                        colors: [Color(hex: "#7558F7"), Color(hex: "#9A56EE"), Color(hex: "#D06BCB")],
                        startPoint: .topTrailing, endPoint: .bottomLeading)
                    : LinearGradient(
                        colors: [Color(hex: "#187FD8"), Color(hex: "#1EA7D5"), Color(hex: "#5CC6BE")],
                        startPoint: .topTrailing, endPoint: .bottomLeading))
                    .cornerRadius(22)

                // Bottom-aligned content (matches Android gravity="bottom")
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: fs(27)))
                        .foregroundColor(.white)
                    Text(title)
                        .font(.system(size: fs(16), weight: .bold))
                        .foregroundColor(.white)
                    Text(hint)
                        .font(.system(size: fs(12)))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(isPad ? 18 : 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isPad ? 128 : 104)
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Inspiration Header

    private var inspirationHeader: some View {
        HStack {
            Text("灵感")
                .font(.system(size: fs(18), weight: .bold))
                .foregroundColor(Color(hex: "#1C1C22"))
            Spacer()
        }
        .padding(.horizontal, isPad ? 28 : 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: - Gallery Grid (2-column staggered)

    private var galleryGrid: some View {
        let items = selectedTab == .image ? loader.images : loader.videos
        let columns = masonryColumns(for: items)
        return ZStack {
            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 6) {
                    ForEach(columns.left) { asset in
                        galleryCell(asset: asset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 6) {
                    ForEach(columns.right) { asset in
                        galleryCell(asset: asset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }

            if loader.isLoading && items.isEmpty {
                VStack(spacing: 10) {
                    CompatProgressView()
                        .scaleEffect(1.15)
                    Text(selectedTab == .image ? "图片加载中…" : "视频加载中…")
                        .font(.system(size: fs(13)))
                        .foregroundColor(Color(hex: "#8A8B93"))
                }
                .frame(maxWidth: .infinity, minHeight: isPad ? 300 : 220)
            }
        }
        .padding(.horizontal, 6)
        .animation(.default, value: selectedTab)
    }

    private func masonryColumns(for items: [CreationAsset]) -> (left: [CreationAsset], right: [CreationAsset]) {
        var left: [CreationAsset] = []
        var right: [CreationAsset] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for item in items {
            let estimatedHeight = item.type == .image ? max(item.aspectRatio, 0.35) : 9.0 / 16.0
            if leftHeight <= rightHeight {
                left.append(item)
                leftHeight += estimatedHeight
            } else {
                right.append(item)
                rightHeight += estimatedHeight
            }
        }
        return (left, right)
    }

    @ViewBuilder
    private func galleryCell(asset: CreationAsset) -> some View {
        if asset.type == .image {
            ImageGalleryCell(asset: asset)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { viewerAsset = asset }
        } else {
            VideoGalleryCell(asset: asset)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { viewerAsset = asset }
        }
    }

    // MARK: - Actions

    private func tryLaunchImageChat(prompt: String = "") {
        if QuotaManager.shared.canGenerateImage() {
            onLaunchImageChat?(prompt)
        } else {
            showUpgrade = .image
        }
    }

    private func tryLaunchVideoChat() {
        if QuotaManager.shared.canGenerateVideo() {
            onLaunchVideoChat?()
        } else {
            showUpgrade = .video
        }
    }
}

private extension View {
    @ViewBuilder
    func creationFullScreenCover<Item: Identifiable, Content: View>(
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

// MARK: - Image Cell

struct ImageGalleryCell: View {
    let asset: CreationAsset
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            Color(hex: "#E8E0F0")
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(Color.gray.opacity(0.4))
            }
        }
        .aspectRatio(asset.aspectRatio > 0 ? 1.0 / asset.aspectRatio : 0.75, contentMode: .fit)
        .clipped()
        .cornerRadius(10)
        .onAppear {
            Task {
                let img = await CreationAssetLoader.shared.loadImage(asset)
                await MainActor.run { image = img }
            }
        }
    }
}

// MARK: - Video Cell

struct VideoGalleryCell: View {
    let asset: CreationAsset
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        ZStack {
            Color(hex: "#1A1A2E")
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(thumbnail != nil ? 0.85 : 0.4))
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipped()
        .cornerRadius(10)
        .onAppear {
            Task {
                let img = await CreationAssetLoader.shared.loadVideoThumbnail(asset)
                await MainActor.run { thumbnail = img }
            }
        }
    }
}

// MARK: - Upgrade Sheet

struct VipUpgradeSheet: View {
    let type: VipUpgradeType
    var onGoVip: (() -> Void)?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text(upgradeTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(hex: "#1A1A2E"))

            quotaCompare(
                icon: "photo.fill",
                title: "AI图片生成",
                freeUsed: QuotaManager.shared.todayImageCount(),
                freeLimit: QuotaManager.shared.freeImageLimit(),
                vipLimit: QuotaManager.shared.vipImageLimit()
            )
            quotaCompare(
                icon: "video.fill",
                title: "AI视频生成",
                freeUsed: QuotaManager.shared.todayVideoCount(),
                freeLimit: QuotaManager.shared.freeVideoLimit(),
                vipLimit: QuotaManager.shared.vipVideoLimit()
            )

            avatarConversationBenefit

            Button(action: {
                presentationMode.wrappedValue.dismiss()
                onGoVip?()
            }) {
                Text("立即开通会员")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(LinearGradient(colors: [Color(hex: "#6750F5"), Color(hex: "#9B7BFE")], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(14)
            }
            .padding(.horizontal, 4)

            Button("稍后再说") { presentationMode.wrappedValue.dismiss() }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .modifier(CompactUpgradeSheetModifier())
    }

    private var upgradeTitle: String {
        switch type {
        case .image: return "今日图片次数已用完"
        case .video: return "今日视频次数已用完"
        case .avatar: return "智能体免费对话次数已用完"
        }
    }

    private var avatarConversationBenefit: some View {
        HStack(spacing: 12) {
            Image("avatar_agent_tab_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color(hex: "#8A72F8").opacity(0.55), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text("智能体对话")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A2E"))
                Text("普通用户：最多 3 次")
                    .font(.system(size: 12))
                    .foregroundColor(AgentClawDesign.secondaryText)
            }
            Spacer()
            Label("无限畅聊", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "#6750F5"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(hex: "#F6F2FF"))
        .cornerRadius(10)
    }

    private func quotaCompare(icon: String, title: String, freeUsed: Int, freeLimit: Int, vipLimit: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#6750F5"))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.85))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(freeUsed)/\(freeLimit)").font(.system(size: 11)).foregroundColor(.gray)
                }
                HStack {
                    Text("免费 \(freeLimit)次/天")
                    Spacer()
                    Text("会员 \(vipLimit)次/天")
                        .foregroundColor(Color(hex: "#6750F5"))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AgentClawDesign.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(hex: "#F6F2FF"))
        .cornerRadius(10)
    }
}

private struct CompactUpgradeSheetModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.height(390)])
        } else {
            content
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
