import SwiftUI

struct StoreView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    
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
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("None Availabe")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding(.top, 50)
                
                Text("No purchases available at this time")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    StoreView()
} 
