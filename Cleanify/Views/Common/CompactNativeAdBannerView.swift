//
//  CompactNativeAdBannerView.swift
//  Cleanify
//
//  Compact Native Ad View styled as a bottom banner
//

import UIKit
import GoogleMobileAds

final class CompactNativeAdBannerView: NativeAdView {
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let adBadgeLabel: UILabel = {
        let label = UILabel()
        label.text = "AD"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.backgroundColor = .systemOrange
        label.textAlignment = .center
        label.layer.cornerRadius = 3
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let callToActionButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        btn.titleLabel?.adjustsFontSizeToFitWidth = true
        btn.titleLabel?.minimumScaleFactor = 0.8
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        btn.layer.cornerRadius = 18
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        btn.isUserInteractionEnabled = false // NativeAdView handles the click
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        backgroundColor = .secondarySystemBackground
        clipsToBounds = true
        
        addSubview(iconImageView)
        addSubview(adBadgeLabel)
        addSubview(headlineLabel)
        addSubview(bodyLabel)
        addSubview(callToActionButton)
        
        self.iconView = iconImageView
        self.headlineView = headlineLabel
        self.bodyView = bodyLabel
        self.callToActionView = callToActionButton
        
        // Priority ensures CTA button is never compressed or truncated by labels
        callToActionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        callToActionButton.setContentHuggingPriority(.required, for: .horizontal)
        headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            // Icon (52x52)
            iconImageView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 14),
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconImageView.widthAnchor.constraint(equalToConstant: 52),
            iconImageView.heightAnchor.constraint(equalToConstant: 52),
            
            // Call to action button on trailing
            callToActionButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            callToActionButton.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            callToActionButton.heightAnchor.constraint(equalToConstant: 36),
            callToActionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Ad badge
            adBadgeLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            adBadgeLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 2),
            adBadgeLabel.widthAnchor.constraint(equalToConstant: 24),
            adBadgeLabel.heightAnchor.constraint(equalToConstant: 15),
            
            // Headline (15pt bold)
            headlineLabel.leadingAnchor.constraint(equalTo: adBadgeLabel.trailingAnchor, constant: 6),
            headlineLabel.centerYAnchor.constraint(equalTo: adBadgeLabel.centerYAnchor),
            headlineLabel.trailingAnchor.constraint(lessThanOrEqualTo: callToActionButton.leadingAnchor, constant: -10),
            
            // Body (12pt, up to 2 lines)
            bodyLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(lessThanOrEqualTo: callToActionButton.leadingAnchor, constant: -10),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }
    
    func populate(with nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        
        if let icon = nativeAd.icon?.image {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }
        
        let ctaTitle = nativeAd.callToAction ?? "Install"
        callToActionButton.setTitle(ctaTitle, for: .normal)
        callToActionButton.isHidden = nativeAd.callToAction == nil
        callToActionButton.sizeToFit()
    }
}
