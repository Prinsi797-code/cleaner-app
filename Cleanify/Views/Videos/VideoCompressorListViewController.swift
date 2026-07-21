import UIKit
import Photos

class VideoCompressorListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var videos: [PHAsset] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Smart Compress"
        view.backgroundColor = .systemGroupedBackground
        
        // Use large videos by default, or all videos if no large videos exist
        let allLarge = VideoScanManager.shared.largeVideos
        videos = allLarge.isEmpty ? VideoScanManager.shared.allVideos : allLarge
        
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
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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
        cell.configure(asset: asset, sizeStr: sizeStr, durationStr: durationStr)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let asset = videos[indexPath.row]
        
        let alert = UIAlertController(title: "Compress Video?", message: "This will compress the video to 720p to save space. The original video will be replaced.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Compress", style: .default, handler: { [weak self] _ in
            self?.startCompression(for: asset, at: indexPath)
        }))
        present(alert, animated: true)
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
        
        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLbl.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLbl.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor, constant: 6),
            
            sizeLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            sizeLbl.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),
            sizeLbl.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: -6)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(asset: PHAsset, sizeStr: String, durationStr: String) {
        titleLbl.text = "Video - \(durationStr)"
        sizeLbl.text = "Size: \(sizeStr) (Tap to Compress)"
        
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
