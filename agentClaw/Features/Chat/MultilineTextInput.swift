import SwiftUI
import UIKit

struct MultilineTextInput: UIViewRepresentable {
    private static let inputTextColor = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
    private static let inputTintColor = UIColor(red: 0.23, green: 0.47, blue: 0.95, alpha: 1)

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
        Self.applyFixedColors(to: textView)
        textView.adjustsFontForContentSizeCategory = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.returnKeyType = .done
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        Self.applyFixedColors(to: uiView)

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

    private static func applyFixedColors(to textView: UITextView) {
        textView.textColor = inputTextColor
        textView.tintColor = inputTintColor
        textView.keyboardAppearance = .light
        textView.typingAttributes[.foregroundColor] = inputTextColor
        textView.typingAttributes[.font] = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
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
                textView.resignFirstResponder()
                onReturn?()
                return false
            }
            return true
        }
    }
}
