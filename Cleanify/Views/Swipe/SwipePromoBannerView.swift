//
//  SwipePromoBannerView.swift
//  Cleanify
//

import UIKit

protocol SwipePromoBannerDelegate: AnyObject {
    func didTapTryNow()
}

class SwipePromoBannerView: UIView {
    
    weak var delegate: SwipePromoBannerDelegate?
    
    private let containerView = UIView()
    private let iconContainer = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tryNowButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 24
        addSubview(containerView)
        
        // Icon Container Setup
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let heroImageView = UIImageView(image: UIImage(named: "swipe_promo_image"))
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.layer.cornerRadius = 16
        heroImageView.clipsToBounds = true
        iconContainer.addSubview(heroImageView)
        containerView.addSubview(iconContainer)
        
        // Text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Swipe to Sort Photos"
        titleLabel.font = UIFont.roundedFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Left to remove or right to keep."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        containerView.addSubview(subtitleLabel)
        
        // Button
        tryNowButton.translatesAutoresizingMaskIntoConstraints = false
        tryNowButton.backgroundColor = .systemBlue
        tryNowButton.setTitle(" Try Now", for: .normal)
        tryNowButton.setImage(UIImage(systemName: "hand.draw.fill"), for: .normal)
        tryNowButton.tintColor = .white
        tryNowButton.titleLabel?.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        tryNowButton.layer.cornerRadius = 24
        tryNowButton.addTarget(self, action: #selector(handleTryNow), for: .touchUpInside)
        containerView.addSubview(tryNowButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            iconContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            iconContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 120),
            iconContainer.heightAnchor.constraint(equalToConstant: 120),
            
            heroImageView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),
            heroImageView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            tryNowButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            tryNowButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            tryNowButton.widthAnchor.constraint(equalToConstant: 160),
            tryNowButton.heightAnchor.constraint(equalToConstant: 48),
            tryNowButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])
    }
    
    @objc private func handleTryNow() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        delegate?.didTapTryNow()
    }
}
