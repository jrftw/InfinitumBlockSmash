import SwiftUI

struct StoreView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                        StorePreviewView()
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

struct StorePreviewView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var hasEliteAccess = false
    @State private var selectedSection: StoreSection?
    
    enum StoreSection: String, CaseIterable {
        case themes = "Themes"
        case powerUps = "Power Ups"
        case removeAds = "Remove Ads"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(StoreSection.allCases, id: \.self) { section in
                StoreSectionPreview(
                    section: section,
                    hasEliteAccess: hasEliteAccess,
                    themeManager: themeManager,
                    subscriptionManager: subscriptionManager
                )
                .onTapGesture {
                    selectedSection = section
                }
            }
        }
        .padding()
        .sheet(item: $selectedSection) { section in
            NavigationView {
                StoreSectionDetail(
                    section: section,
                    hasEliteAccess: hasEliteAccess,
                    themeManager: themeManager,
                    subscriptionManager: subscriptionManager
                )
            }
        }
        .task {
            hasEliteAccess = await subscriptionManager.hasFeature(.customTheme)
        }
    }
}

struct StoreSectionPreview: View {
    let section: StorePreviewView.StoreSection
    let hasEliteAccess: Bool
    let themeManager: ThemeManager
    let subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if section == .themes && hasEliteAccess {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Elite Access")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            
            // Preview content based on section
            switch section {
            case .themes:
                ThemePreviewGrid(themeManager: themeManager, hasEliteAccess: hasEliteAccess)
            case .powerUps:
                PowerUpsPreview(subscriptionManager: subscriptionManager)
            case .removeAds:
                RemoveAdsPreview(subscriptionManager: subscriptionManager)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct ThemePreviewGrid: View {
    let themeManager: ThemeManager
    let hasEliteAccess: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(Array(themeManager.getAvailableThemes().keys.sorted().prefix(4)), id: \.self) { themeKey in
                if let theme = themeManager.getAvailableThemes()[themeKey] {
                    ThemePreviewCard(theme: theme, isPurchased: hasEliteAccess || theme.isFree)
                }
            }
        }
    }
}

struct ThemePreviewCard: View {
    let theme: Theme
    let isPurchased: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Theme Preview
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(getColor(for: index))
                        .frame(height: 20)
                }
            }
            
            Text(theme.name)
                .font(.caption)
                .foregroundColor(theme.colors.text)
            
            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.colors.primary)
                    .font(.caption)
            } else {
                Text("$0.99")
                    .font(.caption)
                    .foregroundColor(theme.colors.primary)
            }
        }
        .padding(8)
        .background(theme.colors.background)
        .cornerRadius(8)
    }
    
    private func getColor(for index: Int) -> Color {
        switch index {
        case 0: return theme.colors.primary
        case 1: return theme.colors.background
        case 2: return theme.colors.secondary
        case 3: return theme.colors.text
        default: return .clear
        }
    }
}

struct PowerUpsPreview: View {
    let subscriptionManager: SubscriptionManager
    
    var body: some View {
        HStack(spacing: 16) {
            PowerUpPreviewCard(
                title: "Hints",
                icon: "lightbulb.fill",
                count: subscriptionManager.getRemainingHints()
            )
            
            PowerUpPreviewCard(
                title: "Undos",
                icon: "arrow.uturn.backward",
                count: subscriptionManager.getRemainingUndos()
            )
        }
    }
}

struct PowerUpPreviewCard: View {
    let title: String
    let icon: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("\(count)")
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct RemoveAdsPreview: View {
    let subscriptionManager: SubscriptionManager
    
    var body: some View {
        HStack {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundColor(.red)
            
            VStack(alignment: .leading) {
                Text("Remove Ads")
                    .font(.headline)
                Text("Never see another ad")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$99.99")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct StoreSectionDetail: View {
    let section: StorePreviewView.StoreSection
    let hasEliteAccess: Bool
    let themeManager: ThemeManager
    let subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch section {
                case .themes:
                    ThemesView()
                case .powerUps:
                    PowerUpsView()
                case .removeAds:
                    RemoveAdsView()
                }
            }
            .padding()
        }
        .navigationTitle(section.rawValue)
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

// Make StoreSection conform to Identifiable for sheet presentation
extension StorePreviewView.StoreSection: Identifiable {
    var id: String { rawValue }
}

struct ThemesView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var hasEliteAccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Custom Themes Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Themes")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if hasEliteAccess {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Elite Access")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // System Theme (Free)
                    if let systemTheme = themeManager.getAvailableThemes()["system"] {
                        ThemeCard(
                            theme: systemTheme,
                            themeKey: "system",
                            isPurchased: true,
                            isSelected: themeManager.currentTheme == "system",
                            subscriptionManager: subscriptionManager,
                            themeManager: themeManager,
                            isPurchasing: $isPurchasing,
                            showError: $showError,
                            errorMessage: $errorMessage,
                            showSuccess: $showSuccess
                        )
                    }
                    
                    // Custom Themes
                    ForEach(Array(themeManager.getAvailableThemes().keys.sorted()), id: \.self) { themeKey in
                        if themeKey != "system",
                           let theme = themeManager.getAvailableThemes()[themeKey] {
                            ThemeCard(
                                theme: theme,
                                themeKey: themeKey,
                                isPurchased: hasEliteAccess || subscriptionManager.purchasedProducts.contains("com.infinitum.blocksmash.theme.\(themeKey)"),
                                isSelected: themeManager.currentTheme == themeKey,
                                subscriptionManager: subscriptionManager,
                                themeManager: themeManager,
                                isPurchasing: $isPurchasing,
                                showError: $showError,
                                errorMessage: $errorMessage,
                                showSuccess: $showSuccess
                            )
                        }
                    }
                }
                
                // Power Ups Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Power Ups")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
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
                }
                
                // Remove Ads Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remove Ads")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
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
                }
                
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
            hasEliteAccess = await subscriptionManager.hasFeature(.customTheme)
        }
    }
    
    private func handleRestorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await subscriptionManager.restorePurchases()
            hasEliteAccess = await subscriptionManager.hasFeature(.customTheme)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct ThemeCard: View {
    let theme: Theme
    let themeKey: String
    let isPurchased: Bool
    let isSelected: Bool
    let subscriptionManager: SubscriptionManager
    let themeManager: ThemeManager
    @Binding var isPurchasing: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Binding var showSuccess: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(theme.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.text)
                    
                    if theme.isCustom {
                        Text("Custom Theme")
                            .font(.caption)
                            .foregroundColor(theme.colors.text.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.colors.primary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.colors.primary)
                }
            }
            
            // Theme Preview
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(getColor(for: index))
                        .frame(height: 40)
                }
            }
            
            HStack {
                if isPurchased || theme.isFree {
                    Button(action: {
                        themeManager.setTheme(themeKey)
                    }) {
                        Text(isSelected ? "Selected" : "Select")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.gray : theme.colors.primary)
                            .cornerRadius(8)
                    }
                    .disabled(isSelected)
                } else {
                    Button(action: {
                        Task {
                            await handlePurchase()
                        }
                    }) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("$0.99")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 100)
                                .padding(.vertical, 8)
                                .background(theme.colors.primary)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isPurchasing)
                }
            }
        }
        .padding()
        .background(theme.colors.background)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private func getColor(for index: Int) -> Color {
        switch index {
        case 0: return theme.colors.primary
        case 1: return theme.colors.background
        case 2: return theme.colors.secondary
        case 3: return theme.colors.text
        default: return .clear
        }
    }
    
    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let productId = "com.infinitum.blocksmash.theme.\(themeKey)"
            guard let product = subscriptionManager.subscriptions.first(where: { $0.id == productId }) else {
                throw SubscriptionError.unknown
            }
            
            try await subscriptionManager.purchase(product)
            // Update purchased products and check if theme is now unlocked
            await subscriptionManager.updatePurchasedProducts()
            if await subscriptionManager.isThemeUnlocked(themeKey) {
                themeManager.setTheme(themeKey)
                showSuccess = true
            } else {
                errorMessage = "Theme purchase successful but could not be applied. Please try again."
                showError = true
            }
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
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Binding var isPurchasing: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Binding var showSuccess: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text(price)
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button(action: {
                    Task {
                        isPurchasing = true
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
                        isPurchasing = false
                    }
                }) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Purchase")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .disabled(isPurchasing)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PowerUpsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
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
            
            // Current Counts
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.blue)
                    Text("Remaining Hints: \(subscriptionManager.getRemainingHints())")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(.blue)
                    Text("Remaining Undos: \(subscriptionManager.getRemainingUndos())")
                    Spacer()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
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
    }
}

struct RemoveAdsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
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
            
            // Benefits
            VStack(alignment: .leading, spacing: 16) {
                Text("Benefits")
                    .font(.headline)
                
                BenefitRow(icon: "infinity", text: "Unlimited Hints")
                BenefitRow(icon: "infinity", text: "Unlimited Undos")
                BenefitRow(icon: "paintpalette.fill", text: "All Themes Unlocked")
                BenefitRow(icon: "xmark.circle.fill", text: "No Ads")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Purchase successful! Ads have been removed from your game.")
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
            Spacer()
        }
    }
}

#Preview {
    StoreView()
} 
