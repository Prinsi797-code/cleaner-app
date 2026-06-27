//  RemoteConfigService.swift
//  cleaner-app
//  Created by Hevin Technoweb on 21/03/26.

import Foundation
import Combine
import FirebaseRemoteConfig

@MainActor
class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()

    @Published var adConfig  = AppAdConfig()
    @Published var isFetched = false

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() { setupDefaults() }

    // MARK: - Defaults
    private func setupDefaults() {
        let defaults: [String: NSObject] = [
            // main_screen
            "ad_flag":             NSNumber(value: 1),
            "baner_id":            NSString("ca-app-pub-3940256099942544/2934735716"),
            "main_inter_flag":     NSNumber(value: 1),
            "main_inter_id":       NSString("ca-app-pub-3940256099942544/4411468910"),
            // splash_screen
            "splash_inter_flag":   NSNumber(value: 1),
            "splash_inter_id":     NSString("ca-app-pub-3940256099942544/4411468910"),
            // floor_inter
            "floor_inter_id":      NSString("ca-app-pub-3940256099942544/4411468910"),
            "inter_ads_flag":      NSNumber(value: 1),
            // video_screen
            "video_flag":          NSNumber(value: 3),
            "video_inter_id":      NSString("ca-app-pub-3940256099942544/4411468910"),
            "video_native_flag":   NSNumber(value: 1),
            "video_native_id":     NSString("ca-app-pub-3940256099942544/2247696110"),
            // dup_video_screen
            "dup_inter_flag":      NSNumber(value: 3),
            "dup_inter_id":        NSString("ca-app-pub-3940256099942544/4411468910"),
            "dup_native_flag":     NSNumber(value: 1),
            "dup_native_id":       NSString("ca-app-pub-3940256099942544/2247696110"),
            // compress_screen
            "compress_inter_flag": NSNumber(value: 3),
            "compress_inter_id":   NSString("ca-app-pub-3940256099942544/4411468910"),
            "compress_native_flag":NSNumber(value: 1),
            "compress_native_id":  NSString("ca-app-pub-3940256099942544/2247696110"),
            // contact_screen
            "contact_inter_flag":  NSNumber(value: 3),
            "contact_inter_id":    NSString("ca-app-pub-3940256099942544/4411468910"),
            "contact_native_flag": NSNumber(value: 1),
            "contact_native_id":   NSString("ca-app-pub-3940256099942544/2247696110"),
            // file_manager_screen
            "file_inter_flag":     NSNumber(value: 3),
            "file_inter_id":       NSString("ca-app-pub-3940256099942544/4411468910"),
            "file_native_flag":    NSNumber(value: 1),
            "file_native_id":      NSString("ca-app-pub-3940256099942544/2247696110"),
            // cache_screen
            "cache_inter_flag":    NSNumber(value: 3),
            "cache_inter_id":      NSString("ca-app-pub-3940256099942544/4411468910"),
            "cache_native_flag":   NSNumber(value: 1),
            "cache_native_id":     NSString("ca-app-pub-3940256099942544/2247696110"),
        ]
        remoteConfig.setDefaults(defaults)
    }

    // MARK: - Fetch
    func fetchConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0  // production: 3600
        remoteConfig.configSettings = settings

        remoteConfig.fetchAndActivate { [weak self] _, error in
            if let error { print("RemoteConfig error: \(error)") }
            Task { @MainActor in
                self?.parseConfig()
                self?.isFetched = true
                print("✅ RemoteConfig fetched")
            }
        }
    }

    // MARK: - Parse
    private func parseConfig() {
        var c = AppAdConfig()

        c.mainScreen.bannerFlag = intVal("ad_flag") == 1
        c.mainScreen.bannerId   = strVal("baner_id")
        c.mainScreen.interFlag  = InterAdFlag(rawValue: intVal("main_inter_flag")) ?? .never
        c.mainScreen.interId    = strVal("main_inter_id")

        c.splashScreen.interFlag = InterAdFlag(rawValue: intVal("splash_inter_flag")) ?? .never
        c.splashScreen.interId   = strVal("splash_inter_id")

        c.floorInterId   = strVal("floor_inter_id")
        c.floorInterFlag = intVal("inter_ads_flag") == 1

        c.videoScreen.interFlag  = InterAdFlag(rawValue: intVal("video_flag")) ?? .never
        c.videoScreen.interId    = strVal("video_inter_id")
        c.videoScreen.nativeFlag = intVal("video_native_flag") == 1
        c.videoScreen.nativeId   = strVal("video_native_id")

        c.dupVideoScreen.interFlag  = InterAdFlag(rawValue: intVal("dup_inter_flag")) ?? .never
        c.dupVideoScreen.interId    = strVal("dup_inter_id")
        c.dupVideoScreen.nativeFlag = intVal("dup_native_flag") == 1
        c.dupVideoScreen.nativeId   = strVal("dup_native_id")

        c.compressScreen.interFlag  = InterAdFlag(rawValue: intVal("compress_inter_flag")) ?? .never
        c.compressScreen.interId    = strVal("compress_inter_id")
        c.compressScreen.nativeFlag = intVal("compress_native_flag") == 1
        c.compressScreen.nativeId   = strVal("compress_native_id")

        c.contactScreen.interFlag  = InterAdFlag(rawValue: intVal("contact_inter_flag")) ?? .never
        c.contactScreen.interId    = strVal("contact_inter_id")
        c.contactScreen.nativeFlag = intVal("contact_native_flag") == 1
        c.contactScreen.nativeId   = strVal("contact_native_id")

        c.fileScreen.interFlag  = InterAdFlag(rawValue: intVal("file_inter_flag")) ?? .never
        c.fileScreen.interId    = strVal("file_inter_id")
        c.fileScreen.nativeFlag = intVal("file_native_flag") == 1
        c.fileScreen.nativeId   = strVal("file_native_id")

        c.cacheScreen.interFlag  = InterAdFlag(rawValue: intVal("cache_inter_flag")) ?? .never
        c.cacheScreen.interId    = strVal("cache_inter_id")
        c.cacheScreen.nativeFlag = intVal("cache_native_flag") == 1
        c.cacheScreen.nativeId   = strVal("cache_native_id")

        self.adConfig = c
    }

    private func intVal(_ key: String) -> Int { remoteConfig[key].numberValue.intValue }
    private func strVal(_ key: String) -> String { remoteConfig[key].stringValue ?? "" }
}
