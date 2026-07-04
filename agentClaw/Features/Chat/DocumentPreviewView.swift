import SwiftUI
import UIKit
import WebKit
import AVKit

struct DocumentPreviewView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AgentClawDesign.controlSurface)

            if isImage {
                LocalImagePreview(url: url)
            } else if isVideo {
                LocalVideoPreview(url: url)
            } else {
                DocumentWebPreview(url: url)
            }
        }
    }

    private var isImage: Bool {
        ["jpg", "jpeg", "png", "webp", "heic"].contains(url.pathExtension.lowercased())
    }

    private var isVideo: Bool {
        ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }
}

private struct LocalImagePreview: View {
    let url: URL

    var body: some View {
        ZStack {
            Color.black
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                Text("图片加载失败")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))
            }
        }
    }
}

private struct LocalVideoPreview: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player = player {
                LocalVideoPlayerController(player: player)
            }
        }
        .onAppear {
            let nextPlayer = AVPlayer(url: url)
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

private struct LocalVideoPlayerController: UIViewControllerRepresentable {
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

private struct DocumentWebPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            webView.loadHTMLString(errorHTML("文件不存在：\(url.lastPathComponent)"), baseURL: nil)
            return
        }

        let ext = url.pathExtension.lowercased()
        if ext == "html" || ext == "htm" {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }

        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        webView.loadHTMLString(textPreviewHTML(text, title: url.lastPathComponent), baseURL: nil)
    }

    private func textPreviewHTML(_ text: String, title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapeHTML(title))</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 18px; color: #222; line-height: 1.55; }
        pre { white-space: pre-wrap; word-wrap: break-word; font: 14px Menlo, monospace; }
        </style>
        </head>
        <body><pre>\(escapeHTML(text))</pre></body>
        </html>
        """
    }

    private func errorHTML(_ message: String) -> String {
        """
        <!doctype html>
        <html><body style="font-family:-apple-system;padding:20px;color:#333;">\(escapeHTML(message))</body></html>
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

struct DocumentExportView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // 对于iPad，设置popover的源位置
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            activityVC.popoverPresentationController?.permittedArrowDirections = []
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
