//  SplashView.swift
//  cleaner-app
//  Created by Hevin Technoweb on 21/03/26.

import SwiftUI

struct SplashView: View {
    @State private var isActive       = false
    @State private var scale: CGFloat = 0.75
    @State private var opacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var adAttempted    = false

    @ObservedObject private var adManager = AdManager.shared

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            splashContent
                .onAppear { startSplash() }
                // ✅ Ad ready hote hi dikhao (SDK fast ho to 1-2s mein ready hogi)
                .onChange(of: adManager.isSplashInterReady) { isReady in
                    guard isReady, !adAttempted, !isActive else { return }
                    print("🎯 onChange: splash ad ready, showing now")
                    tryShowSplashAd()
                }
        }
    }

    // MARK: - Splash UI
    private var splashContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtle glow behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .opacity(glowOpacity)
                .animation(.easeIn(duration: 0.9).delay(0.15), value: glowOpacity)

            // Centered logo
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .scaleEffect(scale)
                .opacity(opacity)
                .animation(.spring(response: 0.65, dampingFraction: 0.68), value: scale)
                .animation(.easeIn(duration: 0.4), value: opacity)
        }
    }

    // MARK: - Logic
    private func startSplash() {
        withAnimation {
            scale   = 1.0
            opacity = 1.0
        }
        glowOpacity = 1.0

        // ✅ 3s baad bhi agar ad ready hai aur nahi dikhaya to dikhao
        // (onChange already fast path hai — yeh fallback hai)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if adManager.isSplashInterReady && !adAttempted && !isActive {
                print("⏰ 3s timer: splash ad ready, showing now")
                tryShowSplashAd()
            }
        }

        // ✅ Hard timeout: 6s baad kuch bhi ho, main pe jao
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            if !isActive {
                print("⚠️ Hard timeout: navigating to main without ad")
                navigateToMain()
            }
        }
    }

    private func tryShowSplashAd() {
        guard !adAttempted else { return }
        adAttempted = true

        guard let vc = rootViewController() else {
            print("❌ tryShowSplashAd: rootViewController nil")
            navigateToMain()
            return
        }

        AdManager.shared.showSplashInter(from: vc) {
            navigateToMain()
        }
    }

    // MARK: - VC Helper
    private func rootViewController() -> UIViewController? {
        guard
            let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let root   = window.rootViewController
        else { return nil }
        return topMost(root)
    }

    private func topMost(_ vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController { return topMost(presented) }
        if let nav = vc as? UINavigationController    { return topMost(nav.visibleViewController ?? nav) }
        if let tab = vc as? UITabBarController        { return topMost(tab.selectedViewController ?? tab) }
        return vc
    }

    private func navigateToMain() {
        guard !isActive else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            isActive = true
        }
    }
}
