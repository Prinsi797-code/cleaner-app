import UIKit
import Contacts

class MergePreviewViewController: UIViewController {
    
    private let group: ContactGroup
    private let mergeAction: () -> Void
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let mergeButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    init(group: ContactGroup, mergeAction: @escaping () -> Void) {
        self.group = group
        self.mergeAction = mergeAction
        super.init(nibName: nil, bundle: nil)
        
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        titleLabel.text = "Merge Contacts"
        titleLabel.font = UIFont.roundedFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        subtitleLabel.text = "The following contacts will be merged into a single profile. All unique phone numbers and emails will be kept."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MergeContactCell.self, forCellReuseIdentifier: "MergeContactCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        mergeButton.setTitle("Merge All", for: .normal)
        mergeButton.titleLabel?.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        mergeButton.setTitleColor(.white, for: .normal)
        mergeButton.backgroundColor = .systemBlue
        mergeButton.layer.cornerRadius = 24
        mergeButton.addTarget(self, action: #selector(didTapMerge), for: .touchUpInside)
        mergeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mergeButton)
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            mergeButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -16),
            mergeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            mergeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            mergeButton.heightAnchor.constraint(equalToConstant: 50),
            
            tableView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: mergeButton.topAnchor, constant: -16)
        ])
    }
    
    @objc private func didTapMerge() {
        dismiss(animated: true) {
            self.mergeAction()
        }
    }
    
    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}

extension MergePreviewViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return group.contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MergeContactCell", for: indexPath) as! MergeContactCell
        let contact = group.contacts[indexPath.row]
        cell.configure(with: contact)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.text = "CONTACTS TO BE MERGED"
        label.font = UIFont.roundedFont(ofSize: 13, weight: .bold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
}

class MergeContactCell: UITableViewCell {
    
    private let cardView = UIView()
    private let nameLabel = UILabel()
    private let detailsStack = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
            selectionStyle = .none
        backgroundColor = .clear
        
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)
        
        nameLabel.font = UIFont.roundedFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        stack.addArrangedSubview(nameLabel)
        
        detailsStack.axis = .vertical
        detailsStack.spacing = 6
        stack.addArrangedSubview(detailsStack)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with contact: CNContact) {
        let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = fullName.isEmpty ? "No Name" : fullName
        
        detailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        var hasDetails = false
        for phone in contact.phoneNumbers {
            hasDetails = true
            let label = UILabel()
            label.text = "\(phone.value.stringValue)"
            label.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
            label.textColor = .secondaryLabel
            detailsStack.addArrangedSubview(label)
        }
        for email in contact.emailAddresses {
            hasDetails = true
            let label = UILabel()
            label.text = "✉️ \(email.value as String)"
            label.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
            label.textColor = .secondaryLabel
            detailsStack.addArrangedSubview(label)
        }
        
        if !hasDetails {
            let label = UILabel()
            label.text = "No contact details"
            label.font = UIFont.roundedFont(ofSize: 14, weight: .regular)
            label.textColor = .tertiaryLabel
            detailsStack.addArrangedSubview(label)
        }
    }
}
