import SwiftUI

struct StoreView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                // Tab selector
                Picker("Store Section", selection: $selectedTab) {
                    Text("Subscriptions").tag(0)
                    Text("In-App Purchases").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                if selectedTab == 0 {
                    SubscriptionView()
                } else {
                    ThemesView()
                }
                
                #if DEBUG
                // Test buttons (only visible in debug mode)
                VStack(spacing: 10) {
                    Button("Test Purchase Flow") {
                        Task {
                            await subscriptionManager.verifyTestPurchase()
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("Simulate Expiration") {
                        Task {
                            await subscriptionManager.simulateSubscriptionExpiration()
                        }
                    }
                    .foregroundColor(.red)
                }
                .padding()
                #endif
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ThemesView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("One-Time Purchases")
                    .font(.title)
                    .padding(.top)
                
                // 10 Hints Pack
                PurchaseCard(
                    title: "10 Hints Pack",
                    description: "Get 10 additional hints to use after your free ones are up. No ads required!",
                    price: "$0.99",
                    productId: "com.infinitum.blocksmash.hints10",
                    subscriptionManager: subscriptionManager,
                    isPurchasing: $isPurchasing,
                    showError: $showError,
                    errorMessage: $errorMessage,
                    showSuccess: $showSuccess
                )
                
                // 10 Undos Pack
                PurchaseCard(
                    title: "10 Undos Pack",
                    description: "Get 10 additional undos to use after your free ones are up. No ads required!",
                    price: "$0.99",
                    productId: "com.infinitum.blocksmash.undos10",
                    subscriptionManager: subscriptionManager,
                    isPurchasing: $isPurchasing,
                    showError: $showError,
                    errorMessage: $errorMessage,
                    showSuccess: $showSuccess
                )
                
                // Remove Ads Forever
                PurchaseCard(
                    title: "Remove Ads Forever",
                    description: "Never see another ad in the game again!",
                    price: "$99.99",
                    productId: "com.infinitum.blocksmash.removeads",
                    subscriptionManager: subscriptionManager,
                    isPurchasing: $isPurchasing,
                    showError: $showError,
                    errorMessage: $errorMessage,
                    showSuccess: $showSuccess
                )
                
                // Restore Purchases Button
                Button(action: {
                    Task {
                        await handleRestorePurchases()
                    }
                }) {
                    Text("Restore Purchases")
                        .foregroundColor(.blue)
                }
                .disabled(isPurchasing)
                .padding(.top, 20)
            }
            .padding()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Purchase successful! Your items have been added to your account.")
        }
        .task {
            await subscriptionManager.loadProducts()
        }
    }
    
    private func handleRestorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await subscriptionManager.restorePurchases()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct PurchaseCard: View {
    let title: String
    let description: String
    let price: String
    let productId: String
    let subscriptionManager: SubscriptionManager
    @Binding var isPurchasing: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Binding var showSuccess: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(description)
                .foregroundColor(.secondary)
            
            if productId == "com.infinitum.blocksmash.hints10" {
                Text("Remaining: \(subscriptionManager.getRemainingHints())")
                    .foregroundColor(.blue)
            } else if productId == "com.infinitum.blocksmash.undos10" {
                Text("Remaining: \(subscriptionManager.getRemainingUndos())")
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await handlePurchase()
                    }
                }) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Buy")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
                .disabled(isPurchasing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            guard let product = subscriptionManager.subscriptions.first(where: { $0.id == productId }) else {
                throw SubscriptionError.unknown
            }
            
            try await subscriptionManager.purchase(product)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    StoreView()
} 
