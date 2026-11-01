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
            
            let isEnabled = remoteConfig.configValue(forKey: "sub_inter_show").boolValue
            let adUnitID = (remoteConfig.configValue(forKey: "sub_inter_id").stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("[VideosInterstitialManager] Remote Config: ID=\(adUnitID), isShow=\(isEnabled)")
            
            guard isEnabled, !adUnitID.isEmpty, adUnitID != "(empty string)", (adUnitID.contains("ca-app-pub-") || adUnitID.contains("/")) else {
                self.isLoading = false
                return
            }
            
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
        }
    }
    
    func showAdOnBack(from vc: UIViewController, dismissAction: @escaping () -> Void) {
        if PremiumManager.shared.isPremium {
            dismissAction()
            return
        }
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let isEnabled = remoteConfig.configValue(forKey: "sub_inter_show").boolValue
        guard isEnabled else {
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
        AnalyticsManager.shared.logInterstitialAdShown(placement: "videos_back")
        ad.present(from: vc)
        interstitialAd = nil
        preloadInterstitialAd()
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
