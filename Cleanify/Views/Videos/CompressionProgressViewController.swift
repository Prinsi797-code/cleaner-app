import UIKit

class CompressionProgressViewController: UIViewController {
    
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let percentageLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        titleLabel.text = "Compressing Video..."
        titleLabel.font = UIFont.roundedFont(ofSize: 22, weight: .bold)
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
        percentageLabel.font = UIFont.roundedFont(ofSize: 16, weight: .semibold)
        percentageLabel.textColor = .secondaryLabel
        percentageLabel.textAlignment = .center
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(percentageLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
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
