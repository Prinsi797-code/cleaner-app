//
//  VideoGridViewController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit
import Photos

class VideoGridViewController: UIViewController {
    
    private let categoryType: VideoCleanerViewController.VideoCategory.CategoryType
    private let categoryTitle: String
    
    private var collectionView: UICollectionView!
    private let bottomBar = UIView()
    private let deleteButton = UIButton(type: .system)
    
    private var assets: [PHAsset] = []
    private var selectedAssets = Set<PHAsset>()
    
    init(categoryType: VideoCleanerViewController.VideoCategory.CategoryType, categoryTitle: String) {
        self.categoryType = categoryType
        self.categoryTitle = categoryTitle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAssets()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = categoryTitle
        navigationItem.largeTitleDisplayMode = .never
        
        // Grid Layout configuration
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(VideoGridCell.self, forCellWithReuseIdentifier: "VideoCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        // Bottom toolbar bar setup
        bottomBar.backgroundColor = .secondarySystemBackground
        bottomBar.layer.shadowColor = UIColor.black.cgColor
        bottomBar.layer.shadowOpacity = 0.08
        bottomBar.layer.shadowRadius = 8
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -4)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        
        deleteButton.backgroundColor = .systemRed
        deleteButton.setTitle("Delete Selected (0)", for: .normal)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        deleteButton.layer.cornerRadius = 14
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        bottomBar.addSubview(deleteButton)
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 84),
            
            deleteButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            deleteButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 24),
            deleteButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -24),
            deleteButton.heightAnchor.constraint(equalToConstant: 48),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private let emptyStateView = EmptyStateView(
        iconName: "video.circle.fill",
        title: "No Videos Found",
        subtitle: "There are no videos in this category.",
        iconColor: .systemOrange
    )
    
    private func loadAssets() {
        selectedAssets.removeAll()
        
        switch categoryType {
        case .large:
            assets = VideoScanManager.shared.largeVideos
            emptyStateView.configure(iconName: "externaldrive.fill.badge.checkmark", title: "No Large Videos", subtitle: "No videos over 100MB found in your library.", iconColor: .systemOrange)
        case .old:
            assets = VideoScanManager.shared.oldVideos
            emptyStateView.configure(iconName: "clock.badge.checkmark.fill", title: "No Old Videos", subtitle: "No videos older than 1 year found in your library.", iconColor: .systemBlue)
        case .all:
            assets = VideoScanManager.shared.allVideos
            emptyStateView.configure(iconName: "video.badge.checkmark", title: "No Videos", subtitle: "No videos found in your photo library.", iconColor: .systemGreen)
        }
        
        emptyStateView.isHidden = !assets.isEmpty
        bottomBar.isHidden = assets.isEmpty
        
        collectionView.reloadData()
        updateDeleteButtonTitle()
    }
    
    private func updateDeleteButtonTitle() {
        deleteButton.setTitle("Delete Selected (\(selectedAssets.count))", for: .normal)
        deleteButton.isEnabled = !selectedAssets.isEmpty
        deleteButton.alpha = selectedAssets.isEmpty ? 0.5 : 1.0
    }
    
    @objc private func didTapDelete() {
        guard !selectedAssets.isEmpty else { return }
        
        let assetsArray = Array(selectedAssets)
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsArray as NSArray)
        } completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self?.removeDeletedAssets(assetsArray)
                    self?.loadAssets()
                } else if let error = error {
                    print("Error deleting assets: \(error)")
                }
            }
        }
    }
    
    private func removeDeletedAssets(_ deleted: [PHAsset]) {
        let deletedSet = Set(deleted)
        
        // Remove from cached video lists
        VideoScanManager.shared.allVideos.removeAll(where: { deletedSet.contains($0) })
        VideoScanManager.shared.largeVideos.removeAll(where: { deletedSet.contains($0) })
        VideoScanManager.shared.oldVideos.removeAll(where: { deletedSet.contains($0) })
        
        for asset in deleted {
            VideoScanManager.shared.videoSizes.removeValue(forKey: asset.localIdentifier)
        }
    }
}

// MARK: - CollectionView delegate flow
extension VideoGridViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as? VideoGridCell else {
            return UICollectionViewCell()
        }
        let asset = assets[indexPath.item]
        let size = VideoScanManager.shared.videoSizes[asset.localIdentifier] ?? 0
        let isSelected = selectedAssets.contains(asset)
        cell.configure(with: asset, fileSize: size, isChecked: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets[indexPath.item]
        
        if selectedAssets.contains(asset) {
            selectedAssets.remove(asset)
        } else {
            selectedAssets.insert(asset)
        }
        
        collectionView.reloadItems(at: [indexPath])
        updateDeleteButtonTitle()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let width = (collectionView.bounds.width - (columns - 1) * 2) / columns
        return CGSize(width: width, height: width)
    }
}

// MARK: - VideoGridCell custom Cell
class VideoGridCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let durationLabel = UILabel()
    private let sizeLabel = UILabel()
    private let checkContainer = UIView()
    private let checkIcon = UIImageView()
    
    private var imageRequestID: PHImageRequestID?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // Gradient overlay at bottom to see duration clearly
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: 0, y: bounds.height - 24, width: bounds.width, height: 24)
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        imageView.layer.addSublayer(gradient)
        
        // Size tag on top-left
        sizeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        sizeLabel.textColor = .white
        sizeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        sizeLabel.layer.cornerRadius = 4
        sizeLabel.clipsToBounds = true
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sizeLabel)
        
        // Duration on bottom-left
        durationLabel.font = .systemFont(ofSize: 10, weight: .bold)
        durationLabel.textColor = .white
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)
        
        checkContainer.layer.cornerRadius = 12
        checkContainer.layer.borderWidth = 2.0
        checkContainer.layer.borderColor = UIColor.white.cgColor
        checkContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkContainer)
        
        checkIcon.image = UIImage(systemName: "checkmark")
        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkContainer.addSubview(checkIcon)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            sizeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            
            durationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            checkContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            checkContainer.widthAnchor.constraint(equalToConstant: 24),
            checkContainer.heightAnchor.constraint(equalToConstant: 24),
            
            checkIcon.centerXAnchor.constraint(equalTo: checkContainer.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkContainer.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 12),
            checkIcon.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configure(with asset: PHAsset, fileSize: Int64, isChecked: Bool) {
        // Thumbnail request
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        
        imageRequestID = PHImageManager.default().requestImage(for: asset, targetSize: bounds.size, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            self?.imageView.image = image
        }
        
        // Format size
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        sizeLabel.text = "  \(formatter.string(fromByteCount: fileSize))  "
        
        // Format duration
        let duration = Int(asset.duration)
        let min = duration / 60
        let sec = duration % 60
        durationLabel.text = String(format: "%d:%02d", min, sec)
        
        if isChecked {
            checkContainer.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
            checkContainer.layer.borderColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0).cgColor
            checkIcon.isHidden = false
        } else {
            checkContainer.backgroundColor = UIColor.black.withAlphaComponent(0.24)
            checkContainer.layer.borderColor = UIColor.white.cgColor
            checkIcon.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
    }
}
