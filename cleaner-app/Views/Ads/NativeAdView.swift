//  NativeAdView.swift
//  cleaner-app
//  Created by Hevin Technoweb on 21/03/26.

import SwiftUI
import Combine
import GoogleMobileAds

// MARK: - Native Ad Loader
@MainActor
class NativeAdLoader: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    @Published var isLoaded = false

    private var adLoader: AdLoader?

    func load(adUnitID: String) {
        guard !adUnitID.isEmpty else { return }
        
        let opts = NativeAdViewAdOptions()
        opts.preferredAdChoicesPosition = .topRightCorner

        adLoader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: AdManager.shared.topViewController(),
            adTypes: [.native],
            options: [opts]
        )
        adLoader?.delegate = self
        adLoader?.load(Request())
    }

    // MARK: - NativeAdLoaderDelegate
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.nativeAd = nativeAd
            self.isLoaded = true
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Native ad failed: \(error.localizedDescription)")
    }
}

// MARK: - Native Ad UIKit View
class NativeAdUIView: NativeAdView {

    private let headlineLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .bold)
        l.numberOfLines = 2
        return l
    }()

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        return l
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.widthAnchor.constraint(equalToConstant: 40).isActive = true
        iv.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return iv
    }()

    private let ctaButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .systemBlue
        b.layer.cornerRadius = 8
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return b
    }()

    private let adBadge: UILabel = {
        let l = UILabel()
        l.text = "Ad"
        l.font = .systemFont(ofSize: 9, weight: .bold)
        l.textColor = .white
        l.backgroundColor = UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)
        l.layer.cornerRadius = 3
        l.clipsToBounds = true
        l.textAlignment = .center
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 14
        clipsToBounds = true

        let hStack = UIStackView(arrangedSubviews: [iconImageView])
        hStack.axis = .horizontal
        hStack.spacing = 10
        hStack.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        hStack.addArrangedSubview(textStack)

        let adRow = UIStackView(arrangedSubviews: [adBadge, UIView(), ctaButton])
        adRow.axis = .horizontal
        adRow.spacing = 8
        adRow.alignment = .center

        adBadge.widthAnchor.constraint(equalToConstant: 22).isActive = true
        adBadge.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let mainStack = UIStackView(arrangedSubviews: [hStack, adRow])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])

        headlineView     = headlineLabel
        bodyView         = bodyLabel
        iconView         = iconImageView
        callToActionView = ctaButton
    }

    func populate(with ad: NativeAd) {
        nativeAd = ad
        headlineLabel.text = ad.headline
        bodyLabel.text     = ad.body
        ctaButton.setTitle(ad.callToAction, for: .normal)
        if let icon = ad.icon?.image {
            iconImageView.image = icon
        }
    }
}

// MARK: - SwiftUI Native Ad Card
struct NativeAdCard: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdUIView {
        let view = NativeAdUIView()
        view.populate(with: nativeAd)
        return view
    }

    func updateUIView(_ uiView: NativeAdUIView, context: Context) {
        uiView.populate(with: nativeAd)
    }
}

// MARK: - Smart Native Ad Container
struct SmartNativeAdView: View {
    let screen: AdScreen
    @StateObject private var loader = NativeAdLoader()
    @ObservedObject private var rcService = RemoteConfigService.shared

    var body: some View {
        let config = rcService.adConfig.config(for: screen)
        if config.nativeFlag, !config.nativeId.isEmpty {
            Group {
                if loader.isLoaded, let ad = loader.nativeAd {
                    NativeAdCard(nativeAd: ad)
                        .frame(height: 100)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 100)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .redacted(reason: .placeholder)
                }
            }
            .onAppear {
                if !loader.isLoaded {
                    loader.load(adUnitID: config.nativeId)
                }
            }
        }
    }
}
