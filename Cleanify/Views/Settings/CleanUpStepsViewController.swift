//
//  CleanUpStepsViewController.swift
//  Cleanify
//
//  Created by Hevin on 15/07/26.
//

import UIKit

class CleanUpStepsViewController: UIViewController {
    
    private let guide: CleanUpGuide
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let iconBackgroundView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let stepsStackView = UIStackView()
    
    init(guide: CleanUpGuide) {
        self.guide = guide
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateSteps()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .label
        backButton.backgroundColor = .tertiarySystemFill
        backButton.layer.cornerRadius = 18
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        view.addSubview(backButton)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        iconBackgroundView.backgroundColor = guide.iconBackgroundColor
        iconBackgroundView.layer.cornerRadius = 16
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBackgroundView)
        
        iconImageView.image = UIImage(systemName: guide.iconName)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconBackgroundView.addSubview(iconImageView)
        
        titleLabel.text = guide.title
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        stepsStackView.axis = .vertical
        stepsStackView.spacing = 20
        stepsStackView.alignment = .fill
        stepsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepsStackView)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),
            
            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            iconBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            iconBackgroundView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 80),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 80),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.topAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            stepsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            stepsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stepsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stepsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    @objc private func didTapBack() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.popViewController(animated: true)
    }
    
    private func populateSteps() {
        for (index, stepText) in guide.steps.enumerated() {
            let stepView = createStepView(number: index + 1, text: stepText)
            stepsStackView.addArrangedSubview(stepView)
        }
    }
    
    private func createStepView(number: Int, text: String) -> UIView {
        let container = UIView()
        
        let numberLabel = UILabel()
        numberLabel.text = "\(number)"
        numberLabel.font = .systemFont(ofSize: 16, weight: .bold)
        numberLabel.textColor = .systemGroupedBackground
        numberLabel.textAlignment = .center
        numberLabel.backgroundColor = guide.iconBackgroundColor
        numberLabel.layer.cornerRadius = 14
        numberLabel.clipsToBounds = true
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numberLabel)
        
        let textLabel = UILabel()
        textLabel.text = text
        textLabel.font = .systemFont(ofSize: 16, weight: .regular)
        textLabel.textColor = .label
        textLabel.numberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            numberLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            numberLabel.topAnchor.constraint(equalTo: container.topAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 28),
            numberLabel.heightAnchor.constraint(equalToConstant: 28),
            
            textLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            textLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
}
