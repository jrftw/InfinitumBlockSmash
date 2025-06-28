import SwiftUI
import Foundation

struct UpdatePromptView: View {
    let isTestFlight: Bool
    let isEmergency: Bool
    
    @Environment(\.dismiss) var dismiss
    @State private var showingAppStore = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: isEmergency ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isEmergency ? .red : .blue)
                
                Text(isEmergency ? "Emergency Update Required" : "Update Available")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(getUpdateMessage())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if isEmergency {
                    Text("This update is required to continue using the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    openAppStore()
                }) {
                    Text("Update Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEmergency ? Color.red : Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if !isEmergency {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
    
    private func getUpdateMessage() -> String {
        if isEmergency {
            return "A critical update is required to fix important issues and ensure the app continues to work properly."
        } else if isTestFlight {
            return "A new TestFlight version is available. Please update to the latest version for the best experience."
        } else {
            return "A new version is available with bug fixes and improvements. Please update to continue enjoying the game."
        }
    }
    
    private func openAppStore() {
        let appStoreId = "6746708231"
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreId)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    UpdatePromptView(isTestFlight: false, isEmergency: false)
} 