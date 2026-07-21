import UIKit

class OptionSelectionCard: UIControl {
    
    private let containerView = UIView()
    private let iconCircle = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let checkCircle = UIView()
    private let checkIcon = UIImageView()
    
    init(title: String, icon: String, iconColor: UIColor) {
        super.init(frame: .zero)
        setup(title: title, icon: icon, iconColor: iconColor)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setup(title: String, icon: String, iconColor: UIColor) {
        translatesAutoresizingMaskIntoConstraints = false
        
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 2.0
        containerView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.2).cgColor
        containerView.isUserInteractionEnabled = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Soft shadow
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.05
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        
        addSubview(containerView)
        
        iconCircle.backgroundColor = iconColor.withAlphaComponent(0.12)
        iconCircle.layer.cornerRadius = 24
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconCircle)
        
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = iconColor
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconImageView)
        
        titleLabel.text = title
        titleLabel.textColor = .label
        titleLabel.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        checkCircle.layer.cornerRadius = 14
        checkCircle.layer.borderWidth = 2.0
        checkCircle.layer.borderColor = UIColor.systemGray4.cgColor
        checkCircle.backgroundColor = .clear
        checkCircle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(checkCircle)
        
        checkIcon.image = UIImage(systemName: "checkmark")
        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkCircle.addSubview(checkIcon)
        checkIcon.isHidden = true
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            iconCircle.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconCircle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 48),
            iconCircle.heightAnchor.constraint(equalToConstant: 48),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: checkCircle.leadingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            checkCircle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            checkCircle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkCircle.widthAnchor.constraint(equalToConstant: 28),
            checkCircle.heightAnchor.constraint(equalToConstant: 28),
            
            checkIcon.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 14),
            checkIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    func setSelected(_ selected: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            if selected {
                self.containerView.layer.borderColor = UIColor.label.cgColor
                self.containerView.backgroundColor = UIColor.label.withAlphaComponent(0.04)
                self.checkCircle.backgroundColor = UIColor.label
                self.checkCircle.layer.borderColor = UIColor.label.cgColor
                self.checkIcon.isHidden = false
                self.checkIcon.tintColor = .systemBackground
                self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                self.containerView.layer.shadowOpacity = 0.1
            } else {
                self.containerView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.2).cgColor
                self.containerView.backgroundColor = .secondarySystemBackground
                self.checkCircle.backgroundColor = .clear
                self.checkCircle.layer.borderColor = UIColor.systemGray4.cgColor
                self.checkIcon.isHidden = true
                self.transform = .identity
                self.containerView.layer.shadowOpacity = 0.05
            }
        }, completion: nil)
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                if self.isHighlighted {
                    self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                } else {
                    self.transform = .identity
                }
            }
        }
    }
}
