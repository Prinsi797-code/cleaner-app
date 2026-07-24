import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds

class VideosNativeAdHelper: NSObject, NativeAdLoaderDelegate {
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
            
            let adUnitID = remoteConfig.configValue(forKey: "videos_native_id").stringValue
            let flagStr = remoteConfig.configValue(forKey: "videos_native_flag").stringValue
            let flag = Int(flagStr) ?? 3
            
            let finalID = adUnitID.isEmpty ? "ca-app-pub-3940256099942544/3986624511" : adUnitID
            print("[VideosNativeAdHelper] Remote config: ID=\(finalID), Flag=\(flag)")
            
            if self.shouldShowAd(flag: flag, key: "videos_native") && (finalID.contains("ca-app-pub-") || finalID.contains("/")) {
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
        print("[VideosNativeAdHelper] Native Ad loaded successfully!")
        self.nativeAd = nativeAd
        guard let containerView = containerView else { return }
        
        self.onAdLoaded?()
        
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
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = .systemOrange
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 3
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(badgeLabel)
        
        let headlineLabel = UILabel()
        headlineLabel.text = nativeAd.headline
        headlineLabel.font = .systemFont(ofSize: 14, weight: .bold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel
        
        let bodyLabel = UILabel()
        bodyLabel.text = nativeAd.body
        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel
        
        let actionButton = UIButton(type: .system)
        actionButton.setTitle(nativeAd.callToAction, for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = .systemBlue
        actionButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        actionButton.layer.cornerRadius = 8
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isUserInteractionEnabled = false
        adView.addSubview(actionButton)
        adView.callToActionView = actionButton
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            badgeLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: iconImageView.leadingAnchor),
            badgeLabel.widthAnchor.constraint(equalToConstant: 20),
            badgeLabel.heightAnchor.constraint(equalToConstant: 14),
            
            headlineLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            headlineLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            
            actionButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            actionButton.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 80),
            actionButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        adView.nativeAd = nativeAd
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("[VideosNativeAdHelper] Failed to load native ad: \(error.localizedDescription)")
        self.heightConstraint?.constant = 0
        self.containerView?.isHidden = true
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
