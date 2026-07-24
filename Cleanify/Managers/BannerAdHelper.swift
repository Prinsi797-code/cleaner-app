import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class BannerAdHelper: NSObject, BannerViewDelegate {
    
    private weak var viewController: UIViewController?
    private var bannerView: BannerView?
    private let bannerContainer = UIView()
    private var bannerHeightConstraint: NSLayoutConstraint?
    private var bannerIDKey: String
    private var bannerFlagKey: String
    
    private var hasLoadedSuccessfully = false
    private var isLoading = false
    
    init(viewController: UIViewController, bannerIDKey: String = "main_banner_id", bannerFlagKey: String = "main_banner_flag") {
        self.viewController = viewController
        self.bannerIDKey = bannerIDKey
        self.bannerFlagKey = bannerFlagKey
        super.init()
        setupContainer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePremiumStatusChange), name: .premiumStatusChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePremiumStatusChange() {
        if PremiumManager.shared.isPremium {
            bannerHeightConstraint?.constant = 0
            bannerContainer.isHidden = true
            bannerView?.removeFromSuperview()
            bannerView = nil
            hasLoadedSuccessfully = false
            isLoading = false
        }
    }
    
    private func setupContainer() {
        guard let vc = viewController else { return }
        
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.isHidden = true
        vc.view.addSubview(bannerContainer)
        
        NSLayoutConstraint.activate([
            bannerContainer.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor),
            bannerContainer.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            bannerContainer.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
        ])
        
        bannerHeightConstraint = bannerContainer.heightAnchor.constraint(equalToConstant: 0)
        bannerHeightConstraint?.isActive = true
    }
    
    func fetchRemoteConfigAndLoadBannerAd() {
        if PremiumManager.shared.isPremium {
            bannerHeightConstraint?.constant = 0
            bannerContainer.isHidden = true
            bannerView?.removeFromSuperview()
            bannerView = nil
            hasLoadedSuccessfully = false
            isLoading = false
            return
        }
        
        // Prevent blinking: If already loaded successfully or currently loading, do not reload!
        if hasLoadedSuccessfully && bannerView != nil {
            print("BannerAdHelper: Banner already loaded & cached. Skipping reload to prevent blinking.")
            return
        }
        
        if isLoading {
            return
        }
        
        isLoading = true
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self, let vc = self.viewController else { return }
            
            let bannerID = remoteConfig.configValue(forKey: self.bannerIDKey).stringValue ?? "ca-app-pub-3940256099942544/2934735716"
            let flagStr = remoteConfig.configValue(forKey: self.bannerFlagKey).stringValue ?? ""
            let flag = Int(flagStr) ?? 1
            
            print("BannerAdHelper fetched Remote Config: ID=\(bannerID), Flag=\(flag)")
            
            if flag > 0 && (bannerID.contains("ca-app-pub-") || bannerID.contains("/")) {
                self.loadBannerAd(adUnitID: bannerID, in: vc)
            } else {
                self.isLoading = false
                self.hasLoadedSuccessfully = false
                self.bannerHeightConstraint?.constant = 0
                self.bannerContainer.isHidden = true
            }
        }
    }
    
    private func loadBannerAd(adUnitID: String, in vc: UIViewController) {
        bannerView?.removeFromSuperview()
        
        let frame = vc.view.frame.inset(by: vc.view.safeAreaInsets)
        let viewWidth = frame.size.width
        let adSize = adSizeFor(cgSize: CGSize(width: viewWidth, height: 50))
        
        let adView = BannerView(adSize: adSize)
        adView.adUnitID = adUnitID
        adView.rootViewController = vc
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false
        
        bannerContainer.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor),
            adView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor)
        ])
        
        adView.load(Request())
        self.bannerView = adView
    }
    
    // MARK: - BannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("BannerAdHelper: Banner ad preloaded & loaded successfully!")
        hasLoadedSuccessfully = true
        isLoading = false
        bannerHeightConstraint?.constant = bannerView.adSize.size.height
        bannerContainer.isHidden = false
        viewController?.view.layoutIfNeeded()
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("BannerAdHelper: Failed to load banner ad: \(error.localizedDescription)")
        hasLoadedSuccessfully = false
        isLoading = false
        bannerHeightConstraint?.constant = 0
        bannerContainer.isHidden = true
    }
}
