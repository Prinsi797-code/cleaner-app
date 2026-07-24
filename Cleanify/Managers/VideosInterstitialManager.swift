import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class VideosInterstitialManager: NSObject, FullScreenContentDelegate {
    static let shared = VideosInterstitialManager()
    
    private var interstitialAd: InterstitialAd?
    private var isLoading = false
    private var lastShowTime: Date?
    private var pendingDismissAction: (() -> Void)?
    
    override private init() {
        super.init()
    }
    
    func preloadInterstitialAd() {
        if PremiumManager.shared.isPremium { return }
        guard interstitialAd == nil, !isLoading else { return }
        isLoading = true
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            let adUnitID = remoteConfig.configValue(forKey: "videos_inter_id").stringValue ?? "ca-app-pub-3940256099942544/4411468910"
            let flagStr = remoteConfig.configValue(forKey: "videos_inter_flag").stringValue ?? ""
            let flag = Int(flagStr) ?? 3
            
            if self.shouldShowAd(flag: flag, key: "videos_inter") && (adUnitID.contains("ca-app-pub-") || adUnitID.contains("/")) {
                InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                    self?.isLoading = false
                    if let error = error {
                        print("[VideosInterstitialManager] Failed to load: \(error.localizedDescription)")
                        return
                    }
                    self?.interstitialAd = ad
                    self?.interstitialAd?.fullScreenContentDelegate = self
                    print("[VideosInterstitialManager] Preloaded successfully!")
                }
            } else {
                self.isLoading = false
            }
        }
    }
    
    func showAdOnBack(from vc: UIViewController, dismissAction: @escaping () -> Void) {
        if PremiumManager.shared.isPremium {
            dismissAction()
            return
        }
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let flagStr = remoteConfig.configValue(forKey: "videos_inter_flag").stringValue ?? ""
        let flag = Int(flagStr) ?? 3
        
        guard shouldShowAd(flag: flag, key: "videos_inter") else {
            dismissAction()
            return
        }
        
        let now = Date()
        if let lastShow = lastShowTime, now.timeIntervalSince(lastShow) < 10.0 {
            print("[VideosInterstitialManager] Cooldown active (<10s). Skipping ad.")
            dismissAction()
            return
        }
        
        guard let ad = interstitialAd else {
            preloadInterstitialAd()
            dismissAction()
            return
        }
        
        self.pendingDismissAction = dismissAction
        ad.present(from: vc)
        interstitialAd = nil
        markAdShown(flag: flag, key: "videos_inter")
        preloadInterstitialAd()
    }
    
    private func shouldShowAd(flag: Int, key: String) -> Bool {
        switch flag {
        case 0: return false
        case 1:
            let shown = UserDefaults.standard.bool(forKey: "ad_shown_lifetime_\(key)")
            return !shown
        case 2:
            let lastDate = UserDefaults.standard.string(forKey: "ad_shown_daily_\(key)") ?? ""
            return lastDate != todayString()
        case 3: return true
        default: return flag > 0
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
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[VideosInterstitialManager] Ad dismissed.")
        lastShowTime = Date()
        let action = pendingDismissAction
        pendingDismissAction = nil
        action?()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[VideosInterstitialManager] Failed to present: \(error)")
        let action = pendingDismissAction
        pendingDismissAction = nil
        action?()
    }
}
