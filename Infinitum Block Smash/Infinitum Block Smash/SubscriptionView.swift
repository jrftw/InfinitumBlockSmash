import SwiftUI
import StoreKit

struct SubscriptionPlan: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let features: [String]
    let weeklyPrice: Double
    let monthlyPrice: Double
    let yearlyPrice: Double
    let description: String
    let productId: String
    let trialPeriod: String = "3-day free trial"
}

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: SubscriptionPlan?
    @State private var selectedDuration: String = "monthly"
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showTrialInfo = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    let plans = [
        SubscriptionPlan(
            name: "Smash Pass",
            color: .blue,
            features: ["Remove Ads"],
            weeklyPrice: 2.49,
            monthlyPrice: 4.49,
            yearlyPrice: 29.99,
            description: "Perfect for casual players looking for a cleaner experience.",
            productId: "com.infinitum.blocksmash.pass"
        ),
        SubscriptionPlan(
            name: "Smash+",
            color: .green,
            features: ["Remove Ads", "Unlimited Hints"],
            weeklyPrice: 3.49,
            monthlyPrice: 6.99,
            yearlyPrice: 44.99,
            description: "Ideal for strategic players who love having a hint ready.",
            productId: "com.infinitum.blocksmash.plus"
        ),
        SubscriptionPlan(
            name: "Smash Elite",
            color: .red,
            features: ["Remove Ads", "Unlimited Hints", "Unlimited Undos"],
            weeklyPrice: 5.99,
            monthlyPrice: 9.99,
            yearlyPrice: 69.99,
            description: "For the hardcore pros who demand unlimited control.",
            productId: "com.infinitum.blocksmash.elite"
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("🧱 Block Smash Subscriptions")
                    .font(.title)
                    .fontWeight(.bold)
                
                if subscriptionManager.hasUsedTrial {
                    Text("Choose your subscription plan to continue enjoying premium features 👇")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Start with a 3-day free trial and unlock exclusive features. Choose your plan below 👇")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                ForEach(plans) { plan in
                    SubscriptionPlanCard(
                        plan: plan,
                        isSelected: selectedPlan?.id == plan.id,
                        selectedDuration: $selectedDuration,
                        onSelect: { selectedPlan = plan }
                    )
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("💡 Why Subscribe?")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Enjoy a seamless, uninterrupted experience")
                        BulletPoint("Access power features that make every move count")
                        BulletPoint("Support the continued development of Block Smash")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("⚠️ Subscription Info:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if !subscriptionManager.hasUsedTrial {
                            BulletPoint("Start with a 3-day free trial")
                            BulletPoint("After trial, subscription auto-renews at the selected price")
                            BulletPoint("Cancel anytime during the trial to avoid charges")
                        } else {
                            BulletPoint("Subscription auto-renews at the selected price")
                            BulletPoint("Cancel anytime to stop future charges")
                        }
                        BulletPoint("Manage or cancel subscriptions in your account settings")
                        BulletPoint("No refunds for unused time")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                VStack(spacing: 16) {
                    Button(action: {
                        if subscriptionManager.hasUsedTrial {
                            Task {
                                await handlePurchase()
                            }
                        } else {
                            showTrialInfo = true
                        }
                    }) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(subscriptionManager.hasUsedTrial ? "Subscribe Now" : "Start Free Trial")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedPlan?.color ?? .gray)
                    .cornerRadius(12)
                    .disabled(selectedPlan == nil || isPurchasing)
                    
                    Button(action: {
                        Task {
                            await handleRestorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .foregroundColor(.blue)
                    }
                    .disabled(isPurchasing)
                }
                .padding()
                
                // Legal Links
                HStack(spacing: 20) {
                    Button("Terms of Service") {
                        showTerms = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Privacy Policy") {
                        showPrivacy = true
                    }
                    .foregroundColor(.blue)
                }
                .font(.footnote)
                .padding(.bottom)
            }
            .padding()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(subscriptionManager.hasUsedTrial ? "Your subscription has been activated successfully!" : "Your free trial has started! Enjoy your premium features.")
        }
        .alert("Start Free Trial", isPresented: $showTrialInfo) {
            Button("Cancel", role: .cancel) { }
            Button("Start Trial") {
                Task {
                    await handlePurchase()
                }
            }
        } message: {
            Text("Your 3-day free trial will start now. After the trial period, you'll be charged \(getPriceText()) automatically. You can cancel anytime during the trial to avoid charges. By starting the trial, you agree to our Terms of Service and Privacy Policy.")
        }
        .sheet(isPresented: $showTerms) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Service")
                            .font(.title)
                            .padding(.bottom)
                        
                        Group {
                            Text("Subscription Terms")
                                .font(.headline)
                            Text("• Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period")
                            Text("• Your account will be charged for renewal within 24 hours prior to the end of the current period")
                            Text("• You can manage and cancel your subscriptions by going to your account settings on the App Store")
                            Text("• Any unused portion of a free trial period will be forfeited when purchasing a subscription")
                        }
                        
                        Group {
                            Text("Cancellation")
                                .font(.headline)
                                .padding(.top)
                            Text("• You can cancel your subscription at any time")
                            Text("• Cancellation will take effect at the end of the current billing period")
                            Text("• No refunds will be provided for unused time")
                        }
                    }
                    .padding()
                }
                .navigationBarItems(trailing: Button("Done") {
                    showTerms = false
                })
            }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy Policy")
                            .font(.title)
                            .padding(.bottom)
                        
                        Group {
                            Text("Data Collection")
                                .font(.headline)
                            Text("• We collect minimal data necessary to provide our services")
                            Text("• Subscription information is processed securely through Apple's systems")
                            Text("• We do not share your personal information with third parties")
                        }
                        
                        Group {
                            Text("Subscription Data")
                                .font(.headline)
                                .padding(.top)
                            Text("• Subscription status is stored locally on your device")
                            Text("• Trial usage is tracked to prevent abuse")
                            Text("• You can request deletion of your data at any time")
                        }
                    }
                    .padding()
                }
                .navigationBarItems(trailing: Button("Done") {
                    showPrivacy = false
                })
            }
        }
        .task {
            await subscriptionManager.loadProducts()
        }
    }
    
    private func getPriceText() -> String {
        guard let plan = selectedPlan else { return "" }
        switch selectedDuration {
        case "weekly":
            return "$\(String(format: "%.2f", plan.weeklyPrice))/week"
        case "monthly":
            return "$\(String(format: "%.2f", plan.monthlyPrice))/month"
        case "yearly":
            return "$\(String(format: "%.2f", plan.yearlyPrice))/year"
        default:
            return ""
        }
    }
    
    private func handlePurchase() async {
        guard let plan = selectedPlan else { return }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let productId = "\(plan.productId).\(selectedDuration)"
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
    
    private func handleRestorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await subscriptionManager.restorePurchases()
            if subscriptionManager.hasActiveSubscription {
                showSuccess = true
            } else {
                errorMessage = "No active subscriptions found to restore."
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    @Binding var selectedDuration: String
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(plan.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(plan.color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(plan.color)
                        Text(feature)
                    }
                }
            }
            
            Picker("Duration", selection: $selectedDuration) {
                Text("Weekly").tag("weekly")
                Text("Monthly").tag("monthly")
                Text("Yearly").tag("yearly")
            }
            .pickerStyle(.segmented)
            
            HStack {
                Text(getPrice(for: selectedDuration))
                    .font(.title3)
                    .fontWeight(.bold)
                
                if selectedDuration == "yearly" {
                    Text("(Best Value — Save \(getSavings())%)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Text(plan.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? plan.color : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onSelect)
    }
    
    private func getPrice(for duration: String) -> String {
        switch duration {
        case "weekly":
            return "$\(String(format: "%.2f", plan.weeklyPrice))/week"
        case "monthly":
            return "$\(String(format: "%.2f", plan.monthlyPrice))/month"
        case "yearly":
            return "$\(String(format: "%.2f", plan.yearlyPrice))/year"
        default:
            return ""
        }
    }
    
    private func getSavings() -> Int {
        let yearlyTotal = plan.yearlyPrice
        let monthlyTotal = plan.monthlyPrice * 12
        let savings = ((monthlyTotal - yearlyTotal) / monthlyTotal) * 100
        return Int(round(savings))
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text("•")
                .padding(.trailing, 4)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SubscriptionView()
} 