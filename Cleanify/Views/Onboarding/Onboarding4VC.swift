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
            let isEnabled = selectedIndex != nil
            continueButton.isEnabled = isEnabled
            
            UIView.animate(withDuration: 0.3) {
                if isEnabled {
                    self.continueButton.alpha = 1.0
                    self.continueButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                } else {
                    self.continueButton.alpha = 0.5
                    self.continueButton.transform = .identity
                }
            } completion: { _ in
                if isEnabled {
                    UIView.animate(withDuration: 0.2) {
                        self.continueButton.transform = .identity
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        setupUI()
        setupConstraints()
        prepareForAnimation()
        selectedIndex = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
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
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "Select the main problem you'd like to resolve so we can personalize your experience."
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = UIFont.roundedFont(ofSize: 16, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Options Stack setup
        optionsStack.axis = .vertical
        optionsStack.spacing = 20
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
        
        // Action Button
        continueButton.backgroundColor = .label
        continueButton.setTitle("Get Started ", for: .normal)
        continueButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        continueButton.semanticContentAttribute = .forceRightToLeft
        continueButton.setTitleColor(.systemBackground, for: .normal)
        continueButton.tintColor = .systemBackground
        continueButton.titleLabel?.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        continueButton.layer.cornerRadius = 28
        
        // Add subtle shadow to button
        continueButton.layer.shadowColor = UIColor.black.cgColor
        continueButton.layer.shadowOpacity = 0.15
        continueButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        continueButton.layer.shadowRadius = 16
        
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            optionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48),
            optionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            optionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            option1Card.heightAnchor.constraint(equalToConstant: 80),
            option2Card.heightAnchor.constraint(equalToConstant: 80),
            option3Card.heightAnchor.constraint(equalToConstant: 80),
            
            continueButton.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 56),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -48),
            continueButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    // MARK: - Animations
    private func prepareForAnimation() {
        let elements = [titleLabel, subtitleLabel, option1Card, option2Card, option3Card, continueButton]
        for (index, element) in elements.enumerated() {
            element.alpha = 0
            element.transform = CGAffineTransform(translationX: 0, y: 30 + CGFloat(index * 10))
        }
    }
    
    private func animateIn() {
        let elements = [titleLabel, subtitleLabel, option1Card, option2Card, option3Card, continueButton]
        
        for (index, element) in elements.enumerated() {
            UIView.animate(withDuration: 0.8,
                           delay: 0.1 + Double(index) * 0.1,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0.5,
                           options: .curveEaseOut,
                           animations: {
                element.alpha = index == 5 && self.selectedIndex == nil ? 0.5 : 1 // Adjust button alpha
                element.transform = .identity
            }, completion: nil)
        }
    }
    
    // MARK: - Handlers
    @objc private func didSelectOption1() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        highlightSelection(index: 1)
    }
    
    @objc private func didSelectOption2() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        highlightSelection(index: 2)
    }
    
    @objc private func didSelectOption3() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        
        UIView.animate(withDuration: 0.1, animations: {
            self.continueButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.continueButton.transform = .identity
            }) { _ in
                self.completeOnboarding()
            }
        }
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
