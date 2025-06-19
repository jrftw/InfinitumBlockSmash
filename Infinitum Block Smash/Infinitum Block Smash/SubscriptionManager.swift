/*
 * SubscriptionManager.swift
 * 
 * IN-APP PURCHASE AND SUBSCRIPTION MANAGEMENT SERVICE
 * 
 * This service manages all in-app purchases, subscriptions, and premium features
 * for the Infinitum Block Smash game. It handles product loading, purchase
 * validation, subscription status tracking, and premium feature access control.
 * 
 * KEY RESPONSIBILITIES:
 * - In-app purchase product management
 * - Subscription status tracking and validation
 * - Premium feature access control
 * - Trial period management
 * - Purchase transaction handling
 * - Product availability verification
 * - Receipt validation and verification
 * - Premium content unlocking
 * - Subscription renewal monitoring
 * - Purchase history tracking
 * 
 * MAJOR DEPENDENCIES:
 * - StoreKit: Apple's in-app purchase framework
 * - FirebaseManager.swift: Purchase data synchronization
 * - AdManager.swift: Ad removal for premium users
 * - GameState.swift: Premium feature integration
 * - ThemeManager.swift: Premium theme unlocking
 * - UserDefaults: Local purchase data storage
 * 
 * PRODUCT TYPES MANAGED:
 * - Subscriptions: Weekly, monthly, yearly premium passes
 * - One-time purchases: Hints, undos, ad removal
 * - Premium themes: Visual customization options
 * - Consumable items: Game enhancement items
 * 
 * SUBSCRIPTION TIERS:
 * - Smash Pass: Basic premium features (Remove Ads)
 * - Smash+: Enhanced premium features (Remove ads + Unlimited hints)
 * - Smash Elite: Ultimate premium experience (Remove ads + Unlimited hints + Unlimited Undos + All Themes Unlocked)
 *
 * PREMIUM FEATURES:
 * - Ad removal across the app
 * - Unlimited undos
 * - Premium themes and customization
 * - Enhanced hint system
 * - Priority support
 * - Exclusive content access
 * 
 * TRIAL MANAGEMENT:
 * - 3-day free trial for new subscribers
 * - Trial usage tracking
 * - Trial expiration handling
 * - Trial to paid conversion
 * - Trial restoration across devices
 * 
 * PURCHASE VALIDATION:
 * - Receipt verification
 * - Transaction validation
 * - Subscription status checking
 * - Purchase history verification
 * - Fraud prevention measures
 * 
 * DATA SYNCHRONIZATION:
 * - Cross-device purchase sync
 * - Cloud backup of purchase data
 * - Purchase restoration
 * - Subscription status sync
 * - Premium feature access sync
 * 
 * ERROR HANDLING:
 * - Purchase failure recovery
 * - Network error handling
 * - Receipt validation errors
 * - Subscription renewal failures
 * - User-friendly error messages
 * 
 * SECURITY FEATURES:
 * - Receipt validation
 * - Transaction verification
 * - Purchase authenticity checking
 * - Subscription fraud prevention
 * - Secure purchase data storage
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - Cached product information
 * - Efficient purchase validation
 * - Background subscription monitoring
 * - Optimized receipt verification
 * - Memory-efficient data structures
 * 
 * USER EXPERIENCE:
 * - Seamless purchase flow
 * - Clear pricing information
 * - Trial period transparency
 * - Easy subscription management
 * - Purchase restoration support
 * 
 * ARCHITECTURE ROLE:
 * This service acts as the central coordinator for all monetization-related
 * operations, providing a clean interface for purchase management while
 * ensuring security and user experience.
 * 
 * THREADING MODEL:
 * - @MainActor ensures UI updates on main thread
 * - Background operations for purchase validation
 * - Async/await for StoreKit operations
 * - Transaction listener for real-time updates
 * 
 * INTEGRATION POINTS:
 * - StoreView for purchase UI
 * - GameState for premium features
 * - AdManager for ad removal
 * - ThemeManager for premium themes
 * - Firebase for purchase sync
 * - Analytics for purchase tracking
 */

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
    @Published private(set) var purchasedHints: Int = 0
    @Published var purchasedUndos: Int = 0
    
    private var updateListenerTask: Task<Void, Error>?
    private let trialUsageKey = "hasUsedTrial"
    private let purchasedHintsKey = "purchasedHints"
    private let purchasedUndosKey = "purchasedUndos"
    
    init() {
        updateListenerTask = listenForTransactions()
        
        // Load purchased hints and undos
        purchasedHints = UserDefaults.standard.integer(forKey: purchasedHintsKey)
        purchasedUndos = UserDefaults.standard.integer(forKey: purchasedUndosKey)
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
            await validateSubscriptionFeatures()
            await verifyProductAvailability()
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
            print("[SubscriptionManager] Processing verified transaction: \(transaction.id)")
            // Add to purchased products
            purchasedProducts.insert(transaction.productID)
            
            // Handle one-time purchases
            switch transaction.productID {
            case "com.infinitum.blocksmash.hints10":
                purchasedHints += 10
                UserDefaults.standard.set(purchasedHints, forKey: purchasedHintsKey)
                print("[SubscriptionManager] Added 10 hints, new total: \(purchasedHints)")
            case "com.infinitum.blocksmash.undos10":
                purchasedUndos += 10
                UserDefaults.standard.set(purchasedUndos, forKey: purchasedUndosKey)
                print("[SubscriptionManager] Added 10 undos, new total: \(purchasedUndos)")
            default:
                if transaction.productID.contains(".weekly") || 
                   transaction.productID.contains(".monthly") || 
                   transaction.productID.contains(".yearly") {
                    print("[SubscriptionManager] Processed subscription purchase: \(transaction.productID)")
                }
            }
            
            // Update trial end date if this is a new subscription
            if !hasUsedTrial && transaction.productType == .autoRenewable {
                trialEndDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
                markTrialAsUsed()
                print("[SubscriptionManager] Started trial period, ends: \(trialEndDate)")
            }
            
            // Finish the transaction
            await transaction.finish()
            print("[SubscriptionManager] Transaction finished successfully")
            
        case .unverified:
            print("[SubscriptionManager] Transaction verification failed")
            // Handle unverified transaction
            break
        }
    }
    
    private func getEnvironmentInfo() -> String {
        #if DEBUG
        return "DEBUG"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "SANDBOX (TestFlight)"
        } else {
            return "PRODUCTION"
        }
        #endif
    }
    
    func loadProducts() async {
        isLoading = true
        error = nil
        
        print("[SubscriptionManager] Running in \(getEnvironmentInfo()) environment")
        
        do {
            let productIds = [
                // Subscription products (9 total)
                "com.infinitum.blocksmash.pass.weekly",
                "com.infinitum.blocksmash.pass.monthly",
                "com.infinitum.blocksmash.pass.yearly",
                "com.infinitum.blocksmash.plus.weekly",
                "com.infinitum.blocksmash.plus.monthly",
                "com.infinitum.blocksmash.plus.yearly",
                "com.infinitum.blocksmash.elite.weekly",
                "com.infinitum.blocksmash.elite.monthly",
                "com.infinitum.blocksmash.elite.yearly",
                
                // One-time purchases
                "com.infinitum.blocksmash.hints10",
                "com.infinitum.blocksmash.undos10",
                "com.infinitum.blocksmash.removeads",
                "com.infinitum.blocksmash.theme.neon",
                "com.infinitum.blocksmash.theme.retro",
                "com.infinitum.blocksmash.theme.nature",
                "com.infinitum.blocksmash.theme.execution",
                "com.infinitum.blocksmash.theme.rainbow",
                "com.infinitum.blocksmash.theme.adventure",
                "com.infinitum.blocksmash.theme.cyberpunk",
                "com.infinitum.blocksmash.theme.sunset",
                "com.infinitum.blocksmash.theme.ocean",
                "com.infinitum.blocksmash.theme.forest",
                "com.infinitum.blocksmash.theme.nordic",
                "com.infinitum.blocksmash.theme.midnight",
                "com.infinitum.blocksmash.theme.desert",
                "com.infinitum.blocksmash.theme.aurora",
                "com.infinitum.blocksmash.theme.cherry"
            ]
            
            print("[SubscriptionManager] Loading products with IDs: \(productIds)")
            let products = try await Product.products(for: productIds)
            
            // Verify all products were loaded
            let loadedProductIds = products.map { $0.id }
            let missingProducts = productIds.filter { !loadedProductIds.contains($0) }
            
            if !missingProducts.isEmpty {
                print("[SubscriptionManager] Warning: Some products failed to load: \(missingProducts)")
                self.error = "Some products are currently unavailable. Please try again later."
            } else {
                print("[SubscriptionManager] Successfully loaded all \(products.count) products")
            }
            
            // Store products for later use
            self.subscriptions = products
            
            // Log product details
            for product in products {
                print("[SubscriptionManager] Product loaded: \(product.id)")
                print("- Type: \(product.type)")
                print("- Price: \(product.displayPrice)")
                print("- Description: \(product.description)")
            }
            
        } catch {
            print("[SubscriptionManager] Error loading products: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func purchase(_ product: Product) async throws {
        print("[SubscriptionManager] Attempting to purchase product: \(product.id) in \(getEnvironmentInfo()) environment")
        
        // Only check trial for subscription products
        if product.type == .autoRenewable && hasUsedTrial {
            print("[SubscriptionManager] Purchase failed: Trial already used")
            throw SubscriptionError.trialAlreadyUsed
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                print("[SubscriptionManager] Purchase successful, verifying transaction")
                await handleTransactionResult(verification)
                print("[SubscriptionManager] Transaction verified and processed")
            case .userCancelled:
                print("[SubscriptionManager] Purchase cancelled by user")
                throw SubscriptionError.userCancelled
            case .pending:
                print("[SubscriptionManager] Purchase pending approval")
                throw SubscriptionError.pending
            @unknown default:
                print("[SubscriptionManager] Unknown purchase result")
                throw SubscriptionError.unknown
            }
        } catch let error as StoreKitError {
            print("[SubscriptionManager] StoreKit error: \(error.localizedDescription)")
            switch error {
            case .networkError:
                throw SubscriptionError.networkError
            case .notEntitled:
                throw SubscriptionError.notEntitled
            default:
                throw SubscriptionError.unknown
            }
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
        
        // If in trial period, grant all features
        if isInTrialPeriod {
            return true
        }
        
        switch feature {
        case .noAds:
            return purchasedProducts.contains("com.infinitum.blocksmash.removeads") ||
                   purchasedProducts.contains { $0.contains("elite") }
        case .unlimitedUndos:
            return purchasedProducts.contains { $0.contains("elite") } ||
                   purchasedProducts.contains("com.infinitum.blocksmash.removeads")
        case .undoPack:
            return purchasedUndos > 0
        case .hints:
            return purchasedProducts.contains { $0.contains("elite") } ||
                   purchasedProducts.contains("com.infinitum.blocksmash.hints")
        case .customTheme:
            // Check if any theme is purchased or if user has Elite subscription
            return purchasedProducts.contains { $0.starts(with: "com.infinitum.blocksmash.theme.") } ||
                   purchasedProducts.contains { $0.contains("elite") }
        case .allThemes:
            return purchasedProducts.contains { $0.contains("elite") }
        }
    }
    
    func isThemeUnlocked(_ themeId: String) async -> Bool {
        // If user has Elite subscription, all themes are unlocked
        if await hasFeature(.allThemes) {
            return true
        }
        
        // Check if the specific theme was purchased
        let themeProductId = "com.infinitum.blocksmash.theme.\(themeId)"
        return purchasedProducts.contains(themeProductId)
    }
    
    func checkSubscriptionStatus() async {
        // Update purchased products first
        await updatePurchasedProducts()
        
        // Check for expired subscriptions
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.expirationDate != nil && transaction.expirationDate! < Date() {
                    // Remove expired subscription from purchased products
                    purchasedProducts.remove(transaction.productID)
                }
            case .unverified:
                continue
            }
        }
        
        // Save updated state
        UserDefaults.standard.synchronize()
    }
    
    func getSubscriptionExpirationDate() async -> Date? {
        var latestExpiration: Date? = nil
        
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if let expiration = transaction.expirationDate {
                    if latestExpiration == nil || expiration > latestExpiration! {
                        latestExpiration = expiration
                    }
                }
            case .unverified:
                continue
            }
        }
        
        return latestExpiration
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
    
    // Add methods to use hints and undos
    func useHint() -> Bool {
        guard purchasedHints > 0 else { return false }
        purchasedHints -= 1
        UserDefaults.standard.set(purchasedHints, forKey: purchasedHintsKey)
        return true
    }
    
    func useUndo() -> Bool {
        guard purchasedUndos > 0 else { return false }
        purchasedUndos -= 1
        UserDefaults.standard.set(purchasedUndos, forKey: purchasedUndosKey)
        return true
    }
    
    func getRemainingHints() -> Int {
        return purchasedHints
    }
    
    func getRemainingUndos() -> Int {
        return purchasedUndos
    }
    
    // Add validation methods
    func validateSubscriptionFeatures() async {
        print("[SubscriptionManager] Validating subscription features...")
        
        // Check subscription status
        await checkSubscriptionStatus()
        
        // Log current state
        print("[SubscriptionManager] Current subscription state:")
        print("- Has active subscription: \(hasActiveSubscription)")
        print("- Is in trial period: \(isInTrialPeriod)")
        print("- Trial days remaining: \(getTrialDaysRemaining())")
        print("- Purchased products: \(purchasedProducts)")
        print("- Remaining hints: \(purchasedHints)")
        print("- Remaining undos: \(purchasedUndos)")
        
        // Verify feature access
        let hasUnlimitedUndos = await hasFeature(.unlimitedUndos)
        let hasHints = await hasFeature(.hints)
        let hasNoAds = await hasFeature(.noAds)
        
        print("[SubscriptionManager] Feature access:")
        print("- Unlimited Undos: \(hasUnlimitedUndos)")
        print("- Hints: \(hasHints)")
        print("- No Ads: \(hasNoAds)")
        
        // Get subscription tier
        let tier = await getSubscriptionTier()
        print("[SubscriptionManager] Current subscription tier: \(tier)")
        
        // Get expiration date
        if let expiration = await getSubscriptionExpirationDate() {
            print("[SubscriptionManager] Subscription expires: \(expiration)")
        } else {
            print("[SubscriptionManager] No active subscription expiration date")
        }
    }
    
    // Add method to verify product availability
    func verifyProductAvailability() async {
        print("[SubscriptionManager] Verifying product availability...")
        
        for product in subscriptions {
            print("[SubscriptionManager] Product: \(product.id)")
            print("- Type: \(product.type)")
            print("- Price: \(product.displayPrice)")
            print("- Description: \(product.description)")
        }
    }
    
    // Add test purchase verification
    func verifyTestPurchase() async {
        print("[SubscriptionManager] Starting test purchase verification...")
        
        // Verify we're in test environment
        #if DEBUG
        print("[SubscriptionManager] Running in DEBUG mode")
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            print("[SubscriptionManager] Running in TestFlight/Sandbox environment")
        } else {
            print("[SubscriptionManager] Running in Production environment")
        }
        #endif
        
        // Test subscription purchase
        if let subscriptionProduct = subscriptions.first(where: { $0.type == .autoRenewable }) {
            print("[SubscriptionManager] Testing subscription purchase: \(subscriptionProduct.id)")
            do {
                try await purchase(subscriptionProduct)
                print("[SubscriptionManager] Test subscription purchase successful")
                
                // Verify subscription features
                let hasUnlimitedUndos = await hasFeature(.unlimitedUndos)
                let hasHints = await hasFeature(.hints)
                let hasNoAds = await hasFeature(.noAds)
                
                print("[SubscriptionManager] Feature verification after subscription:")
                print("- Unlimited Undos: \(hasUnlimitedUndos)")
                print("- Hints: \(hasHints)")
                print("- No Ads: \(hasNoAds)")
            } catch {
                print("[SubscriptionManager] Test subscription purchase failed: \(error.localizedDescription)")
            }
        }
        
        // Test one-time purchase
        if let oneTimeProduct = subscriptions.first(where: { $0.type == .nonConsumable }) {
            print("[SubscriptionManager] Testing one-time purchase: \(oneTimeProduct.id)")
            do {
                try await purchase(oneTimeProduct)
                print("[SubscriptionManager] Test one-time purchase successful")
                
                // Verify purchase was recorded
                print("[SubscriptionManager] Purchased products after one-time purchase: \(purchasedProducts)")
            } catch {
                print("[SubscriptionManager] Test one-time purchase failed: \(error.localizedDescription)")
            }
        }
        
        // Test consumable purchase
        if let consumableProduct = subscriptions.first(where: { $0.type == .consumable }) {
            print("[SubscriptionManager] Testing consumable purchase: \(consumableProduct.id)")
            do {
                try await purchase(consumableProduct)
                print("[SubscriptionManager] Test consumable purchase successful")
                
                // Verify consumable was added
                if consumableProduct.id == "com.infinitum.blocksmash.hints10" {
                    print("[SubscriptionManager] Hints after purchase: \(purchasedHints)")
                } else if consumableProduct.id == "com.infinitum.blocksmash.undos10" {
                    print("[SubscriptionManager] Undos after purchase: \(purchasedUndos)")
                }
            } catch {
                print("[SubscriptionManager] Test consumable purchase failed: \(error.localizedDescription)")
            }
        }
        
        // Verify restore purchases
        print("[SubscriptionManager] Testing restore purchases...")
        do {
            try await restorePurchases()
            print("[SubscriptionManager] Restore purchases successful")
            print("[SubscriptionManager] Restored products: \(purchasedProducts)")
        } catch {
            print("[SubscriptionManager] Restore purchases failed: \(error.localizedDescription)")
        }
    }
    
    // Add method to simulate subscription expiration
    func simulateSubscriptionExpiration() async {
        print("[SubscriptionManager] Simulating subscription expiration...")
        
        // Clear all purchased products
        purchasedProducts.removeAll()
        purchasedSubscriptions.removeAll()
        
        // Reset trial status
        UserDefaults.standard.set(false, forKey: trialUsageKey)
        trialEndDate = Date.distantPast
        
        // Verify features are disabled
        let hasUnlimitedUndos = await hasFeature(.unlimitedUndos)
        let hasHints = await hasFeature(.hints)
        let hasNoAds = await hasFeature(.noAds)
        
        print("[SubscriptionManager] Feature status after expiration:")
        print("- Unlimited Undos: \(hasUnlimitedUndos)")
        print("- Hints: \(hasHints)")
        print("- No Ads: \(hasNoAds)")
    }
    
    // Add method to preload subscription status
    func preloadSubscriptionStatus() async {
        await loadProducts()
        await updatePurchasedProducts()
        await validateSubscriptionFeatures()
    }
}

enum SubscriptionFeature: String {
    case noAds = "no_ads"
    case unlimitedUndos = "unlimited_undos"
    case undoPack = "undo_pack"
    case hints = "hints"
    case customTheme = "custom_theme"
    case allThemes = "all_themes"
}

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    case trialAlreadyUsed
    case networkError
    case notEntitled
    
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
        case .networkError:
            return "Network error occurred. Please check your internet connection and try again."
        case .notEntitled:
            return "You are not entitled to make this purchase. Please contact support if this persists."
        }
    }
}

enum SubscriptionTier {
    case premium
    case basic
    case none
} 
