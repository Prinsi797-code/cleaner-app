import UIKit
import Photos

class VideoCompressorListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var videos: [PHAsset] = []
    
    private let emptyStateView = EmptyStateView(
        iconName: "video.badge.checkmark",
        title: "No Videos to Compress",
        subtitle: "No videos larger than 50 MB were found in your library.",
        iconColor: .systemBlue
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Smart Compress"
        view.backgroundColor = .systemGroupedBackground
        
        // Filter videos over 50 MB
        let minSizeInBytes: Int64 = 50 * 1024 * 1024 // 50 MB
        videos = VideoScanManager.shared.allVideos.filter { asset in
            let size = VideoScanManager.shared.videoSizes[asset.localIdentifier] ?? 0
            return size >= minSizeInBytes
        }
        
        // Sort by size descending
        videos.sort { a, b in
            let sizeA = VideoScanManager.shared.videoSizes[a.localIdentifier] ?? 0
            let sizeB = VideoScanManager.shared.videoSizes[b.localIdentifier] ?? 0
            return sizeA > sizeB
        }
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(VideoCompressorCell.self, forCellReuseIdentifier: "VideoCell")
        view.addSubview(tableView)
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = !videos.isEmpty
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - TableView
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videos.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! VideoCompressorCell
        let asset = videos[indexPath.row]
        
        let size = VideoScanManager.shared.videoSizes[asset.localIdentifier] ?? 0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: size)
        
        let durationStr = formatDuration(asset.duration)
        let isCompressed = VideoCompressionManager.shared.isCompressed(assetId: asset.localIdentifier)
        cell.configure(asset: asset, sizeStr: sizeStr, durationStr: durationStr, isCompressed: isCompressed)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let asset = videos[indexPath.row]
        
        if VideoCompressionManager.shared.isCompressed(assetId: asset.localIdentifier) {
            let alert = UIAlertController(title: "Already Compressed", message: "This video has already been compressed to optimal 720p HD size.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let confirmVC = CompressConfirmationViewController(asset: asset) { [weak self] in
            self?.startCompression(for: asset, at: indexPath)
        }
        present(confirmVC, animated: true)
    }
    
    private func startCompression(for asset: PHAsset, at indexPath: IndexPath) {
        let progressVC = CompressionProgressViewController()
        progressVC.modalPresentationStyle = .pageSheet
        progressVC.isModalInPresentation = true
        present(progressVC, animated: true)
        
        VideoCompressionManager.shared.compressVideo(asset: asset) { progress in
            progressVC.updateProgress(progress)
        } completion: { [weak self] result in
            progressVC.dismiss(animated: true) {
                switch result {
                case .success(let resultTuple):
                    let newAsset = resultTuple.0
                    let didDelete = resultTuple.1
                    VideoCompressionManager.shared.markCompressed(assetId: asset.localIdentifier)
                    VideoCompressionManager.shared.markCompressed(assetId: newAsset.localIdentifier)
                    self?.showSuccess(for: newAsset, oldAsset: asset, at: indexPath, didDelete: didDelete)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func showSuccess(for newAsset: PHAsset, oldAsset: PHAsset, at indexPath: IndexPath, didDelete: Bool) {
        if didDelete {
            // Update local arrays
            videos.removeAll { $0.localIdentifier == oldAsset.localIdentifier }
            
            // Remove it from global lists
            VideoScanManager.shared.allVideos.removeAll { $0.localIdentifier == oldAsset.localIdentifier }
            VideoScanManager.shared.largeVideos.removeAll { $0.localIdentifier == oldAsset.localIdentifier }
            
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            let alert = UIAlertController(title: "Success", message: "Video compressed and original deleted!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Success", message: "Video compressed successfully, but original was kept since you didn't allow deletion.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

class VideoCompressorCell: UITableViewCell {
    
    private let thumbnailImageView = UIImageView()
    private let titleLbl = UILabel()
    private let sizeLbl = UILabel()
    private let compressedBadge = UILabel()
    private var currentAssetIdentifier: String?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        accessoryType = .disclosureIndicator
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.backgroundColor = .secondarySystemBackground
        contentView.addSubview(thumbnailImageView)
        
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLbl.textColor = .label
        contentView.addSubview(titleLbl)
        
        sizeLbl.translatesAutoresizingMaskIntoConstraints = false
        sizeLbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        sizeLbl.textColor = .secondaryLabel
        contentView.addSubview(sizeLbl)
        
        compressedBadge.translatesAutoresizingMaskIntoConstraints = false
        compressedBadge.text = " ✓ Compressed "
        compressedBadge.font = UIFont.roundedFont(ofSize: 11, weight: .bold)
        compressedBadge.textColor = .systemGreen
        compressedBadge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.14)
        compressedBadge.layer.cornerRadius = 6
        compressedBadge.clipsToBounds = true
        compressedBadge.isHidden = true
        contentView.addSubview(compressedBadge)
        
        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLbl.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(lessThanOrEqualTo: compressedBadge.leadingAnchor, constant: -8),
            titleLbl.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor, constant: 6),
            
            compressedBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            compressedBadge.centerYAnchor.constraint(equalTo: titleLbl.centerYAnchor),
            compressedBadge.heightAnchor.constraint(equalToConstant: 20),
            
            sizeLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            sizeLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sizeLbl.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: -6)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(asset: PHAsset, sizeStr: String, durationStr: String, isCompressed: Bool) {
        titleLbl.text = "Video - \(durationStr)"
        
        if isCompressed {
            sizeLbl.text = "Size: \(sizeStr) • 720p HD"
            compressedBadge.isHidden = false
            accessoryType = .none
        } else {
            sizeLbl.text = "Size: \(sizeStr) (Tap to Compress)"
            compressedBadge.isHidden = true
            accessoryType = .disclosureIndicator
        }
        
        currentAssetIdentifier = asset.localIdentifier
        thumbnailImageView.image = nil // reset
        
        let targetSize = CGSize(width: 120, height: 120)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            if self?.currentAssetIdentifier == asset.localIdentifier {
                self?.thumbnailImageView.image = image
            }
        }
    }
}
