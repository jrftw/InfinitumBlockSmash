/*
 * AuthView.swift
 * 
 * USER AUTHENTICATION AND ACCOUNT MANAGEMENT INTERFACE
 * 
 * This view provides the complete authentication interface for Infinitum Block Smash,
 * including sign-in, sign-up, password reset, and various authentication methods.
 * It handles user account creation, login, and profile management with a modern UI.
 * 
 * KEY RESPONSIBILITIES:
 * - User authentication interface and flow management
 * - Multiple authentication method support (email, Apple, Google, Game Center)
 * - User registration and account creation
 * - Password reset and recovery
 * - Profile information collection and management
 * - Authentication state management
 * - Error handling and user feedback
 * - Notification permission requests
 * - Guest user support
 * - Cross-platform authentication
 * 
 * MAJOR DEPENDENCIES:
 * - AuthViewModel.swift: Authentication logic and state management
 * - AuthComponents.swift: Reusable authentication UI components
 * - FirebaseAuth: Firebase authentication services
 * - GameKit: Game Center authentication
 * - AuthenticationServices: Apple Sign-In integration
 * - UserNotifications: Push notification permissions
 * - BlurView.swift: Visual effects and styling
 * 
 * AUTHENTICATION METHODS:
 * - Email/Password: Traditional email-based authentication
 * - Apple Sign-In: Secure Apple ID authentication
 * - Google Sign-In: Google account integration
 * - Game Center: iOS Game Center authentication
 * - Guest Mode: Anonymous user access
 * - Phone Authentication: SMS-based verification
 * 
 * USER FLOW FEATURES:
 * - Multi-step registration process
 * - Profile information collection
 * - Username availability checking
 * - Email verification
 * - Password strength validation
 * - Account linking and merging
 * - Cross-device authentication
 * 
 * UI COMPONENTS:
 * - Modern gradient background
 * - Card-based authentication forms
 * - Blur effects and visual styling
 * - Loading indicators and progress states
 * - Error message display
 * - Responsive design for different screen sizes
 * - Accessibility support
 * 
 * SECURITY FEATURES:
 * - Secure password requirements
 * - Email verification
 * - Account recovery options
 * - Session management
 * - Fraud prevention measures
 * - Data privacy protection
 * 
 * ERROR HANDLING:
 * - Network connectivity issues
 * - Authentication failures
 * - Account conflicts
 * - Invalid credentials
 * - Service unavailability
 * - User-friendly error messages
 * 
 * PERFORMANCE FEATURES:
 * - Efficient form validation
 * - Optimized authentication flows
 * - Background authentication processing
 * - Memory-efficient UI components
 * - Fast loading and transitions
 * 
 * USER EXPERIENCE:
 * - Intuitive authentication flow
 * - Clear visual feedback
 * - Smooth transitions and animations
 * - Responsive design
 * - Accessibility compliance
 * - Multi-language support
 * 
 * INTEGRATION POINTS:
 * - Firebase authentication backend
 * - Game Center for iOS integration
 * - Apple Sign-In for privacy
 * - Google authentication services
 * - Push notification system
 * - User profile management
 * 
 * ARCHITECTURE ROLE:
 * This view acts as the primary interface for user authentication,
 * providing a secure and user-friendly way to access the game
 * while managing user accounts and preferences.
 * 
 * THREADING CONSIDERATIONS:
 * - UI updates on main thread
 * - Background authentication processing
 * - Async/await for network operations
 * - State management with Combine
 * 
 * SECURITY CONSIDERATIONS:
 * - Secure credential handling
 * - Token management
 * - Session security
 * - Data encryption
 * - Privacy compliance
 * 
 * REVIEW NOTES:
 * - Ensure AuthViewModel state management is thread-safe
 * - Verify Firebase Auth configuration is properly initialized
 * - Check Apple Sign-In entitlements and configuration
 * - Validate Game Center authentication flow
 * - Test network connectivity error handling
 * - Verify password reset email functionality
 * - Check username availability API integration
 * - Validate cross-device authentication sync
 * - Test guest mode data persistence
 * - Verify notification permission flow
 * - Check accessibility compliance for all UI elements
 * - Validate error message localization
 * - Test authentication state persistence across app launches
 * - Verify account linking and merging logic
 * - Check security token refresh mechanisms
 */

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
