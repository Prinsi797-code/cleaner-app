//
//  SettingsViewController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit

class SettingsViewController: UIViewController {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [SettingsSection] = []
    
    private var deviceName: String {
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
    
    struct SettingsSection {
        let title: String
        let items: [SettingsItem]
    }
    
    struct SettingsItem {
        let title: String
        let icon: String
        let iconColor: UIColor
        let type: ItemType
        
        enum ItemType {
            case recentlyDeleted
            case darkMode
            case language
            case privacyPolicy
            case termsOfService
            case rateApp
            case shareApp
            case resetOnboarding
            case cleanupGuide
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // Custom Header Labels
        titleLabel.text = "Settings"
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        subtitleLabel.text = "Configure app languages and dark mode settings."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SettingsCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SettingsToggleCell.self, forCellReuseIdentifier: "SettingsToggleCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.showsVerticalScrollIndicator = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            tableView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadSettings() {
        sections = [
            SettingsSection(title: "How to Clean Up", items: [
                SettingsItem(title: "View Stories", icon: "graduationcap.fill", iconColor: .systemTeal, type: .cleanupGuide)
            ]),
            SettingsSection(title: "Junk Storage", items: [
                SettingsItem(title: "Recently Deleted Guide", icon: "trash.fill", iconColor: .systemRed, type: .recentlyDeleted)
            ]),
            SettingsSection(title: "Preferences", items: [
                SettingsItem(title: "Dark Mode", icon: "moon.fill", iconColor: .systemBlue, type: .darkMode),
                //SettingsItem(title: "App Language", icon: "globe", iconColor: .systemGreen, type: .language)
            ]),
            SettingsSection(title: "About & Legal", items: [
                SettingsItem(title: "Privacy Policy", icon: "hand.raised.fill", iconColor: .systemOrange, type: .privacyPolicy),
                SettingsItem(title: "Terms of Service", icon: "doc.text.fill", iconColor: .systemGray, type: .termsOfService),
                SettingsItem(title: "Rate Cleanify", icon: "star.fill", iconColor: .systemYellow, type: .rateApp),
                SettingsItem(title: "Share Cleanify", icon: "square.and.arrow.up.fill", iconColor: .systemPink, type: .shareApp)
            ])
        ]
        tableView.reloadData()
    }
    
    // MARK: - Action Handlers
    
    private func showRecentlyDeletedGuide() {
        let alert = UIAlertController(
            title: "Recently Deleted Guide",
            message: "iOS sandboxing prevents direct cleaning of Apple's trash album. To permanently free up space:\n\n1. Open the native Photos App\n2. Navigate to Albums tab\n3. Scroll down to 'Recently Deleted'\n4. Unlock it and tap 'Delete All'\n\nWould you like to open the Photos App now?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Photos App", style: .default, handler: { _ in
            if let url = URL(string: "photos-redirect://") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Got It", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showLanguageSelector() {
        let alert = UIAlertController(title: "Select Language", message: "Choose your preferred interface language.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "English (US)", style: .default, handler: { _ in
            self.showToast(message: "Language set to English")
        }))
        alert.addAction(UIAlertAction(title: "Hindi (हिंदी)", style: .default, handler: { _ in
            self.showToast(message: "भाषा हिंदी में सेट की गई है")
        }))
        alert.addAction(UIAlertAction(title: "Spanish (Español)", style: .default, handler: { _ in
            self.showToast(message: "Idioma establecido en Español")
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func triggerShare() {
        let text = "Check out Cleanify! The fast and premium way to clean your \(deviceName) storage."
        let items = [text]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(ac, animated: true)
    }
    
    private func triggerRate() {
        showToast(message: "Thank you for rating Cleanify!")
    }
    
    private func showWebLink(title: String, urlString: String) {
        let alert = UIAlertController(title: title, message: "This would normally open: \(urlString)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func performResetOnboarding() {
        let alert = UIAlertController(title: "Reset Onboarding?", message: "This will clear your completed status and restart the initial onboarding flow.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { _ in
            UserDefaults.standard.set(false, forKey: "onboarding_completed")
            
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                UIView.transition(with: window, duration: 0.45, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = Onboarding1VC()
                }, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showToast(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }
}

// MARK: - TableView delegates
extension SettingsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        
        if item.type == .darkMode {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsToggleCell", for: indexPath) as? SettingsToggleCell else {
                return UITableViewCell()
            }
            cell.configure(with: item)
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as? SettingsCell else {
                return UITableViewCell()
            }
            cell.configure(with: item)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        
        switch item.type {
        case .recentlyDeleted:
            showRecentlyDeletedGuide()
        case .darkMode:
            break
        case .language:
            showLanguageSelector()
        case .privacyPolicy:
            showWebLink(title: "Privacy Policy", urlString: "https://cleanify.app/privacy")
        case .termsOfService:
            showWebLink(title: "Terms of Service", urlString: "https://cleanify.app/terms")
        case .rateApp:
            triggerRate()
        case .shareApp:
            triggerShare()
        case .resetOnboarding:
            break
        case .cleanupGuide:
            let vc = CleanUpGuideListViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - SettingsCell Standard Component
class SettingsCell: UITableViewCell {
    
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        iconContainer.layer.cornerRadius = 8
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconContainer)
        
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with item: SettingsViewController.SettingsItem) {
        titleLabel.text = item.title
        iconContainer.backgroundColor = item.iconColor
        iconView.image = UIImage(systemName: item.icon)
        
        if item.type == .resetOnboarding {
            titleLabel.textColor = .systemRed
        } else {
            titleLabel.textColor = .label
        }
    }
}

// MARK: - SettingsToggleCell with Switch Override
class SettingsToggleCell: UITableViewCell {
    
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let toggleSwitch = UISwitch()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        iconContainer.layer.cornerRadius = 8
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconContainer)
        
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        toggleSwitch.addTarget(self, action: #selector(didToggle), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toggleSwitch)
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with item: SettingsViewController.SettingsItem) {
        titleLabel.text = item.title
        iconContainer.backgroundColor = item.iconColor
        iconView.image = UIImage(systemName: item.icon)
        
        if item.type == .darkMode {
            if let isDark = UserDefaults.standard.object(forKey: "isDarkModeForced") as? Bool {
                toggleSwitch.isOn = isDark
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first {
                toggleSwitch.isOn = window.traitCollection.userInterfaceStyle == .dark
            }
        }
    }
    
    @objc private func didToggle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let isDark = toggleSwitch.isOn
        UserDefaults.standard.set(isDark, forKey: "isDarkModeForced")
        let style: UIUserInterfaceStyle = isDark ? .dark : .light
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                    window.overrideUserInterfaceStyle = style
                }, completion: nil)
            }
        }
    }
}
