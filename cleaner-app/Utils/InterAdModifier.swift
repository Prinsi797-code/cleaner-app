//  InterAdModifier.swift
//  cleaner-app
//  Created by Hevin Technoweb on 21/03/26.

import SwiftUI
import Combine
import UIKit

// MARK: - AppLifecycleObserver
final class AppLifecycleObserver: ObservableObject {
    @Published var didBecomeActive = false
    private var isFirstLaunch = true

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func appDidBecomeActive() {
        if isFirstLaunch { isFirstLaunch = false; return }
        DispatchQueue.main.async {
            self.didBecomeActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.didBecomeActive = false
            }
        }
    }
}

// MARK: - Global Helper
// Views directly call karein — koi toolbar conflict nahi
@MainActor
func showInterAdThenDismiss(screen: AdScreen, dismiss: @escaping () -> Void) {
    let config = RemoteConfigService.shared.adConfig.config(for: screen)
    guard config.interFlag != .never else { dismiss(); return }

    // Ad ready hai → seedha dikhao
    if tryShowAd(screen: screen, dismiss: dismiss) { return }

    // Ad abhi load nahi hui → 1.5s wait karke retry
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        if !tryShowAd(screen: screen, dismiss: dismiss) {
            dismiss() // tab bhi nahi aayi → dismiss
        }
    }
}
@MainActor
@discardableResult
private func tryShowAd(screen: AdScreen, dismiss: @escaping () -> Void) -> Bool {
    guard let vc = findTopVC() else { dismiss(); return true }
    let shown = AdManager.shared.showInterAd(for: screen, from: vc) {
        DispatchQueue.main.async { dismiss() }
    }
    return shown
}

private func findTopVC() -> UIViewController? {
    guard let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          let root   = window.rootViewController
    else { return nil }
    return topVC(from: root)
}

private func topVC(from vc: UIViewController) -> UIViewController {
    if let p   = vc.presentedViewController { return topVC(from: p) }
    if let nav = vc as? UINavigationController { return topVC(from: nav.visibleViewController ?? nav) }
    if let tab = vc as? UITabBarController     { return topVC(from: tab.selectedViewController ?? tab) }
    return vc
}

// MARK: - BackInterAdModifier
// Views jo .navigationTitle use karte hain unke liye
struct BackInterAdModifier: ViewModifier {
    let screen: AdScreen
    @Environment(\.dismiss) private var dismiss
    @State private var isAdShowing = false

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        guard !isAdShowing else { return }
                        isAdShowing = true
                        showInterAdThenDismiss(screen: screen) {
                            isAdShowing = false
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .disabled(isAdShowing)
                }
            }
            .background(SwipeBackDisabler())
    }
}

// MARK: - SwipeBackDisabler
struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { DisablerVC() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

class DisablerVC: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}

// MARK: - View Extension
extension View {
    func withBackInterAd(screen: AdScreen) -> some View {
        modifier(BackInterAdModifier(screen: screen))
    }
}
