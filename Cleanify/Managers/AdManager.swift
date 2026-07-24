import UIKit
import GoogleMobileAds
import FirebaseRemoteConfig

class AdManager: NSObject, FullScreenContentDelegate {
    static let shared = AdManager()
    
    // Remote Config parameter values with screenshot defaults
    var appOpenId: String = "ca-app-pub-3940256099942544/5575463023"
    var mainOpenFlag: Int = 3
    
    var mainBannerId: String = "ca-app-pub-3940256099942544/2934735716"
    var mainBannerFlag: Int = 1
    
    var mainInterId: String = "ca-app-pub-3940256099942544/4411468910"
    var mainInterFlag: Int = 3
    
    private var appOpenAd: AppOpenAd?
    private var isLoadingAppOpenAd = false
    private var isShowingAppOpenAd = false
    private var loadTime: Date?
    
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
        settings.minimumFetchInterval = 0 // Instant fetch for development/testing
        remoteConfig.configSettings = settings
        
        let defaults: [String: NSObject] = [
            "app_open_id": "ca-app-pub-3940256099942544/5575463023" as NSObject,
            "main_open_flag": "3" as NSObject,
            "main_banner_id": "ca-app-pub-3940256099942544/2934735716" as NSObject,
            "main_banner_flag": "1" as NSObject,
            "main_inter_id": "ca-app-pub-3940256099942544/4411468910" as NSObject,
            "main_inter_flag": "3" as NSObject
        ]
        remoteConfig.setDefaults(defaults)
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            let openId = remoteConfig.configValue(forKey: "app_open_id").stringValue ?? ""
            if !openId.isEmpty {
                self.appOpenId = openId
            }
            
            let openFlagStr = remoteConfig.configValue(forKey: "main_open_flag").stringValue ?? ""
            if let val = Int(openFlagStr) {
                self.mainOpenFlag = val
            }
            
            let bannerId = remoteConfig.configValue(forKey: "main_banner_id").stringValue ?? ""
            if !bannerId.isEmpty {
                self.mainBannerId = bannerId
            }
            
            let bannerFlagStr = remoteConfig.configValue(forKey: "main_banner_flag").stringValue ?? ""
            if let val = Int(bannerFlagStr) {
                self.mainBannerFlag = val
            }
            
            let interId = remoteConfig.configValue(forKey: "main_inter_id").stringValue ?? ""
            if !interId.isEmpty {
                self.mainInterId = interId
            }
            
            let interFlagStr = remoteConfig.configValue(forKey: "main_inter_flag").stringValue ?? ""
            if let val = Int(interFlagStr) {
                self.mainInterFlag = val
            }
            
            print("[AdManager] Remote Config loaded: app_open_id=\(self.appOpenId), main_open_flag=\(self.mainOpenFlag), main_banner_id=\(self.mainBannerId), main_banner_flag=\(self.mainBannerFlag)")
            
            self.loadAppOpenAd()
            completion?()
        }
    }
    
    // MARK: - Ad Frequency Flag Logic
    // 0 -> don't show ads
    // 1 -> once in a lifetime
    // 2 -> once in a day
    // 3 -> every time
    func shouldShowAd(flag: Int, key: String) -> Bool {
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
    
    func markAdShown(flag: Int, key: String) {
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
    
    // MARK: - App Open Ad Implementation
    func loadAppOpenAd() {
        guard mainOpenFlag != 0, !isLoadingAppOpenAd else { return }
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
        guard shouldShowAd(flag: mainOpenFlag, key: "app_open") else {
            print("[AdManager] App Open Ad suppressed by flag \(mainOpenFlag)")
            return
        }
        
        guard !isShowingAppOpenAd else { return }
        
        guard let appOpenAd = appOpenAd, wasLoadTimeLessThanFourHoursAgo() else {
            loadAppOpenAd()
            return
        }
        
        guard let rootVC = viewController ?? topViewController() else { return }
        
        isShowingAppOpenAd = true
        appOpenAd.present(from: rootVC)
    }
    
    // MARK: - Banner Ad Factory & Attacher
    func createBannerView(in viewController: UIViewController) -> BannerView? {
        guard mainBannerFlag > 0 else { return nil }
        
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = mainBannerId
        bannerView.rootViewController = viewController
        bannerView.load(Request())
        return bannerView
    }
    
    func attachBannerAd(to viewController: UIViewController) {
        // Prevent duplicate banner views on the same controller
        if viewController.view.subviews.contains(where: { $0 is BannerView }) {
            return
        }
        
        guard let bannerView = createBannerView(in: viewController) else { return }
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(bannerView)
        
        NSLayoutConstraint.activate([
            bannerView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor),
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: 320),
            bannerView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - FullScreenContentDelegate
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[AdManager] Full screen ad will dismiss.")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[AdManager] Full screen ad dismissed.")
        isShowingAppOpenAd = false
        if ad is AppOpenAd {
            markAdShown(flag: mainOpenFlag, key: "app_open")
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
