//  AppCacheView.swift
//  Model + Service + ViewModel + View all in one file

import SwiftUI
import Combine

// MARK: - Model
struct CacheCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let colorHex: String
    let paths: [URL]
    var sizeBytes: Int64 = 0
    var isSelected: Bool = true
}

// MARK: - Service (private, only used in this file)
private class CacheService {
    static let shared = CacheService()

    func scan(completion: @escaping ([CacheCategory]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var cats: [CacheCategory] = []

            // 1. App Caches directory
            // App Caches directory - SIRF directory size, URLCache alag
            if let url = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let dirSize = self.size(url)  // URLCache.shared.currentDiskUsage mat add karo
                if dirSize > 0 {
                    cats.append(CacheCategory(name: "App Cache", icon: "internaldrive.fill",
                                              colorHex: "#FF6B35", paths: [url], sizeBytes: dirSize))
                }
            }
            // 2. Temp directory
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            let tmpSize = self.size(tmp)
            if tmpSize > 0 {
                cats.append(CacheCategory(name: "Temp Files", icon: "doc.fill",
                                          colorHex: "#E8A838", paths: [tmp], sizeBytes: tmpSize))
            }
            // 3. Application Support
            if let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let s = self.size(url)
                if s > 5_000 {
                    cats.append(CacheCategory(name: "App Support", icon: "folder.fill",
                                              colorHex: "#6B5EA8", paths: [url], sizeBytes: s))
                }
            }
            // 4. Documents
            if let url = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                let s = self.size(url)
                if s > 0 {
                    var cat = CacheCategory(name: "Documents", icon: "doc.text.fill",
                                            colorHex: "#2E86AB", paths: [url], sizeBytes: s)
                    cat.isSelected = false
                    cats.append(cat)
                }
            }
            DispatchQueue.main.async {
                completion(cats.sorted { $0.sizeBytes > $1.sizeBytes })
            }
        }
    }

    func clear(_ cats: [CacheCategory], completion: @escaping (Int64) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var actuallyFreed: Int64 = 0
            
            cats.forEach { cat in
                cat.paths.forEach { url in
                    let before = self.size(url)
                    self.clearDir(url)
                    let after = self.size(url)
                    actuallyFreed += (before - after)
                }
            }
            
            URLCache.shared.removeAllCachedResponses()
            URLCache.shared.diskCapacity = 0
            URLCache.shared.memoryCapacity = 0
            
            DispatchQueue.main.async { completion(actuallyFreed) }
        }
    }

    private func size(_ url: URL) -> Int64 {
        var total: Int64 = 0
        guard let e = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return 0 }
        for case let f as URL in e {
            total += (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        }
        return total
    }

    private func clearDir(_ url: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles)) ?? []
        
        files.forEach { fileURL in
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Could not delete: \(fileURL), error: \(error)")
            }
        }
    }
}

// MARK: - ViewModel
@MainActor
class AppCacheViewModel: ObservableObject {
    @Published var categories: [CacheCategory] = []
    @Published var isScanning  = false
    @Published var isClearing  = false
    @Published var freedBytes: Int64 = 0
    @Published var toastMessage: String?
    @Published var hasScanned: Bool = false

    // ← YEH MISSING THE - ADD KARO
    var selected: [CacheCategory] { categories.filter { $0.isSelected } }
    var totalSelected: Int64 { selected.reduce(0) { $0 + $1.sizeBytes } }
    var totalAll: Int64 { categories.reduce(0) { $0 + $1.sizeBytes } }

    func scan() {
        isScanning = true
        categories = []
        CacheService.shared.scan { [weak self] cats in
            self?.categories = cats
            self?.isScanning = false
            self?.hasScanned = true
        }
    }

    func toggle(_ id: UUID) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].isSelected.toggle()
    }

    func clearSelected() {
        isClearing = true
        CacheService.shared.clear(selected) { [weak self] freed in
            self?.freedBytes  = freed
            self?.isClearing  = false
            self?.categories.removeAll { $0.isSelected }
            self?.hasScanned = true
            self?.toast("✅ Freed \(formatBytes(freed))!")
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - View
struct AppCacheView: View {
    @StateObject private var vm = AppCacheViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                if vm.isScanning {
                    ScanningView(text: "Scanning cached data…", progress: 0)
                } else if vm.categories.isEmpty && vm.freedBytes == 0 && !vm.hasScanned {
                    EmptyStateView(
                        icon: "internaldrive",
                        title: "Check Your Cache",
                        subtitle: "Tap Scan to check for clearable data",
                        buttonTitle: "Scan Now") { vm.scan() }
                } else if vm.categories.isEmpty && vm.hasScanned {
                    EmptyStateView(
                        icon: vm.freedBytes > 0 ? "sparkles" : "internaldrive",
                        title: vm.freedBytes > 0 ? "All Clean! 🎉" : "Nothing Found",
                        subtitle: vm.freedBytes > 0 ? "Freed \(formatBytes(vm.freedBytes))" : "No clearable cache found",
                        buttonTitle: "Scan Again") { vm.scan() }
                } else {
                    cacheBody
                }
                if let msg = vm.toastMessage {
                    VStack { Spacer(); ToastView(message: msg).padding(.bottom, 90) }
                        .animation(.spring(), value: vm.toastMessage)
                }
            }
        }
        .navigationTitle("Cache & Storage")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { vm.scan() }) {
                    Text("Scan")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .clipShape(Capsule())
                }
                .disabled(vm.isScanning)
                .animation(nil, value: vm.isScanning)
                .transaction { t in t.animation = nil }
            }
            
        }
//        .toolbar(.hidden, for: .tabBar)
        
        
        .onAppear {
            if !vm.hasScanned { vm.scan() }
        }
//
    }

    private var cacheBody: some View {
        VStack(spacing: 0) {
            // Bar summary
            VStack(spacing: 8) {
                HStack {
                    Text("Clearable Storage").font(.headline)
                    Spacer()
                    Text(formatBytes(vm.totalAll)).font(.headline).foregroundColor(.orange)
                }
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        List {
                            ForEach(vm.categories) { cat in
                                CacheRow(cat: Binding(
                                    get: { vm.categories.first(where: { $0.id == cat.id }) ?? cat },
                                    set: { newVal in
                                        if let i = vm.categories.firstIndex(where: { $0.id == cat.id }) {
                                            vm.categories[i] = newVal
                                        }
                                    }
                                )) { vm.toggle(cat.id) }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(height: 10).clipShape(Capsule())
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            List {
                ForEach($vm.categories) { $cat in
                    CacheRow(cat: $cat) { vm.toggle(cat.id) }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)

            if !vm.selected.isEmpty {
                Button { vm.clearSelected() } label: {
                    HStack {
                        if vm.isClearing { ProgressView().tint(.white) }
                        else {
                            Image(systemName: "trash.fill")
                            Text("Clear \(formatBytes(vm.totalSelected))").bold()
                        }
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding()
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal).padding(.bottom, 16)
                }
                .disabled(vm.isClearing)
            }
        }
    }
}

// MARK: - Cache Row
struct CacheRow: View {
    @Binding var cat: CacheCategory
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: cat.icon).font(.title3).foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(hexString: cat.colorHex))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(cat.name).font(.subheadline).bold()
                Text(formatBytes(cat.sizeBytes)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(cat.isSelected ? Color.red : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 26, height: 26)
                if cat.isSelected {
                    RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 18, height: 18)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(cat.isSelected ? Color.red.opacity(0.06) : Color(.secondarySystemBackground)))
        .onTapGesture { onTap() }
    }
}




























































































