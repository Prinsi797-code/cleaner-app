//
//  RootContainerVC.swift
//  Cleanify
//

import UIKit
import GoogleMobileAds
import FirebaseRemoteConfig

final class RootContainerVC: UIViewController {

    private let tabController = MainTabBarController()

    // MARK: - Ad Properties
    private let adContainer = UIView()
    private var adHeightConstraint: NSLayoutConstraint!
    private var tabBottomToAdTop: NSLayoutConstraint!
    private var tabBottomToViewBottom: NSLayoutConstraint!
    private var currentAdView: UIView?
    private var adLoader: AdLoader?
    private var isCurrentAdPreloadBanner = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        embedTabController()
        setupAdContainer()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePremiumStatusChanged),
            name: .premiumStatusChanged,
            object: nil
        )
        loadBottomAdWaterfall()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if currentAdView == nil && !PremiumManager.shared.isPremium {
            loadBottomAdWaterfall()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let currentNav = tabController.selectedViewController as? UINavigationController
        let topVC = currentNav?.topViewController ?? tabController.selectedViewController
        let isChildHidingBar = (topVC?.hidesBottomBarWhenPushed == true) || (currentNav != nil && topVC != currentNav?.viewControllers.first)
        
        if isChildHidingBar && !adContainer.isHidden {
            setAdHidden(true)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout

    private func embedTabController() {
        addChild(tabController)
        tabController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabController.view)

        tabBottomToViewBottom = tabController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        tabBottomToViewBottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            tabController.view.topAnchor.constraint(equalTo: view.topAnchor),
            tabController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBottomToViewBottom
        ])
        tabController.didMove(toParent: self)
        
        tabController.delegate = self
        tabController.attachNavigationDelegates(self)
    }

    private func setupAdContainer() {
        adContainer.translatesAutoresizingMaskIntoConstraints = false
        adContainer.backgroundColor = .secondarySystemBackground
        adContainer.clipsToBounds = true
        adContainer.isHidden = true
        view.addSubview(adContainer)

        adHeightConstraint = adContainer.heightAnchor.constraint(equalToConstant: 0)
        tabBottomToAdTop = tabController.view.bottomAnchor.constraint(equalTo: adContainer.topAnchor)
        tabBottomToAdTop.priority = .required

        NSLayoutConstraint.activate([
            adContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            adContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            adContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor), // Ignores safe area, anchored to superview bottom
            adHeightConstraint
        ])
    }

    // MARK: - Waterfall Ad Loading

    private func loadBottomAdWaterfall() {
        if PremiumManager.shared.isPremium {
            hideAd()
            return
        }

        let rc = RemoteConfig.remoteConfig()
        let isBannerShow = rc.configValue(forKey: "main_banner_show").boolValue
        guard isBannerShow else {
            hideAd()
            return
        }

        let nativeID = (rc.configValue(forKey: "main_preload_native_id").stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !nativeID.isEmpty && nativeID != "(empty string)" {
            if let preloaded = AdManager.shared.getPreloadedNativeAd(placementIdKey: "main_preload_native_id") {
                displayNativeAd(preloaded)
                return
            }
            loadNativeAd(adUnitID: nativeID)
            return
        }
        fallbackToPreloadBanner()
    }

    private func loadNativeAd(adUnitID: String) {
        adLoader = AdLoader(adUnitID: adUnitID, rootViewController: self, adTypes: [.native], options: nil)
        adLoader?.delegate = self
        adLoader?.load(Request())
    }

    private func displayNativeAd(_ nativeAd: NativeAd) {
        currentAdView?.removeFromSuperview()

        let nativeBannerView = CompactNativeAdBannerView()
        nativeBannerView.translatesAutoresizingMaskIntoConstraints = false
        nativeBannerView.populate(with: nativeAd)

        adContainer.addSubview(nativeBannerView)
        NSLayoutConstraint.activate([
            nativeBannerView.leadingAnchor.constraint(equalTo: adContainer.leadingAnchor),
            nativeBannerView.trailingAnchor.constraint(equalTo: adContainer.trailingAnchor),
            nativeBannerView.topAnchor.constraint(equalTo: adContainer.topAnchor),
            nativeBannerView.bottomAnchor.constraint(equalTo: adContainer.bottomAnchor)
        ])
        currentAdView = nativeBannerView
        showAd(withHeight: 90)
    }

    private func fallbackToPreloadBanner() {
        let rc = RemoteConfig.remoteConfig()
        let id = (rc.configValue(forKey: "main_preload_banner_id").stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !id.isEmpty && id != "(empty string)" {
            if let preloaded = AdManager.shared.getPreloadedBanner(placementIdKey: "main_preload_banner_id", for: self) {
                displayBanner(preloaded.banner, isReady: preloaded.isReady)
                return
            }
            loadBannerAd(adUnitID: id, isPreloadBanner: true)
            return
        }
        fallbackToMainBanner()
    }

    private func fallbackToMainBanner() {
        let rc = RemoteConfig.remoteConfig()
        let id = (rc.configValue(forKey: "main_banner_id").stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !id.isEmpty && id != "(empty string)" {
            if let preloaded = AdManager.shared.getPreloadedBanner(placementIdKey: "main_banner_id", for: self) {
                displayBanner(preloaded.banner, isReady: preloaded.isReady)
                return
            }
            loadBannerAd(adUnitID: id, isPreloadBanner: false)
        } else {
            hideAd()
        }
    }

    private func loadBannerAd(adUnitID: String, isPreloadBanner: Bool) {
        currentAdView?.removeFromSuperview()
        isCurrentAdPreloadBanner = isPreloadBanner

        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        let adView = BannerView(adSize: adSize)
        adView.adUnitID = adUnitID
        adView.rootViewController = self
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false

        adContainer.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.leadingAnchor.constraint(equalTo: adContainer.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: adContainer.trailingAnchor),
            adView.topAnchor.constraint(equalTo: adContainer.topAnchor),
            adView.heightAnchor.constraint(equalToConstant: adSize.size.height)
        ])
        currentAdView = adView
        adView.load(Request())
    }

    private func displayBanner(_ banner: BannerView, isReady: Bool) {
        currentAdView?.removeFromSuperview()
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        adContainer.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: adContainer.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: adContainer.trailingAnchor),
            banner.topAnchor.constraint(equalTo: adContainer.topAnchor),
            banner.heightAnchor.constraint(equalToConstant: banner.adSize.size.height)
        ])
        currentAdView = banner
        if isReady {
            showAd(withHeight: banner.adSize.size.height)
        }
    }

    // MARK: - Show / Hide

    private func setAdHidden(_ hidden: Bool) {
        let shouldHide = hidden || PremiumManager.shared.isPremium || currentAdView == nil

        if shouldHide {
            adContainer.isHidden = true
            tabBottomToAdTop?.isActive = false
            tabBottomToViewBottom?.isActive = true
        } else {
            adContainer.isHidden = false
            tabBottomToViewBottom?.isActive = false
            tabBottomToAdTop?.isActive = true
        }
    }

    private func showAd(withHeight height: CGFloat) {
        guard height > 0 else { return }
        adHeightConstraint.constant = height

        let currentNav = tabController.selectedViewController as? UINavigationController
        let topVC = currentNav?.topViewController ?? tabController.selectedViewController
        let isChildHidingBar = (topVC?.hidesBottomBarWhenPushed == true) || (currentNav != nil && topVC != currentNav?.viewControllers.first)

        setAdHidden(isChildHidingBar)
    }

    private func hideAd() {
        adHeightConstraint.constant = 0
        currentAdView?.removeFromSuperview()
        currentAdView = nil
        setAdHidden(true)
    }

    @objc private func handlePremiumStatusChanged() {
        DispatchQueue.main.async { [weak self] in
            PremiumManager.shared.isPremium ? self?.hideAd() : self?.loadBottomAdWaterfall()
        }
    }
}

// MARK: - Delegates
extension RootContainerVC: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        displayNativeAd(nativeAd)
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        fallbackToPreloadBanner()
    }
}

extension RootContainerVC: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        showAd(withHeight: bannerView.adSize.size.height)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        isCurrentAdPreloadBanner ? fallbackToMainBanner() : hideAd()
    }
}

extension RootContainerVC: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let isRootVC = (viewController == navigationController.viewControllers.first)
        let hidesBar = viewController.hidesBottomBarWhenPushed || !isRootVC

        // Hide main bottom ad immediately when pushing a subpage
        if hidesBar {
            setAdHidden(true)
        }
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        let isRootVC = (viewController == navigationController.viewControllers.first)
        let hidesBar = viewController.hidesBottomBarWhenPushed || !isRootVC

        // Restore main bottom ad only AFTER pop transition is complete
        if !hidesBar {
            setAdHidden(false)
        }
    }
}

extension RootContainerVC: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let currentNav = viewController as? UINavigationController
        let topVC = currentNav?.topViewController ?? viewController
        let isRoot = (topVC == currentNav?.viewControllers.first)
        let hidesBar = (topVC.hidesBottomBarWhenPushed == true) || !isRoot
        setAdHidden(hidesBar)
    }
}
