import UIKit
import StoreKit

@available(iOS 15.0, *)
class PaywallViewController: UIViewController {
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let closeButton = UIButton(type: .system)
    
    // Header
    private let headerStack = UIStackView()
    private let headerTextStack = UIStackView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private var premiumBadgeView: UIView!
    
    // Features
    private var featuresContainerView: UIView!
    
    // VS Comparison View
    private let comparisonContainer = UIView()
    private let vsStack = UIStackView()
    
    // Subscriptions Options
    private let optionsStack = UIStackView()
    private var optionCards: [SubscriptionOptionCard] = []
    
    // Bottom Action
    private let secureInfoStack = UIStackView()
    private let subscribeButton = UIButton(type: .custom)
    
    private let restoreButton = UIButton(type: .system)
    private let footerTextLabel = UILabel()
    
    private var selectedIndex = 1 // Default to Monthly (middle)
    private var products: [Product] = []
    private var loadingSpinner = UIActivityIndicatorView(style: .large)
    
    private let backgroundGradient = CAGradientLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        
        // Fetch products
        loadProducts()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        backgroundGradient.colors = [
            UIColor.systemBlue.withAlphaComponent(0.2).cgColor,
            UIColor.systemBackground.cgColor
        ]
        backgroundGradient.locations = [0.0, 0.4]
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Close Button
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label
        closeButton.backgroundColor = .clear
        closeButton.layer.cornerRadius = 16
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        contentView.addSubview(closeButton)
        
        // Premium Badge Pill
        let badgeContainer = UIView()
        badgeContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        badgeContainer.layer.cornerRadius = 8
        badgeContainer.layer.borderWidth = 1
        badgeContainer.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeContainer)
        
        let badgeIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
        badgeIcon.tintColor = .systemBlue
        badgeIcon.contentMode = .scaleAspectFit
        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeIcon)
        
        let badgeLabel = UILabel()
        badgeLabel.text = "PREMIUM"
        badgeLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        badgeLabel.textColor = .systemBlue
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        
        NSLayoutConstraint.activate([
            badgeIcon.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8),
            badgeIcon.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 12),
            badgeIcon.heightAnchor.constraint(equalToConstant: 12),
            
            badgeLabel.leadingAnchor.constraint(equalTo: badgeIcon.trailingAnchor, constant: 4),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8),
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4)
        ])
        
        // Header Text Stack
        headerTextStack.axis = .vertical
        headerTextStack.spacing = 8
        headerTextStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerTextStack)
        
        let titleLabelLine1 = UILabel()
        titleLabelLine1.text = "Clean More."
        titleLabelLine1.font = .systemFont(ofSize: 42, weight: .black)
        titleLabelLine1.textColor = .label
        
        let titleLabelLine2 = UILabel()
        titleLabelLine2.text = "Free Space."
        titleLabelLine2.font = .systemFont(ofSize: 42, weight: .black)
        titleLabelLine2.textColor = .systemBlue
        
        let titlesStack = UIStackView(arrangedSubviews: [titleLabelLine1, titleLabelLine2])
        titlesStack.axis = .vertical
        titlesStack.spacing = -8
        
        descriptionLabel.text = "Unlock premium features and keep your device clean, fast, and organized."
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        headerTextStack.addArrangedSubview(titlesStack)
        headerTextStack.addArrangedSubview(descriptionLabel)
        
        // Save the badgeContainer in a local var or just add constraints later
        self.premiumBadgeView = badgeContainer
        
        // Features (2x2 Grid)
        setupFeaturesGrid()
        
        // Options Stack
        optionsStack.axis = .vertical
        optionsStack.spacing = 12
        optionsStack.distribution = .fillEqually
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(optionsStack)
        
        // Create 3 Cards
        let weeklyCard = SubscriptionOptionCard(
            period: "Weekly Plan",
            subtext: "Stay consistent, every week",
            accessBadgeText: "7 Days Access",
            price: "₹99.00",
            breakdown: "₹14.14 / day",
            saveText: nil,
            index: 0
        )
        let monthlyCard = SubscriptionOptionCard(
            period: "Monthly Plan",
            subtext: "Build a healthy habit",
            accessBadgeText: "30 Days Access",
            price: "₹299.00",
            breakdown: "₹9.96 / day",
            saveText: nil,
            index: 1
        )
        let yearlyCard = SubscriptionOptionCard(
            period: "Yearly Plan",
            subtext: "Best value, stay fit all year",
            accessBadgeText: "365 Days Access",
            price: "₹999.00",
            breakdown: "₹2.73 / day",
            saveText: "Save 77%",
            index: 2
        )
        
        optionCards = [weeklyCard, monthlyCard, yearlyCard]
        for card in optionCards {
            card.addTarget(self, action: #selector(didSelectCard(_:)), for: .touchUpInside)
            optionsStack.addArrangedSubview(card)
        }
        
        updateCardSelection()
        
        // Bottom details
        secureInfoStack.axis = .horizontal
        secureInfoStack.distribution = .equalCentering
        secureInfoStack.alignment = .center
        secureInfoStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secureInfoStack)
        
        let info1 = createSecureInfoItem(icon: "checkmark.shield", text: "Secure\nPayment")
        let info2 = createSecureInfoItem(icon: "arrow.2.squarepath", text: "Cancel\nAnytime")
        let info3 = createSecureInfoItem(icon: "person.3", text: "Trusted by\n100K+ Users")
        
        secureInfoStack.addArrangedSubview(info1)
        secureInfoStack.addArrangedSubview(info2)
        secureInfoStack.addArrangedSubview(info3)
        
        // Subscribe Button
        subscribeButton.layer.cornerRadius = 16
        subscribeButton.clipsToBounds = true
        subscribeButton.backgroundColor = .systemBlue
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.addTarget(self, action: #selector(didTapSubscribe), for: .touchUpInside)
        contentView.addSubview(subscribeButton)
        
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .center
        buttonStack.isUserInteractionEnabled = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.addSubview(buttonStack)
        
        let btnIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
        btnIcon.tintColor = .white
        
        btnIcon.contentMode = .scaleAspectFit
        btnIcon.translatesAutoresizingMaskIntoConstraints = false
        btnIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        btnIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        
        let btnTitle = UILabel()
        btnTitle.text = "Subscribe Now"
        btnTitle.textColor = .white
        btnTitle.font = .systemFont(ofSize: 18, weight: .bold)
        
        buttonStack.addArrangedSubview(btnIcon)
        buttonStack.addArrangedSubview(btnTitle)
        
        NSLayoutConstraint.activate([
            buttonStack.centerXAnchor.constraint(equalTo: subscribeButton.centerXAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: subscribeButton.centerYAnchor)
        ])
        
        // Footer links
        restoreButton.setTitle("Restore Purchases", for: .normal)
        restoreButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        restoreButton.setTitleColor(.systemBlue, for: .normal)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.addTarget(self, action: #selector(didTapRestore), for: .touchUpInside)
        contentView.addSubview(restoreButton)
        
        let footerText = "By continuing, you agree to our Terms of Service & Privacy Policy"
        let attrString = NSMutableAttributedString(string: footerText)
        let orangeColor = UIColor.systemBlue
        
        if let termRange = footerText.range(of: "Terms of Service") {
            let nsRange = NSRange(termRange, in: footerText)
            attrString.addAttribute(.foregroundColor, value: orangeColor, range: nsRange)
            attrString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
        }
        if let privRange = footerText.range(of: "Privacy Policy") {
            let privNsRange = NSRange(privRange, in: footerText)
            attrString.addAttribute(.foregroundColor, value: orangeColor, range: privNsRange)
            attrString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: privNsRange)
        }
        
        footerTextLabel.attributedText = attrString
        footerTextLabel.font = .systemFont(ofSize: 11, weight: .regular)
        footerTextLabel.textColor = .secondaryLabel
        footerTextLabel.textAlignment = .center
        footerTextLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerTextLabel)
        
        // Add gesture to footer text
        footerTextLabel.isUserInteractionEnabled = true
        let footerTap = UITapGestureRecognizer(target: self, action: #selector(didTapFooterText(_:)))
        footerTextLabel.addGestureRecognizer(footerTap)
        
        // Loading Spinner
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.hidesWhenStopped = true
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func createSecureInfoItem(icon: String, text: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 6
        container.alignment = .center
        
        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let label = UILabel()
        label.text = text
        label.numberOfLines = 2
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabel
        
        container.addArrangedSubview(imageView)
        container.addArrangedSubview(label)
        
        return container
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            closeButton.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 0),
            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            premiumBadgeView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 20),
            premiumBadgeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            headerTextStack.topAnchor.constraint(equalTo: premiumBadgeView.bottomAnchor, constant: 16),
            headerTextStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerTextStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            featuresContainerView.topAnchor.constraint(equalTo: headerTextStack.bottomAnchor, constant: 24),
            featuresContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            featuresContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            optionsStack.topAnchor.constraint(equalTo: featuresContainerView.bottomAnchor, constant: 16),
            optionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            optionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            secureInfoStack.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 16),
            secureInfoStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secureInfoStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subscribeButton.topAnchor.constraint(equalTo: secureInfoStack.bottomAnchor, constant: 16),
            subscribeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subscribeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            subscribeButton.heightAnchor.constraint(equalToConstant: 54),
            
            restoreButton.topAnchor.constraint(equalTo: subscribeButton.bottomAnchor, constant: 6),
            restoreButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            footerTextLabel.topAnchor.constraint(equalTo: restoreButton.bottomAnchor, constant: 6),
            footerTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            footerTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            footerTextLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    

    private func setupFeaturesGrid() {
        let featuresContainer = UIView()
        featuresContainer.backgroundColor = .secondarySystemGroupedBackground
        featuresContainer.layer.cornerRadius = 16
        featuresContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(featuresContainer)
        
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.distribution = .fillEqually
        hStack.alignment = .top
        hStack.translatesAutoresizingMaskIntoConstraints = false
        featuresContainer.addSubview(hStack)
        
        // Remove old featuresTitleLabel constraints if any (it will be removed in setupConstraints)
        
        let card1 = FeatureCard(iconName: "infinity", title: "Unlimited\nScans")
        let card2 = FeatureCard(iconName: "sparkles", title: "Deep\nClean")
        let card3 = FeatureCard(iconName: "photo.on.rectangle", title: "Duplicate\nRemover")
        let card4 = FeatureCard(iconName: "nosign", title: "Ad Free\nExperience")
        
        hStack.addArrangedSubview(card1)
        hStack.addArrangedSubview(card2)
        hStack.addArrangedSubview(card3)
        hStack.addArrangedSubview(card4)
        
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: featuresContainer.topAnchor, constant: 16),
            hStack.bottomAnchor.constraint(equalTo: featuresContainer.bottomAnchor, constant: -16),
            hStack.leadingAnchor.constraint(equalTo: featuresContainer.leadingAnchor, constant: 8),
            hStack.trailingAnchor.constraint(equalTo: featuresContainer.trailingAnchor, constant: -8)
        ])
        
        self.featuresContainerView = featuresContainer
    }
    

    private func updateCardSelection() {
        for i in 0..<optionCards.count {
            optionCards[i].isSelectedCard = (i == selectedIndex)
        }
    }
    
    private func loadProducts() {
        loadingSpinner.startAnimating()
        Task {
            let fetched = await PremiumManager.shared.fetchProducts()
            await MainActor.run {
                self.loadingSpinner.stopAnimating()
                if !fetched.isEmpty {
                    self.products = fetched
                    // Update option cards with real prices
                    for i in 0..<min(self.products.count, self.optionCards.count) {
                        let product = self.products[i]
                        let card = self.optionCards[i]
                        
                        card.priceLabel.text = product.displayPrice
                        
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        formatter.locale = product.priceFormatStyle.locale
                        
                        if product.id.contains("weekly") {
                            let daily = (product.price as NSDecimalNumber).dividing(by: 7)
                            if let formattedDaily = formatter.string(from: daily) {
                                card.breakdownLabel.text = "\(formattedDaily) / day"
                            }
                        } else if product.id.contains("monthly") {
                            let daily = (product.price as NSDecimalNumber).dividing(by: 30)
                            if let formattedDaily = formatter.string(from: daily) {
                                card.breakdownLabel.text = "\(formattedDaily) / day"
                            }
                        } else if product.id.contains("yearly") {
                            let daily = (product.price as NSDecimalNumber).dividing(by: 365)
                            if let formattedDaily = formatter.string(from: daily) {
                                card.breakdownLabel.text = "\(formattedDaily) / day"
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc private func didSelectCard(_ sender: SubscriptionOptionCard) {
        selectedIndex = sender.index
        updateCardSelection()
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    @objc private func didTapClose() {
        dismiss(animated: true)
    }
    
    @objc private func didTapSubscribe() {
        guard selectedIndex < products.count else {
            // Fallback simulated success if StoreKit products couldn't load (Sandbox safety)
            simulatePremiumActivation()
            return
        }
        
        let product = products[selectedIndex]
        loadingSpinner.startAnimating()
        
        Task {
            let success = await PremiumManager.shared.purchase(product)
            await MainActor.run {
                self.loadingSpinner.stopAnimating()
                if success {
                    self.showSuccessAlert()
                } else {
                    self.showErrorAlert(message: "Purchase could not be completed.")
                }
            }
        }
    }
    
    private func simulatePremiumActivation() {
        let alert = UIAlertController(title: "Sandbox Mode", message: "Connecting to App Store sandbox failed. Would you like to simulate Premium activation?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Simulate Upgrade", style: .default, handler: { [weak self] _ in
            PremiumManager.shared.isPremium = true
            self?.showSuccessAlert()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSuccessAlert() {
        let alert = UIAlertController(title: "Premium Activated", message: "Thank you for upgrading! You now have unlimited access with no ads.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }))
        present(alert, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Purchase Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func didTapRestore() {
        loadingSpinner.startAnimating()
        Task {
            let success = await PremiumManager.shared.restorePurchases()
            await MainActor.run {
                self.loadingSpinner.stopAnimating()
                if success {
                    let alert = UIAlertController(title: "Restored", message: "Your premium membership was successfully restored.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                        self?.dismiss(animated: true)
                    }))
                    self.present(alert, animated: true)
                } else {
                    let alert = UIAlertController(title: "Restore Failed", message: "No active premium subscriptions found to restore.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    @objc private func didTapFooterText(_ gesture: UITapGestureRecognizer) {
        let text = footerTextLabel.text ?? ""
        let termsRange = (text as NSString).range(of: "Terms of Use")
        let privacyRange = (text as NSString).range(of: "Privacy Policy")
        
        let location = gesture.location(in: footerTextLabel)
        
        // Simple bounding check or just present privacy policy by default (standard practice for safety)
        if gesture.didTapAttributedTextInLabel(label: footerTextLabel, inRange: termsRange) {
            showWebLink(title: "Terms of Use", urlString: "https://cleanify.app/terms")
        } else if gesture.didTapAttributedTextInLabel(label: footerTextLabel, inRange: privacyRange) {
            showWebLink(title: "Privacy Policy", urlString: "https://cleanifyai.blogspot.com/")
        }
    }
    
    private func showWebLink(title: String, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Helper Views

class FeatureCard: UIView {
    init(iconName: String, title: String) {
        super.init(frame: .zero)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 32),
            container.heightAnchor.constraint(equalToConstant: 32),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        stack.addArrangedSubview(container)
        stack.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SubscriptionOptionCard: UIButton {
    
    let periodLabel = UILabel()
    let priceLabel = UILabel()
    let subtextLabel = UILabel()
    let badgeLabel = UILabel()
    let badgeView = UIView()
    let selectionIndicator = UIImageView()
    let breakdownLabel = UILabel()
    let saveBadgeLabel = UILabel()
    
    let index: Int
    
    var isSelectedCard: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    
    init(period: String, subtext: String, accessBadgeText: String, price: String, breakdown: String, saveText: String?, index: Int) {
        self.index = index
        super.init(frame: .zero)
        
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 20
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.systemGray4.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        
        heightAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        
        // Selection Indicator (Radio button)
        selectionIndicator.image = UIImage(systemName: "circle")
        selectionIndicator.tintColor = .quaternaryLabel
        selectionIndicator.contentMode = .scaleAspectFit
        selectionIndicator.isUserInteractionEnabled = false
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionIndicator)
        
        // Text Stack for Title & Subtext
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)
        
        periodLabel.text = period
        periodLabel.font = .systemFont(ofSize: 17, weight: .bold)
        periodLabel.textColor = .label
        textStack.addArrangedSubview(periodLabel)
        
        subtextLabel.text = subtext
        subtextLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtextLabel.textColor = .secondaryLabel
        subtextLabel.numberOfLines = 0
        textStack.addArrangedSubview(subtextLabel)
        
        // Access Badge under subtext
        badgeView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        badgeView.layer.cornerRadius = 6
        badgeView.layer.masksToBounds = true
        badgeView.isUserInteractionEnabled = false
        
        badgeLabel.text = accessBadgeText
        badgeLabel.textColor = .systemBlue
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(badgeLabel)
        
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -8),
            badgeLabel.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 4),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -4)
        ])
        
        // Add some padding above the badge
        let badgeContainer = UIView()
        badgeContainer.isUserInteractionEnabled = false
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeView)
        NSLayoutConstraint.activate([
            badgeView.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor),
            badgeView.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
            badgeView.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor),
            badgeView.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor)
        ])
        textStack.addArrangedSubview(badgeContainer)
        
        // Right Side Stack for Price, Breakdown and Save Tag
        let rightStack = UIStackView()
        rightStack.axis = .vertical
        rightStack.spacing = 2
        rightStack.alignment = .trailing
        rightStack.isUserInteractionEnabled = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightStack)
        
        priceLabel.text = price
        priceLabel.font = .roundedFont(ofSize: 22, weight: .heavy)
        priceLabel.textColor = .label
        priceLabel.textAlignment = .right
        rightStack.addArrangedSubview(priceLabel)
        
        breakdownLabel.text = breakdown
        breakdownLabel.font = .systemFont(ofSize: 12, weight: .medium)
        breakdownLabel.textColor = .secondaryLabel
        breakdownLabel.textAlignment = .right
        rightStack.addArrangedSubview(breakdownLabel)
        
        if let saveText = saveText {
            saveBadgeLabel.text = saveText
            saveBadgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
            saveBadgeLabel.textColor = .systemBlue
            saveBadgeLabel.textAlignment = .right
            rightStack.addArrangedSubview(saveBadgeLabel)
        }
        
        NSLayoutConstraint.activate([
            selectionIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            selectionIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            textStack.leadingAnchor.constraint(equalTo: selectionIndicator.trailingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightStack.leadingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: 8)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateSelectionState() {
        if isSelectedCard {
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            layer.borderColor = UIColor.systemBlue.cgColor
            layer.borderWidth = 2.0
            
            layer.shadowColor = UIColor.systemBlue.cgColor
            layer.shadowOpacity = 0.2
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
            
            selectionIndicator.image = UIImage(systemName: "circle.inset.filled")
            selectionIndicator.tintColor = .systemBlue
            
        } else {
            backgroundColor = .secondarySystemGroupedBackground
            layer.borderColor = UIColor.systemGray4.cgColor
            layer.borderWidth = 1.5
            
            layer.shadowOpacity = 0
            
            selectionIndicator.image = UIImage(systemName: "circle")
            selectionIndicator.tintColor = .systemGray3
        }
    }
}

// MARK: - Label Link Detection Helper

extension UITapGestureRecognizer {
    func didTapAttributedTextInLabel(label: UILabel, inRange targetRange: NSRange) -> Bool {
        guard let text = label.text else { return false }
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize.zero)
        let textStorage = NSTextStorage(string: text)
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        label.isUserInteractionEnabled = true
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.size = label.bounds.size
        
        let indexOfCharacter = layoutManager.characterIndex(for: self.location(in: label), in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        return NSLocationInRange(indexOfCharacter, targetRange)
    }
}
