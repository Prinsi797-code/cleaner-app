import UIKit

protocol CompressPromoBannerDelegate: AnyObject {
    func didTapCompressNow()
}

class CompressPromoBannerView: UIView {
    
    weak var delegate: CompressPromoBannerDelegate?
    
    private let accentBlue = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)

    
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
        iconContainer.backgroundColor = accentBlue.withAlphaComponent(0.2)
        iconContainer.layer.cornerRadius = 35
        containerView.addSubview(iconContainer)
        
        let heroImageView = UIImageView(image: UIImage(systemName: "arrow.down.right.and.arrow.up.left.circle.fill"))
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.tintColor = accentBlue
        iconContainer.addSubview(heroImageView)
        
        // Text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Smart Video Compressor"
        titleLabel.font = UIFont.roundedFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Shrink large videos up to 80% without losing noticeable quality."
        
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        containerView.addSubview(subtitleLabel)
        
        // Button
        tryNowButton.translatesAutoresizingMaskIntoConstraints = false
        tryNowButton.backgroundColor = accentBlue
        tryNowButton.setTitle(" Compress Now", for: .normal)
        tryNowButton.setImage(UIImage(systemName: "wand.and.stars"), for: .normal)
        tryNowButton.tintColor = .white
        tryNowButton.titleLabel?.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        tryNowButton.layer.cornerRadius = 24
        tryNowButton.addTarget(self, action: #selector(handleTryNow), for: .touchUpInside)
        containerView.addSubview(tryNowButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            iconContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            iconContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 70),
            iconContainer.heightAnchor.constraint(equalToConstant: 70),
            
            heroImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            heroImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            heroImageView.widthAnchor.constraint(equalToConstant: 40),
            heroImageView.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            tryNowButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            tryNowButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            tryNowButton.widthAnchor.constraint(equalToConstant: 180),
            tryNowButton.heightAnchor.constraint(equalToConstant: 48),
            tryNowButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    @objc private func handleTryNow() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        delegate?.didTapCompressNow()
    }
}
