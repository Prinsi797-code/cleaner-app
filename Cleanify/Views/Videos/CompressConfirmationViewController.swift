import UIKit
import Photos

class CompressConfirmationViewController: UIViewController {
    
    private let asset: PHAsset
    private let onConfirm: () -> Void
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let imageCardView = UIView()
    private let heroImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let compressButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    init(asset: PHAsset, onConfirm: @escaping () -> Void) {
        self.asset = asset
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.large(), .medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 32
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateEntrance()
    }
    
    private func setupUI() {
        // ScrollView setup for small screen support
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Hero Image Card Container with Soft Blue Tint
        imageCardView.translatesAutoresizingMaskIntoConstraints = false
        imageCardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0)
        imageCardView.layer.cornerRadius = 24
        imageCardView.layer.borderWidth = 1
        imageCardView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0).cgColor
        contentView.addSubview(imageCardView)
        
        // Large Hero Image
        heroImageView.image = UIImage(named: "video_compress")
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.clipsToBounds = true
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        imageCardView.addSubview(heroImageView)
        
        // Title
        titleLabel.text = "Compress Video?"
        titleLabel.font = UIFont.roundedFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Description
        descriptionLabel.text = "This will compress your video to 720p HD resolution to save up to 80% storage space while preserving great visual quality."
        descriptionLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        // Compress Button
        compressButton.setTitle("Compress Video", for: .normal)
        compressButton.titleLabel?.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        compressButton.setTitleColor(.white, for: .normal)
        compressButton.backgroundColor = .systemBlue
        compressButton.layer.cornerRadius = 26
        compressButton.layer.shadowColor = UIColor.systemBlue.cgColor
        compressButton.layer.shadowOpacity = 0.35
        compressButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        compressButton.layer.shadowRadius = 12
        compressButton.addTarget(self, action: #selector(didTapCompress), for: .touchUpInside)
        compressButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(compressButton)
        
        // Cancel Button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            imageCardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            imageCardView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageCardView.heightAnchor.constraint(equalToConstant: 185),
            
            heroImageView.centerXAnchor.constraint(equalTo: imageCardView.centerXAnchor),
            heroImageView.centerYAnchor.constraint(equalTo: imageCardView.centerYAnchor),
            heroImageView.widthAnchor.constraint(equalTo: imageCardView.widthAnchor, constant: -24),
            heroImageView.heightAnchor.constraint(equalTo: imageCardView.heightAnchor, constant: -16),
            
            titleLabel.topAnchor.constraint(equalTo: imageCardView.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            compressButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            compressButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            compressButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            compressButton.heightAnchor.constraint(equalToConstant: 52),
            
            cancelButton.topAnchor.constraint(equalTo: compressButton.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    private func animateEntrance() {
        imageCardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        imageCardView.alpha = 0.5
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: [], animations: {
            self.imageCardView.transform = .identity
            self.imageCardView.alpha = 1.0
        })
    }
    
    @objc private func didTapCompress() {
        dismiss(animated: true) { [weak self] in
            self?.onConfirm()
        }
    }
    
    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}
