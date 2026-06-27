//  cleaner_appApp.swift
//  cleaner-app
//  Created by Hevin Technoweb on 05/03/26.

import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct cleaner_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Step 1: Firebase
        FirebaseApp.configure()

        // Step 2: Remote config (async — splash ad is independent of this)
        Task { @MainActor in
            RemoteConfigService.shared.fetchConfig()
        }

        // Step 3: ✅ AdMob SDK — ads SIRF completion ke andar load karo
        // Pehle initializeSDK() call hoti thi jo internally start() karta tha
        // lekin ads usse bhi pehle 0.5s delay se load ho jaati thi → SDK ready nahi hoti thi
        MobileAds.shared.start { status in
            print("✅ AdMob SDK ready: \(status)")
            Task { @MainActor in
                // ✅ Splash sabse pehle — SplashView ka onChange isse pakdega
                AdManager.shared.loadSplashInter()
                AdManager.shared.loadFloorInter()
                AdManager.shared.loadMainInter()
            }

            // Baaki screen ads 1s baad — network pressure kam karo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task { @MainActor in
                    AdManager.shared.loadInterAd(for: .video)
                    AdManager.shared.loadInterAd(for: .dupVideo)
                    AdManager.shared.loadInterAd(for: .compress)
                    AdManager.shared.loadInterAd(for: .contact)
                    AdManager.shared.loadInterAd(for: .fileManager)
                    AdManager.shared.loadInterAd(for: .cache)
                }
            }
        }

        return true
    }
}
