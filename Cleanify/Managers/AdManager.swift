//
//  AdManager.swift
//  Cleanify
//

import UIKit
import GoogleMobileAds
import FirebaseRemoteConfig

class AdManager: NSObject, FullScreenContentDelegate, BannerViewDelegate, NativeAdLoaderDelegate {
    static let shared = AdManager()
    
    // Remote Config fetched parameter values (no static defaults)
    var appOpenId: String = ""
    var mainBannerId: String = ""
    var mainInterId: String = ""
    
    private var appOpenAd: AppOpenAd?
    private var isLoadingAppOpenAd = false
    private var isShowingAppOpenAd = false
    private var loadTime: Date?
    
    // MARK: - Banner Preload Properties
    private var preloadedBanners: [String: BannerView] = [:]
    private var preloadedBannerReadyPlacements: Set<String> = []
    private var loadingBannerPlacements: Set<String> = []
    
    // MARK: - Native Preload Properties
    private var preloadedNativeAds: [String: NativeAd] = [:]
    private var loadingNativePlacements: Set<String> = []
    private var nativeAdLoaders: [String: AdLoader] = [:]
    private var placementToggleKeys: [String: String] = [:]
    
    override private init() {
        super.init()
    }
    
    // MARK: - SDK & Remote Config Initialization
    func initializeSDK() {
        MobileAds.shared.start(completionHandler: nil)
        fetchRemoteConfig()
    }
    
    func fetchRemoteConfig(completion: (() -> Void)? = nil) {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            let openId = (remoteConfig.configValue(forKey: "main_app_open_id").stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !openId.isEmpty && openId != "(empty string)" {
                self.appOpenId = openId
            }
            
            let bannerId = (remoteConfig.configValue(forKey: "main_banner_id").stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !bannerId.isEmpty && bannerId != "(empty string)" {
                self.mainBannerId = bannerId
            }
            
            print("[AdManager] Remote Config loaded: appOpenId=\(self.appOpenId), mainBannerId=\(self.mainBannerId)")
            
            self.preloadCommonAds()
            completion?()
        }
    }
    
    // MARK: - Preloading
    func preloadCommonAds() {
        if PremiumManager.shared.isPremium { return }
        preloadNativeAd(placementIdKey: "main_preload_native_id", toggleKey: "main_banner_show")
        preloadBanner(placementIdKey: "main_preload_banner_id", toggleKey: "main_banner_show")
        preloadBanner(placementIdKey: "main_banner_id", toggleKey: "main_banner_show")
        
        // Common & Sub Section Ads
        SettingsInterstitialManager.shared.preloadInterstitialAd()
        preloadNativeAd(placementIdKey: "sub_native_id", toggleKey: "sub_native_show")
    }
    
    // MARK: - Banner Ads Preload
    func preloadBanner(placementIdKey: String, toggleKey: String) {
        if PremiumManager.shared.isPremium { return }
        placementToggleKeys[placementIdKey] = toggleKey
        guard preloadedBanners[placementIdKey] == nil, !loadingBannerPlacements.contains(placementIdKey) else { return }
        
        let rc = RemoteConfig.remoteConfig()
        let isEnabled = rc.configValue(forKey: toggleKey).boolValue
        let adUnitID = (rc.configValue(forKey: placementIdKey).stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isEnabled, !adUnitID.isEmpty, adUnitID != "(empty string)" else { return }
        
        loadingBannerPlacements.insert(placementIdKey)
        let screenWidth = UIScreen.main.bounds.width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: screenWidth)
        let adView = BannerView(adSize: adSize)
        adView.adUnitID = adUnitID
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false
        
        preloadedBanners[placementIdKey] = adView
        adView.load(Request())
    }
    
    func getPreloadedBanner(placementIdKey: String, for vc: UIViewController) -> (banner: BannerView, isReady: Bool)? {
        if PremiumManager.shared.isPremium { return nil }
        guard let banner = preloadedBanners.removeValue(forKey: placementIdKey) else {
            return nil
        }
        let isReady = preloadedBannerReadyPlacements.contains(placementIdKey)
        preloadedBannerReadyPlacements.remove(placementIdKey)
        loadingBannerPlacements.remove(placementIdKey)
        
        banner.rootViewController = vc
        let toggle = placementToggleKeys[placementIdKey] ?? "main_banner_show"
        preloadBanner(placementIdKey: placementIdKey, toggleKey: toggle)
        return (banner, isReady)
    }
    
    // MARK: - Native Ad Preloading
    func preloadNativeAd(placementIdKey: String, toggleKey: String) {
        if PremiumManager.shared.isPremium { return }
        placementToggleKeys[placementIdKey] = toggleKey
        guard preloadedNativeAds[placementIdKey] == nil, !loadingNativePlacements.contains(placementIdKey) else { return }
        
        let rc = RemoteConfig.remoteConfig()
        let isEnabled = rc.configValue(forKey: toggleKey).boolValue
        let adUnitID = (rc.configValue(forKey: placementIdKey).stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isEnabled, !adUnitID.isEmpty, adUnitID != "(empty string)" else { return }
        
        loadingNativePlacements.insert(placementIdKey)
        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        nativeAdLoaders[placementIdKey] = loader
        loader.load(Request())
    }
    
    func getPreloadedNativeAd(placementIdKey: String) -> NativeAd? {
        if PremiumManager.shared.isPremium { return nil }
        guard let ad = preloadedNativeAds.removeValue(forKey: placementIdKey) else { return nil }
        let toggle = placementToggleKeys[placementIdKey] ?? "main_banner_show"
        preloadNativeAd(placementIdKey: placementIdKey, toggleKey: toggle)
        return ad
    }
    
    // MARK: - BannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("✅ [AdManager] Preloaded Banner ad loaded successfully!")
        for (key, banner) in preloadedBanners where banner === bannerView {
            loadingBannerPlacements.remove(key)
            preloadedBannerReadyPlacements.insert(key)
        }
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("❌ [AdManager] Preloaded Banner failed to load: \(error.localizedDescription)")
        for (key, banner) in preloadedBanners where banner === bannerView {
            loadingBannerPlacements.remove(key)
            preloadedBanners.removeValue(forKey: key)
            preloadedBannerReadyPlacements.remove(key)
        }
    }
    
    // MARK: - NativeAdLoaderDelegate
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("✅ [AdManager] Preloaded Native Ad received successfully!")
        for (key, loader) in nativeAdLoaders where loader === adLoader {
            loadingNativePlacements.remove(key)
            preloadedNativeAds[key] = nativeAd
            nativeAdLoaders.removeValue(forKey: key)
        }
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("❌ [AdManager] Preloaded Native Ad failed to load: \(error.localizedDescription)")
        for (key, loader) in nativeAdLoaders where loader === adLoader {
            loadingNativePlacements.remove(key)
            preloadedNativeAds.removeValue(forKey: key)
            nativeAdLoaders.removeValue(forKey: key)
        }
    }
    
    // MARK: - App Open Ad Implementation
    func loadAppOpenAd() {
        guard !appOpenId.isEmpty, appOpenId != "(empty string)", !isLoadingAppOpenAd else { return }
        isLoadingAppOpenAd = true
        
        let request = Request()
        AppOpenAd.load(with: appOpenId, request: request) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingAppOpenAd = false
            if let error = error {
                print("[AdManager] Failed to load App Open Ad: \(error.localizedDescription)")
                return
            }
            self.appOpenAd = ad
            self.appOpenAd?.fullScreenContentDelegate = self
            self.loadTime = Date()
            print("[AdManager] App Open Ad successfully preloaded.")
        }
    }
    
    private func wasLoadTimeLessThanFourHoursAgo() -> Bool {
        guard let loadTime = loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < 4 * 3600
    }
    
    func showAppOpenAdIfAvailable(viewController: UIViewController? = nil) {
        guard !isShowingAppOpenAd else { return }
        guard let appOpenAd = appOpenAd, wasLoadTimeLessThanFourHoursAgo() else {
            loadAppOpenAd()
            return
        }
        guard let rootVC = viewController ?? topViewController() else { return }
        isShowingAppOpenAd = true
        appOpenAd.present(from: rootVC)
    }
    
    // MARK: - FullScreenContentDelegate
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[AdManager] Full screen ad will dismiss.")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[AdManager] Full screen ad dismissed.")
        isShowingAppOpenAd = false
        if ad is AppOpenAd {
            appOpenAd = nil
            loadAppOpenAd()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] Full screen ad failed to present: \(error.localizedDescription)")
        isShowingAppOpenAd = false
        if ad is AppOpenAd {
            appOpenAd = nil
            loadAppOpenAd()
        }
    }
    
    // Helper to get active top controller
    private func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        let controller = controller ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
