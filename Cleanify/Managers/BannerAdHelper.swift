import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class BannerAdHelper: NSObject, BannerViewDelegate, NativeAdLoaderDelegate {
    
    private let containerView: UIView
    private weak var rootViewController: UIViewController?
    
    var onAdHeightChanged: ((CGFloat) -> Void)?
    
    private var bannerView: BannerView?
    private var nativeAd: NativeAd?
    private var adLoader: AdLoader?
    
    private var isAdLoaded = false
    private var isLoading = false
    
    // Priority IDs from Remote Config
    private var preloadNativeID: String?
    private var preloadBannerID: String?
    private var mainBannerID: String?
    
    private var bannerCompletion: ((Bool) -> Void)?
    
    init(containerView: UIView, rootViewController: UIViewController) {
        self.containerView = containerView
        self.rootViewController = rootViewController
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePremiumStatusChange),
            name: .premiumStatusChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePremiumStatusChange() {
        if PremiumManager.shared.isPremium {
            hideAd()
        }
    }
    
    func hideAd() {
        bannerView?.removeFromSuperview()
        bannerView = nil
        nativeAd = nil
        adLoader = nil
        isAdLoaded = false
        isLoading = false
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.isHidden = true
        onAdHeightChanged?(0)
    }
    
    private func cleanID(_ id: String?) -> String? {
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed != "(empty string)",
              trimmed.lowercased() != "empty" else {
            return nil
        }
        return trimmed
    }
    
    private func isValidID(_ id: String) -> Bool {
        return id.contains("ca-app-pub-") || id.contains("/")
    }
    
    // MARK: - Remote Config & Fallback Execution
    func fetchRemoteConfigAndLoadBannerAd() {
        if PremiumManager.shared.isPremium {
            hideAd()
            return
        }
        
        if isAdLoaded && (bannerView != nil || nativeAd != nil) {
            print("[BannerAdHelper] Ad already loaded. Skipping reload.")
            return
        }
        
        if isLoading { return }
        isLoading = true
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            // 1. Check toggle main_banner_show
            let showVal = remoteConfig.configValue(forKey: "main_banner_show")
            let isBannerShow = showVal.boolValue
            
            print("[BannerAdHelper] Remote Config: main_banner_show=\(isBannerShow)")
            
            guard isBannerShow && !PremiumManager.shared.isPremium else {
                print("[BannerAdHelper] Ad disabled via main_banner_show or user is Premium.")
                self.isLoading = false
                self.hideAd()
                return
            }
            
            // 2. Fetch Priority IDs
            let rawNative = remoteConfig.configValue(forKey: "main_preload_native_id").stringValue ?? ""
            let rawPreloadBanner = remoteConfig.configValue(forKey: "main_preload_banner_id").stringValue ?? ""
            let rawMainBanner = remoteConfig.configValue(forKey: "main_banner_id").stringValue ?? ""
            
            self.preloadNativeID = self.cleanID(rawNative)
            self.preloadBannerID = self.cleanID(rawPreloadBanner)
            self.mainBannerID = self.cleanID(rawMainBanner)
            
            print("[BannerAdHelper] IDs: Native=\(self.preloadNativeID ?? "nil"), PreloadBanner=\(self.preloadBannerID ?? "nil"), MainBanner=\(self.mainBannerID ?? "nil")")
            
            // 3. Start fallback chain
            self.tryLoadNativeAd()
        }
    }
    
    // MARK: - Priority 1: Native Ad
    private func tryLoadNativeAd() {
        guard let nativeID = preloadNativeID, isValidID(nativeID) else {
            print("[BannerAdHelper] 1st Priority (Native) empty/invalid. Falling back to Preload Banner.")
            tryLoadPreloadBanner()
            return
        }
        
        guard let vc = rootViewController else {
            isLoading = false
            return
        }
        
        print("[BannerAdHelper] 1st Priority: Loading Native Ad with ID=\(nativeID)")
        let loader = AdLoader(
            adUnitID: nativeID,
            rootViewController: vc,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        self.adLoader = loader
        loader.load(Request())
    }
    
    // MARK: - Priority 2: Preload Banner
    private func tryLoadPreloadBanner() {
        guard let bannerID = preloadBannerID, isValidID(bannerID) else {
            print("[BannerAdHelper] 2nd Priority (Preload Banner) empty/invalid. Falling back to Main Banner.")
            tryLoadMainBanner()
            return
        }
        
        print("[BannerAdHelper] 2nd Priority: Loading Preload Banner with ID=\(bannerID)")
        loadBanner(adUnitID: bannerID) { [weak self] success in
            guard let self = self else { return }
            if !success {
                print("[BannerAdHelper] 2nd Priority failed. Falling back to Main Banner.")
                self.tryLoadMainBanner()
            }
        }
    }
    
    // MARK: - Priority 3: Main Banner
    private func tryLoadMainBanner() {
        guard let bannerID = mainBannerID, isValidID(bannerID) else {
            print("[BannerAdHelper] 3rd Priority (Main Banner) empty/invalid. All priorities exhausted.")
            self.isLoading = false
            self.hideAd()
            return
        }
        
        print("[BannerAdHelper] 3rd Priority: Loading Main Banner with ID=\(bannerID)")
        loadBanner(adUnitID: bannerID) { [weak self] success in
            guard let self = self else { return }
            self.isLoading = false
            if !success {
                print("[BannerAdHelper] All ad priorities failed. Hiding ad.")
                self.hideAd()
            }
        }
    }
    
    // MARK: - Banner Loader Helper
    private func loadBanner(adUnitID: String, completion: @escaping (Bool) -> Void) {
        guard let vc = rootViewController else {
            completion(false)
            return
        }
        
        bannerView?.removeFromSuperview()
        bannerCompletion = completion
        
        let viewWidth = vc.view.bounds.width > 0 ? vc.view.bounds.width : UIScreen.main.bounds.width
        let adSize = adSizeFor(cgSize: CGSize(width: viewWidth, height: 50))
        
        let adView = BannerView(adSize: adSize)
        adView.adUnitID = adUnitID
        adView.rootViewController = vc
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false
        self.bannerView = adView
        adView.load(Request())
    }
    
    // MARK: - BannerViewDelegate
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("[BannerAdHelper] Banner ad received successfully!")
        self.isAdLoaded = true
        self.isLoading = false
        displayBannerAd(bannerView)
        bannerCompletion?(true)
        bannerCompletion = nil
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("[BannerAdHelper] Banner ad failed: \(error.localizedDescription)")
        bannerCompletion?(false)
        bannerCompletion = nil
    }
    
    // MARK: - NativeAdLoaderDelegate
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("[BannerAdHelper] Native ad received successfully!")
        self.nativeAd = nativeAd
        self.isAdLoaded = true
        self.isLoading = false
        displayNativeAd(nativeAd)
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("[BannerAdHelper] Native ad failed: \(error.localizedDescription). Proceeding to Preload Banner fallback.")
        tryLoadPreloadBanner()
    }
    
    // MARK: - Ad Display Methods
    private func displayBannerAd(_ banner: BannerView) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        banner.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(banner)
        
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: containerView.topAnchor),
            banner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            banner.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor)
        ])
        
        containerView.isHidden = false
        onAdHeightChanged?(50)
    }
    
    private func displayNativeAd(_ nativeAd: NativeAd) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        let adView = NativeAdView()
        adView.backgroundColor = .clear
        adView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: containerView.topAnchor),
            adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Icon
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconImageView)
        adView.iconView = iconImageView
        if let icon = nativeAd.icon {
            iconImageView.image = icon.image
        }
        
        // Badge "Ad"
        let badgeLabel = UILabel()
        badgeLabel.text = "Ad"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = .systemOrange
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 3
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(badgeLabel)
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 13, weight: .bold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 1
        headlineLabel.text = nativeAd.headline
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel
        
        // CTA Button
        let ctaButton = UIButton(type: .system)
        let ctaTitle = nativeAd.callToAction ?? "Install"
        ctaButton.setTitle(ctaTitle, for: .normal)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        ctaButton.backgroundColor = .systemBlue
        ctaButton.layer.cornerRadius = 14
        ctaButton.isUserInteractionEnabled = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton
        
        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 11, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 1
        bodyLabel.text = nativeAd.body ?? nativeAd.advertiser ?? ""
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 38),
            iconImageView.heightAnchor.constraint(equalToConstant: 38),
            
            badgeLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            badgeLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 2),
            badgeLabel.widthAnchor.constraint(equalToConstant: 20),
            badgeLabel.heightAnchor.constraint(equalToConstant: 14),
            
            headlineLabel.leadingAnchor.constraint(equalTo: badgeLabel.trailingAnchor, constant: 4),
            headlineLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -8),
            headlineLabel.centerYAnchor.constraint(equalTo: badgeLabel.centerYAnchor),
            
            bodyLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            bodyLabel.trailingAnchor.constraint(lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -8),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            ctaButton.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            ctaButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        adView.nativeAd = nativeAd
        containerView.isHidden = false
        onAdHeightChanged?(50)
    }
}
