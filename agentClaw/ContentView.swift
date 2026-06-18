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
    @State private var didRequestSplashAd = false
    @State private var isWaitingForSplashAd: Bool

    init(container: DependencyContainer) {
        self.container = container
        let completed = container.preferences.onboardingCompleted
        _onboardingCompleted = State(initialValue: completed)
        _isWaitingForSplashAd = State(
            initialValue: completed && PangleSplashAdManager.shared.shouldRequestSplashThisSession
        )
    }

    var body: some View {
        if onboardingCompleted {
            ZStack {
                if !isWaitingForSplashAd {
                    ShellView(container: container)
                } else {
                    splashWaitingView
                }
            }
            .onAppear(perform: initializeTrackingAndProceed)
        } else {
            OnboardingView {
                container.preferences.onboardingCompleted = true
                onboardingCompleted = true
                isWaitingForSplashAd = PangleSplashAdManager.shared.shouldRequestSplashThisSession
                requestSplashAdIfNeeded()
            }
        }
    }

    private var splashWaitingView: some View {
        Color.white
            .edgesIgnoringSafeArea(.all)
    }

    private func initializeTrackingAndProceed() {
        // ATT 权限请求必须先于统计/广告 SDK 初始化出现
        TrackingAuthorization.requestIfNeeded {
            UMengAnalytics.shared.initialize()
            requestSplashAdIfNeeded()
        }
    }

    private func requestSplashAdIfNeeded() {
        guard !didRequestSplashAd, PangleSplashAdManager.shared.shouldRequestSplashThisSession else {
            isWaitingForSplashAd = false
            print("csjad splash_request_skip already_requested=true")
            return
        }

        didRequestSplashAd = true
        print("csjad splash_request_prepare slotID=\(PangleSplashAdManager.defaultSplashSlotID)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if isWaitingForSplashAd {
                isWaitingForSplashAd = false
                print("csjad splash_request_timeout_fallback")
            }
        }

        PangleAdManager.shared.initialize { success in
            DispatchQueue.main.async {
                guard success else {
                    isWaitingForSplashAd = false
                    print("csjad splash_request_abort sdk_init_success=false")
                    return
                }

                PangleSplashAdManager.shared.loadAndShowDefaultSplashAd { shown, error in
                    if shown {
                        print("csjad splash_request_complete shown=true")
                    } else {
                        print("csjad splash_request_complete shown=false error=\(error?.localizedDescription ?? "none")")
                    }
                    isWaitingForSplashAd = false
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(container: DependencyContainer())
    }
}
