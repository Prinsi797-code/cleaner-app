//  AdManager.swift
//  cleaner-app
//  Created by Hevin Technoweb on 21/03/26.

import Foundation
import Combine
import GoogleMobileAds
import UIKit

private enum AdStorageKeys {
    static let lastInterDatePrefix = "lastInterDate_"
    static let shownEverPrefix     = "shownEver_"
    static let lastSplashDate      = "lastSplashDate"
}

@MainActor
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published var isFloorInterReady   = false
    @Published var isSplashInterReady  = false
    @Published var isMainInterReady    = false
    @Published var shouldShowResumeAd  = false

    private var floorInterAd:   InterstitialAd?
    private var screenInterAds: [AdScreen: InterstitialAd] = [:]
    private var mainInterAd:    InterstitialAd?
    private var splashInterAd:  InterstitialAd?

    private var splashDismissCallback: (() -> Void)?
    private var interDismissCallback:  (() -> Void)?

    private var isFirstLaunch = true
    private var appResumeObserver: NSObjectProtocol?

    // ✅ Global inter cooldown — kisi bhi screen ki ad dikhane ke baad 5s wait
    private var lastInterShownDate: Date? = nil
    private let interCooldownSeconds: TimeInterval = 20.0

    private var currentConfig: AppAdConfig { RemoteConfigService.shared.adConfig }

    private override init() {
        super.init()
        setupAppResumeObserver()
    }

    // MARK: - GLOBAL COOLDOWN CHECK
    private func isInterOnCooldown() -> Bool {
        guard let last = lastInterShownDate else { return false }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed < interCooldownSeconds {
            print("⏱️ Inter cooldown active. Elapsed: \(String(format: "%.1f", elapsed))s / \(interCooldownSeconds)s")
            return true
        }
        return false
    }

    private func markInterShownNow() {
        lastInterShownDate = Date()
    }

    // MARK: - APP RESUME OBSERVER
    private func setupAppResumeObserver() {
        appResumeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isFirstLaunch { self.isFirstLaunch = false; return }

                let cfg = self.currentConfig.mainScreen
                guard cfg.interFlag != .never else { return }
                guard self.shouldShowInter(screen: .main, flag: cfg.interFlag) else { return }

                if self.mainInterAd != nil {
                    self.shouldShowResumeAd = true
                } else {
                    self.loadMainInterForResume()
                }
            }
        }
    }

    private func loadMainInterForResume() {
        let cfg = currentConfig.mainScreen
        guard cfg.interFlag != .never, !cfg.interId.isEmpty else { return }
        InterstitialAd.load(with: cfg.interId, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                if let error { print("Resume inter load failed: \(error)"); return }
                self.mainInterAd = ad
                self.isMainInterReady = true
                self.shouldShowResumeAd = true
            }
        }
    }

    func showResumeAdIfNeeded(from vc: UIViewController) {
        guard shouldShowResumeAd else { return }
        shouldShowResumeAd = false
        showMainInterIfNeeded(from: vc)
    }

    func initializeSDK() {
        MobileAds.shared.start { status in
            print("AdMob initialized: \(status)")
        }
    }

    // MARK: - FLOOR INTER
    func loadFloorInter() {
        let config = currentConfig
        guard config.floorInterFlag, !config.floorInterId.isEmpty else { return }
        InterstitialAd.load(with: config.floorInterId, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error { print("Floor inter failed: \(error)"); return }
                self?.floorInterAd = ad
                self?.isFloorInterReady = true
            }
        }
    }

    // MARK: - SCREEN INTER
    func loadInterAd(for screen: AdScreen) {
        let cfg = currentConfig.config(for: screen)
        guard cfg.interFlag != .never, !cfg.interId.isEmpty else { return }
        InterstitialAd.load(with: cfg.interId, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error { print("\(screen.rawValue) inter failed: \(error)"); return }
                self?.screenInterAds[screen] = ad
            }
        }
    }

    @discardableResult
    func showInterAd(
        for screen: AdScreen,
        from vc: UIViewController,
        dismissCallback: (() -> Void)? = nil
    ) -> Bool {
        let cfg = currentConfig.config(for: screen)
        guard cfg.interFlag != .never else { return false }
        guard shouldShowInter(screen: screen, flag: cfg.interFlag) else { return false }
        guard !isInterOnCooldown() else { return false }

        // Floor inter pehle
        if currentConfig.floorInterFlag, let floorAd = floorInterAd {
            floorAd.fullScreenContentDelegate = self
            interDismissCallback = dismissCallback
            floorAd.present(from: vc)
            floorInterAd = nil; isFloorInterReady = false
            recordInterShown(screen: screen)
            markInterShownNow()
            loadFloorInter()
            return true
        }

        // Screen inter fallback
        if let ad = screenInterAds[screen] {
            ad.fullScreenContentDelegate = self
            interDismissCallback = dismissCallback
            ad.present(from: vc)
            screenInterAds[screen] = nil
            recordInterShown(screen: screen)
            markInterShownNow()
            loadInterAd(for: screen)
            return true
        }
        return false
    }

    // MARK: - SPLASH INTER
    func loadSplashInter() {
        let cfg = currentConfig.splashScreen
        let adId: String
        if cfg.interId.isEmpty {
            #if DEBUG
            adId = "ca-app-pub-3940256099942544/4411468910"
            print("⚠️ Splash: Remote config ID empty, using TEST ad ID")
            #else
            print("❌ Splash inter load skipped: interId empty")
            return
            #endif
        } else {
            adId = cfg.interId
        }
        print("🔄 Loading splash inter with ID: \(adId)")
        InterstitialAd.load(with: adId, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error { print("❌ Splash inter failed: \(error.localizedDescription)"); return }
                print("✅ Splash inter loaded successfully")
                self?.splashInterAd = ad
                self?.isSplashInterReady = true
            }
        }
    }

    func showSplashInter(from vc: UIViewController, completion: @escaping () -> Void) {
        let key = AdStorageKeys.lastSplashDate
        #if DEBUG
        let cooldown: TimeInterval = 3
        #else
        let cooldown: TimeInterval = 10
        #endif
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            print("⏱️ Splash cooldown active. Elapsed: \(Date().timeIntervalSince(last))s")
            completion(); return
        }
        guard let ad = splashInterAd else {
            print("❌ showSplashInter: splashInterAd is nil")
            completion(); return
        }
        print("▶️ Presenting splash interstitial...")
        splashInterAd = nil
        isSplashInterReady = false
        UserDefaults.standard.set(Date(), forKey: key)
        markInterShownNow()              // ✅ Splash bhi cooldown start karegi
        splashDismissCallback = completion
        ad.fullScreenContentDelegate = self
        ad.present(from: vc)
    }

    // MARK: - MAIN INTER
    func loadMainInter() {
        let cfg = currentConfig.mainScreen
        guard cfg.interFlag != .never, !cfg.interId.isEmpty else { return }
        InterstitialAd.load(with: cfg.interId, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                if let error { print("Main inter failed: \(error)"); return }
                self?.mainInterAd = ad
                self?.isMainInterReady = true
            }
        }
    }

    func showMainInterIfNeeded(from vc: UIViewController) {
        let cfg = currentConfig.mainScreen
        guard cfg.interFlag != .never else { return }
        guard shouldShowInter(screen: .main, flag: cfg.interFlag) else { return }

        // ✅ Resume ad pe bhi cooldown apply hogi
        guard !isInterOnCooldown() else { return }

        guard let ad = mainInterAd else { return }
        mainInterAd = nil; isMainInterReady = false
        recordInterShown(screen: .main)
        markInterShownNow()              // ✅ Cooldown start
        ad.fullScreenContentDelegate = self
        ad.present(from: vc)
        loadMainInter()
    }

    // MARK: - FREQUENCY CAPPING
    private func shouldShowInter(screen: AdScreen, flag: InterAdFlag) -> Bool {
        switch flag {
        case .never:   return false
        case .always:  return true
        case .onceEver:
            return !UserDefaults.standard.bool(forKey: AdStorageKeys.shownEverPrefix + screen.rawValue)
        case .oncePerDay:
            let key = AdStorageKeys.lastInterDatePrefix + screen.rawValue
            guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return true }
            return !Calendar.current.isDateInToday(last)
        }
    }

    private func recordInterShown(screen: AdScreen) {
        let cfg = currentConfig.config(for: screen)
        switch cfg.interFlag {
        case .onceEver:
            UserDefaults.standard.set(true, forKey: AdStorageKeys.shownEverPrefix + screen.rawValue)
        case .oncePerDay:
            UserDefaults.standard.set(Date(), forKey: AdStorageKeys.lastInterDatePrefix + screen.rawValue)
        default: break
        }
    }

    // MARK: - PRELOAD ALL
    func preloadAllAds() {
        loadFloorInter(); loadSplashInter(); loadMainInter()
        loadInterAd(for: .video); loadInterAd(for: .dupVideo)
        loadInterAd(for: .compress); loadInterAd(for: .contact)
        loadInterAd(for: .fileManager); loadInterAd(for: .cache)
    }

    // MARK: - TOP VC
    func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        return findTop(root)
    }

    private func findTop(_ vc: UIViewController) -> UIViewController {
        if let p = vc.presentedViewController { return findTop(p) }
        if let nav = vc as? UINavigationController { return findTop(nav.visibleViewController ?? nav) }
        if let tab = vc as? UITabBarController { return findTop(tab.selectedViewController ?? tab) }
        return vc
    }
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            print("✅ Ad dismissed")
            if let cb = splashDismissCallback { cb(); splashDismissCallback = nil; return }
            if let cb = interDismissCallback  { cb(); interDismissCallback  = nil }
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("❌ Ad failed to present: \(error.localizedDescription)")
            splashDismissCallback?(); splashDismissCallback = nil
            interDismissCallback?();  interDismissCallback  = nil
        }
    }
}
