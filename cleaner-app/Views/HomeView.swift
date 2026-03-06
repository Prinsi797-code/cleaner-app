//  HomeView.swift

import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @Binding var selectedTab: Int

    // Tab indices in MainTabView
    // 0=Home, 1=Photos, 2=Blurry, 3=FaceMatch, 4=More
    // More contains: Videos, DupVideos, Compress, Contacts, Files, Cache via NavigationLink

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    StorageRingView(usedGB: vm.usedGB, totalGB: vm.totalGB)
                        .padding(.top)

                    // Stat Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

                        // Photos → tab 1
                        Button { selectedTab = 1 } label: {
                            StatCard(icon: "photo.fill", title: "Photos", value: vm.photoCount, color: .blue)
                        }.buttonStyle(.plain)

                        // Videos → More tab (4), then user navigates inside
                        Button { selectedTab = 4 } label: {
                            StatCard(icon: "video.fill", title: "Videos", value: vm.videoCount, color: .orange)
                        }.buttonStyle(.plain)

                        // Contacts → More tab (4)
                        Button { selectedTab = 4 } label: {
                            StatCard(icon: "person.fill", title: "Contacts", value: vm.contactCount, color: .green)
                        }.buttonStyle(.plain)

                        // Apps — no redirect
                        StatCard(icon: "square.grid.2x2", title: "Apps", value: vm.appCount, color: .purple)
                    }
                    .padding(.horizontal)

                    // Quick Clean
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Quick Clean")
                            .font(.headline).padding(.horizontal).padding(.bottom, 10)

                        // Face Duplicates → tab 3
                        Button { selectedTab = 3 } label: {
                            QuickActionRow(icon: "person.2.fill", title: "Face Duplicates",
                                           subtitle: "Group same-person photos", color: .pink)
                        }.buttonStyle(.plain)

                        Divider().padding(.leading, 70)

                        // Large Videos → More tab (4)
                        Button { selectedTab = 4 } label: {
                            QuickActionRow(icon: "video.fill", title: "Large Videos",
                                           subtitle: "Free up video space", color: .orange)
                        }.buttonStyle(.plain)

                        Divider().padding(.leading, 70)

                        // App Cache → More tab (4)
                        Button { selectedTab = 4 } label: {
                            QuickActionRow(icon: "trash.fill", title: "App Cache",
                                           subtitle: "Clear cached app data", color: .red)
                        }.buttonStyle(.plain)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Phone Cleaner")
            .onAppear { vm.load() }
        }
    }
}

struct StorageRingView: View {
    let usedGB: Double
    let totalGB: Double
    var percent: Double { totalGB > 0 ? min(usedGB / totalGB, 1) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 18).frame(width: 180, height: 180)
            Circle()
                .trim(from: 0, to: CGFloat(percent))
                .stroke(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 180, height: 180)
                .animation(.easeInOut(duration: 1), value: percent)
            VStack(spacing: 4) {
                Text(String(format: "%.1f GB", usedGB)).font(.title2).bold()
                Text("of \(String(format: "%.0f", totalGB)) GB used")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct StatCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct QuickActionRow: View {
    let icon: String; let title: String; let subtitle: String; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundColor(.white)
                .frame(width: 42, height: 42).background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
        }
        .padding(.horizontal).padding(.vertical, 12)
    }
}
