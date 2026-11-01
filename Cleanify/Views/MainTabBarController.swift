//
//  MainTabBarController.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit

struct AppState {
    static var hasShownRescanPopup = false
}

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        let scanVC = ScanViewController()
        let photosVC = PhotoCleanerViewController()
        let videosVC = VideoCleanerViewController()
        let contactsVC = ContactCleanerViewController()
        let settingsVC = SettingsViewController()
        
        let symbolName: String
        if #available(iOS 26.0, *) {
            symbolName = "wand.and.sparkles"
        } else {
            symbolName = "wand.and.stars"
        }

        let scanNav = createNav(with: scanVC, title: "Scan", image: UIImage(systemName: symbolName))
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
        tabBar.tintColor = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        tabBar.unselectedItemTintColor = .secondaryLabel
        
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .systemBackground
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    func attachNavigationDelegates(_ delegate: UINavigationControllerDelegate) {
        for vc in viewControllers ?? [] {
            if let nav = vc as? UINavigationController {
                nav.delegate = delegate
            }
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let navDelegate = parent as? UINavigationControllerDelegate {
            attachNavigationDelegates(navDelegate)
        }
    }
}
