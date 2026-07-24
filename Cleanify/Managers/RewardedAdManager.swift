import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class RewardedAdManager: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()
    
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    private var pendingCompletionAction: ((Bool) -> Void)?
    private var earnedReward: Bool = false
    
    override private init() {
        super.init()
    }
    
    func preloadRewardedAd() {
        if PremiumManager.shared.isPremium { return }
        guard rewardedAd == nil, !isLoading else { return }
        isLoading = true
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let adUnitID = remoteConfig.configValue(forKey: "reward_id").stringValue ?? "ca-app-pub-3940256099942544/1712485313"
        let flagStr = remoteConfig.configValue(forKey: "reward_flag").stringValue ?? ""
        let flag = Int(flagStr) ?? 1
        
        if shouldShowAd(flag: flag, key: "reward") && (adUnitID.contains("ca-app-pub-") || adUnitID.contains("/")) {
            RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                self?.isLoading = false
                if let error = error {
                    print("[RewardedAdManager] Failed to load: \(error.localizedDescription)")
                    return
                }
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                print("[RewardedAdManager] Preloaded successfully!")
            }
        } else {
            isLoading = false
        }
    }
    
    func isAdRequired(key: String = "reward") -> Bool {
        if PremiumManager.shared.isPremium { return false }
        let remoteConfig = RemoteConfig.remoteConfig()
        let flagStr = remoteConfig.configValue(forKey: "reward_flag").stringValue ?? ""
        let flag = Int(flagStr) ?? 1
        return shouldShowAd(flag: flag, key: key)
    }
    
    func canShowAd() -> Bool {
        if !isAdRequired() { return true }
        return rewardedAd != nil
    }
    
    func loadAdOnDemand(completion: @escaping (Bool) -> Void) {
        if !isAdRequired() {
            completion(true)
            return
        }
        if rewardedAd != nil {
            completion(true)
            return
        }
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let adUnitID = remoteConfig.configValue(forKey: "reward_id").stringValue ?? "ca-app-pub-3940256099942544/1712485313"
        let flagStr = remoteConfig.configValue(forKey: "reward_flag").stringValue ?? ""
        let flag = Int(flagStr) ?? 1
        
        if shouldShowAd(flag: flag, key: "reward") && (adUnitID.contains("ca-app-pub-") || adUnitID.contains("/")) {
            isLoading = true
            RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                self?.isLoading = false
                if let error = error {
                    print("[RewardedAdManager] On demand load failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                print("[RewardedAdManager] Loaded ad on demand successfully!")
                completion(true)
            }
        } else {
            completion(false)
        }
    }
    
    func showRewardedAd(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        if !isAdRequired() {
            completion(true)
            return
        }
        
        guard let ad = rewardedAd else {
            print("[RewardedAdManager] Ad not ready")
            preloadRewardedAd()
            completion(false)
            return
        }
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let flagStr = remoteConfig.configValue(forKey: "reward_flag").stringValue ?? ""
        let flag = Int(flagStr) ?? 1
        
        self.earnedReward = false
        self.pendingCompletionAction = completion
        ad.present(from: vc) { [weak self] in
            // Reward granted
            self?.markAdShown(flag: flag, key: "reward")
            self?.earnedReward = true
        }
        
        self.rewardedAd = nil
        preloadRewardedAd()
    }
    
    private func shouldShowAd(flag: Int, key: String) -> Bool {
        return flag == 1
    }
    
    private func markAdShown(flag: Int, key: String) {
        // Rewarded ads do not use frequency capping here.
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[RewardedAdManager] Ad dismissed")
        let action = pendingCompletionAction
        let success = earnedReward
        pendingCompletionAction = nil
        earnedReward = false
        action?(success)
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[RewardedAdManager] Failed to present: \(error)")
        let action = pendingCompletionAction
        pendingCompletionAction = nil
        earnedReward = false
        action?(false)
    }
}
