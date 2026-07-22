import UIKit

class CompressionProgressViewController: UIViewController {
    
    private let imageCardView = UIView()
    private let heroImageView = UIImageView()
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let percentageLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // Styled Card Container for Image
        imageCardView.translatesAutoresizingMaskIntoConstraints = false
        imageCardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0)
        imageCardView.layer.cornerRadius = 24
        imageCardView.layer.borderWidth = 1
        imageCardView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0).cgColor
        view.addSubview(imageCardView)
        
        heroImageView.image = UIImage(named: "video_compress")
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        imageCardView.addSubview(heroImageView)
        
        titleLabel.text = "Compressing Video..."
        titleLabel.font = UIFont.roundedFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .secondarySystemBackground
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        view.addSubview(progressView)
        
        percentageLabel.text = "0%"
        percentageLabel.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        percentageLabel.textColor = .systemBlue
        percentageLabel.textAlignment = .center
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(percentageLabel)
        
        NSLayoutConstraint.activate([
            imageCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -90),
            imageCardView.widthAnchor.constraint(equalToConstant: 250),
            imageCardView.heightAnchor.constraint(equalToConstant: 170),
            
            heroImageView.centerXAnchor.constraint(equalTo: imageCardView.centerXAnchor),
            heroImageView.centerYAnchor.constraint(equalTo: imageCardView.centerYAnchor),
            heroImageView.widthAnchor.constraint(equalTo: imageCardView.widthAnchor, constant: -32),
            heroImageView.heightAnchor.constraint(equalTo: imageCardView.heightAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: imageCardView.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 28),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            
            percentageLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            percentageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    func updateProgress(_ progress: Float) {
        progressView.setProgress(progress, animated: true)
        percentageLabel.text = "\(Int(progress * 100))%"
    }
}
