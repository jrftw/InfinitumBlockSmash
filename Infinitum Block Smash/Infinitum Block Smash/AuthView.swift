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
        GeometryReader { geometry in
            ZStack {
                // Modern gradient background
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemIndigo), Color(.systemBlue), Color(.systemPurple)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onAppear {
                    print("[AuthView] Background gradient appeared")
                }

                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer()
                        
                        AuthHeaderView()
                            .onAppear {
                                print("[AuthView] Header view appeared")
                            }
                        
                        // Card-like container for sign-in options
                        VStack(spacing: 18) {
                            if !viewModel.showSignUp && !viewModel.showSignIn && !viewModel.showPhoneSignIn && !viewModel.showGameCenterSignIn && !viewModel.showAdditionalInfo {
                                MainAuthButtonsView(viewModel: viewModel)
                                    .onAppear {
                                        print("[AuthView] Main auth buttons appeared")
                                    }
                            }
                            
                            if viewModel.showSignUp {
                                SignUpFormView(viewModel: viewModel)
                                    .onAppear {
                                        print("[AuthView] Sign up form appeared")
                                    }
                            }
                            
                            if viewModel.showSignIn {
                                SignInFormView(viewModel: viewModel)
                                    .onAppear {
                                        print("[AuthView] Sign in form appeared")
                                    }
                            }
                            
                            if viewModel.showPasswordReset {
                                PasswordResetFormView(viewModel: viewModel)
                                    .onAppear {
                                        print("[AuthView] Password reset form appeared")
                                    }
                            }
                            
                            if viewModel.showAdditionalInfo {
                                AdditionalInfoFormView(viewModel: viewModel)
                                    .onAppear {
                                        print("[AuthView] Additional info form appeared")
                                    }
                            }
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .onAppear {
                                        print("[AuthView] Loading indicator appeared")
                                    }
                            }
                            
                            if !viewModel.errorMessage.isEmpty {
                                Text(viewModel.errorMessage)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                                    .onAppear {
                                        print("[AuthView] Error message appeared: \(viewModel.errorMessage)")
                                    }
                            }
                        }
                        .padding(24)
                        .background(BlurView(style: .systemUltraThinMaterialDark))
                        .cornerRadius(28)
                        .padding(.horizontal, min(geometry.size.width * 0.1, 24))
                        .frame(maxWidth: 500)
                        .contentShape(Rectangle())
                        .onAppear {
                            print("[AuthView] Auth container appeared with size: \(geometry.size)")
                        }
                        Spacer()
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .simultaneousGesture(DragGesture().onChanged { _ in
                    if viewModel.isLoading {
                        // Prevent scrolling while loading
                        return
                    }
                })
                .onAppear {
                    print("[AuthView] ScrollView appeared")
                }
            }
        }
        .onAppear {
            print("[AuthView] View appeared")
            viewModel.dismiss = { dismiss() }
        }
        .onDisappear {
            print("[AuthView] View disappeared")
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
