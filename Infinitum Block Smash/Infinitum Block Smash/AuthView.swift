import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GameKit
import AuthenticationServices
import UserNotifications

// MARK: - AuthView

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemIndigo), Color(.systemBlue), Color(.systemPurple)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                
                AuthHeaderView()
                
                // Card-like container for sign-in options
                VStack(spacing: 18) {
                    if !viewModel.showSignUp && !viewModel.showSignIn && !viewModel.showPhoneSignIn && !viewModel.showGameCenterSignIn && !viewModel.showAdditionalInfo {
                        MainAuthButtonsView(viewModel: viewModel)
                    }
                    
                    if viewModel.showSignUp {
                        SignUpFormView(viewModel: viewModel)
                    }
                    
                    if viewModel.showSignIn {
                        SignInFormView(viewModel: viewModel)
                    }
                    
                    if viewModel.showAdditionalInfo {
                        AdditionalInfoFormView(viewModel: viewModel)
                    }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(24)
                .background(BlurView(style: .systemUltraThinMaterialDark))
                .cornerRadius(28)
                .padding(.horizontal, 24)
                Spacer()
            }
        }
        .onAppear {
            viewModel.dismiss = { dismiss() }
        }
        .alert("Enable Notifications", isPresented: $viewModel.showingNotificationPermission) {
            Button("Enable") {
                viewModel.requestNotificationPermission()
            }
            Button("Not Now", role: .cancel) {
                viewModel.hasRequestedNotifications = true
                dismiss()
            }
        } message: {
            Text("Would you like to receive notifications for game updates, events, and reminders?")
        }
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .preferredColorScheme(.dark) // Since the view uses a dark theme
}
