//  FaceGroupView.swift

import SwiftUI
import Photos

struct FaceGroupView: View {
    @StateObject private var vm = FaceGroupViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                if vm.isScanning {
                    ScanningView(text: vm.progressText,
                                 progress: vm.total > 0 ? Double(vm.progress) / Double(vm.total) : 0)
                } else if vm.groups.isEmpty {
                    EmptyStateView(icon: "person.2.fill", title: "No Face Groups",
                                   subtitle: "Tap Scan to find duplicate face photos",
                                   buttonTitle: "Scan Photos") { vm.startScan() }
                } else {
                    groupBody
                }
                if let msg = vm.toastMessage {
                    VStack { Spacer(); ToastView(message: msg).padding(.bottom, 90) }
                        .animation(.spring(), value: vm.toastMessage)
                }
            }
            .navigationTitle("Face Match")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !vm.groups.isEmpty { Button("Rescan") { vm.startScan() } }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.selectedIDs.isEmpty {
                        Button { vm.showDeleteAlert = true } label: {
                            Label("Delete", systemImage: "trash").foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Delete \(vm.selectedIDs.count) Photos?", isPresented: $vm.showDeleteAlert) {
                Button("Delete", role: .destructive) { vm.deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Free \(formatBytes(vm.totalSelectedSize)). Cannot be undone.")
            }
        }
    }

    private var groupBody: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.groups.count) Groups").font(.subheadline).bold()
                    Text("\(vm.selectedIDs.count) selected · \(formatBytes(vm.totalSelectedSize))")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if !vm.selectedIDs.isEmpty {
                    Button { vm.showDeleteAlert = true } label: {
                        Text("Delete Selected").font(.subheadline).bold()
                            .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color.red).clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.groups) { group in
                        FaceGroupCard(group: group, selectedIDs: $vm.selectedIDs) {
                            vm.toggleSelection($0)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct FaceGroupCard: View {
    let group: FaceGroup
    @Binding var selectedIDs: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.fill").foregroundColor(.purple)
                Text("\(group.photos.count) similar photos").font(.subheadline).bold()
                Spacer()
                Text(formatBytes(group.totalSize)).font(.caption).foregroundColor(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.photos, id: \.asset.localIdentifier) { photo in
                        FacePhotoCell(
                            asset: photo.asset,
                            fileSize: photo.fileSize,
                            isSelected: selectedIDs.contains(photo.asset.localIdentifier),
                            isBest: photo.asset.localIdentifier == group.representative.localIdentifier
                        ) { onToggle(photo.asset.localIdentifier) }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FacePhotoCell: View {
    let asset: PHAsset
    let fileSize: Int64
    let isSelected: Bool
    let isBest: Bool
    let onTap: () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = image { Image(uiImage: img).resizable().scaledToFill() }
                else { Color.gray.opacity(0.3) }
            }
            .frame(width: 110, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.red : isBest ? Color.green : Color.clear, lineWidth: 3))
            .overlay(isSelected ? Color.red.opacity(0.15) : Color.clear)

            ZStack {
                Circle().fill(isSelected ? Color.red : Color.white.opacity(0.8)).frame(width: 24, height: 24)
                if isSelected { Image(systemName: "checkmark").font(.caption).bold().foregroundColor(.white) }
            }.padding(6)
        }
        .overlay(alignment: .bottom) {
            HStack {
                if isBest {
                    Text("KEEP").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2).background(Color.green).clipShape(Capsule())
                }
                Spacer()
                Text(formatBytes(fileSize)).font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white).shadow(radius: 1)
            }.padding(.horizontal, 6).padding(.bottom, 6)
        }
        .onTapGesture { onTap() }
        .onAppear {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat; opts.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 220, height: 280),
                contentMode: .aspectFill, options: opts
            ) { img, _ in DispatchQueue.main.async { image = img } }
        }
    }
}
