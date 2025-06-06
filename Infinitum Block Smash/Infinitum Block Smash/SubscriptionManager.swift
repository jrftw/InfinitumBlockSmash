import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var purchasedProducts: Set<String> = []
    @Published private(set) var trialEndDate: Date = Date.distantPast
    
    private var updateListenerTask: Task<Void, Error>?
    private let trialUsageKey = "hasUsedTrial"
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    var hasUsedTrial: Bool {
        UserDefaults.standard.bool(forKey: trialUsageKey)
    }
    
    private func markTrialAsUsed() {
        UserDefaults.standard.set(true, forKey: trialUsageKey)
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Add to purchased products
            purchasedProducts.insert(transaction.productID)
            
            // Update trial end date if this is a new purchase
            if !hasUsedTrial {
                trialEndDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
                markTrialAsUsed()
            }
            
            // Finish the transaction
            await transaction.finish()
            
        case .unverified:
            // Handle unverified transaction
            break
        }
    }
    
    func loadProducts() async {
        isLoading = true
        error = nil
        
        do {
            let products = try await Product.products(for: [
                "com.infinitum.blocksmash.unlimitedundos",
                "com.infinitum.blocksmash.hints",
                "com.infinitum.blocksmash.noads"
            ])
            
            // Store products for later use
            self.subscriptions = products
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func purchase(_ product: Product) async throws {
        // Check if user has already used their trial
        if hasUsedTrial {
            throw SubscriptionError.trialAlreadyUsed
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            await handleTransactionResult(verification)
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }
    
    func updatePurchasedProducts() async {
        purchasedSubscriptions.removeAll()
        purchasedProducts.removeAll()
        
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                purchasedProducts.insert(transaction.productID)
            case .unverified:
                continue
            }
        }
    }
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    var hasActiveSubscription: Bool {
        !purchasedSubscriptions.isEmpty
    }
    
    var isInTrialPeriod: Bool {
        return Date() < trialEndDate
    }
    
    func getTrialDaysRemaining() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: trialEndDate)
        return max(0, components.day ?? 0)
    }
    
    func hasFeature(_ feature: SubscriptionFeature) async -> Bool {
        // Update purchased products first
        await updatePurchasedProducts()
        
        // If in trial period, grant access to all features
        if isInTrialPeriod {
            return true
        }
        
        // Check if user has purchased the feature
        return purchasedProducts.contains { product in
            switch feature {
            case .unlimitedUndos:
                return product == "com.infinitum.blocksmash.unlimitedundos"
            case .hints:
                return product == "com.infinitum.blocksmash.hints"
            case .noAds:
                return product == "com.infinitum.blocksmash.noads"
            }
        }
    }
    
    func getSubscriptionTier() async -> SubscriptionTier {
        // Update purchased products first
        await updatePurchasedProducts()
        
        // If in trial period, return the highest tier
        if isInTrialPeriod {
            return .premium
        }
        
        // Check for premium features
        let hasUnlimitedUndos = purchasedProducts.contains("com.infinitum.blocksmash.unlimitedundos")
        let hasHints = purchasedProducts.contains("com.infinitum.blocksmash.hints")
        let hasNoAds = purchasedProducts.contains("com.infinitum.blocksmash.noads")
        
        if hasUnlimitedUndos && hasHints && hasNoAds {
            return .premium
        } else if hasUnlimitedUndos || hasHints || hasNoAds {
            return .basic
        } else {
            return .none
        }
    }
}

enum SubscriptionFeature {
    case unlimitedUndos
    case hints
    case noAds
}

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    case trialAlreadyUsed
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Failed to verify the purchase. Please try again."
        case .userCancelled:
            return "Purchase was cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .unknown:
            return "An unknown error occurred. Please try again."
        case .trialAlreadyUsed:
            return "You have already used your free trial. Please choose a subscription plan to continue."
        }
    }
}

enum SubscriptionTier {
    case premium
    case basic
    case none
} 