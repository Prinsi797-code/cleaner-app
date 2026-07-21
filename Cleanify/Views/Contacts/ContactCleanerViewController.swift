//
//  ContactCleanerViewController.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import UIKit
import Contacts

class ContactCleanerViewController: UIViewController {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let segmentControl = UISegmentedControl(items: ["Names", "Numbers", "Incomplete"])
    private let emptyLabel = UILabel()
    
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
        // Hide navigation bar on root tab screen
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
        
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentControl)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ContactGroupCell.self, forCellReuseIdentifier: "GroupCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "IncompleteCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        emptyLabel.text = "No duplicate contacts found."
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            segmentControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentControl.heightAnchor.constraint(equalToConstant: 45),

            tableView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadData() {
        let contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
        guard contactsStatus == .authorized else {
            emptyLabel.text = "Please grant Contacts Access in Settings"
            emptyLabel.isHidden = false
            tableView.isHidden = true
            return
        }
        
        let hasData: Bool
        switch activeMode {
        case .names:
            hasData = !ContactScanManager.shared.duplicateNameGroups.isEmpty
            emptyLabel.text = "No duplicate names found."
        case .numbers:
            hasData = !ContactScanManager.shared.duplicatePhoneGroups.isEmpty
            emptyLabel.text = "No duplicate phone numbers found."
        case .incomplete:
            hasData = !ContactScanManager.shared.incompleteContactsList.isEmpty
            emptyLabel.text = "No incomplete contacts found."
        }
        
        emptyLabel.isHidden = hasData
        tableView.isHidden = !hasData
        tableView.reloadData()
    }
    
    @objc private func didChangeSegment() {
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
        
        // Keep the first contact as primary, merge others info, and delete duplicates
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
            cell.configure(title: group.key, count: group.contacts.count)
            return cell
            
        case .numbers:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath) as? ContactGroupCell else {
                return UITableViewCell()
            }
            let group = ContactScanManager.shared.duplicatePhoneGroups[indexPath.row]
            cell.configure(title: group.key, count: group.contacts.count)
            return cell
            
        case .incomplete:
            let cell = tableView.dequeueReusableCell(withIdentifier: "IncompleteCell", for: indexPath)
            let contact = ContactScanManager.shared.incompleteContactsList[indexPath.row]
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
            
            if fullName.isEmpty {
                cell.textLabel?.text = "No Name (Incomplete Profile)"
            } else {
                cell.textLabel?.text = fullName
            }
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            cell.accessoryType = .disclosureIndicator
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
        let alert = UIAlertController(title: "Merge Duplicates?", message: "Cleanify will merge info from these \(group.contacts.count) duplicate contacts into a single primary contact profile.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Merge Profiles", style: .default, handler: { [weak self] _ in
            self?.mergeGroup(group)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
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
    
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        countLabel.textColor = .white
        countLabel.font = .systemFont(ofSize: 12, weight: .bold)
        countLabel.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        countLabel.layer.cornerRadius = 10
        countLabel.clipsToBounds = true
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: 32),
            countLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(title: String, count: Int) {
        titleLabel.text = title
        countLabel.text = "\(count)"
    }
}
