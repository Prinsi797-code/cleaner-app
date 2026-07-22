import UIKit
import Contacts

class ContactCleanerViewController: UIViewController {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let segmentControl = UISegmentedControl(items: ["Names", "Numbers", "Incomplete"])
    private let emptyStateView = EmptyStateView()
    
    
    private let headerWrapper = UIView()
    private let headerCard = UIView()
    private let headerTitle = UILabel()
    private let totalCountLabel = UILabel()
    private let totalSizeLabel = UILabel()
    
    private var activeMode: Mode = .names
    
    enum Mode {
        case names
        case numbers
        case incomplete
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !AppState.hasShownRescanPopup {
            AppState.hasShownRescanPopup = true
            let alert = UIAlertController(title: "Notice", message: "If you have added new contacts, please run a new Scan from the Scan tab to refresh the data.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Scan Now", style: .default, handler: { [weak self] _ in
                self?.tabBarController?.selectedIndex = 0
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // Custom Header Labels
        titleLabel.text = "Contacts"
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        subtitleLabel.text = "Merge duplicate profiles or delete incomplete cards."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        
        let normalTextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedFont(ofSize: 14, weight: .medium)
        ]
        let selectedTextAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedFont(ofSize: 14, weight: .bold)
        ]
        segmentControl.setTitleTextAttributes(normalTextAttributes, for: .normal)
        segmentControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
        
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentControl)
        
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ContactGroupCell.self, forCellReuseIdentifier: "GroupCell")
        tableView.register(IncompleteContactCell.self, forCellReuseIdentifier: "IncompleteCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        
        headerWrapper.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 130)
        headerWrapper.backgroundColor = .clear
        
        headerCard.backgroundColor = .secondarySystemGroupedBackground
        headerCard.layer.cornerRadius = 16
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        headerWrapper.addSubview(headerCard)
        
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4
        container.alignment = .center
        container.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(container)
        
        headerTitle.text = "CLEANABLE CONTACTS"
        headerTitle.font = .systemFont(ofSize: 11, weight: .bold)
        headerTitle.textColor = .secondaryLabel
        container.addArrangedSubview(headerTitle)
        
        totalCountLabel.font = .systemFont(ofSize: 32, weight: .black)
        totalCountLabel.textColor = .systemBlue
        container.addArrangedSubview(totalCountLabel)
        
        totalSizeLabel.text = "Review items to organize address book"
        totalSizeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        totalSizeLabel.textColor = .secondaryLabel
        container.addArrangedSubview(totalSizeLabel)
        
        tableView.tableHeaderView = headerWrapper
        
        // Empty View setup
        emptyStateView.isHidden = true
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            segmentControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentControl.heightAnchor.constraint(equalToConstant: 45),

            tableView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            headerCard.topAnchor.constraint(equalTo: headerWrapper.topAnchor, constant: 0),
            headerCard.bottomAnchor.constraint(equalTo: headerWrapper.bottomAnchor, constant: -20),
            headerCard.leadingAnchor.constraint(equalTo: headerWrapper.leadingAnchor, constant: 20),
            headerCard.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor, constant: -20),
            
            container.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: headerCard.centerYAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func loadData() {
        let contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
        guard contactsStatus == .authorized else {
            emptyStateView.configure(iconName: "person.crop.circle.badge.exclamationmark", title: "Access Required", subtitle: "Please grant Contacts Access in Settings to scan duplicates.", iconColor: .systemOrange)
            emptyStateView.isHidden = false
            tableView.isHidden = true
            return
        }
        
        let totalCleanable = ContactScanManager.shared.duplicateNameGroups.count +
                             ContactScanManager.shared.duplicatePhoneGroups.count +
                             ContactScanManager.shared.incompleteContactsList.count
        totalCountLabel.text = "\(totalCleanable) Duplicates"
        
        let hasData: Bool
        switch activeMode {
        case .names:
            hasData = !ContactScanManager.shared.duplicateNameGroups.isEmpty
            emptyStateView.configure(iconName: "person.2.slash.fill", title: "No Duplicate Names", subtitle: "All contact names in your address book are unique.", iconColor: .systemPurple)
        case .numbers:
            hasData = !ContactScanManager.shared.duplicatePhoneGroups.isEmpty
            emptyStateView.configure(iconName: "phone.badge.checkmark", title: "No Duplicate Numbers", subtitle: "No shared phone numbers found across contacts.", iconColor: .systemBlue)
        case .incomplete:
            hasData = !ContactScanManager.shared.incompleteContactsList.isEmpty
            emptyStateView.configure(iconName: "person.badge.shield.checkmark.fill", title: "No Incomplete Contacts", subtitle: "All contacts have complete names and details.", iconColor: .systemGreen)
        }
        
        emptyStateView.isHidden = hasData
        tableView.isHidden = !hasData
        tableView.reloadData()
    }
    
    @objc private func didChangeSegment() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch segmentControl.selectedSegmentIndex {
        case 0: activeMode = .names
        case 1: activeMode = .numbers
        case 2: activeMode = .incomplete
        default: break
        }
        loadData()
    }
    
    // MARK: - Action Handlers
    private func mergeGroup(_ group: ContactGroup) {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        guard let primaryContact = group.contacts.first?.mutableCopy() as? CNMutableContact else { return }
        
        var mergedPhones = primaryContact.phoneNumbers
        var mergedEmails = primaryContact.emailAddresses
        
        for index in 1..<group.contacts.count {
            let duplicate = group.contacts[index]
            
            for phone in duplicate.phoneNumbers {
                if !mergedPhones.contains(where: { $0.value.stringValue == phone.value.stringValue }) {
                    mergedPhones.append(phone)
                }
            }
            
            for email in duplicate.emailAddresses {
                if !mergedEmails.contains(where: { $0.value as String == email.value as String }) {
                    mergedEmails.append(email)
                }
            }
            
            if let mutableDuplicate = duplicate.mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutableDuplicate)
            }
        }
        
        primaryContact.phoneNumbers = mergedPhones
        primaryContact.emailAddresses = mergedEmails
        saveRequest.update(primaryContact)
        
        do {
            try store.execute(saveRequest)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(message: "Merged successfully!")
            
            ContactScanManager.shared.scanContacts(progressHandler: { _, _ in }, completion: { [weak self] in
                self?.loadData()
            })
        } catch {
            print("Error executing contact merge save: \(error)")
        }
    }
    
    private func deleteIncompleteContact(_ contact: CNContact) {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        guard let mutable = contact.mutableCopy() as? CNMutableContact else { return }
        saveRequest.delete(mutable)
        
        do {
            try store.execute(saveRequest)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(message: "Contact deleted!")
            
            ContactScanManager.shared.scanContacts(progressHandler: { _, _ in }, completion: { [weak self] in
                self?.loadData()
            })
        } catch {
            print("Error deleting incomplete contact: \(error)")
        }
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
extension ContactCleanerViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch activeMode {
        case .names: return ContactScanManager.shared.duplicateNameGroups.count
        case .numbers: return ContactScanManager.shared.duplicatePhoneGroups.count
        case .incomplete: return ContactScanManager.shared.incompleteContactsList.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch activeMode {
        case .names:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath) as? ContactGroupCell else {
                return UITableViewCell()
            }
            let group = ContactScanManager.shared.duplicateNameGroups[indexPath.row]
            cell.configure(title: group.key, count: group.contacts.count, iconName: "person.2.fill")
            return cell
            
        case .numbers:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath) as? ContactGroupCell else {
                return UITableViewCell()
            }
            let group = ContactScanManager.shared.duplicatePhoneGroups[indexPath.row]
            cell.configure(title: group.key, count: group.contacts.count, iconName: "phone.fill")
            return cell
            
        case .incomplete:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "IncompleteCell", for: indexPath) as? IncompleteContactCell else {
                return UITableViewCell()
            }
            let contact = ContactScanManager.shared.incompleteContactsList[indexPath.row]
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
            
            if fullName.isEmpty {
                cell.configure(title: "No Name", subtitle: "Incomplete Profile")
            } else {
                cell.configure(title: fullName, subtitle: "Missing phone/email")
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch activeMode {
        case .names:
            let group = ContactScanManager.shared.duplicateNameGroups[indexPath.row]
            promptMerge(for: group)
        case .numbers:
            let group = ContactScanManager.shared.duplicatePhoneGroups[indexPath.row]
            promptMerge(for: group)
        case .incomplete:
            let contact = ContactScanManager.shared.incompleteContactsList[indexPath.row]
            promptDelete(for: contact)
        }
    }
    
    private func promptMerge(for group: ContactGroup) {
        let previewVC = MergePreviewViewController(group: group) { [weak self] in
            self?.mergeGroup(group)
        }
        present(previewVC, animated: true)
    }
    
    private func promptDelete(for contact: CNContact) {
        let alert = UIAlertController(title: "Delete Incomplete Contact?", message: "Are you sure you want to delete this profile from your device?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete Contact", style: .destructive, handler: { [weak self] _ in
            self?.deleteIncompleteContact(contact)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - ContactGroupCell custom Cell
class ContactGroupCell: UITableViewCell {
    
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let chevronImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconImageView)
        
        titleLabel.font = UIFont.roundedFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        countLabel.textColor = .white
        countLabel.font = UIFont.roundedFont(ofSize: 13, weight: .bold)
        countLabel.backgroundColor = .systemBlue
        countLabel.layer.cornerRadius = 14
        countLabel.clipsToBounds = true
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(countLabel)
        
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            
            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -12),
            
            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
            
            countLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            countLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: 28),
            countLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    func configure(title: String, count: Int, iconName: String) {
        titleLabel.text = title
        countLabel.text = "\(count)"
        iconImageView.image = UIImage(systemName: iconName)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.1) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            self.cardView.alpha = highlighted ? 0.8 : 1.0
        }
    }
}

// MARK: - IncompleteContactCell custom Cell
class IncompleteContactCell: UITableViewCell {
    
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        iconImageView.image = UIImage(systemName: "person.crop.circle.badge.exclamationmark")
        iconImageView.tintColor = .systemRed
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconImageView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)
        
        titleLabel.font = UIFont.roundedFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        stack.addArrangedSubview(titleLabel)
        
        subtitleLabel.font = UIFont.roundedFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(subtitleLabel)
        
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            
            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28),
            
            stack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.1) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            self.cardView.alpha = highlighted ? 0.8 : 1.0
        }
    }
}
