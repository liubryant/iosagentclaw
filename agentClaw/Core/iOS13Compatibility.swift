//
//  iOS13Compatibility.swift
//  agentClaw
//
//  iOS 13 compatibility helpers
//

import SwiftUI
import UIKit

// MARK: - ProgressView replacement for iOS 13
struct CompatProgressView: View {
    var value: Double? = nil

    var body: some View {
        if #available(iOS 14.0, *) {
            if let value = value {
                ProgressView(value: value)
            } else {
                ProgressView()
            }
        } else {
            ActivityIndicator(isAnimating: .constant(true))
        }
    }
}

struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool
    var style: UIActivityIndicatorView.Style = .medium

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: style)
        view.hidesWhenStopped = true
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}
