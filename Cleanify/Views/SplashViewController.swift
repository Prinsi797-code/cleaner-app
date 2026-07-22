import UIKit

class SplashViewController: UIViewController {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    private var loadStartTime: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateEntrance()
        loadDataAndTransition()
    }
    
    private func setupUI() {
        // App Icon
        iconImageView.image = UIImage(named: "app_icon")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 28
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)
        
        // App Icon Shadow Wrapper
        let iconShadowView = UIView()
        iconShadowView.translatesAutoresizingMaskIntoConstraints = false
        iconShadowView.backgroundColor = .clear
        iconShadowView.layer.shadowColor = UIColor.black.cgColor
        iconShadowView.layer.shadowOpacity = 0.15
        iconShadowView.layer.shadowOffset = CGSize(width: 0, height: 8)
        iconShadowView.layer.shadowRadius = 16
        view.insertSubview(iconShadowView, belowSubview: iconImageView)
        
        // Title
        titleLabel.text = "iOS Cleanify"
        titleLabel.font = UIFont.roundedFont(ofSize: 38, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "Smart Storage Saver"
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Activity Indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.tintColor = .systemBlue
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // Initial animation state
        iconImageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        iconImageView.alpha = 0
        iconShadowView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        iconShadowView.alpha = 0
        
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        
        activityIndicator.alpha = 0
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            iconImageView.widthAnchor.constraint(equalToConstant: 120),
            iconImageView.heightAnchor.constraint(equalToConstant: 120),
            
            iconShadowView.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            iconShadowView.leadingAnchor.constraint(equalTo: iconImageView.leadingAnchor),
            iconShadowView.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor),
            iconShadowView.bottomAnchor.constraint(equalTo: iconImageView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
    }
    
    private func animateEntrance() {
        
        UIView.animate(withDuration: 0.8, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.6, options: .curveEaseOut, animations: {
            self.iconImageView.transform = .identity
            self.iconImageView.alpha = 1.0
        }, completion: nil)
        
        
        UIView.animate(withDuration: 0.6, delay: 0.2, options: .curveEaseOut, animations: {
            self.titleLabel.alpha = 1.0
            self.titleLabel.transform = .identity
            
            self.subtitleLabel.alpha = 1.0
            self.subtitleLabel.transform = .identity
            
            self.activityIndicator.alpha = 1.0
        }, completion: nil)
    }
    
    private func loadDataAndTransition() {
        loadStartTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = PhotoScanManager.shared.loadFromDisk()
            let _ = VideoScanManager.shared.loadFromDisk()
            let _ = ContactScanManager.shared.loadFromDisk()
            
            let elapsedTime = Date().timeIntervalSince(self.loadStartTime ?? Date())
            let minimumDisplayDuration: TimeInterval = 1.4
            let remainingTime = max(0, minimumDisplayDuration - elapsedTime)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                self.transitionToNextScreen()
            }
        }
    }
    
    private func transitionToNextScreen() {
        guard let window = view.window else { return }
        
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")
        let nextVC: UIViewController = onboardingCompleted ? MainTabBarController() : Onboarding1VC()
        
        UIView.animate(withDuration: 0.4, animations: {
            self.iconImageView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.iconImageView.alpha = 0.0
            self.titleLabel.alpha = 0.0
            self.subtitleLabel.alpha = 0.0
            self.activityIndicator.alpha = 0.0
        }) { _ in
            window.rootViewController = nextVC
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
        }
    }
}
