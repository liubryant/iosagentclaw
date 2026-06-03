//
//  ContentView.swift
//  agentClaw
//
//  Created by Liuzheng on 2026/5/16.
//  Email: bryant_liu24@126.com
//

import SwiftUI

struct ContentView: View {
    let container: DependencyContainer
    @State private var onboardingCompleted: Bool

    init(container: DependencyContainer) {
        self.container = container
        _onboardingCompleted = State(initialValue: container.preferences.onboardingCompleted)
    }

    var body: some View {
        if onboardingCompleted {
            ShellView(container: container)
        } else {
            OnboardingView {
                container.preferences.onboardingCompleted = true
                onboardingCompleted = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(container: DependencyContainer())
    }
}
