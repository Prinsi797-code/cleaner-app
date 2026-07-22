import UIKit

protocol CompressPromoBannerDelegate: AnyObject {
    func didTapCompressNow()
}

class CompressPromoBannerView: UIView {
    
    weak var delegate: CompressPromoBannerDelegate?
    
    private let accentBlue = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
    
    private let containerView = UIView()
    private let imageCardView = UIView()
    private let heroImageView = UIImageView()
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
        // Main Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 28
        addSubview(containerView)
        
        // Styled Image Card Container
        imageCardView.translatesAutoresizingMaskIntoConstraints = false
        imageCardView.backgroundColor = accentBlue.withAlphaComponent(0)
        imageCardView.layer.cornerRadius = 20
        imageCardView.layer.borderWidth = 1
        imageCardView.layer.borderColor = accentBlue.withAlphaComponent(0).cgColor
        containerView.addSubview(imageCardView)
        
        // Hero Image (video_compress asset)
        heroImageView.image = UIImage(named: "video_compress")
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.clipsToBounds = true
        imageCardView.addSubview(heroImageView)
        
        // Text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Smart Video Compressor"
        titleLabel.font = UIFont.roundedFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Shrink large videos up to 80% without losing noticeable quality."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        containerView.addSubview(subtitleLabel)
        
        // Button
        tryNowButton.translatesAutoresizingMaskIntoConstraints = false
        tryNowButton.backgroundColor = accentBlue
        tryNowButton.setTitle(" Compress Now", for: .normal)
        tryNowButton.setTitleColor(.white, for: .normal)
        if let wandIcon = UIImage(systemName: "wand.and.stars")?.withRenderingMode(.alwaysTemplate) {
            tryNowButton.setImage(wandIcon, for: .normal)
        }
        tryNowButton.tintColor = .white
        tryNowButton.imageView?.tintColor = .white
        tryNowButton.titleLabel?.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        tryNowButton.layer.cornerRadius = 24
        tryNowButton.layer.shadowColor = accentBlue.cgColor
        tryNowButton.layer.shadowOpacity = 0.3
        tryNowButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        tryNowButton.layer.shadowRadius = 8
        tryNowButton.addTarget(self, action: #selector(handleTryNow), for: .touchUpInside)
        containerView.addSubview(tryNowButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            imageCardView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            imageCardView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageCardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            imageCardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            imageCardView.heightAnchor.constraint(equalToConstant: 160),
            
            heroImageView.centerXAnchor.constraint(equalTo: imageCardView.centerXAnchor),
            heroImageView.centerYAnchor.constraint(equalTo: imageCardView.centerYAnchor),
            heroImageView.widthAnchor.constraint(equalTo: imageCardView.widthAnchor, constant: -24),
            heroImageView.heightAnchor.constraint(equalTo: imageCardView.heightAnchor, constant: -16),
            
            titleLabel.topAnchor.constraint(equalTo: imageCardView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            tryNowButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            tryNowButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            tryNowButton.widthAnchor.constraint(equalToConstant: 180),
            tryNowButton.heightAnchor.constraint(equalToConstant: 44),
            tryNowButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func handleTryNow() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        delegate?.didTapCompressNow()
    }
}
