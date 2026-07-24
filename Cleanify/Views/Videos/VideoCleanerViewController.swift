//
//  VideoCleanerViewController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit
import Photos

class VideoCleanerViewController: UIViewController, CompressPromoBannerDelegate {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerWrapper = UIView()
    private let headerCard = UIView()
    private let totalCountLabel = UILabel()
    private let totalSizeLabel = UILabel()
    
    private var categories: [VideoCategory] = []
    
    struct VideoCategory {
        let title: String
        let icon: String
        let iconColor: UIColor
        let count: Int
        let type: CategoryType
        
        enum CategoryType {
            case large
            case old
            case all
        }
    }
    
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
        // Hide navigation bar on root tab screen
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        loadData() // Refresh counts if items were deleted
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        
        // Custom Header Labels
        titleLabel.text = "Videos"
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        subtitleLabel.text = "Find large files and purge old video clips."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(VideoCategoryCell.self, forCellReuseIdentifier: "CategoryCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.showsVerticalScrollIndicator = false
        view.addSubview(tableView)
        
        // Stats card as header
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
        headerTitle.text = "CLEANABLE CLIPS"
        headerTitle.font = .systemFont(ofSize: 11, weight: .bold)
        headerTitle.textColor = .secondaryLabel
        container.addArrangedSubview(headerTitle)
        
        totalCountLabel.font = .systemFont(ofSize: 32, weight: .black)
        totalCountLabel.textColor = .systemOrange
        container.addArrangedSubview(totalCountLabel)
        
        totalSizeLabel.text = "Review large files to clear up GBs"
        totalSizeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        totalSizeLabel.textColor = .secondaryLabel
        container.addArrangedSubview(totalSizeLabel)
        
        tableView.tableHeaderView = headerWrapper
        
        let promoBanner = CompressPromoBannerView()
        promoBanner.delegate = self
        
        let footerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 380))
        promoBanner.translatesAutoresizingMaskIntoConstraints = false
        footerContainer.addSubview(promoBanner)
        
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
        
        NSLayoutConstraint.activate([
            promoBanner.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 16),
            promoBanner.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 16),
            promoBanner.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -16),
            promoBanner.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -16)
        ])
        
        tableView.tableFooterView = footerContainer
    }
    
    private func loadData() {
        let largeCount = VideoScanManager.shared.largeVideos.count
        let oldCount = VideoScanManager.shared.oldVideos.count
        let allCount = VideoScanManager.shared.allVideos.count
        
        categories = [
            VideoCategory(title: "Large Videos (> 100MB)", icon: "arrow.down.left.video.fill", iconColor: .systemRed, count: largeCount, type: .large),
            VideoCategory(title: "Old Videos (> 6 months)", icon: "calendar", iconColor: .systemBlue, count: oldCount, type: .old),
            VideoCategory(title: "All Videos", icon: "video.fill", iconColor: .systemGray, count: allCount, type: .all)
        ]
        
        // Sum total size of cleanable items
        var totalBytes: Int64 = 0
        for asset in VideoScanManager.shared.largeVideos {
            totalBytes += VideoScanManager.shared.videoSizes[asset.localIdentifier] ?? 0
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: totalBytes)
        
        totalCountLabel.text = "\(largeCount) Large Files"
        totalSizeLabel.text = "Estimated cleanable size: \(sizeStr)"
        
        tableView.reloadData()
    }
}

// MARK: - UITableView Delegates
extension VideoCleanerViewController: UITableViewDelegate, UITableViewDataSource {
    
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath) as? VideoCategoryCell else {
            return UITableViewCell()
        }
        let category = categories[indexPath.row]
        cell.configure(with: category)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let category = categories[indexPath.row]
        
        let gridVC = VideoGridViewController(categoryType: category.type, categoryTitle: category.title)
        gridVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(gridVC, animated: true)
    }
    
    // MARK: - CompressPromoBannerDelegate
    
    func didTapCompressNow() {
        let compressorVC = VideoCompressorListViewController()
        compressorVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(compressorVC, animated: true)
    }
}

// MARK: - VideoCategoryCell Custom Component
class VideoCategoryCell: UITableViewCell {
    
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
    
    func configure(with category: VideoCleanerViewController.VideoCategory) {
        titleLabel.text = category.title
        countLabel.text = "\(category.count)"
        iconContainer.backgroundColor = category.iconColor
        iconView.image = UIImage(systemName: category.icon)
    }
}
