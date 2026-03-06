//  cleaner_appApp.swift
//  cleaner-app
//  Created by Hevin Technoweb on 05/03/26.

import SwiftUI

@main
struct cleaner_appApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
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

            MoreView()
                .tabItem { Label("More",       systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .accentColor(.purple)
    }
}

// MARK: - More View  (NavigationLink — no tab switching needed)
struct MoreView: View {

    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    VideoCleanerView()
                } label: {
                    MoreRow(icon: "video.fill",              title: "Videos")
                }

                NavigationLink {
                    DuplicateVideoView()
                } label: {
                    MoreRow(icon: "video.badge.checkmark",   title: "Dup Videos")
                }

                NavigationLink {
                    VideoCompressView()
                } label: {
                    MoreRow(icon: "arrow.down.circle.fill",  title: "Compress")
                }

                NavigationLink {
                    ContactsHubView()
                } label: {
                    MoreRow(icon: "person.crop.circle.fill", title: "Contacts")
                }

                NavigationLink {
                    FileManagerRootView()
                } label: {
                    MoreRow(icon: "folder.fill",             title: "Files")
                }

                NavigationLink {
                    AppCacheView()
                } label: {
                    MoreRow(icon: "trash.fill",              title: "Cache")
                }
            }
            .listStyle(.plain)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)   // large = LEFT aligned
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
