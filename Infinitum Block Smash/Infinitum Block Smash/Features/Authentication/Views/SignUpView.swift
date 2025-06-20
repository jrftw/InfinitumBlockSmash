/******************************************************
 * FILE: SignUpView.swift
 * MARK: User Registration Interface
 * CREATED: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides a user registration interface for creating new accounts,
 * with comprehensive form validation and referral code support.
 *
 * KEY RESPONSIBILITIES:
 * - Display user registration form with validation
 * - Handle account creation with Firebase Auth
 * - Validate username availability and appropriateness
 * - Process referral codes for new users
 * - Provide comprehensive error handling
 * - Manage loading states and user feedback
 * - Support form validation and user guidance
 *
 * MAJOR DEPENDENCIES:
 * - FirebaseAuth: Core authentication services
 * - SwiftUI: Core UI framework for interface
 * - ProfanityFilter.swift: Username content validation
 * - ReferralManager.swift: Referral code processing
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - FirebaseAuth: Firebase authentication services
 *
 * ARCHITECTURE ROLE:
 * Acts as the user registration interface that handles
 * new account creation with comprehensive validation.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Form validation must occur before account creation
 * - Username validation must check for inappropriate content
 * - Referral code processing must be optional and error-safe
 * - Authentication state must be properly managed
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify Firebase account creation integration
 * - Check username validation and profanity filtering
 * - Test referral code processing and error handling
 * - Validate form validation logic and user feedback
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add email verification flow
 * - Implement username availability checking
 * - Add password strength indicators
 ******************************************************/

import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var referralCode: String = ""
    @State private var showReferralError = false
    @State private var referralErrorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                    
                    TextField("Referral Code (Optional)", text: $referralCode)
                        .textContentType(.newPassword)
                        .autocapitalization(.allCharacters)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await createAccount()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Account")
                        }
                    }
                    .disabled(!isValidInput || isLoading)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValidInput: Bool {
        !email.isEmpty && !password.isEmpty && !username.isEmpty &&
        username.count >= 3 && password == confirmPassword && password.count >= 6 &&
        ProfanityFilter.isAppropriate(username)
    }
    
    private func createAccount() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            showingError = true
            return
        }
        
        guard !username.isEmpty else {
            errorMessage = "Please choose a username."
            showingError = true
            return
        }
        
        guard username.count >= 3 else {
            errorMessage = "Username must be at least 3 characters long."
            showingError = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter a password."
            showingError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match. Please make sure both passwords are the same."
            showingError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long."
            showingError = true
            return
        }
        
        guard ProfanityFilter.isAppropriate(username) else {
            errorMessage = "Username contains inappropriate language. Please choose a different username."
            showingError = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create the user account
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = result.user
            
            // Update the user's profile with username
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()
            
            // If a referral code was provided, apply it
            if !referralCode.isEmpty {
                do {
                    try await ReferralManager.shared.applyReferralCode(referralCode, forUserID: user.uid)
                } catch {
                    referralErrorMessage = "Unable to apply referral code. Please try again later."
                    showReferralError = true
                }
            }
            
            // Sign in successful
            await MainActor.run {
                isAuthenticated = true
                dismiss()
            }
        } catch {
            await MainActor.run {
                let errorCode = (error as NSError).code
                switch errorCode {
                case AuthErrorCode.invalidEmail.rawValue:
                    errorMessage = "Please enter a valid email address."
                case AuthErrorCode.weakPassword.rawValue:
                    errorMessage = "Your password is too weak. Please use at least 6 characters with a mix of letters, numbers, and symbols."
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    errorMessage = "This email is already registered. Please try signing in or use a different email."
                case AuthErrorCode.networkError.rawValue:
                    errorMessage = "Unable to connect to the server. Please check your internet connection and try again."
                case AuthErrorCode.operationNotAllowed.rawValue:
                    errorMessage = "This sign-in method is not enabled. Please try a different method."
                default:
                    errorMessage = "An unexpected error occurred. Please try again later."
                }
                showingError = true
            }
        }
    }
} 