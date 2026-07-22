import UIKit

class Onboarding3VC: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header labels
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Illustration
    private let illustrationShadowContainer = UIView()
    private let illustrationView = UIImageView()
    
    private var deviceName: String {
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
    
    // Highlight Section
    private let highlightContainer = UIView()
    private let highlightTitleLabel = UILabel()
    private let highlightDescLabel = UILabel()
    
    // Continue Button
    private let nextButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupConstraints()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareForAnimation()
    }
    
    private func setupUI() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = "100% Safe & Secure"
        titleLabel.textColor = .label
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "All cleaning happens directly on your \(deviceName). We never upload your personal data."
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = UIFont.roundedFont(ofSize: 16, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Illustration Container with Shadow
        illustrationShadowContainer.layer.shadowColor = UIColor.black.cgColor
        illustrationShadowContainer.layer.shadowOpacity = 0.16
        illustrationShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 12)
        illustrationShadowContainer.layer.shadowRadius = 18
        illustrationShadowContainer.layer.masksToBounds = false
        illustrationShadowContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(illustrationShadowContainer)
        
        // Inner rounded image view
        illustrationView.image = UIImage(named: "OnboardingSafe")
        illustrationView.contentMode = .scaleAspectFill
        illustrationView.layer.cornerRadius = 24
        illustrationView.clipsToBounds = true
        illustrationView.translatesAutoresizingMaskIntoConstraints = false
        illustrationShadowContainer.addSubview(illustrationView)
        
        // Highlight Card (No icon, just text)
        highlightContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(highlightContainer)
        
        highlightTitleLabel.text = "Privacy First"
        highlightTitleLabel.textColor = .label
        highlightTitleLabel.font = UIFont.roundedFont(ofSize: 17, weight: .bold)
        highlightTitleLabel.textAlignment = .center
        highlightTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightContainer.addSubview(highlightTitleLabel)
        
        highlightDescLabel.text = "Everything is processed locally. We have absolutely zero access to your photos."
        highlightDescLabel.textColor = .secondaryLabel
        highlightDescLabel.font = UIFont.roundedFont(ofSize: 14, weight: .medium)
        highlightDescLabel.textAlignment = .center
        highlightDescLabel.numberOfLines = 0
        highlightDescLabel.translatesAutoresizingMaskIntoConstraints = false
        highlightContainer.addSubview(highlightDescLabel)
        
        // Action Button
        nextButton.backgroundColor = .label
        nextButton.setTitle("Continue ", for: .normal)
        nextButton.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        nextButton.semanticContentAttribute = .forceRightToLeft
        nextButton.setTitleColor(.systemBackground, for: .normal)
        nextButton.tintColor = .systemBackground
        nextButton.titleLabel?.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        nextButton.layer.cornerRadius = 28
        
        // Add subtle shadow to button
        nextButton.layer.shadowColor = UIColor.black.cgColor
        nextButton.layer.shadowOpacity = 0.15
        nextButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        nextButton.layer.shadowRadius = 16
        
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            illustrationShadowContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            illustrationShadowContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            illustrationShadowContainer.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.8),
            illustrationShadowContainer.heightAnchor.constraint(equalTo: illustrationShadowContainer.widthAnchor, multiplier: 1.2),
            
            illustrationView.topAnchor.constraint(equalTo: illustrationShadowContainer.topAnchor),
            illustrationView.leadingAnchor.constraint(equalTo: illustrationShadowContainer.leadingAnchor),
            illustrationView.trailingAnchor.constraint(equalTo: illustrationShadowContainer.trailingAnchor),
            illustrationView.bottomAnchor.constraint(equalTo: illustrationShadowContainer.bottomAnchor),
            
            highlightContainer.topAnchor.constraint(equalTo: illustrationShadowContainer.bottomAnchor, constant: 32),
            highlightContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            highlightContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            highlightTitleLabel.topAnchor.constraint(equalTo: highlightContainer.topAnchor, constant: 12),
            highlightTitleLabel.leadingAnchor.constraint(equalTo: highlightContainer.leadingAnchor),
            highlightTitleLabel.trailingAnchor.constraint(equalTo: highlightContainer.trailingAnchor),
            
            highlightDescLabel.topAnchor.constraint(equalTo: highlightTitleLabel.bottomAnchor, constant: 6),
            highlightDescLabel.leadingAnchor.constraint(equalTo: highlightContainer.leadingAnchor, constant: 12),
            highlightDescLabel.trailingAnchor.constraint(equalTo: highlightContainer.trailingAnchor, constant: -12),
            highlightDescLabel.bottomAnchor.constraint(equalTo: highlightContainer.bottomAnchor),
            
            nextButton.topAnchor.constraint(equalTo: highlightContainer.bottomAnchor, constant: 40),
            nextButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nextButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            nextButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -48),
            nextButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    // MARK: - Animations
    
    private func prepareForAnimation() {
        let elements = [titleLabel, subtitleLabel, illustrationShadowContainer, highlightContainer, nextButton]
        for (index, element) in elements.enumerated() {
            element.alpha = 0
            element.transform = CGAffineTransform(translationX: 0, y: 30 + CGFloat(index * 10))
        }
    }
    
    private func animateIn() {
        let elements = [titleLabel, subtitleLabel, illustrationShadowContainer, highlightContainer, nextButton]
        
        for (index, element) in elements.enumerated() {
            UIView.animate(withDuration: 0.8,
                           delay: 0.1 + Double(index) * 0.1,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0.5,
                           options: .curveEaseOut,
                           animations: {
                element.alpha = 1
                element.transform = .identity
            }, completion: nil)
        }
    }
    
    @objc private func didTapNext() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        UIView.animate(withDuration: 0.1, animations: {
            self.nextButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.nextButton.transform = .identity
            }) { _ in
                let nextVC = Onboarding4VC()
                if let window = self.view.window {
                    UIView.transition(with: window, duration: 0.45, options: .transitionCrossDissolve, animations: {
                        window.rootViewController = nextVC
                    }, completion: nil)
                }
            }
        }
    }
}
