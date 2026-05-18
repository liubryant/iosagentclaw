import SwiftUI
import UIKit

struct MultilineTextInput: UIViewRepresentable {
    @Binding var text: String
    var focusToken: Int = 0
    var minHeight: CGFloat = 44
    var maxHeight: CGFloat = 110
    var onReturn: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }

        // Do not overwrite active marked text. This keeps Chinese/Japanese/Korean
        // input composition stable on older SwiftUI runtimes.
        if uiView.markedTextRange != nil {
            return
        }
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onReturn: onReturn)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var text: Binding<String>
        private var onReturn: (() -> Void)?
        var lastFocusToken = 0

        init(text: Binding<String>, onReturn: (() -> Void)?) {
            self.text = text
            self.onReturn = onReturn
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                onReturn?()
                return false
            }
            return true
        }
    }
}
