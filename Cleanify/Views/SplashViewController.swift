import UIKit

class SplashViewController: UIViewController {
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let logoLabel = UILabel()
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        logoLabel.text = "Cleanify"
        logoLabel.font = UIFont.roundedFont(ofSize: 44, weight: .black)
        logoLabel.textColor = .label
        view.addSubview(logoLabel)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 30)
        ])
        
        loadDataAndTransition()
    }
    
    private func loadDataAndTransition() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedPhotos = PhotoScanManager.shared.loadFromDisk()
            let loadedVideos = VideoScanManager.shared.loadFromDisk()
            let loadedContacts = ContactScanManager.shared.loadFromDisk()
            
                
            
            DispatchQueue.main.async {
                self.transitionToMain()
            }
        }
    }
    
    private func transitionToMain() {
        guard let window = view.window else { return }
        let mainVC = MainTabBarController()
        window.rootViewController = mainVC
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
    }
}
