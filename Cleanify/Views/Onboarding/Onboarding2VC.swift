//
//  Onboarding2VC.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import UIKit

class Onboarding2VC: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header labels
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Center Illustration with Shadow wrapper
    private let illustrationShadowContainer = UIView()
    private let illustrationView = UIImageView()
    
    // Bottom Highlight Card
    private let highlightContainer = UIView()
    private let highlightIconCircle = UIView()
    private let highlightIcon = UIImageView()
    private let highlightTitleLabel = UILabel()
    private let highlightDescLabel = UILabel()
    
    // Main Next Button
    private let nextButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        setupUI()
        setupConstraints()
    }
    
    private func setupTheme() {
        view.backgroundColor = .systemBackground
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Split Title
        let text = "Find & Remove\nDuplicates"
        let attributed = NSMutableAttributedString(string: text)
        let rangeAll = NSRange(location: 0, length: attributed.length)
        let rangeColored = (text as NSString).range(of: "Duplicates")
        
        attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: 28, weight: .black), range: rangeAll)
        attributed.addAttribute(.foregroundColor, value: UIColor.label, range: rangeAll)
        attributed.addAttribute(.foregroundColor, value: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0), range: rangeColored)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: rangeAll)
        
        titleLabel.attributedText = attributed
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "Find duplicate and similar photos, screenshots, and other clutter you don't need."
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Outer Shadow wrapper
        illustrationShadowContainer.backgroundColor = .clear
        illustrationShadowContainer.layer.shadowColor = UIColor.black.cgColor
        illustrationShadowContainer.layer.shadowOpacity = 0.16
        illustrationShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 12)
        illustrationShadowContainer.layer.shadowRadius = 18
        illustrationShadowContainer.layer.masksToBounds = false
        illustrationShadowContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(illustrationShadowContainer)
        
        // Inner rounded image view
        illustrationView.image = UIImage(named: "OnboardingDuplicate")
        illustrationView.contentMode = .scaleAspectFill
        illustrationView.layer.cornerRadius = 24
        illustrationView.clipsToBounds = true
        illustrationView.translatesAutoresizingMaskIntoConstraints = false
        illustrationShadowContainer.addSubview(illustrationView)
        
        // Highlight Card
        highlightContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(highlightContainer)
        
        highlightIconCircle.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.12)
        highlightIconCircle.layer.cornerRadius = 24
        highlightIconCircle.translatesAutoresizingMaskIntoConstraints = false
        highlightContainer.addSubview(highlightIconCircle)
        
        highlightIcon.image = UIImage(systemName: "square.on.square.fill")
        highlightIcon.tintColor = .systemPurple
        highlightIcon.contentMode = .scaleAspectFit
        highlightIcon.translatesAutoresizingMaskIntoConstraints = false
        highlightIconCircle.addSubview(highlightIcon)
        
        highlightTitleLabel.text = "Smart Detection"
        highlightTitleLabel.textColor = .label
        highlightTitleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        highlightTitleLabel.textAlignment = .center
        highlightTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightContainer.addSubview(highlightTitleLabel)
        
        highlightDescLabel.text = "Our smart scan helps you find duplicates and similar items accurately."
        highlightDescLabel.textColor = .secondaryLabel
        highlightDescLabel.font = .systemFont(ofSize: 13, weight: .medium)
        highlightDescLabel.textAlignment = .center
        highlightDescLabel.numberOfLines = 0
        highlightDescLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightContainer.addSubview(highlightDescLabel)
        
        // Blue Action Next Button
        nextButton.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        nextButton.setTitle("Next", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        nextButton.layer.cornerRadius = 24
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
        contentView.addSubview(nextButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            illustrationShadowContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            illustrationShadowContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            illustrationShadowContainer.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.82),
            illustrationShadowContainer.heightAnchor.constraint(equalTo: illustrationShadowContainer.widthAnchor, multiplier: 1.33),
            
            illustrationView.topAnchor.constraint(equalTo: illustrationShadowContainer.topAnchor),
            illustrationView.leadingAnchor.constraint(equalTo: illustrationShadowContainer.leadingAnchor),
            illustrationView.trailingAnchor.constraint(equalTo: illustrationShadowContainer.trailingAnchor),
            illustrationView.bottomAnchor.constraint(equalTo: illustrationShadowContainer.bottomAnchor),
            
            highlightContainer.topAnchor.constraint(equalTo: illustrationShadowContainer.bottomAnchor, constant: 24),
            highlightContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            highlightContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            highlightContainer.heightAnchor.constraint(equalToConstant: 120),
            
            highlightIconCircle.centerXAnchor.constraint(equalTo: highlightContainer.centerXAnchor),
            highlightIconCircle.topAnchor.constraint(equalTo: highlightContainer.topAnchor),
            highlightIconCircle.widthAnchor.constraint(equalToConstant: 48),
            highlightIconCircle.heightAnchor.constraint(equalToConstant: 48),
            
            highlightIcon.centerXAnchor.constraint(equalTo: highlightIconCircle.centerXAnchor),
            highlightIcon.centerYAnchor.constraint(equalTo: highlightIconCircle.centerYAnchor),
            highlightIcon.widthAnchor.constraint(equalToConstant: 24),
            highlightIcon.heightAnchor.constraint(equalToConstant: 24),
            
            highlightTitleLabel.topAnchor.constraint(equalTo: highlightIconCircle.bottomAnchor, constant: 12),
            highlightTitleLabel.leadingAnchor.constraint(equalTo: highlightContainer.leadingAnchor),
            highlightTitleLabel.trailingAnchor.constraint(equalTo: highlightContainer.trailingAnchor),
            
            highlightDescLabel.topAnchor.constraint(equalTo: highlightTitleLabel.bottomAnchor, constant: 6),
            highlightDescLabel.leadingAnchor.constraint(equalTo: highlightContainer.leadingAnchor, constant: 12),
            highlightDescLabel.trailingAnchor.constraint(equalTo: highlightContainer.trailingAnchor, constant: -12),
            
            nextButton.topAnchor.constraint(equalTo: highlightContainer.bottomAnchor, constant: 36),
            nextButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nextButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            nextButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            nextButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    @objc private func didTapNext() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let nextVC = Onboarding3VC()
        if let window = view.window {
            UIView.transition(with: window, duration: 0.45, options: .transitionCrossDissolve, animations: {
                window.rootViewController = nextVC
            }, completion: nil)
        }
    }
}
