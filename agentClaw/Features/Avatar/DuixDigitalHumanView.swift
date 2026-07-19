import SwiftUI
import UIKit

struct DuixDigitalHumanView: UIViewRepresentable {
    @ObservedObject var controller: DuixDigitalHumanController

    func makeUIView(context: Context) -> DuixDigitalHumanHostView {
        let view = DuixDigitalHumanHostView()
        view.backgroundColor = UIColor(red: 0.34, green: 0.24, blue: 0.56, alpha: 1.0)
        view.clipsToBounds = true
        view.controller = controller
        DispatchQueue.main.async { view.attachIfReady() }
        return view
    }

    func updateUIView(_ uiView: DuixDigitalHumanHostView, context: Context) {
        uiView.controller = controller
        guard !controller.state.isReady else { return }
        uiView.attachIfReady()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            uiView.attachIfReady(force: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            uiView.attachIfReady(force: true)
        }
    }
}

final class DuixDigitalHumanHostView: UIView {
    weak var controller: DuixDigitalHumanController?
    private var didAttach = false
    private var lastAttachedSize: CGSize = .zero

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfReady()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachIfReady()
    }

    func attachIfReady(force: Bool = false) {
        guard window != nil, bounds.width > 1, bounds.height > 1 else { return }
        let currentSize = bounds.size
        guard force || !didAttach || abs(currentSize.width - lastAttachedSize.width) > 1 || abs(currentSize.height - lastAttachedSize.height) > 1 else {
            return
        }
        didAttach = true
        lastAttachedSize = currentSize
        controller?.attach(to: self)
    }
}
