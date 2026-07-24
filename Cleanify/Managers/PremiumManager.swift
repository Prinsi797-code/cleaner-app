import Foundation
import StoreKit

extension Notification.Name {
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}

@available(iOS 15.0, *)
class PremiumManager {
    static let shared = PremiumManager()
    
    private let premiumStatusKey = "com.princi607.CleanerApp.isPremium"
    
    var isPremium: Bool {
        get {
            return UserDefaults.standard.bool(forKey: premiumStatusKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: premiumStatusKey)
            NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
        }
    }
    
    private let activePlanIDKey = "com.princi607.CleanerApp.activePlanID"
    
    var activePlanID: String? {
        get {
            return UserDefaults.standard.string(forKey: activePlanIDKey)
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: activePlanIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activePlanIDKey)
            }
        }
    }
    
    // Product IDs matching App Store Connect
    static let productIDs = [
        "com.hevin.phonecleaner.weekly",
        "com.hevin.phonecleaner.monthly",
        "com.hevin.phonecleaner.yearly"
    ]
    
    var products: [Product] = []
    private var transactionListener: Task<Void, Error>?
    
    private init() {
        // Start listening to transactions when the app starts
        transactionListener = listenToTransactions()
        
        Task {
            await syncEntitlements()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    func syncEntitlements() async {
        var hasActivePlan = false
        var currentPlanID: String? = nil
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if PremiumManager.productIDs.contains(transaction.productID) {
                    hasActivePlan = true
                    currentPlanID = transaction.productID
                }
            }
        }
        
        await MainActor.run {
            self.activePlanID = currentPlanID
            self.isPremium = hasActivePlan
        }
    }
    
    func fetchProducts() async -> [Product] {
        do {
            let fetchedProducts = try await Product.products(for: PremiumManager.productIDs)
            // Sort by price ascending
            self.products = fetchedProducts.sorted(by: { $0.price < $1.price })
            print("[PremiumManager] Fetched products: \(self.products.map { "\($0.id): \($0.displayPrice)" })")
            return self.products
        } catch {
            print("[PremiumManager] Error fetching products: \(error)")
            return []
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Enable premium access
                    self.isPremium = true
                    self.activePlanID = product.id
                    await transaction.finish()
                    return true
                case .unverified(_, let error):
                    print("[PremiumManager] Purchase unverified: \(error.localizedDescription)")
                    return false
                }
            case .userCancelled:
                print("[PremiumManager] User cancelled purchase")
                return false
            case .pending:
                print("[PremiumManager] Purchase pending")
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[PremiumManager] Purchase failed: \(error)")
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        do {
            var restored = false
            var currentPlanID: String? = nil
            
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if PremiumManager.productIDs.contains(transaction.productID) {
                        restored = true
                        currentPlanID = transaction.productID
                        await transaction.finish()
                    }
                case .unverified:
                    break
                }
            }
            
            await MainActor.run {
                self.activePlanID = currentPlanID
                self.isPremium = restored
            }
            
            return restored
        } catch {
            print("[PremiumManager] Error restoring purchases: \(error)")
            return false
        }
    }
    
    private func listenToTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Active premium found in transaction updates
                    await MainActor.run {
                        self.isPremium = true
                        self.activePlanID = transaction.productID
                    }
                    await transaction.finish()
                case .unverified(_, let error):
                    print("[PremiumManager] Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // For tracking daily photo deletions
    private let dailyDeleteCountKey = "com.princi607.CleanerApp.dailyDeleteCount"
    private let lastDeleteDateKey = "com.princi607.CleanerApp.lastDeleteDate"
    private let maxFreeDailyDeletes = 30
    
    func canDeletePhotos(count: Int) -> Bool {
        if isPremium { return true }
        
        let today = todayString()
        let lastDate = UserDefaults.standard.string(forKey: lastDeleteDateKey) ?? ""
        
        var currentCount = 0
        if lastDate == today {
            currentCount = UserDefaults.standard.integer(forKey: dailyDeleteCountKey)
        } else {
            // New day, reset count
            UserDefaults.standard.set(today, forKey: lastDeleteDateKey)
            UserDefaults.standard.set(0, forKey: dailyDeleteCountKey)
        }
        
        return (currentCount + count) <= maxFreeDailyDeletes
    }
    
    func getRemainingFreeDeletes() -> Int {
        if isPremium { return 99999 }
        
        let today = todayString()
        let lastDate = UserDefaults.standard.string(forKey: lastDeleteDateKey) ?? ""
        
        var currentCount = 0
        if lastDate == today {
            currentCount = UserDefaults.standard.integer(forKey: dailyDeleteCountKey)
        }
        
        return max(0, maxFreeDailyDeletes - currentCount)
    }
    
    func recordDeletions(count: Int) {
        if isPremium { return }
        
        let today = todayString()
        let lastDate = UserDefaults.standard.string(forKey: lastDeleteDateKey) ?? ""
        
        var currentCount = 0
        if lastDate == today {
            currentCount = UserDefaults.standard.integer(forKey: dailyDeleteCountKey)
        } else {
            UserDefaults.standard.set(today, forKey: lastDeleteDateKey)
        }
        
        UserDefaults.standard.set(currentCount + count, forKey: dailyDeleteCountKey)
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
