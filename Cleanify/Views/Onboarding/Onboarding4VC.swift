//
//  Onboarding4VC.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import UIKit

class Onboarding4VC: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header labels
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Option Cards Stack
    private let optionsStack = UIStackView()
    private let option1Card = OptionSelectionCard(title: "My storage is full", icon: "exclamationmark.triangle.fill", iconColor: .systemRed)
    private let option2Card = OptionSelectionCard(title: "I want to organize photos", icon: "photo.on.rectangle.angled", iconColor: .systemBlue)
    private let option3Card = OptionSelectionCard(title: "I am just curious", icon: "eye.fill", iconColor: .systemGreen)
    
    // Continue Button
    private let continueButton = UIButton(type: .system)
    
    private var selectedIndex: Int? {
        didSet {
            continueButton.isEnabled = selectedIndex != nil
            continueButton.alpha = selectedIndex != nil ? 1.0 : 0.5
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        setupUI()
        setupConstraints()
        selectedIndex = nil
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
        
        // Title
        titleLabel.text = "What is your focus?"
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "Select the main problem you'd like to resolve."
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Options Stack setup
        optionsStack.axis = .vertical
        optionsStack.spacing = 16
        optionsStack.alignment = .fill
        optionsStack.distribution = .fillEqually
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(optionsStack)
        
        optionsStack.addArrangedSubview(option1Card)
        optionsStack.addArrangedSubview(option2Card)
        optionsStack.addArrangedSubview(option3Card)
        
        option1Card.addTarget(self, action: #selector(didSelectOption1), for: .touchUpInside)
        option2Card.addTarget(self, action: #selector(didSelectOption2), for: .touchUpInside)
        option3Card.addTarget(self, action: #selector(didSelectOption3), for: .touchUpInside)
        
        // Blue Continue Button
        continueButton.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        continueButton.layer.cornerRadius = 24
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
        contentView.addSubview(continueButton)
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            optionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 36),
            optionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            optionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            option1Card.heightAnchor.constraint(equalToConstant: 72),
            option2Card.heightAnchor.constraint(equalToConstant: 72),
            option3Card.heightAnchor.constraint(equalToConstant: 72),
            
            continueButton.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 48),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            continueButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    // MARK: - Handlers
    @objc private func didSelectOption1() {
        highlightSelection(index: 1)
    }
    
    @objc private func didSelectOption2() {
        highlightSelection(index: 2)
    }
    
    @objc private func didSelectOption3() {
        highlightSelection(index: 3)
    }
    
    private func highlightSelection(index: Int) {
        selectedIndex = index
        option1Card.setSelected(index == 1)
        option2Card.setSelected(index == 2)
        option3Card.setSelected(index == 3)
    }
    
    @objc private func didTapContinue() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        if let window = self.view.window {
            UIView.transition(with: window, duration: 0.45, options: .transitionCrossDissolve, animations: {
                window.rootViewController = MainTabBarController()
            }, completion: nil)
        }
    }
}
