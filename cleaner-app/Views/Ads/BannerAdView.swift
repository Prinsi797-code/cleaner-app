//  BannerAdView.swift
//  cleaner-app
//  Created by Hevin Technoweb on 21/03/26.

import SwiftUI
import Combine
import GoogleMobileAds

// MARK: - Banner Ad View
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = context.coordinator.findVC()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        func findVC() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root  = scene.windows.first?.rootViewController else { return nil }
            return root
        }
    }
}

// MARK: - Smart Banner Container
// Sirf MainTabView ke niche dikhega — MoreView ke andar wali screens me nahi
struct SmartBannerView: View {
    @ObservedObject private var rcService = RemoteConfigService.shared

    var body: some View {
        let config = rcService.adConfig.mainScreen
        if config.bannerFlag, !config.bannerId.isEmpty {
            BannerAdView(adUnitID: config.bannerId)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        } else {
            EmptyView()
        }
    }
}
