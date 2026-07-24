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
    
    // MARK: - Ad Frequency Flag Logic
    // 0 -> don't show ads
    // 1 -> once in a lifetime
    // 2 -> once in a day
    // 3 -> every time
    private func shouldShowAd(flag: Int, key: String) -> Bool {
        switch flag {
        case 0:
            return false
        case 1:
            let shown = UserDefaults.standard.bool(forKey: "ad_shown_lifetime_\(key)")
            return !shown
        case 2:
            let lastDate = UserDefaults.standard.string(forKey: "ad_shown_daily_\(key)") ?? ""
            let today = todayString()
            return lastDate != today
        case 3:
            return true
        default:
            return flag > 0
        }
    }
    
    private func markAdShown(flag: Int, key: String) {
        if flag == 1 {
            UserDefaults.standard.set(true, forKey: "ad_shown_lifetime_\(key)")
        } else if flag == 2 {
            UserDefaults.standard.set(todayString(), forKey: "ad_shown_daily_\(key)")
        }
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
            
            let adUnitID = remoteConfig.configValue(forKey: "app_open_id").stringValue ?? "ca-app-pub-3940256099942544/5575463023"
            
            // Check main_open_flag or fallback app_open_flag
            var adFlag = 3
            if let flagVal = Int(remoteConfig.configValue(forKey: "main_open_flag").stringValue ?? "") {
                adFlag = flagVal
            } else if let flagVal = Int(remoteConfig.configValue(forKey: "app_open_flag").stringValue ?? "") {
                adFlag = flagVal
            }
            
            print("AppOpenAdManager remote config fetched: ID=\(adUnitID), Flag=\(adFlag)")
            
            if self.shouldShowAd(flag: adFlag, key: "app_open") && (adUnitID.contains("ca-app-pub-") || adUnitID.contains("/")) {
                AppOpenAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                    self?.isLoadingAd = false
                    if let error = error {
                        print("AppOpenAdManager failed to load: \(error.localizedDescription)")
                        return
                    }
                    self?.appOpenAd = ad
                    self?.appOpenAd?.fullScreenContentDelegate = self
                    print("AppOpenAdManager loaded successfully!")
                }
            } else {
                self.isLoadingAd = false
                print("AppOpenAdManager: Invalid or disabled ID/Flag. Skipping load.")
            }
        }
    }
    
    func showAdIfAvailable() {
        if PremiumManager.shared.isPremium {
            appOpenAd = nil
            return
        }
        guard let ad = appOpenAd else {
            fetchAndLoadAd()
            return
        }
        
        let now = Date()
        if let lastShow = lastAdShowTime, now.timeIntervalSince(lastShow) < 5.0 {
            print("AppOpenAdManager: Cooldown active. Skipping presentation.")
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
    
    @objc private func applicationWillEnterForeground() {
        showAdIfAvailable()
    }
    
    private func getTopMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        var topVC = window.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("AppOpenAdManager: Ad dismissed successfully.")
        let remoteConfig = RemoteConfig.remoteConfig()
        let flag = Int(remoteConfig.configValue(forKey: "main_open_flag").stringValue ?? "") ?? 3
        markAdShown(flag: flag, key: "app_open")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AppOpenAdManager: Failed to present: \(error.localizedDescription)")
    }
}
