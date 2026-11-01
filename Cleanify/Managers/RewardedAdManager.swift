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
    
    private func getRewardAdUnitID() -> String? {
        let rc = RemoteConfig.remoteConfig()
        let adUnitID = (rc.configValue(forKey: "sub_reward_id").stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !adUnitID.isEmpty, adUnitID != "(empty string)", (adUnitID.contains("ca-app-pub-") || adUnitID.contains("/")) else {
            return nil
        }
        return adUnitID
    }
    
    func preloadRewardedAd() {
        if PremiumManager.shared.isPremium { return }
        guard rewardedAd == nil, !isLoading else { return }
        guard let adUnitID = getRewardAdUnitID() else { return }
        
        isLoading = true
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
    }
    
    func isAdRequired(key: String = "reward") -> Bool {
        if PremiumManager.shared.isPremium { return false }
        return getRewardAdUnitID() != nil
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
        guard let adUnitID = getRewardAdUnitID() else {
            completion(false)
            return
        }
        
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
        
        self.earnedReward = false
        self.pendingCompletionAction = completion
        ad.present(from: vc) { [weak self] in
            // Reward granted
            AnalyticsManager.shared.logRewardedAdCompleted(rewardType: "compress_or_clean")
            self?.earnedReward = true
        }
        
        self.rewardedAd = nil
        preloadRewardedAd()
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
