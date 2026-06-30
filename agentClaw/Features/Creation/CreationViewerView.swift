import SwiftUI
import AVKit

struct CreationViewerView: View {
    let asset: CreationAsset
    var onCreateSame: ((CreationAssetType) -> Void)?

    @Environment(\.presentationMode) private var presentationMode
    @State private var loadedImage: UIImage? = nil
    @State private var videoURL: URL? = nil
    @State private var isLoading = true
    @State private var player: AVPlayer? = nil
    @State private var playbackEndObserver: NSObjectProtocol?

    // Zoom & pan for images
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    // Video scale
    @State private var videoScale: CGFloat = 1.0
    @State private var videoOffset: CGSize = .zero
    @State private var videoLastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if asset.type == .image {
                imageViewer
            } else {
                videoViewer
            }

            // Top controls
            VStack {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 52)
                Spacer()
            }

            // Bottom button
            VStack {
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    onCreateSame?(asset.type)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("画同款")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#1A0D08"))
                    .frame(width: 140, height: 44)
                    .background(LinearGradient(colors: [Color(hex: "#EBC783"), Color(hex: "#C87830")], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(22)
                }
                .padding(.bottom, 48)
            }

            if isLoading {
                CompatProgressView()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear { loadMedia() }
        .onDisappear(perform: stopPlayback)
    }

    // MARK: - Image Viewer

    private var imageViewer: some View {
        Group {
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(imageScale)
                    .offset(imageOffset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    imageScale = (lastScale * value).clamped(to: 1.0...5.0)
                                }
                                .onEnded { _ in
                                    lastScale = imageScale
                                    if imageScale < 1.0 {
                                        withAnimation { imageScale = 1.0; imageOffset = .zero }
                                        lastScale = 1.0; lastOffset = .zero
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    guard imageScale > 1.0 else { return }
                                    imageOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = imageOffset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if imageScale > 1.2 {
                                imageScale = 1.0; imageOffset = .zero
                                lastScale = 1.0; lastOffset = .zero
                            } else {
                                imageScale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Video Viewer

    private var videoViewer: some View {
        Group {
            if let player = player {
                AVPlayerControllerView(player: player)
                    .scaleEffect(videoScale)
                    .offset(videoOffset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    videoScale = (videoLastScale * value).clamped(to: 1.0...5.0)
                                }
                                .onEnded { _ in
                                    videoLastScale = videoScale
                                },
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation(.spring()) {
                                        if videoScale > 1.2 {
                                            videoScale = 1.0; videoOffset = .zero; videoLastScale = 1.0
                                        } else {
                                            videoScale = 2.5; videoLastScale = 2.5
                                        }
                                    }
                                }
                        )
                    )
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }

    // MARK: - Load

    private func loadMedia() {
        Task {
            if asset.type == .image {
                let img = await CreationAssetLoader.shared.loadImage(asset)
                await MainActor.run {
                    loadedImage = img
                    isLoading = false
                }
            } else {
                guard let url = CreationAssetLoader.shared.videoURL(for: asset) else {
                    await MainActor.run { isLoading = false }
                    return
                }
                let p = AVPlayer(url: url)
                await MainActor.run {
                    player = p
                    isLoading = false
                    p.play()
                    // Loop video
                    playbackEndObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: p.currentItem,
                        queue: .main
                    ) { [weak p] _ in
                        p?.seek(to: .zero)
                        p?.play()
                    }
                }
            }
        }
    }

    private func stopPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        if let playbackEndObserver = playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
    }
}

// MARK: - AVPlayer wrapper (iOS 13 compatible, replaces VideoPlayer)

private struct AVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspect
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        vc.player = player
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
