//
//  CleanUpGuideListViewController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 15/07/26.
//

import UIKit

struct CleanUpGuide {
    let title: String
    let iconName: String
    let iconBackgroundColor: UIColor
    let steps: [String]
}

class CleanUpGuideListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var deviceName: String {
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
    
    private lazy var guides: [CleanUpGuide] = [
        CleanUpGuide(
            title: "Offload Unused Apps",
            iconName: "gearshape.fill",
            iconBackgroundColor: UIColor(red: 173/255, green: 191/255, blue: 232/255, alpha: 1.0),
            steps: [
                "Open the 'Settings' app on your \(deviceName).",
                "Scroll down and tap on 'General'.",
                "Tap on '\(deviceName) Storage'.",
                "Review the list of apps. Tap 'Enable' next to 'Offload Unused Apps' to let iOS do it automatically, OR tap on an individual app.",
                "If you tapped an app, select 'Offload App' to free up storage while keeping its documents and data."
            ]
        ),
        CleanUpGuide(
            title: "Clear Telegram Cache",
            iconName: "paperplane.fill",
            iconBackgroundColor: UIColor(red: 122/255, green: 201/255, blue: 245/255, alpha: 1.0),
            steps: [
                "Open the 'Telegram' app on your \(deviceName).",
                "Tap on 'Settings' in the bottom right corner.",
                "Select 'Data and Storage'.",
                "Tap on 'Storage Usage'.",
                "Wait for Telegram to calculate the cache size, then tap 'Clear Entire Cache' at the bottom."
            ]
        ),
        CleanUpGuide(
            title: "Clean Up WhatsApp",
            iconName: "phone.fill",
            iconBackgroundColor: UIColor(red: 161/255, green: 233/255, blue: 184/255, alpha: 1.0),
            steps: [
                "Open the 'WhatsApp' app on your \(deviceName).",
                "Tap on 'Settings' in the bottom right corner.",
                "Select 'Storage and Data'.",
                "Tap on 'Manage Storage'.",
                "Review the suggestions like 'Larger than 5 MB' or 'Many Times Forwarded'.",
                "Select media items and delete them to free up space."
            ]
        ),
        CleanUpGuide(
            title: "Clear Safari Cache",
            iconName: "safari.fill",
            iconBackgroundColor: UIColor(red: 173/255, green: 191/255, blue: 232/255, alpha: 1.0),
            steps: [
                "Open the 'Settings' app on your \(deviceName).",
                "Scroll down and tap on 'Safari'.",
                "Scroll down until you find 'Clear History and Website Data'.",
                "Tap it, choose the timeframe you want to clear, and confirm.",
                "This will remove history, cookies, and other browsing data."
            ]
        ),
        CleanUpGuide(
            title: "Delete Unused Apps",
            iconName: "trash.fill",
            iconBackgroundColor: UIColor(red: 204/255, green: 173/255, blue: 232/255, alpha: 1.0),
            steps: [
                "Go to your Home Screen and find an app you no longer use.",
                "Touch and hold the app icon until a menu appears.",
                "Tap 'Remove App'.",
                "Tap 'Delete App' to completely remove it and its data from your \(deviceName).",
                "Alternatively, you can delete apps from Settings > General > \(deviceName) Storage."
            ]
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)
        
        let headerIcon = UIImageView(image: UIImage(systemName: "square.stack.3d.up.fill"))
        headerIcon.tintColor = UIColor(red: 88/255, green: 172/255, blue: 250/255, alpha: 1.0)
        headerIcon.contentMode = .scaleAspectFit
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(headerIcon)
        
        titleLabel.text = "Clean Up Your \(deviceName)"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(titleLabel)
        
        subtitleLabel.text = "Clear cache and unwanted files manually to optimize your \(deviceName) storage"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(subtitleLabel)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(CleanUpGuideCell.self, forCellReuseIdentifier: "GuideCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),
            
            headerContainer.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            headerIcon.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            headerIcon.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            headerIcon.widthAnchor.constraint(equalToConstant: 48),
            headerIcon.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.topAnchor.constraint(equalTo: headerIcon.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            
            tableView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func didTapBack() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return guides.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "GuideCell", for: indexPath) as? CleanUpGuideCell else {
            return UITableViewCell()
        }
        let guide = guides[indexPath.row]
        cell.configure(title: guide.title, iconName: guide.iconName, iconBgColor: guide.iconBackgroundColor)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let guide = guides[indexPath.row]
        let stepsVC = CleanUpStepsViewController(guide: guide)
        navigationController?.pushViewController(stepsVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

class CleanUpGuideCell: UITableViewCell {
    
    private let containerView = UIView()
    private let iconBackgroundView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let arrowIcon = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.backgroundColor = .secondarySystemGroupedBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        iconBackgroundView.layer.cornerRadius = 8
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconBackgroundView)
        
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconBackgroundView.addSubview(iconImageView)
        
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        arrowIcon.image = UIImage(systemName: "chevron.right")
        arrowIcon.tintColor = .secondaryLabel
        arrowIcon.contentMode = .scaleAspectFit
        arrowIcon.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(arrowIcon)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            
            iconBackgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconBackgroundView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 40),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 40),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconBackgroundView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: arrowIcon.leadingAnchor, constant: -16),
            
            arrowIcon.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            arrowIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            arrowIcon.widthAnchor.constraint(equalToConstant: 14),
            arrowIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    func configure(title: String, iconName: String, iconBgColor: UIColor) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: iconName)
        iconBackgroundView.backgroundColor = iconBgColor
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.2) {
            self.containerView.alpha = highlighted ? 0.7 : 1.0
        }
    }
}
