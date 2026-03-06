//
//  ContactsView.swift
//  cleaner-app
//
//  Created by Hevin Technoweb on 06/03/26.
//

//  ContactsView.swift
//  Duplicate Contacts + Incomplete Contacts + All Contacts

import SwiftUI
import Combine
import Contacts

// MARK: - Model
struct ContactItem: Identifiable {
    let id: String
    let contact: CNContact
    var fullName: String {
        [contact.givenName, contact.middleName, contact.familyName]
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
    var displayName: String { fullName.isEmpty ? (contact.organizationName.isEmpty ? "No Name" : contact.organizationName) : fullName }
    var phone: String  { contact.phoneNumbers.first?.value.stringValue ?? "" }
    var email: String  { contact.emailAddresses.first?.value as String? ?? "" }
    var hasPhone: Bool { !contact.phoneNumbers.isEmpty }
    var hasEmail: Bool { !contact.emailAddresses.isEmpty }
    var hasName:  Bool { !fullName.isEmpty }
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(displayName.prefix(2)).uppercased()
    }
}

struct ContactGroup: Identifiable {
    let id = UUID()
    var contacts: [ContactItem]
    var matchReason: String   // e.g. "Same phone" / "Same name"
}

// MARK: - Service
class ContactsService {
    static let shared = ContactsService()

    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactIdentifierKey as CNKeyDescriptor,
    ]

    func requestAccess(completion: @escaping (Bool) -> Void) {
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func fetchAll(completion: @escaping ([ContactItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let store   = CNContactStore()
            let request = CNContactFetchRequest(keysToFetch: self.keysToFetch)
            var items: [ContactItem] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                items.append(ContactItem(id: contact.identifier, contact: contact))
            }
            DispatchQueue.main.async { completion(items.sorted { $0.displayName < $1.displayName }) }
        }
    }

    // ── Duplicates: same phone OR same name ─────────────────────────────────
    func findDuplicates(_ all: [ContactItem]) -> [ContactGroup] {
        var phoneMap: [String: [ContactItem]] = [:]
        var nameMap:  [String: [ContactItem]] = [:]

        for item in all {
            // Normalize phone: digits only
            for ph in item.contact.phoneNumbers {
                let digits = ph.value.stringValue.filter { $0.isNumber }
                if digits.count >= 7 {
                    let key = String(digits.suffix(10))
                    phoneMap[key, default: []].append(item)
                }
            }
            // Normalize name
            let name = item.fullName.lowercased().trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { nameMap[name, default: []].append(item) }
        }

        var used   = Set<String>()
        var groups = [ContactGroup]()

        // Phone duplicates first
        for (_, contacts) in phoneMap where contacts.count >= 2 {
            let ids = contacts.map(\.id)
            if ids.allSatisfy({ used.contains($0) }) { continue }
            ids.forEach { used.insert($0) }
            groups.append(ContactGroup(contacts: contacts.sorted { $0.displayName < $1.displayName },
                                       matchReason: "Same phone number"))
        }
        // Name duplicates
        for (_, contacts) in nameMap where contacts.count >= 2 {
            let newOnes = contacts.filter { !used.contains($0.id) }
            if newOnes.count < 2 { continue }
            newOnes.forEach { used.insert($0.id) }
            groups.append(ContactGroup(contacts: newOnes.sorted { $0.displayName < $1.displayName },
                                       matchReason: "Same name"))
        }
        return groups.sorted { $0.contacts.count > $1.contacts.count }
    }

    // ── Incomplete: missing name OR phone ───────────────────────────────────
    func findIncomplete(_ all: [ContactItem]) -> [ContactItem] {
        all.filter { !$0.hasName || !$0.hasPhone }
    }

    // ── Delete contacts ──────────────────────────────────────────────────────
    func delete(_ ids: Set<String>, completion: @escaping (Bool, Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let store   = CNContactStore()
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
            request.predicate = CNContact.predicateForContacts(withIdentifiers: Array(ids))
            var toDelete: [CNMutableContact] = []
            try? store.enumerateContacts(with: request) { c, _ in
                if let m = c.mutableCopy() as? CNMutableContact { toDelete.append(m) }
            }
            let saveReq = CNSaveRequest()
            toDelete.forEach { saveReq.delete($0) }
            let success = (try? store.execute(saveReq)) != nil
            DispatchQueue.main.async { completion(success, toDelete.count) }
        }
    }
}

// MARK: - Main Contacts Hub View
struct ContactsHubView: View {
    @State private var selectedTab: ContactTab = .duplicate
    @StateObject private var vm = ContactsViewModel()

    enum ContactTab: String, CaseIterable {
        case duplicate   = "Duplicate"
        case incomplete  = "Incomplete"
        case all         = "All"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Total count bar
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("\(vm.allContacts.count)").font(.title2).bold().foregroundColor(.purple)
                        Text("Total").font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 36)
                    VStack(spacing: 2) {
                        Text("\(vm.duplicateGroups.flatMap(\.contacts).count)").font(.title2).bold().foregroundColor(.red)
                        Text("Duplicates").font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 36)
                    VStack(spacing: 2) {
                        Text("\(vm.incompleteContacts.count)").font(.title2).bold().foregroundColor(.orange)
                        Text("Incomplete").font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))

                // Segment picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(ContactTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 8)

                if vm.isLoading {
                    ScanningView(text: "Loading contacts…", progress: 0)
                } else {
                    switch selectedTab {
                    case .duplicate:  DuplicateContactsView(vm: vm)
                    case .incomplete: IncompleteContactsView(vm: vm)
                    case .all:        AllContactsView(vm: vm)
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") { vm.load() }
                }
            }
            .onAppear { vm.load() }
        }
    }
}

// MARK: - ViewModel (shared across all tabs)
@MainActor
class ContactsViewModel: ObservableObject {
    @Published var allContacts:      [ContactItem]   = []
    @Published var duplicateGroups:  [ContactGroup]  = []
    @Published var incompleteContacts: [ContactItem] = []
    @Published var isLoading         = false
    @Published var toastMessage:     String?

    func load() {
        isLoading = true
        ContactsService.shared.requestAccess { [weak self] granted in
            guard granted else { self?.isLoading = false; return }
            ContactsService.shared.fetchAll { [weak self] all in
                guard let self else { return }
                self.allContacts        = all
                self.duplicateGroups    = ContactsService.shared.findDuplicates(all)
                self.incompleteContacts = ContactsService.shared.findIncomplete(all)
                self.isLoading          = false
            }
        }
    }

    func delete(_ ids: Set<String>, completion: @escaping () -> Void) {
        ContactsService.shared.delete(ids) { [weak self] success, count in
            if success {
                self?.allContacts.removeAll        { ids.contains($0.id) }
                self?.incompleteContacts.removeAll { ids.contains($0.id) }
                self?.duplicateGroups = self?.duplicateGroups.compactMap { g in
                    let rem = g.contacts.filter { !ids.contains($0.id) }
                    return rem.count >= 2 ? ContactGroup(contacts: rem, matchReason: g.matchReason) : nil
                } ?? []
                self?.toast("✅ Deleted \(count) contacts")
            }
            completion()
        }
    }

    func toast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.toastMessage = nil }
    }
}

// MARK: - 1. Duplicate Contacts View
struct DuplicateContactsView: View {
    @ObservedObject var vm: ContactsViewModel
    @State private var selectedIDs   = Set<String>()
    @State private var showDeleteAlert = false

    var totalSelected: Int { selectedIDs.count }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Summary + actions bar
                HStack {
                    Text("\(vm.duplicateGroups.count) groups · \(vm.duplicateGroups.flatMap(\.contacts).count) contacts")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if !selectedIDs.isEmpty {
                        Button("Delete (\(selectedIDs.count))") { showDeleteAlert = true }
                            .font(.caption).bold().foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.red).clipShape(Capsule())
                    }
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                if vm.duplicateGroups.isEmpty {
                    EmptyStateView(icon: "person.2.fill", title: "No Duplicates",
                                   subtitle: "All contacts are unique!",
                                   buttonTitle: "Refresh") { vm.load() }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(vm.duplicateGroups) { group in
                                DuplicateContactGroupCard(group: group, selectedIDs: $selectedIDs)
                            }
                        }
                        .padding()
                    }
                }
            }

            // Toast
            if let msg = vm.toastMessage {
                VStack { Spacer(); ToastView(message: msg).padding(.bottom, 20) }
                    .animation(.spring(), value: vm.toastMessage)
            }
        }
        .alert("Delete \(selectedIDs.count) Contacts?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                vm.delete(selectedIDs) { selectedIDs = [] }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .onAppear { autoSelectDuplicates() }
        .onChange(of: vm.duplicateGroups.count) { _ in autoSelectDuplicates() }
    }

    private func autoSelectDuplicates() {
        selectedIDs = []
        for g in vm.duplicateGroups {
            for c in g.contacts.dropFirst() { selectedIDs.insert(c.id) }
        }
    }
}

struct DuplicateContactGroupCard: View {
    let group: ContactGroup
    @Binding var selectedIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.2.fill").foregroundColor(.red).font(.caption)
                Text(group.matchReason).font(.caption).bold().foregroundColor(.red)
                Spacer()
                Text("\(group.contacts.count) contacts").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()

            ForEach(Array(group.contacts.enumerated()), id: \.element.id) { idx, contact in
                let isSelected = selectedIDs.contains(contact.id)
                let isKeep     = idx == 0

                HStack(spacing: 12) {
                    // Avatar
                    ContactAvatar(contact: contact, size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(contact.displayName).font(.subheadline).bold()
                            if isKeep {
                                Text("KEEP").font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.green).clipShape(Capsule())
                            }
                        }
                        if !contact.phone.isEmpty {
                            Label(contact.phone, systemImage: "phone.fill")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        if !contact.email.isEmpty {
                            Label(contact.email, systemImage: "envelope.fill")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Checkbox
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.red : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 26, height: 26)
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 18, height: 18)
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .onTapGesture {
                        if isSelected { selectedIDs.remove(contact.id) }
                        else { selectedIDs.insert(contact.id) }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isSelected ? Color.red.opacity(0.05) : Color.clear)

                if idx < group.contacts.count - 1 { Divider().padding(.leading, 70) }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 2. Incomplete Contacts View
struct IncompleteContactsView: View {
    @ObservedObject var vm: ContactsViewModel
    @State private var selectedIDs    = Set<String>()
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Bar
                HStack {
                    Text("\(vm.incompleteContacts.count) incomplete contacts")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 10) {
                        Button(selectedIDs.count == vm.incompleteContacts.count ? "Deselect All" : "Select All") {
                            if selectedIDs.count == vm.incompleteContacts.count { selectedIDs = [] }
                            else { selectedIDs = Set(vm.incompleteContacts.map(\.id)) }
                        }.font(.caption).foregroundColor(.purple)

                        if !selectedIDs.isEmpty {
                            Button("Delete (\(selectedIDs.count))") { showDeleteAlert = true }
                                .font(.caption).bold().foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Color.red).clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                if vm.incompleteContacts.isEmpty {
                    EmptyStateView(icon: "person.fill.checkmark", title: "All Complete!",
                                   subtitle: "All contacts have name and phone",
                                   buttonTitle: "Refresh") { vm.load() }
                } else {
                    List {
                        ForEach(vm.incompleteContacts) { contact in
                            ContactRow(
                                contact: contact,
                                isSelected: selectedIDs.contains(contact.id),
                                badge: incompleteReason(contact)
                            ) {
                                if selectedIDs.contains(contact.id) { selectedIDs.remove(contact.id) }
                                else { selectedIDs.insert(contact.id) }
                            }
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
        .alert("Delete \(selectedIDs.count) Contacts?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                vm.delete(selectedIDs) { selectedIDs = [] }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }

    private func incompleteReason(_ c: ContactItem) -> String {
        if !c.hasName && !c.hasPhone { return "No name & phone" }
        if !c.hasName  { return "No name" }
        if !c.hasPhone { return "No phone" }
        return ""
    }
}

// MARK: - 3. All Contacts View
struct AllContactsView: View {
    @ObservedObject var vm: ContactsViewModel
    @State private var selectedIDs    = Set<String>()
    @State private var showDeleteAlert = false
    @State private var searchText     = ""

    var filtered: [ContactItem] {
        searchText.isEmpty ? vm.allContacts
            : vm.allContacts.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.phone.contains(searchText)
            }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Bar
                HStack {
                    Text("\(filtered.count) contacts").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 10) {
                        Button(selectedIDs.count == filtered.count ? "Deselect All" : "Select All") {
                            if selectedIDs.count == filtered.count { selectedIDs = [] }
                            else { selectedIDs = Set(filtered.map(\.id)) }
                        }.font(.caption).foregroundColor(.purple)

                        if !selectedIDs.isEmpty {
                            Button("Delete (\(selectedIDs.count))") { showDeleteAlert = true }
                                .font(.caption).bold().foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Color.red).clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                List {
                    ForEach(filtered) { contact in
                        ContactRow(
                            contact: contact,
                            isSelected: selectedIDs.contains(contact.id),
                            badge: nil
                        ) {
                            if selectedIDs.contains(contact.id) { selectedIDs.remove(contact.id) }
                            else { selectedIDs.insert(contact.id) }
                        }
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search contacts")
            }

            if let msg = vm.toastMessage {
                VStack { Spacer(); ToastView(message: msg).padding(.bottom, 20) }
                    .animation(.spring(), value: vm.toastMessage)
            }
        }
        .alert("Delete \(selectedIDs.count) Contacts?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                vm.delete(selectedIDs) { selectedIDs = [] }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
    }
}

// MARK: - Shared Contact Row
struct ContactRow: View {
    let contact: ContactItem
    let isSelected: Bool
    let badge: String?
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(contact: contact, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.displayName).font(.subheadline).bold()
                    if let b = badge, !b.isEmpty {
                        Text(b).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange).clipShape(Capsule())
                    }
                }
                if !contact.phone.isEmpty {
                    Text(contact.phone).font(.caption).foregroundColor(.secondary)
                } else {
                    Text("No phone").font(.caption).foregroundColor(.red.opacity(0.7))
                }
                if !contact.email.isEmpty {
                    Text(contact.email).font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.red : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 26, height: 26)
                if isSelected {
                    RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 18, height: 18)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.red.opacity(0.05) : Color(.secondarySystemBackground)))
        .onTapGesture { onTap() }
    }
}

// MARK: - Contact Avatar
struct ContactAvatar: View {
    let contact: ContactItem
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [avatarColor, avatarColor.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)

            if let data = contact.contact.thumbnailImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(contact.initials)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.purple, .blue, .green, .orange, .pink, .teal, .indigo]
        let idx = abs(contact.displayName.hashValue) % colors.count
        return colors[idx]
    }
}
