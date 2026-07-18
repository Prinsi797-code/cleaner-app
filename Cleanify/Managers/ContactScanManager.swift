//
//  ContactScanManager.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import Foundation
import Contacts

struct ContactGroup {
    let key: String
    var contacts: [CNContact]
}

class ContactScanManager {
    
    static let shared = ContactScanManager()
    
    private init() {}
    
    // Cached lists
    var allContacts: [CNContact] = []
    var duplicateNameGroups: [ContactGroup] = []
    var duplicatePhoneGroups: [ContactGroup] = []
    var incompleteContactsList: [CNContact] = []
    
    // MARK: - Persistence
    
    func saveToDisk() {
        let defaults = UserDefaults.standard
        defaults.set(allContacts.map { $0.identifier }, forKey: "ContactScanManager_allContacts")
        defaults.set(duplicateNameGroups.map { ["key": $0.key, "ids": $0.contacts.map { $0.identifier }] }, forKey: "ContactScanManager_duplicateNames")
        defaults.set(duplicatePhoneGroups.map { ["key": $0.key, "ids": $0.contacts.map { $0.identifier }] }, forKey: "ContactScanManager_duplicatePhones")
        defaults.set(incompleteContactsList.map { $0.identifier }, forKey: "ContactScanManager_incomplete")
        defaults.set(true, forKey: "ContactScanManager_hasCachedData")
    }
    
    func loadFromDisk() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "ContactScanManager_hasCachedData") else { return false }
        
        func fetchContacts(for identifiers: [String]) -> [CNContact] {
            let store = CNContactStore()
            let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactImageDataAvailableKey, CNContactThumbnailImageDataKey] as [CNKeyDescriptor]
            do {
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
                let dict = Dictionary(uniqueKeysWithValues: contacts.map { ($0.identifier, $0) })
                return identifiers.compactMap { dict[$0] }
            } catch {
                return []
            }
        }
        
        func fetchGroups(from array: [[String: Any]]) -> [ContactGroup] {
            var groups = [ContactGroup]()
            for dict in array {
                if let key = dict["key"] as? String, let ids = dict["ids"] as? [String] {
                    let contacts = fetchContacts(for: ids)
                    if contacts.count > 1 {
                        groups.append(ContactGroup(key: key, contacts: contacts))
                    }
                }
            }
            return groups
        }
        
        if let allIDs = defaults.stringArray(forKey: "ContactScanManager_allContacts") {
            self.allContacts = fetchContacts(for: allIDs)
        }
        
        if let dupNames = defaults.array(forKey: "ContactScanManager_duplicateNames") as? [[String: Any]] {
            self.duplicateNameGroups = fetchGroups(from: dupNames)
        }
        
        if let dupPhones = defaults.array(forKey: "ContactScanManager_duplicatePhones") as? [[String: Any]] {
            self.duplicatePhoneGroups = fetchGroups(from: dupPhones)
        }
        
        if let incompleteIDs = defaults.stringArray(forKey: "ContactScanManager_incomplete") {
            self.incompleteContactsList = fetchContacts(for: incompleteIDs)
        }
        
        return true
    }
    
    func scanContacts(progressHandler: @escaping (String, Double) -> Void, completion: @escaping () -> Void) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            completion()
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            progressHandler("Loading contacts list...", 0.2)
            
            let store = CNContactStore()
            let keys = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keys)
            var fetchedContacts: [CNContact] = []
            
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    fetchedContacts.append(contact)
                }
            } catch {
                print("Error loading contacts: \(error)")
            }
            
            self.allContacts = fetchedContacts
            
            progressHandler("Grouping duplicates...", 0.5)
            
            self.analyzeDuplicates(contacts: fetchedContacts)
            
            progressHandler("Finalizing contact metrics...", 0.95)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func analyzeDuplicates(contacts: [CNContact]) {
        var nameDict: [String: [CNContact]] = [:]
        var phoneDict: [String: [CNContact]] = [:]
        var tempIncomplete: [CNContact] = []
        
        for contact in contacts {
            let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
            let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check incomplete
            let hasPhone = !contact.phoneNumbers.isEmpty
            let hasEmail = !contact.emailAddresses.isEmpty
            let hasName = !fullName.isEmpty
            
            if !hasName || (!hasPhone && !hasEmail) {
                tempIncomplete.append(contact)
            }
            
            // Group by name
            if hasName {
                let nameKey = fullName.lowercased()
                nameDict[nameKey, default: []].append(contact)
            }
            
            // Group by phone numbers
            for phone in contact.phoneNumbers {
                let digits = cleanPhoneNumber(phone.value.stringValue)
                if digits.count >= 7 { // Ignore short/invalid number segments
                    phoneDict[digits, default: []].append(contact)
                }
            }
        }
        
        
        self.duplicateNameGroups = nameDict.filter { $0.value.count > 1 }
            .map { ContactGroup(key: $0.key.capitalized, contacts: $0.value) }
            .sorted { $0.key < $1.key }
        
        self.duplicatePhoneGroups = phoneDict.filter { $0.value.count > 1 }
            .map { ContactGroup(key: formatPhoneNumberKey($0.key), contacts: $0.value) }
            .sorted { $0.key < $1.key }
        
        self.incompleteContactsList = tempIncomplete
    }
    
    private func cleanPhoneNumber(_ original: String) -> String {
        return original.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    private func formatPhoneNumberKey(_ digits: String) -> String {
        if digits.count == 10 {
            let area = digits.prefix(3)
            let mid = digits.dropFirst(3).prefix(3)
            let end = digits.suffix(4)
            return "(\(area)) \(mid)-\(end)"
        }
        return digits
    }
}
