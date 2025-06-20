/******************************************************
 * FILE: LoginView.swift
 * MARK: User Login Interface
 * CREATED: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides a simple login interface for user authentication, allowing
 * users to sign in with email and password credentials.
 *
 * KEY RESPONSIBILITIES:
 * - Display login form with email and password fields
 * - Handle user authentication with Firebase
 * - Provide error handling and user feedback
 * - Support navigation to sign-up flow
 * - Manage authentication state
 * - Display app branding and visual elements
 *
 * MAJOR DEPENDENCIES:
 * - FirebaseAuth: Core authentication services
 * - SwiftUI: Core UI framework for interface
 * - SignUpView.swift: Navigation to registration flow
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - FirebaseAuth: Firebase authentication services
 *
 * ARCHITECTURE ROLE:
 * Acts as a simple authentication interface that provides
 * basic login functionality with email and password.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Authentication must be handled securely
 * - Error messages must be user-friendly
 * - Form validation must occur before submission
 * - Navigation to sign-up must be seamless
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify Firebase authentication integration
 * - Check error handling for all authentication scenarios
 * - Test form validation and user feedback
 * - Validate navigation to sign-up flow
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add biometric authentication support
 * - Implement "Remember Me" functionality
 * - Add social login options
 ******************************************************/

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image("AppIcon")
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Infinitum Block Smash")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button(action: signIn) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: { showingSignUp = true }) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.2, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView(isAuthenticated: $isAuthenticated)
        }
    }
    
    private func signIn() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            showingError = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            showingError = true
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                let errorCode = (error as NSError).code
                switch errorCode {
                case AuthErrorCode.invalidEmail.rawValue:
                    errorMessage = "Please enter a valid email address."
                case AuthErrorCode.wrongPassword.rawValue:
                    errorMessage = "Incorrect password. Please try again or use 'Forgot Password' if you've forgotten it."
                case AuthErrorCode.userNotFound.rawValue:
                    errorMessage = "No account found with this email. Please check your email or create a new account."
                case AuthErrorCode.networkError.rawValue:
                    errorMessage = "Unable to connect to the server. Please check your internet connection and try again."
                case AuthErrorCode.tooManyRequests.rawValue:
                    errorMessage = "Too many attempts. Please try again in a few minutes."
                case AuthErrorCode.operationNotAllowed.rawValue:
                    errorMessage = "This sign-in method is not enabled. Please try a different method."
                case AuthErrorCode.invalidCredential.rawValue:
                    errorMessage = "Invalid login credentials. Please check your email and password."
                case AuthErrorCode.requiresRecentLogin.rawValue:
                    errorMessage = "For security reasons, please sign in again to continue."
                default:
                    errorMessage = "An unexpected error occurred. Please try again later."
                }
                showingError = true
            } else {
                isAuthenticated = true
            }
        }
    }
} 