//  FileManagerView.swift
//  cleaner-app

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Model
struct FileItem: Identifiable {
    let id       = UUID()
    let url:       URL
    let name:      String
    let isDir:     Bool
    let fileSize:  Int64
    let modDate:   Date?
    let isCloud:   Bool

    var icon: String {
        if isDir { return "folder.fill" }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg","jpeg","png","heic","gif","webp": return "photo.fill"
        case "mp4","mov","avi","mkv","m4v":          return "video.fill"
        case "mp3","aac","m4a","wav","flac":         return "music.note"
        case "pdf":                                   return "doc.richtext.fill"
        case "zip","rar","gz","tar":                  return "archivebox.fill"
        case "doc","docx":                            return "doc.fill"
        case "xls","xlsx":                            return "tablecells.fill"
        case "ppt","pptx":                            return "rectangle.on.rectangle.fill"
        case "txt","md":                              return "doc.text.fill"
        default:                                      return "doc.fill"
        }
    }

    var iconColor: Color {
        if isDir { return Color(hexString: "#FB8C00") }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg","jpeg","png","heic","gif","webp": return Color(hexString: "#1E88E5")
        case "mp4","mov","avi","mkv","m4v":          return Color(hexString: "#E53935")
        case "mp3","aac","m4a","wav","flac":         return Color(hexString: "#8E24AA")
        case "pdf":                                   return Color(hexString: "#E53935")
        case "zip","rar","gz","tar":                  return Color(hexString: "#6D4C41")
        case "doc","docx":                            return Color(hexString: "#1565C0")
        case "xls","xlsx":                            return Color(hexString: "#2E7D32")
        case "ppt","pptx":                            return Color(hexString: "#F57F17")
        default:                                      return Color(hexString: "#546E7A")
        }
    }
}

// MARK: - Service
class FileManagerService {
    static let shared = FileManagerService()
    private let fm = FileManager.default

    var iCloudURL: URL? {
        fm.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    var onMyIPhoneURL: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func listContents(of url: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [
            .nameKey, .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey, .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemDownloadingStatusKey
        ]
        guard let urls = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { itemURL in
            let res     = try? itemURL.resourceValues(forKeys: Set(keys))
            let isDir   = res?.isDirectory ?? false
            let size    = Int64(res?.fileSize ?? 0)
            let modDate = res?.contentModificationDate
            let isCloud = (res?.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded)
            return FileItem(url: itemURL, name: itemURL.lastPathComponent,
                            isDir: isDir, fileSize: size, modDate: modDate, isCloud: isCloud)
        }.sorted {
            if $0.isDir != $1.isDir { return $0.isDir }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func delete(_ urls: [URL]) throws {
        for url in urls { try fm.removeItem(at: url) }
    }

    func totalSize(of url: URL) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

// MARK: - ViewModel
@MainActor
class FileManagerViewModel: ObservableObject {
    @Published var currentURL:     URL
    @Published var items:          [FileItem] = []
    @Published var selectedIDs     = Set<UUID>()
    @Published var isLoading       = false
    @Published var showDeleteAlert = false
    @Published var toastMessage:   String?
    @Published var searchText      = ""
    @Published var sortBy: SortOption = .name
    @Published var showShareSheet  = false
    @Published var shareURLs:      [URL] = []

    enum SortOption: String, CaseIterable {
        case name = "Name", size = "Size", date = "Date"
    }

    private var history: [URL] = []
    var canGoBack: Bool { !history.isEmpty }

    var breadcrumb: String {
        let parts = currentURL.pathComponents
        if let idx = parts.firstIndex(of: "Documents") {
            return parts[idx...].joined(separator: " › ")
        }
        return currentURL.lastPathComponent
    }

    var filtered: [FileItem] {
        let base = searchText.isEmpty ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        switch sortBy {
        case .name: return base.sorted { $0.isDir != $1.isDir ? $0.isDir : $0.name < $1.name }
        case .size: return base.sorted { $0.fileSize > $1.fileSize }
        case .date: return base.sorted { ($0.modDate ?? .distantPast) > ($1.modDate ?? .distantPast) }
        }
    }

    var selectedItems: [FileItem]  { items.filter { selectedIDs.contains($0.id) } }
    var totalSelectedSize: Int64   { selectedItems.reduce(0) { $0 + $1.fileSize } }

    init(rootURL: URL) {
        self.currentURL = rootURL
        load()
    }

    func load() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = FileManagerService.shared.listContents(of: self.currentURL)
            DispatchQueue.main.async { self.items = result; self.isLoading = false }
        }
    }

    func navigate(to url: URL) {
        history.append(currentURL); currentURL = url
        selectedIDs = []; searchText = ""; load()
    }

    func goBack() {
        guard let prev = history.popLast() else { return }
        currentURL = prev; selectedIDs = []; searchText = ""; load()
    }

    func toggleSelect(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }
    func selectAll()   { selectedIDs = Set(filtered.map(\.id)) }
    func deselectAll() { selectedIDs = [] }

    func deleteSelected() {
        let urls = selectedItems.map(\.url)
        do {
            try FileManagerService.shared.delete(urls)
            items.removeAll { selectedIDs.contains($0.id) }
            let count = urls.count; selectedIDs = []
            toast("✅ Deleted \(count) item(s)")
        } catch { toast("❌ Delete failed: \(error.localizedDescription)") }
    }

    func shareSelected() { shareURLs = selectedItems.map(\.url); showShareSheet = true }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - Root View
// ✅ NavigationView HATA DIYA — AdWrappedView ka NavigationView use hoga
struct FileManagerRootView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Source", selection: $tab) {
                Text("On My iPhone").tag(0)
                Text("iCloud Drive").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            // ✅ Native Ad — search bar ke upar
            SmartNativeAdView(screen: .fileManager)

            if tab == 0 {
                FileListView(
                    vm: FileManagerViewModel(rootURL: FileManagerService.shared.onMyIPhoneURL),
                    title: "On My iPhone"
                )
            } else {
                if let icloud = FileManagerService.shared.iCloudURL {
                    FileListView(vm: FileManagerViewModel(rootURL: icloud), title: "iCloud Drive")
                } else {
                    iCloudPickerView
                }
            }
        }
        .navigationTitle("File Manager")
        .navigationBarTitleDisplayMode(.large)
//        .toolbar(.hidden, for: .tabBar)
    }

    private var iCloudPickerView: some View {
        VStack(spacing: 24) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 70))
                .foregroundStyle(LinearGradient(colors: [.blue, .cyan],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 8) {
                Text("iCloud Drive").font(.title2).bold()
                Text("Browse your iCloud files using\nthe system file picker")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            Button { openSystemFilePicker() } label: {
                Label("Open iCloud Drive", systemImage: "icloud.and.arrow.down")
                    .font(.subheadline).bold().foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            Text("Tip: Enable iCloud Drive in\nSettings → [Your Name] → iCloud")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func openSystemFilePicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
        picker.allowsMultipleSelection = true
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            root.present(picker, animated: true)
        }
    }
}

// MARK: - File List View
struct FileListView: View {
    @StateObject var vm: FileManagerViewModel
    let title: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Breadcrumb + back
                if vm.canGoBack {
                    HStack {
                        Button { vm.goBack() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                                Text("Back").font(.subheadline)
                            }.foregroundColor(.blue)
                        }
                        Spacer()
                        Text(vm.breadcrumb).font(.caption).foregroundColor(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                }

                // Action bar
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vm.filtered.count) items").font(.caption).bold()
                        if !vm.selectedIDs.isEmpty {
                            Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                    Spacer()
                    Menu {
                        ForEach(FileManagerViewModel.SortOption.allCases, id: \.self) { opt in
                            Button(opt.rawValue) { vm.sortBy = opt }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down").font(.caption).foregroundColor(.purple)
                    }
                    Button(vm.selectedIDs.count == vm.filtered.count ? "Deselect All" : "Select All") {
                        if vm.selectedIDs.count == vm.filtered.count { vm.deselectAll() }
                        else { vm.selectAll() }
                    }.font(.caption).foregroundColor(.purple)

                    if !vm.selectedIDs.isEmpty {
                        Button { vm.shareSelected() } label: {
                            Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
                        }
                        Button { vm.showDeleteAlert = true } label: {
                            Image(systemName: "trash.fill").foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))

                // ✅ Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search files…", text: $vm.searchText).font(.subheadline)
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color(.systemGroupedBackground))

                // File list
                if vm.isLoading {
                    Spacer(); ProgressView("Loading…"); Spacer()
                } else if vm.filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48)).foregroundColor(.secondary)
                        Text(vm.searchText.isEmpty ? "Empty Folder" : "No Results")
                            .font(.headline).foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(vm.filtered) { item in
                            FileRow(item: item, isSelected: vm.selectedIDs.contains(item.id)) {
                                if item.isDir { vm.navigate(to: item.url) }
                                else { vm.toggleSelect(item.id) }
                            } onLongPress: { vm.toggleSelect(item.id) }
                        }
                    }
                    .listStyle(.plain)
                }
            }

            if let msg = vm.toastMessage {
                VStack { Spacer(); ToastView(message: msg).padding(.bottom, 20) }
                    .animation(.spring(), value: vm.toastMessage)
            }
        }
        .alert("Delete \(vm.selectedIDs.count) item(s)?", isPresented: $vm.showDeleteAlert) {
            Button("Delete", role: .destructive) { vm.deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .sheet(isPresented: $vm.showShareSheet) {
            ShareSheet(url: vm.shareURLs.first ?? vm.currentURL)
        }
    }
}

// MARK: - File Row
struct FileRow: View {
    let item:        FileItem
    let isSelected:  Bool
    let onTap:       () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(item.iconColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: item.icon).font(.system(size: 20)).foregroundColor(item.iconColor)
                if item.isCloud {
                    Image(systemName: "icloud.and.arrow.down").font(.system(size: 9))
                        .foregroundColor(.white).padding(2).background(Color.blue)
                        .clipShape(Circle()).offset(x: 14, y: -14)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline).lineLimit(1)
                    .foregroundColor(item.isCloud ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text(item.isDir ? "Folder" : formatBytes(item.fileSize))
                        .font(.caption).foregroundColor(.secondary)
                    if let date = item.modDate {
                        Text("·").font(.caption).foregroundColor(.secondary)
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            if item.isDir {
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            } else {
                ZStack {
                    Circle().fill(isSelected ? Color.blue : Color.clear).frame(width: 24, height: 24)
                    Circle().stroke(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.vertical, 6).contentShape(Rectangle())
        .background(isSelected ? Color.blue.opacity(0.06) : Color.clear)
        .onTapGesture { onTap() }
        .onLongPressGesture { onLongPress() }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { try? FileManagerService.shared.delete([item.url]) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { } label: { Label("Share", systemImage: "square.and.arrow.up") }.tint(.blue)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }
}
