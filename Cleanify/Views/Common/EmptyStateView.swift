import UIKit

class EmptyStateView: UIView {
    
    private let stackView = UIStackView()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    init(iconName: String = "checkmark.circle.fill", title: String = "No Items Found", subtitle: String = "Your library is clean and organized.", iconColor: UIColor = .systemBlue) {
        super.init(frame: .zero)
        setupUI()
        configure(iconName: iconName, title: title, subtitle: subtitle, iconColor: iconColor)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        // Icon Container
        iconContainer.layer.cornerRadius = 40
        iconContainer.clipsToBounds = true
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconContainer)
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)
        
        // Title Label
        titleLabel.font = UIFont.roundedFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stackView.addArrangedSubview(titleLabel)
        
        // Subtitle Label
        subtitleLabel.font = UIFont.roundedFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        stackView.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 42),
            iconImageView.heightAnchor.constraint(equalToConstant: 42)
        ])
    }
    
    func configure(iconName: String, title: String, subtitle: String, iconColor: UIColor = .systemBlue) {
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.tintColor = iconColor
        iconContainer.backgroundColor = iconColor.withAlphaComponent(0.12)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
