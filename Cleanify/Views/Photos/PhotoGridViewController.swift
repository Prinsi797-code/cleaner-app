//
//  PhotoGridViewController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit
import Photos

class PhotoGridViewController: UIViewController {
    
    private let categoryType: PhotoCleanerViewController.PhotoCategory.CategoryType
    private let categoryTitle: String
    
    private var collectionView: UICollectionView!
    private let bottomBar = UIView()
    private let deleteButton = UIButton(type: .system)
    
    // Data structures
    private var isGrouped = false
    private var ungroupedAssets: [PHAsset] = []
    private var groupedAssets: [PhotoGroup] = []
    
    private var selectedAssets = Set<PHAsset>()
    
    init(categoryType: PhotoCleanerViewController.PhotoCategory.CategoryType, categoryTitle: String) {
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
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(didTapSelectAll))
        
        // Setup Grid layout
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true
        collectionView.register(PhotoGridCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.register(PhotoSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderView")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        // Setup bottom bar
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
    
    private let emptyStateView = EmptyStateView()
    
    private func loadAssets() {
        selectedAssets.removeAll()
        
        switch categoryType {
        case .duplicates:
            isGrouped = true
            groupedAssets = PhotoScanManager.shared.duplicateGroups
            emptyStateView.configure(iconName: "square.fill.on.square.fill", title: "No Duplicate Photos", subtitle: "All your photos are unique and organized.", iconColor: .systemPurple)
            preselectDuplicates()
        case .similar:
            isGrouped = true
            groupedAssets = PhotoScanManager.shared.similarGroups
            emptyStateView.configure(iconName: "photo.stack.fill", title: "No Similar Photos", subtitle: "No visually similar photo groups detected.", iconColor: .systemBlue)
            preselectDuplicates()
        case .screenshots:
            isGrouped = false
            ungroupedAssets = PhotoScanManager.shared.screenshots
            emptyStateView.configure(iconName: "iphone.circle.fill", title: "No Screenshots", subtitle: "No screenshots found in your photo library.", iconColor: .systemOrange)
        case .livePhotos:
            isGrouped = false
            ungroupedAssets = PhotoScanManager.shared.livePhotos
            emptyStateView.configure(iconName: "livephoto", title: "No Live Photos", subtitle: "No Live Photos found in your library.", iconColor: .systemGreen)
        case .bursts:
            isGrouped = false
            ungroupedAssets = PhotoScanManager.shared.burstPhotos
            emptyStateView.configure(iconName: "burst.fill", title: "No Burst Photos", subtitle: "No burst shot series found in your library.", iconColor: .systemTeal)
        case .blurry:
            isGrouped = false
            ungroupedAssets = PhotoScanManager.shared.blurryPhotos
            emptyStateView.configure(iconName: "drop.circle.fill", title: "No Blurry Photos", subtitle: "Your photos look sharp! No blurry photos detected.", iconColor: .systemIndigo)
        case .all:
            isGrouped = false
            ungroupedAssets = PhotoScanManager.shared.allPhotos
            emptyStateView.configure(iconName: "photo.fill.on.rectangle.fill", title: "No Photos Found", subtitle: "Your photo library appears to be empty.", iconColor: .systemGray)
        }
        
        let isEmpty = isGrouped ? groupedAssets.isEmpty : ungroupedAssets.isEmpty
        emptyStateView.isHidden = !isEmpty
        bottomBar.isHidden = isEmpty
        
        collectionView.reloadData()
        updateDeleteButtonTitle()
    }
    
    private func preselectDuplicates() {
        // Pre-select duplicates and leave the original unchecked
        for group in groupedAssets {
            for asset in group.assets {
                selectedAssets.insert(asset)
            }
        }
    }
    
    private func updateDeleteButtonTitle() {
        deleteButton.setTitle("Delete Selected (\(selectedAssets.count))", for: .normal)
        deleteButton.isEnabled = !selectedAssets.isEmpty
        deleteButton.alpha = selectedAssets.isEmpty ? 0.5 : 1.0
        
        let total = getTotalAssetCount()
        if total > 0 && selectedAssets.count == total {
            navigationItem.rightBarButtonItem?.title = "Deselect All"
        } else {
            navigationItem.rightBarButtonItem?.title = "Select All"
        }
    }
    
    @objc private func didTapSelectAll() {
        let total = getTotalAssetCount()
        if selectedAssets.count == total && total > 0 {
            // Deselect All
            selectedAssets.removeAll()
        } else {
            // Select All
            selectedAssets.removeAll()
            if isGrouped {
                for group in groupedAssets {
                    selectedAssets.insert(group.leadingAsset)
                    for asset in group.assets {
                        selectedAssets.insert(asset)
                    }
                }
            } else {
                for asset in ungroupedAssets {
                    selectedAssets.insert(asset)
                }
            }
        }
        collectionView.reloadData()
        updateDeleteButtonTitle()
    }
    
    private func getTotalAssetCount() -> Int {
        if isGrouped {
            return groupedAssets.reduce(0) { $0 + 1 + $1.assets.count }
        } else {
            return ungroupedAssets.count
        }
    }
    
    @objc private func didTapDelete() {
        guard !selectedAssets.isEmpty else { return }
        
        let assetsArray = Array(selectedAssets)
        let containsBurst = assetsArray.contains(where: { $0.representsBurst })
        
        if containsBurst {
            let alert = UIAlertController(title: "Delete Burst Photos?", message: "You have selected one or more burst photos. Deleting a burst photo will permanently delete ALL the photos contained within that burst. Do you want to continue?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete All", style: .destructive, handler: { [weak self] _ in
                self?.performDeletion(for: assetsArray)
            }))
            present(alert, animated: true)
        } else {
            performDeletion(for: assetsArray)
        }
    }
    
    private func performDeletion(for assetsArray: [PHAsset]) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsArray as NSArray)
        } completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Update lists on disk
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
        let deletedBurstIDs = Set(deleted.filter { $0.representsBurst }.compactMap { $0.burstIdentifier })
        
        // Remove from cached arrays
        PhotoScanManager.shared.screenshots.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
        PhotoScanManager.shared.livePhotos.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
        PhotoScanManager.shared.burstPhotos.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
        PhotoScanManager.shared.blurryPhotos.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
        PhotoScanManager.shared.allPhotos.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
        
        // Clean grouped arrays
        var cleanDuplicates: [PhotoGroup] = []
        for var group in PhotoScanManager.shared.duplicateGroups {
            group.assets.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
            let leadingDeleted = deletedSet.contains(group.leadingAsset) || (group.leadingAsset.burstIdentifier != nil && deletedBurstIDs.contains(group.leadingAsset.burstIdentifier!))
            if !group.assets.isEmpty && !leadingDeleted {
                cleanDuplicates.append(group)
            }
        }
        PhotoScanManager.shared.duplicateGroups = cleanDuplicates
        
        var cleanSimilars: [PhotoGroup] = []
        for var group in PhotoScanManager.shared.similarGroups {
            group.assets.removeAll(where: { deletedSet.contains($0) || ($0.burstIdentifier != nil && deletedBurstIDs.contains($0.burstIdentifier!)) })
            let leadingDeleted = deletedSet.contains(group.leadingAsset) || (group.leadingAsset.burstIdentifier != nil && deletedBurstIDs.contains(group.leadingAsset.burstIdentifier!))
            if !group.assets.isEmpty && !leadingDeleted {
                cleanSimilars.append(group)
            }
        }
        PhotoScanManager.shared.similarGroups = cleanSimilars
    }
}

// MARK: - UICollectionView Delegates
extension PhotoGridViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return isGrouped ? groupedAssets.count : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isGrouped {
            // Group count = leadingAsset + matching assets
            return groupedAssets[section].assets.count + 1
        } else {
            return ungroupedAssets.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as? PhotoGridCell else {
            return UICollectionViewCell()
        }
        
        let asset: PHAsset
        if isGrouped {
            let group = groupedAssets[indexPath.section]
            if indexPath.item == 0 {
                asset = group.leadingAsset
            } else {
                asset = group.assets[indexPath.item - 1]
            }
        } else {
            asset = ungroupedAssets[indexPath.item]
        }
        
        let isSelected = selectedAssets.contains(asset)
        cell.configure(with: asset, isChecked: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset: PHAsset
        if isGrouped {
            let group = groupedAssets[indexPath.section]
            if indexPath.item == 0 {
                asset = group.leadingAsset
            } else {
                asset = group.assets[indexPath.item - 1]
            }
        } else {
            asset = ungroupedAssets[indexPath.item]
        }
        
        if selectedAssets.contains(asset) {
            selectedAssets.remove(asset)
        } else {
            selectedAssets.insert(asset)
        }
        
        collectionView.reloadItems(at: [indexPath])
        updateDeleteButtonTitle()
    }
    
    // Layout formatting
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let width = (collectionView.bounds.width - (columns - 1) * 2) / columns
        return CGSize(width: width, height: width)
    }
    
    // Headers setup for grouped segments
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return isGrouped ? CGSize(width: collectionView.bounds.width, height: 40) : .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader && isGrouped {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as? PhotoSectionHeader else {
                return UICollectionReusableView()
            }
            header.configure(title: "Group \(indexPath.section + 1)")
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - PhotoGridCell custom cell
class PhotoGridCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let checkContainer = UIView()
    private let checkIcon = UIImageView()
    private let burstLabel = UILabel()
    
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
        
        // Circular checkbox indicator
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
            
            checkContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            checkContainer.widthAnchor.constraint(equalToConstant: 24),
            checkContainer.heightAnchor.constraint(equalToConstant: 24),
            
        checkIcon.centerXAnchor.constraint(equalTo: checkContainer.centerXAnchor),
        checkIcon.centerYAnchor.constraint(equalTo: checkContainer.centerYAnchor),
        checkIcon.widthAnchor.constraint(equalToConstant: 12),
        checkIcon.heightAnchor.constraint(equalToConstant: 12)
    ])
    
    // Burst tag on top-left
    burstLabel.text = " BURST "
    burstLabel.font = .systemFont(ofSize: 10, weight: .bold)
    burstLabel.textColor = .white
    burstLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    burstLabel.layer.cornerRadius = 4
    burstLabel.clipsToBounds = true
    burstLabel.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(burstLabel)
    
    NSLayoutConstraint.activate([
        burstLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
        burstLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4)
    ])
}
    
    func configure(with asset: PHAsset, isChecked: Bool) {
        // Cancel previous request
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        
        // Fetch thumbnail image
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let size = bounds.size
        imageRequestID = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            self?.imageView.image = image
        }
        
        if isChecked {
            checkContainer.backgroundColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
            checkContainer.layer.borderColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0).cgColor
            checkIcon.isHidden = false
        } else {
            checkContainer.backgroundColor = UIColor.black.withAlphaComponent(0.24)
            checkContainer.layer.borderColor = UIColor.white.cgColor
            checkIcon.isHidden = true
        }
        
        burstLabel.isHidden = !asset.representsBurst
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
    }
}

// MARK: - Section Header for Grouped Duplicates
class PhotoSectionHeader: UICollectionReusableView {
    
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(title: String) {
        titleLabel.text = title.uppercased()
    }
}
