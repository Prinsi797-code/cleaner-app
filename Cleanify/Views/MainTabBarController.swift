//
//  MainTabBarController.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import UIKit

struct AppState {
    static var hasShownRescanPopup = false
}

class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        let scanVC = ScanViewController()
        let photosVC = PhotoCleanerViewController()
        let videosVC = VideoCleanerViewController()
        let contactsVC = ContactCleanerViewController()
        let settingsVC = SettingsViewController()
        
        // Wrap in Navigation Controllers for standard navigation UI
        let scanNav = createNav(with: scanVC, title: "Scan", image: UIImage(systemName: "wand.and.sparkles"))
        let photosNav = createNav(with: photosVC, title: "Photos", image: UIImage(systemName: "photo.on.rectangle"))
        let videosNav = createNav(with: videosVC, title: "Videos", image: UIImage(systemName: "video"))
        let contactsNav = createNav(with: contactsVC, title: "Contacts", image: UIImage(systemName: "person.crop.circle"))
        let settingsNav = createNav(with: settingsVC, title: "Settings", image: UIImage(systemName: "gearshape"))
        
        self.setViewControllers([scanNav, photosNav, videosNav, contactsNav, settingsNav], animated: false)
        self.selectedIndex = 0 // Land on Scan tab initially
    }
    
    private func createNav(with rootViewController: UIViewController, title: String, image: UIImage?) -> UINavigationController {
        let nav = UINavigationController(rootViewController: rootViewController)
        nav.tabBarItem.title = title
        nav.tabBarItem.image = image
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }
    
    private func setupAppearance() {
        // Set standard background and tint colors supporting dynamic systems
        //tabBar.backgroundColor = .systemBackground
        tabBar.tintColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        tabBar.unselectedItemTintColor = .secondaryLabel
        
        // Dynamic bottom border styling
        //tabBar.shadowImage = UIImage()
        //tabBar.backgroundImage = UIImage()
        
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .systemBackground
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
