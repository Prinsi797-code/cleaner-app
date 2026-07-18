import UIKit

protocol RecentlyDeletedCardDelegate: AnyObject {
    func didTapOpenPhotos()
}

class RecentlyDeletedCardView: UIView {
    
    weak var delegate: RecentlyDeletedCardDelegate?
    
    private let containerView = UIView()
    private let iconContainer = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    
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
        iconContainer.backgroundColor = .systemRed.withAlphaComponent(0.15)
        iconContainer.layer.cornerRadius = 35
        containerView.addSubview(iconContainer)
        
        let heroImageView = UIImageView(image: UIImage(systemName: "trash.circle.fill"))
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.tintColor = .systemRed
        iconContainer.addSubview(heroImageView)
        
        // Text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Empty Recently Deleted"
        titleLabel.font = UIFont.roundedFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Apple requires you to manually empty this folder in the Photos app to permanently free up space."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        containerView.addSubview(subtitleLabel)
        
        // Button
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.backgroundColor = .systemRed
        actionButton.setTitle(" Open Photos", for: .normal)
        actionButton.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        actionButton.tintColor = .white
        actionButton.titleLabel?.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        actionButton.layer.cornerRadius = 24
        actionButton.addTarget(self, action: #selector(handleOpenPhotos), for: .touchUpInside)
        containerView.addSubview(actionButton)
        
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
            
            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 180),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    @objc private func handleOpenPhotos() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        delegate?.didTapOpenPhotos()
    }
}
