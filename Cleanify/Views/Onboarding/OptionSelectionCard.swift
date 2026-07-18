//
//  OptionSelectionCard.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

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
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1.5
        containerView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.2).cgColor
        containerView.isUserInteractionEnabled = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        iconCircle.backgroundColor = iconColor.withAlphaComponent(0.12)
        iconCircle.layer.cornerRadius = 20
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconCircle)
        
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = iconColor
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconImageView)
        
        titleLabel.text = title
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        checkCircle.layer.cornerRadius = 11
        checkCircle.layer.borderWidth = 1.5
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
            iconCircle.widthAnchor.constraint(equalToConstant: 40),
            iconCircle.heightAnchor.constraint(equalToConstant: 40),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: checkCircle.leadingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            checkCircle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            checkCircle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkCircle.widthAnchor.constraint(equalToConstant: 22),
            checkCircle.heightAnchor.constraint(equalToConstant: 22),
            
            checkIcon.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 12),
            checkIcon.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func setSelected(_ selected: Bool) {
        UIView.animate(withDuration: 0.2) {
            if selected {
                self.containerView.layer.borderColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0).cgColor
                self.containerView.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 0.08)
                self.checkCircle.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
                self.checkCircle.layer.borderColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0).cgColor
                self.checkIcon.isHidden = false
            } else {
                self.containerView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.2).cgColor
                self.containerView.backgroundColor = .secondarySystemBackground
                self.checkCircle.backgroundColor = .clear
                self.checkCircle.layer.borderColor = UIColor.systemGray4.cgColor
                self.checkIcon.isHidden = true
            }
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.75 : 1.0
            }
        }
    }
}
