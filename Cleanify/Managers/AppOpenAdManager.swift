import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class AppOpenAdManager: NSObject, FullScreenContentDelegate {
    static let shared = AppOpenAdManager()
    
    private var appOpenAd: AppOpenAd?
    private var isLoadingAd = false
    private var lastAdShowTime: Date?
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Remote Config Helpers
    private func isAppOpenAdEnabled(remoteConfig: RemoteConfig) -> Bool {
        if PremiumManager.shared.isPremium { return false }
        return remoteConfig.configValue(forKey: "main_app_open_show").boolValue
    }
    
    private func getAppOpenAdUnitID(remoteConfig: RemoteConfig) -> String? {
        let mainID = (remoteConfig.configValue(forKey: "main_app_open_id").stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !mainID.isEmpty && mainID != "(empty string)" {
            return mainID
        }
        let fallbackID = (remoteConfig.configValue(forKey: "app_open_id").stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallbackID.isEmpty && fallbackID != "(empty string)" {
            return fallbackID
        }
        return nil
    }
    
    // MARK: - Fetch and Load Ad
    func fetchAndLoadAd() {
        if PremiumManager.shared.isPremium { return }
        guard appOpenAd == nil, !isLoadingAd else { return }
        isLoadingAd = true
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            let isEnabled = self.isAppOpenAdEnabled(remoteConfig: remoteConfig)
            guard isEnabled, let adUnitID = self.getAppOpenAdUnitID(remoteConfig: remoteConfig) else {
                self.isLoadingAd = false
                print("[AppOpenAdManager] Ad disabled via main_app_open_show or empty ID from Remote Config.")
                return
            }
            
            print("[AppOpenAdManager] Remote Config: ID=\(adUnitID), isShow=\(isEnabled)")
            
            AppOpenAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                self?.isLoadingAd = false
                if let error = error {
                    print("[AppOpenAdManager] Failed to load: \(error.localizedDescription)")
                    return
                }
                self?.appOpenAd = ad
                self?.appOpenAd?.fullScreenContentDelegate = self
                print("[AppOpenAdManager] Loaded successfully!")
            }
        }
    }
    
    func showAdIfAvailable() {
        if PremiumManager.shared.isPremium {
            appOpenAd = nil
            return
        }
        
        let remoteConfig = RemoteConfig.remoteConfig()
        guard isAppOpenAdEnabled(remoteConfig: remoteConfig) else {
            print("[AppOpenAdManager] Ad disabled via main_app_open_show.")
            return
        }
        
        guard let ad = appOpenAd else {
            fetchAndLoadAd()
            return
        }
        
        let now = Date()
        if let lastShow = lastAdShowTime, now.timeIntervalSince(lastShow) < 5.0 {
            print("[AppOpenAdManager] Cooldown active. Skipping presentation.")
            return
        }
        
        if let rootVC = getTopMostViewController() {
            if rootVC.presentedViewController == nil {
                lastAdShowTime = now
                ad.present(from: rootVC)
                appOpenAd = nil
                fetchAndLoadAd()
            }
        }
    }
    
    // MARK: - Lifecycle Notifications
    @objc private func applicationWillEnterForeground() {
        showAdIfAvailable()
    }
    
    // MARK: - GADFullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[AppOpenAdManager] Full screen content dismissed.")
        appOpenAd = nil
        fetchAndLoadAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AppOpenAdManager] Failed to present full screen content: \(error.localizedDescription)")
        appOpenAd = nil
        fetchAndLoadAd()
    }
    
    // MARK: - Topmost View Controller Helper
    private func getTopMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var topVC = rootViewController
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
