//
//  SwipePhotosViewController.swift
//  Cleanify
//

import UIKit
import Photos

class SwipePhotosViewController: UIViewController, UIGestureRecognizerDelegate, SwipeCardDelegate {
    
    private var allAssets: [PHAsset] = []
    private var trashedAssets = [String: PHAsset]()
    private var interactedAssets = Set<String>()
    private var trashedAssetSizes = [String: Int64]()
    private var confirmDeleteButton: UIBarButtonItem!
    
    private let imageManager = PHCachingImageManager()
    private var previousPreheatRect = CGRect.zero
    
    private var currentIndex = 0
    private var cardStack: [SwipeCardView] = []
    
    
    private let categoriesScrollView = UIScrollView()
    private let categoriesStack = UIStackView()
    private var categoryButtons: [UIButton] = []
    
    private let cardContainer = UIView()
    private let bottomControlsView = UIView()
    
    private let undoButton = UIButton(type: .system)
    private let trashButton = UIButton(type: .system)
    private let keepButton = UIButton(type: .system)
    
    private let progressLabel = UILabel()
    private let deleteButton = UIButton(type: .system)
    private let emptyStateView = EmptyStateView(
        iconName: "sparkles.rectangle.stack.fill",
        title: "All Sorted!",
        subtitle: "You have reviewed all items in this section.",
        iconColor: .systemGreen
    )
    
    enum Category: String, CaseIterable {
        case all = "All Photos"
        case screenshots = "Screenshots"
        case videos = "Videos"
        case duplicates = "Duplicates"
        case similar = "Similar"
    }
    private var selectedCategory: Category = .all
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Swipe to Sort"
        
        confirmDeleteButton = UIBarButtonItem(title: "Delete (0)", style: .prominent, target: self, action: #selector(handleDeleteSelected))
        confirmDeleteButton.tintColor = .systemRed
        confirmDeleteButton.isEnabled = false
        navigationItem.rightBarButtonItem = confirmDeleteButton
        
        setupCategoriesUI()
        setupUI()
        loadPhotos(for: .all)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Disable swipe back gesture so users don't accidentally exit while swiping cards
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            return false
        }
        return true
    }
    
    private func setupCategoriesUI() {
        categoriesScrollView.translatesAutoresizingMaskIntoConstraints = false
        categoriesScrollView.showsHorizontalScrollIndicator = false
        categoriesScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.addSubview(categoriesScrollView)
        
        categoriesStack.translatesAutoresizingMaskIntoConstraints = false
        categoriesStack.axis = .horizontal
        categoriesStack.spacing = 10
        categoriesScrollView.addSubview(categoriesStack)
        
        NSLayoutConstraint.activate([
            categoriesScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            categoriesScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoriesScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoriesScrollView.heightAnchor.constraint(equalToConstant: 40),
            
            categoriesStack.topAnchor.constraint(equalTo: categoriesScrollView.topAnchor),
            categoriesStack.leadingAnchor.constraint(equalTo: categoriesScrollView.leadingAnchor),
            categoriesStack.trailingAnchor.constraint(equalTo: categoriesScrollView.trailingAnchor),
            categoriesStack.bottomAnchor.constraint(equalTo: categoriesScrollView.bottomAnchor),
            categoriesStack.heightAnchor.constraint(equalTo: categoriesScrollView.heightAnchor)
        ])
        
        for category in Category.allCases {
            let btn = UIButton(type: .system)
            btn.setTitle(category.rawValue, for: .normal)
            btn.titleLabel?.font = UIFont.roundedFont(ofSize: 14, weight: .bold)
            btn.layer.cornerRadius = 16
            btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            
            if category == selectedCategory {
                btn.backgroundColor = .label
                btn.setTitleColor(.systemBackground, for: .normal)
            } else {
                btn.backgroundColor = .secondarySystemBackground
                btn.setTitleColor(.secondaryLabel, for: .normal)
            }
            
            btn.addTarget(self, action: #selector(didTapCategory(_:)), for: .touchUpInside)
            categoriesStack.addArrangedSubview(btn)
            categoryButtons.append(btn)
        }
        
        updateCategoryCounts()
    }
    
    private func updateCategoryCounts() {
        for (index, category) in Category.allCases.enumerated() {
            guard index < categoryButtons.count else { continue }
            let btn = categoryButtons[index]
            var count = 0
            
            switch category {
            case .all:
                count = PhotoScanManager.shared.allPhotos.filter { !interactedAssets.contains($0.localIdentifier) }.count
            case .screenshots:
                count = PhotoScanManager.shared.screenshots.filter { !interactedAssets.contains($0.localIdentifier) }.count
            case .videos:
                btn.setTitle(category.rawValue, for: .normal)
                continue
            case .duplicates:
                count = PhotoScanManager.shared.duplicateGroups.flatMap { $0.assets }.filter { !interactedAssets.contains($0.localIdentifier) }.count
            case .similar:
                count = PhotoScanManager.shared.similarGroups.flatMap { $0.assets }.filter { !interactedAssets.contains($0.localIdentifier) }.count
            }
            
            btn.setTitle("\(category.rawValue) (\(count))", for: .normal)
        }
    }
    
    private func setupUI() {
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = UIFont.roundedFont(ofSize: 14, weight: .semibold)
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center
        view.addSubview(progressLabel)
        
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardContainer)
        
        bottomControlsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomControlsView)
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
        
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setTitle("Delete 0 Photos", for: .normal)
        deleteButton.backgroundColor = .systemRed
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.titleLabel?.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        deleteButton.layer.cornerRadius = 24
        deleteButton.isHidden = true
        deleteButton.addTarget(self, action: #selector(handleDeleteSelected), for: .touchUpInside)
        view.addSubview(deleteButton)
        
        setupButtons()
        
        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: categoriesScrollView.bottomAnchor, constant: 12),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            cardContainer.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 12),
            cardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            cardContainer.bottomAnchor.constraint(equalTo: bottomControlsView.topAnchor, constant: -24),
            
            bottomControlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            bottomControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottomControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomControlsView.heightAnchor.constraint(equalToConstant: 80),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            
            deleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 240),
            deleteButton.heightAnchor.constraint(equalToConstant: 56),
            deleteButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }
    
    private func setupButtons() {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        bottomControlsView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: bottomControlsView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: bottomControlsView.trailingAnchor, constant: -16),
            stackView.centerYAnchor.constraint(equalTo: bottomControlsView.centerYAnchor)
        ])
        
        func createButton(icon: String, color: UIColor, size: CGFloat, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.tintColor = color
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = size / 2
            
            let config = UIImage.SymbolConfiguration(pointSize: size * 0.4, weight: .bold)
            button.setPreferredSymbolConfiguration(config, forImageIn: .normal)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: size),
                button.heightAnchor.constraint(equalToConstant: size)
            ])
            
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }
        
        let undoBtn = createButton(icon: "arrow.uturn.backward", color: .systemYellow, size: 60, action: #selector(handleUndo))
        let trashBtn = createButton(icon: "xmark", color: .systemRed, size: 80, action: #selector(handleTrash))
        let keepBtn = createButton(icon: "heart.fill", color: .systemGreen, size: 80, action: #selector(handleKeep))
        
        stackView.addArrangedSubview(undoBtn)
        stackView.addArrangedSubview(trashBtn)
        stackView.addArrangedSubview(keepBtn)
        
        self.undoButton.isHidden = true
    }
    
    @objc private func didTapCategory(_ sender: UIButton) {
        guard let index = categoryButtons.firstIndex(of: sender) else { return }
        let category = Category.allCases[index]
        guard category != selectedCategory else { return }
        
        selectedCategory = category
        
        // Update UI
        for btn in categoryButtons {
            if btn == sender {
                btn.backgroundColor = .label
                btn.setTitleColor(.systemBackground, for: .normal)
            } else {
                btn.backgroundColor = .secondarySystemBackground
                btn.setTitleColor(.secondaryLabel, for: .normal)
            }
        }
        
        loadPhotos(for: category)
    }
    
    private func loadPhotos(for category: Category) {
        currentIndex = 0
        allAssets.removeAll()
        imageManager.stopCachingImagesForAllAssets()
        
        var tempAssets: [PHAsset] = []
        switch category {
        case .all:
            tempAssets = PhotoScanManager.shared.allPhotos
            if tempAssets.isEmpty { 
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                result.enumerateObjects { asset, _, _ in tempAssets.append(asset) }
            }
        case .screenshots:
            tempAssets = PhotoScanManager.shared.screenshots
        case .videos:
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .video, options: fetchOptions)
            result.enumerateObjects { asset, _, _ in tempAssets.append(asset) }
        case .duplicates:
            tempAssets = PhotoScanManager.shared.duplicateGroups.flatMap { $0.assets }
        case .similar:
            tempAssets = PhotoScanManager.shared.similarGroups.flatMap { $0.assets }
        }
        
        allAssets = tempAssets.filter { !interactedAssets.contains($0.localIdentifier) }
        
        setupCardStack()
        updateProgress()
        updateCache()
    }
    

    
    private func setupCardStack() {
        cardStack.forEach { 
            $0.cleanupPlayer()
            $0.removeFromSuperview() 
        }
        cardStack.removeAll()
        
        emptyStateView.isHidden = true
        bottomControlsView.isHidden = false
        deleteButton.isHidden = true
        
        if currentIndex >= allAssets.count {
            showEmptyState()
            return
        }
        
        let cardsToShow = min(2, allAssets.count - currentIndex)
        for i in (0..<cardsToShow).reversed() {
            let asset = allAssets[currentIndex + i]
            let card = SwipeCardView()
            card.translatesAutoresizingMaskIntoConstraints = false
            card.configure(with: asset, imageManager: imageManager)
            card.delegate = self
            cardContainer.addSubview(card)
            
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: cardContainer.topAnchor),
                card.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                card.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
            ])
            
            if i == 1 {
                card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: -15)
                card.isUserInteractionEnabled = false
            }
            
            cardStack.append(card)
        }
        
        cardStack.last?.playVideo()
    }
    
    private func updateCache() {
        // Stop caching previous if memory gets high, or just let manager handle it.
        // We will cache the next 5 assets
        guard currentIndex < allAssets.count else { return }
        let nextIndex = currentIndex + 2 // skip currently showing
        let endIndex = min(allAssets.count, nextIndex + 5)
        
        if nextIndex < endIndex {
            let assetsToCache = Array(allAssets[nextIndex..<endIndex])
            let targetSize = CGSize(width: UIScreen.main.bounds.width * 1.5, height: UIScreen.main.bounds.height * 1.5)
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            imageManager.startCachingImages(for: assetsToCache, targetSize: targetSize, contentMode: .aspectFill, options: options)
        }
    }
    
    private func updateProgress() {
        progressLabel.text = "\(currentIndex) / \(allAssets.count)"
        undoButton.isHidden = (currentIndex == 0)
        
        if currentIndex >= allAssets.count {
            showEmptyState()
        }
    }
    
    private func showEmptyState() {
        emptyStateView.isHidden = false
        bottomControlsView.isHidden = true
        deleteButton.isHidden = trashedAssets.isEmpty
        
        let totalBytes = trashedAssets.values.compactMap { trashedAssetSizes[$0.localIdentifier] }.reduce(0, +)
        deleteButton.setTitle("Delete \(trashedAssets.count) Items • \(formatBytes(totalBytes))", for: .normal)
    }
    
    private func updateConfirmDeleteButton() {
        if trashedAssets.isEmpty {
            confirmDeleteButton.title = "Delete (0)"
            confirmDeleteButton.isEnabled = false
        } else {
            let totalBytes = trashedAssets.values.compactMap { trashedAssetSizes[$0.localIdentifier] }.reduce(0, +)
            confirmDeleteButton.title = "Delete (\(trashedAssets.count)) • \(formatBytes(totalBytes))"
            confirmDeleteButton.isEnabled = true
        }
        
        if emptyStateView.isHidden == false {
            showEmptyState() // Refresh the big button if empty state is showing
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func computeSize(for asset: PHAsset) {
        if trashedAssetSizes[asset.localIdentifier] != nil { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let resources = PHAssetResource.assetResources(for: asset)
            var size: Int64 = 0
            for resource in resources {
                if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                    size += fileSize
                }
            }
            DispatchQueue.main.async {
                self.trashedAssetSizes[asset.localIdentifier] = size
                self.updateConfirmDeleteButton()
            }
        }
    }
    
    @objc private func handleUndo() {
        guard currentIndex > 0 else { return }
        
        let previousAsset = allAssets[currentIndex - 1]
        trashedAssets.removeValue(forKey: previousAsset.localIdentifier)
        interactedAssets.remove(previousAsset.localIdentifier)
        updateConfirmDeleteButton()
        
        currentIndex -= 1
        setupCardStack()
        updateProgress()
        updateCategoryCounts()
        updateCache()
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    @objc private func handleTrash() {
        guard let topCard = cardStack.last else { return }
        topCard.swipeLeftAction()
    }
    
    @objc private func handleKeep() {
        guard let topCard = cardStack.last else { return }
        topCard.swipeRightAction()
    }
    
    @objc private func handleDeleteSelected() {
        guard !trashedAssets.isEmpty else { return }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(Array(self.trashedAssets.values) as NSFastEnumeration)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    let deletedIds = Set(self.trashedAssets.keys)
                    PhotoScanManager.shared.removeAssets(withIds: deletedIds)
                    
                    self.trashedAssets.removeAll()
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    func cardDidSwipeLeft(_ card: SwipeCardView) {
        if let asset = card.asset {
            trashedAssets[asset.localIdentifier] = asset
            interactedAssets.insert(asset.localIdentifier)
            computeSize(for: asset)
            updateConfirmDeleteButton()
        }
        moveToNextCard()
    }
    
    func cardDidSwipeRight(_ card: SwipeCardView) {
        if let asset = card.asset {
            interactedAssets.insert(asset.localIdentifier)
        }
        moveToNextCard()
    }
    
    func cardDidSwipeDown(_ card: SwipeCardView) {
        handleUndo()
    }
    
    private func moveToNextCard() {
        currentIndex += 1
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        setupCardStack()
        updateProgress()
        updateCategoryCounts()
        updateCache()
    }
}
