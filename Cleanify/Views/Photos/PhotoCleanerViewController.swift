//
//  PhotoCleanerViewController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit
import Photos

class PhotoCleanerViewController: UIViewController, RecentlyDeletedCardDelegate {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerWrapper = UIView()
    private let headerCard = UIView()
    private let totalCountLabel = UILabel()
    private let totalSizeLabel = UILabel()
    
    private var categories: [PhotoCategory] = []
    
    struct PhotoCategory {
        let title: String
        let icon: String
        let iconColor: UIColor
        let count: Int
        let type: CategoryType
        
        enum CategoryType {
            case duplicates
            case similar
            case screenshots
            case livePhotos
            case bursts
            case blurry
            case all
        }
    }
    
    private var recentlyDeletedCard: RecentlyDeletedCardView?
    private var bannerAdHelper: BannerAdHelper?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
        bannerAdHelper = BannerAdHelper(viewController: self, bannerIDKey: "main_banner_id", bannerFlagKey: "main_banner_flag")
        bannerAdHelper?.fetchRemoteConfigAndLoadBannerAd()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PhotosInterstitialManager.shared.preloadInterstitialAd()
        tableView.contentInset.bottom = 60
        
        if !AppState.hasShownRescanPopup {
            AppState.hasShownRescanPopup = true
            let alert = UIAlertController(title: "Notice", message: "If you have added new photos or videos, please run a new Scan from the Scan tab to refresh the data.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Scan Now", style: .default, handler: { [weak self] _ in
                self?.tabBarController?.selectedIndex = 0
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            present(alert, animated: true)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // Custom Header Labels (replacing navigation title)
        titleLabel.text = "Photos"
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        subtitleLabel.text = "Remove duplicates and organize your library."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PhotoCategoryCell.self, forCellReuseIdentifier: "CategoryCell")
        tableView.showsVerticalScrollIndicator = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Dynamic stats card as header
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
        
        let headerTitle = UILabel()
        headerTitle.text = "CLEANABLE IMAGES"
        headerTitle.font = .systemFont(ofSize: 11, weight: .bold)
        headerTitle.textColor = .secondaryLabel
        container.addArrangedSubview(headerTitle)
        
        totalCountLabel.font = .systemFont(ofSize: 32, weight: .black)
        totalCountLabel.textColor = .systemGreen
        container.addArrangedSubview(totalCountLabel)
        
        totalSizeLabel.text = "Tap categories to review items"
        totalSizeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        totalSizeLabel.textColor = .secondaryLabel
        container.addArrangedSubview(totalSizeLabel)
        
        tableView.tableHeaderView = headerWrapper
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            tableView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            headerCard.topAnchor.constraint(equalTo: headerWrapper.topAnchor, constant: 0),
            headerCard.bottomAnchor.constraint(equalTo: headerWrapper.bottomAnchor, constant: -20),
            headerCard.leadingAnchor.constraint(equalTo: headerWrapper.leadingAnchor, constant: 20),
            headerCard.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor, constant: -20),
            
            container.centerXAnchor.constraint(equalTo: headerCard.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: headerCard.centerYAnchor)
        ])
        
        // Setup Recently Deleted Card
        recentlyDeletedCard = RecentlyDeletedCardView()
        recentlyDeletedCard?.delegate = self
        
        let footerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 360))
        recentlyDeletedCard?.translatesAutoresizingMaskIntoConstraints = false
        if let card = recentlyDeletedCard {
            footerContainer.addSubview(card)
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 16),
                card.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 20),
                card.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -20),
                card.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -16)
            ])
        }
        
        tableView.tableFooterView = footerContainer
    }
    
    private func loadData() {
        let duplicatesCount = PhotoScanManager.shared.duplicateGroups.flatMap({ $0.assets }).count
        let similarCount = PhotoScanManager.shared.similarGroups.flatMap({ $0.assets }).count
        let screenshotsCount = PhotoScanManager.shared.screenshots.count
        let liveCount = PhotoScanManager.shared.livePhotos.count
        let burstsCount = PhotoScanManager.shared.burstPhotos.count
        let blurryCount = PhotoScanManager.shared.blurryPhotos.count
        let allCount = PhotoScanManager.shared.allPhotos.count
        
        categories = [
            PhotoCategory(title: "Duplicate Photos", icon: "square.on.square.fill", iconColor: .systemPurple, count: duplicatesCount, type: .duplicates),
            PhotoCategory(title: "Similar Photos", icon: "photo.stack.fill", iconColor: .systemBlue, count: similarCount, type: .similar),
            PhotoCategory(title: "Screenshots", icon: "iphone.circle.fill", iconColor: .systemOrange, count: screenshotsCount, type: .screenshots),
            PhotoCategory(title: "Live Photos", icon: "livephoto", iconColor: .systemGreen, count: liveCount, type: .livePhotos),
            PhotoCategory(title: "Burst Photos", icon: "burst.fill", iconColor: .systemTeal, count: burstsCount, type: .bursts),
            PhotoCategory(title: "Blurry Photos", icon: "drop.circle.fill", iconColor: .systemIndigo, count: blurryCount, type: .blurry),
            PhotoCategory(title: "All Photos", icon: "photo", iconColor: .systemGray, count: allCount, type: .all)
        ]
        
        let totalCleanable = duplicatesCount + similarCount + screenshotsCount + burstsCount + blurryCount
        totalCountLabel.text = "\(totalCleanable) Items"
        
        tableView.reloadData()
    }
}

// MARK: - UITableView Delegates
extension PhotoCleanerViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath) as? PhotoCategoryCell else {
            return UITableViewCell()
        }
        let category = categories[indexPath.row]
        cell.configure(with: category)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let category = categories[indexPath.row]
        
        let gridVC = PhotoGridViewController(categoryType: category.type, categoryTitle: category.title)
        gridVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(gridVC, animated: true)
    }
    
    // MARK: - RecentlyDeletedCardDelegate
    
    func didTapOpenPhotos() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - PhotoCategoryCell Custom Component
class PhotoCategoryCell: UITableViewCell {
    
    private let iconContainer = UIView()
    private let iconView = UIImageView()
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
        
        iconContainer.layer.cornerRadius = 10
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
        
        countLabel.font = .systemFont(ofSize: 15, weight: .bold)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with category: PhotoCleanerViewController.PhotoCategory) {
        titleLabel.text = category.title
        countLabel.text = "\(category.count)"
        iconContainer.backgroundColor = category.iconColor
        iconView.image = UIImage(systemName: category.icon)
    }
}
