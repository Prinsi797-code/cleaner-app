import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class PhotosNativeAdHelper: NSObject, NativeAdLoaderDelegate {
    private var adLoader: AdLoader?
    private var nativeAd: NativeAd?
    private weak var containerView: UIView?
    private weak var viewController: UIViewController?
    private weak var heightConstraint: NSLayoutConstraint?
    
    var onAdLoaded: (() -> Void)?
    
    init(containerView: UIView, viewController: UIViewController, heightConstraint: NSLayoutConstraint? = nil) {
        self.containerView = containerView
        self.viewController = viewController
        self.heightConstraint = heightConstraint
        super.init()
    }
    
    func fetchRemoteConfigAndLoadNativeAd() {
        if PremiumManager.shared.isPremium {
            heightConstraint?.constant = 0
            containerView?.isHidden = true
            return
        }
        
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self, let vc = self.viewController else { return }
            
            let adUnitID = remoteConfig.configValue(forKey: "photos_native_id").stringValue
            let flagStr = remoteConfig.configValue(forKey: "photos_native_flag").stringValue
            let flag = Int(flagStr) ?? 3
            
            let finalID = adUnitID.isEmpty ? "ca-app-pub-3940256099942544/3986624511" : adUnitID
            print("[PhotosNativeAdHelper] Remote config: ID=\(finalID), Flag=\(flag)")
            
            if self.shouldShowAd(flag: flag, key: "photos_native") && (finalID.contains("ca-app-pub-") || finalID.contains("/")) {
                self.loadNativeAd(adUnitID: finalID, in: vc)
            } else {
                self.heightConstraint?.constant = 0
                self.containerView?.isHidden = true
            }
        }
    }
    
    private func loadNativeAd(adUnitID: String, in vc: UIViewController) {
        let multipleAdOptions = MultipleAdsAdLoaderOptions()
        multipleAdOptions.numberOfAds = 1
        
        adLoader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: vc,
            adTypes: [.native],
            options: [multipleAdOptions]
        )
        adLoader?.delegate = self
        adLoader?.load(Request())
    }
    
    // MARK: - NativeAdLoaderDelegate
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("[PhotosNativeAdHelper] Native Ad loaded successfully!")
        self.nativeAd = nativeAd
        guard let containerView = containerView else { return }
        
        self.onAdLoaded?()
        
        // Remove existing subviews
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: containerView.topAnchor),
            adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 6
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconImageView)
        adView.iconView = iconImageView
        if let icon = nativeAd.icon {
            iconImageView.image = icon.image
        }
        
        let badgeLabel = UILabel()
        badgeLabel.text = "Ad"
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = .systemOrange
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 3
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(badgeLabel)
        
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 14, weight: .bold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 1
        headlineLabel.text = nativeAd.headline
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel
        
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.text = nativeAd.body
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel
        
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle(nativeAd.callToAction ?? "Install", for: .normal)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        ctaButton.backgroundColor = .systemBlue
        ctaButton.layer.cornerRadius = 8
        ctaButton.isUserInteractionEnabled = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton
        
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            badgeLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            badgeLabel.widthAnchor.constraint(equalToConstant: 24),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),
            
            iconImageView.leadingAnchor.constraint(equalTo: badgeLabel.trailingAnchor, constant: 8),
            iconImageView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            headlineLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            headlineLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            
            bodyLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            
            ctaButton.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            ctaButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        adView.nativeAd = nativeAd
        heightConstraint?.constant = 130
        containerView.isHidden = false
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("[PhotosNativeAdHelper] Failed to receive Native Ad: \(error.localizedDescription)")
        heightConstraint?.constant = 0
        containerView?.isHidden = true
    }
    
    private func shouldShowAd(flag: Int, key: String) -> Bool {
        return flag > 0
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
