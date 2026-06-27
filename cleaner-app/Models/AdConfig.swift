// AdConfig.swift
// Models for Firebase Remote Config ad configuration

import Foundation

// MARK: - Inter Ad Flag Logic
// 0 = Never show
// 1 = Once in a lifetime (per install)
// 2 = Once per day
// 3 = Every time

enum InterAdFlag: Int {
    case never       = 0
    case onceEver    = 1
    case oncePerDay  = 2
    case always      = 3
}

// MARK: - Screen Names (match Firebase keys)
enum AdScreen: String {
    case main         = "main_screen"
    case splash       = "splash_screen"
    case video        = "video_screen"
    case dupVideo     = "dup_video_screen"
    case compress     = "compress_screen"
    case contact      = "contact_screen"
    case fileManager  = "file_manager_screen"
    case cache        = "cache_screen"
    case floorInter   = "floor_inter"
}

// MARK: - Screen Ad Config
struct ScreenAdConfig {
    let screen: AdScreen

    // Interstitial
    var interFlag: InterAdFlag = .never
    var interId: String = ""

    // Native
    var nativeFlag: Bool = false
    var nativeId: String = ""

    // Banner (main_screen only)
    var bannerFlag: Bool = false
    var bannerId: String = ""
}

// MARK: - Full App Ad Config
struct AppAdConfig {
    var mainScreen    = ScreenAdConfig(screen: .main)
    var splashScreen  = ScreenAdConfig(screen: .splash)
    var videoScreen   = ScreenAdConfig(screen: .video)
    var dupVideoScreen = ScreenAdConfig(screen: .dupVideo)
    var compressScreen = ScreenAdConfig(screen: .compress)
    var contactScreen  = ScreenAdConfig(screen: .contact)
    var fileScreen     = ScreenAdConfig(screen: .fileManager)
    var cacheScreen    = ScreenAdConfig(screen: .cache)

    // Floor inter (global fallback)
    var floorInterId: String  = ""
    var floorInterFlag: Bool  = false  // 1 = enabled, 0 = disabled

    func config(for screen: AdScreen) -> ScreenAdConfig {
        switch screen {
        case .main:         return mainScreen
        case .splash:       return splashScreen
        case .video:        return videoScreen
        case .dupVideo:     return dupVideoScreen
        case .compress:     return compressScreen
        case .contact:      return contactScreen
        case .fileManager:  return fileScreen
        case .cache:        return cacheScreen
        case .floorInter:   return ScreenAdConfig(screen: .floorInter)
        }
    }
}
