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
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            Image("launch_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
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
                    // 广告关闭回调与“跳过”触摸处于同一事件周期。
                    // 稍后再创建首页，避免该触摸穿透到画图瀑布流并打开图片详情。
                    let delay = shown ? 0.15 : 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        isWaitingForSplashAd = false
                    }
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
