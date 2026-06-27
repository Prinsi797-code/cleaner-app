//  MainTabView.swift
//  cleaner-app

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showBanner  = true
    @StateObject private var lifecycle = AppLifecycleObserver()
    @ObservedObject private var adManager = AdManager.shared

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem { Label("Home",       systemImage: "house.fill") }
                    .tag(0)
                
                DuplicatePhotoView()
                    .tabItem { Label("Photos",     systemImage: "photo.on.rectangle.angled") }
                    .tag(1)
                
                BlurryPhotoView()
                    .tabItem { Label("Blurry",     systemImage: "camera.filters") }
                    .tag(2)
                
                FaceGroupView()
                    .tabItem { Label("Face Match", systemImage: "person.2.fill") }
                    .tag(3)
                
                MoreView(showBanner: $showBanner)
                    .tabItem { Label("More",       systemImage: "ellipsis.circle.fill") }
                    .tag(4)
            }
            .accentColor(.purple)
            
            // Banner fixed height — hide hone par bhi space preserve karo
            SmartBannerView()
                .opacity(showBanner ? 1 : 0)   
                .frame(height: showBanner ? nil : 0)  // ← ya height 0 karo
        }
        .onChange(of: adManager.shouldShowResumeAd) { should in
            guard should else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let vc = adManager.topViewController() {
                    adManager.showResumeAdIfNeeded(from: vc)
                }
            }
        }
    }
}

// MARK: - More View
struct MoreView: View {
    @Binding var showBanner: Bool
    @State private var isInSubScreen = false

    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    VideoCleanerView()
                        .withBackInterAd(screen: .video)
                        .onAppear {
                            showBanner = false
                            AdManager.shared.loadInterAd(for: .video)
                        }
                        .onDisappear {
                            isInSubScreen = false
                            restoreBanner()
                        }
                } label: {
                    MoreRow(icon: "video.fill", title: "Videos")
                }

                NavigationLink {
                    DuplicateVideoView()
                        .withBackInterAd(screen: .dupVideo)
                        .onAppear {
                            showBanner = false
                            AdManager.shared.loadInterAd(for: .dupVideo)
                        }
                        .onDisappear {
                             isInSubScreen = false
                             restoreBanner()
                        }
                } label: {
                    MoreRow(icon: "video.badge.checkmark", title: "Dup Videos")
                }

                NavigationLink {
                    VideoCompressView()
                        .withBackInterAd(screen: .compress)
                        .onAppear {
                            showBanner = false
                            AdManager.shared.loadInterAd(for: .compress)
                        }
                        .onDisappear {
                            isInSubScreen = false
                            restoreBanner()
                        }
                } label: {
                    MoreRow(icon: "arrow.down.circle.fill", title: "Compress")
                }

                NavigationLink {
                    ContactsHubView()
                        .withBackInterAd(screen: .contact)
                        .onAppear {
                            showBanner = false
                            AdManager.shared.loadInterAd(for: .contact)
                        }
                        .onDisappear {
                             isInSubScreen = false
                             restoreBanner()
                        }
                } label: {
                    MoreRow(icon: "person.crop.circle.fill", title: "Contacts")
                }

                NavigationLink {
                    FileManagerRootView()
                        .withBackInterAd(screen: .fileManager)
                        .onAppear {
                            showBanner = false
                            AdManager.shared.loadInterAd(for: .fileManager)
                        }
                        .onDisappear {
                             isInSubScreen = false
                             restoreBanner()
                        }
                } label: {
                    MoreRow(icon: "folder.fill", title: "Files")
                }

                NavigationLink {
                    AppCacheView()
                        .withBackInterAd(screen: .cache)   
                        .onAppear {
                            showBanner = false
                            AdManager.shared.loadInterAd(for: .cache)
                        }
                        .onDisappear {
                             isInSubScreen = false
                             restoreBanner()
                        }
                } label: {
                    MoreRow(icon: "trash.fill", title: "Cache")
                }
            }
            .listStyle(.plain)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            showBanner = true  // ← Yahi main fix hai — hamesha restore karo
        }
    }
    private func restoreBanner() {
        // Delay thoda zyada — ad dismiss animation ke baad
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showBanner = true
        }
    }
}

struct MoreRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.purple)
                .frame(width: 32)
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}
