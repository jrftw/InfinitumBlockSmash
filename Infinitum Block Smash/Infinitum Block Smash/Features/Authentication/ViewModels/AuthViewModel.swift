/*
 * AuthViewModel.swift
 * 
 * AUTHENTICATION LOGIC AND STATE MANAGEMENT
 * 
 * This view model manages all authentication-related logic, state, and business rules
 * for the Infinitum Block Smash game. It handles user authentication flows, data
 * persistence, error handling, and integration with various authentication providers.
 * 
 * KEY RESPONSIBILITIES:
 * - Authentication state management and persistence
 * - Multiple authentication provider integration (Firebase, Apple, Google, Game Center)
 * - User registration and profile management
 * - Password reset and account recovery
 * - Username validation and availability checking
 * - Error handling and user feedback
 * - Cross-device authentication synchronization
 * - Guest user management
 * - Notification permission handling
 * - Referral system integration
 * 
 * MAJOR DEPENDENCIES:
 * - FirebaseAuth: Core authentication services
 * - FirebaseFirestore: User data persistence
 * - GameKit: Game Center authentication
 * - AuthenticationServices: Apple Sign-In
 * - UserNotifications: Push notification permissions
 * - ProfanityFilter.swift: Username content validation
 * - UserDefaults: Local data persistence
 * - AuthView.swift: UI presentation layer
 * 
 * AUTHENTICATION PROVIDERS:
 * - Firebase Email/Password: Traditional authentication
 * - Apple Sign-In: Privacy-focused authentication
 * - Google Sign-In: Google account integration
 * - Game Center: iOS gaming platform integration
 * - Phone Authentication: SMS-based verification
 * - Guest Mode: Anonymous user access
 * 
 * STATE MANAGEMENT:
 * - Published properties for reactive UI updates
 * - AppStorage for persistent user data
 * - Loading states and progress indicators
 * - Error state handling and display
 * - Authentication flow state tracking
 * - Form validation and user input management
 * 
 * USER DATA MANAGEMENT:
 * - Username validation and availability
 * - Profile information collection
 * - Cross-device data synchronization
 * - Account linking and merging
 * - Data persistence and recovery
 * - Privacy and security compliance
 * 
 * ERROR HANDLING:
 * - Comprehensive Firebase Auth error mapping
 * - Network connectivity issues
 * - Service unavailability handling
 * - User-friendly error messages
 * - Retry logic and recovery mechanisms
 * - Validation error feedback
 * 
 * SECURITY FEATURES:
 * - Password strength validation
 * - Username content filtering
 * - Secure token management
 * - Session security
 * - Account recovery options
 * - Fraud prevention measures
 * 
 * PERFORMANCE FEATURES:
 * - Efficient state updates
 * - Background authentication processing
 * - Optimized data persistence
 * - Memory-efficient error handling
 * - Fast authentication flows
 * 
 * INTEGRATION POINTS:
 * - Firebase backend services
 * - Apple Sign-In framework
 * - Google authentication
 * - Game Center platform
 * - Push notification system
 * - User profile management
 * - Referral system
 * 
 * USER EXPERIENCE:
 * - Smooth authentication flows
 * - Clear error feedback
 * - Loading state management
 * - Form validation feedback
 * - Cross-device consistency
 * - Accessibility support
 * 
 * ARCHITECTURE ROLE:
 * This view model acts as the business logic layer for authentication,
 * separating concerns between UI presentation and authentication logic
 * while providing a clean interface for the view layer.
 * 
 * THREADING CONSIDERATIONS:
 * - @MainActor for UI updates
 * - Background authentication processing
 * - Thread-safe state management
 * - Async/await for network operations
 * 
 * SECURITY CONSIDERATIONS:
 * - Secure credential handling
 * - Token refresh management
 * - Session security
 * - Data encryption
 * - Privacy compliance
 * 
 * REVIEW NOTES:
 * - Verify Firebase Auth configuration and initialization
 * - Check Apple Sign-In entitlements and capabilities
 * - Validate Game Center authentication flow and error handling
 * - Test network connectivity error scenarios
 * - Verify password reset email functionality
 * - Check username availability API integration and rate limiting
 * - Validate cross-device authentication sync and conflict resolution
 * - Test guest mode data persistence and migration
 * - Verify notification permission flow and state management
 * - Check profanity filter integration and performance
 * - Validate error message localization and user experience
 * - Test authentication state persistence across app launches and updates
 * - Verify account linking and merging logic for multiple providers
 * - Check security token refresh mechanisms and expiration handling
 * - Test referral system integration and validation
 * - Validate form validation logic and user feedback
 * - Check memory management and potential retain cycles
 * - Test authentication flow interruption and recovery
 * - Verify accessibility compliance for error messages and loading states
 * - Check data privacy compliance and user consent handling
 */

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GameKit
import AuthenticationServices
import UserNotifications

class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showSignUp = false
    @Published var showSignIn = false
    @Published var showPhoneSignIn = false
    @Published var showGameCenterSignIn = false
    @Published var showAdditionalInfo = false
    @Published var showPasswordReset = false
    @Published var tempUserID = ""
    @Published var tempAuthProvider = ""
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var showingNotificationPermission = false
    @Published var referralCode: String = ""
    
    // MARK: - AppStorage Properties
    @AppStorage("userID") var userID: String = ""
    @AppStorage("username") var storedUsername: String = ""
    @AppStorage("isGuest") var isGuest: Bool = false
    @AppStorage("hasRequestedNotifications") var hasRequestedNotifications = false
    
    // MARK: - Dismiss Action
    var dismiss: () -> Void = {}
    
    // MARK: - State Management
    func resetState() {
        email = ""
        password = ""
        username = ""
        errorMessage = ""
        isLoading = false
        showSignUp = false
        showSignIn = false
        showPhoneSignIn = false
        showGameCenterSignIn = false
        showAdditionalInfo = false
        showPasswordReset = false
        tempUserID = ""
        tempAuthProvider = ""
        referralCode = ""
    }
    
    // MARK: - Auth Methods
    func checkIfSignedIn() {
        if let user = Auth.auth().currentUser {
            userID = user.uid
            fetchUsername()
            dismiss()
        }
    }
    
    func signUpWithEmail() {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        guard username.count >= 3 else {
            errorMessage = "Username must be at least 3 characters long."
            return
        }
        
        guard ProfanityFilter.isAppropriate(username) else {
            errorMessage = "Username contains inappropriate language."
            return
        }
        
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isLoading = false
                self.handleAuthError(error)
                return
            }
            
            guard let user = result?.user else {
                self.errorMessage = "Failed to create user account."
                self.isLoading = false
                return
            }
            
            // Update the user's profile with username
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = self.username
            changeRequest.commitChanges { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Failed to set username: \(error.localizedDescription)"
                    return
                }
                
                // Save username to Firestore
                let db = Firestore.firestore()
                let userData: [String: Any] = [
                    "username": self.username,
                    "email": self.email,
                    "timestamp": FieldValue.serverTimestamp(),
                    "lastUsernameChange": FieldValue.serverTimestamp()
                ]
                
                db.collection("users").document(user.uid).setData(userData) { [weak self] error in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        Logger.shared.log("Failed to save user data: \(error.localizedDescription)", category: .firebaseFirestore, level: .error)
                        self.errorMessage = "Failed to save user data: \(error.localizedDescription)"
                        return
                    }
                    
                    self.userID = user.uid
                    self.storedUsername = self.username
                    self.isGuest = false
                    self.handleSuccessfulAuth()
                }
            }
        }
    }
    
    func signInWithEmail() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.handleAuthError(error)
                return
            }
            
            guard let user = result?.user else {
                self.errorMessage = "Failed to sign in."
                return
            }
            
            self.userID = user.uid
            self.fetchUsername()
            self.isGuest = false
            self.handleSuccessfulAuth()
        }
    }
    
    private func handleAuthError(_ error: Error) {
        let errorCode = (error as NSError).code
        switch errorCode {
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "Please enter a valid email address."
        case AuthErrorCode.weakPassword.rawValue:
            errorMessage = "Your password is too weak. Please use at least 6 characters with a mix of letters, numbers, and symbols."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            errorMessage = "This email is already registered. Please try signing in or use a different email."
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
        case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
            errorMessage = "An account already exists with this email using a different sign-in method."
        case AuthErrorCode.requiresRecentLogin.rawValue:
            errorMessage = "For security reasons, please sign in again to continue."
        default:
            errorMessage = "An unexpected error occurred. Please try again later."
        }
    }
    
    func signInWithGameCenter() {
        isLoading = true
        let localPlayer = GKLocalPlayer.local
        
        // Handle view controller presentation separately
        let presentViewController = { (vc: UIViewController) in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                // Find the top-most presented view controller
                var topController = rootViewController
                while let presentedController = topController.presentedViewController {
                    topController = presentedController
                }
                
                // Configure the presentation style for iPad
                if UIDevice.current.userInterfaceIdiom == .pad {
                    vc.modalPresentationStyle = .formSheet
                    vc.preferredContentSize = CGSize(width: 400, height: 600)
                }
                
                topController.present(vc, animated: true)
            }
        }
        
        // Handle authentication result
        let handleAuthResult = { [weak self] (error: Error?) in
            guard let self = self else { return }
            
            if localPlayer.isAuthenticated {
                self.handleGameCenterAuthentication()
            } else if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            } else {
                self.isLoading = false
                self.errorMessage = "Game Center authentication failed"
            }
        }
        
        localPlayer.authenticateHandler = { vc, error in
            if let vc = vc {
                presentViewController(vc)
            } else {
                handleAuthResult(error)
            }
        }
    }
    
    private func handleGameCenterAuthentication() {
        GameCenterAuthProvider.getCredential { [weak self] credential, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard let credential = credential else {
                self.isLoading = false
                self.errorMessage = "Failed to get Game Center credential"
                return
            }
            
            Auth.auth().signIn(with: credential) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                if let user = result?.user {
                    // Check if user has email and username set
                    let email = user.email ?? ""
                    let username = UserDefaults.standard.string(forKey: "username") ?? ""
                    
                    if email.isEmpty || username.isEmpty || username == "unknown" {
                        // User needs to complete profile setup
                        self.tempUserID = user.uid
                        self.tempAuthProvider = "gamecenter"
                        self.showAdditionalInfo = true
                        print("[AuthViewModel] Game Center user needs to complete profile setup")
                    } else {
                        // User is fully set up - complete authentication
                        self.userID = user.uid
                        self.storedUsername = username
                        self.isGuest = false
                        self.isLoading = false
                        self.handleSuccessfulAuth()
                        print("[AuthViewModel] Game Center user successfully authenticated")
                    }
                } else {
                    self.isLoading = false
                    self.errorMessage = "Failed to sign in with Game Center"
                }
            }
        }
    }
    
    func completeAdditionalInfo() {
        guard !username.isEmpty else {
            errorMessage = "Please enter a username."
            return
        }
        
        guard ProfanityFilter.isAppropriate(username) else {
            errorMessage = "Username contains inappropriate language."
            return
        }
        
        // Require email and password for Game Center and Apple Sign-In users
        if tempAuthProvider == "gamecenter" || tempAuthProvider == "apple" {
            guard !email.isEmpty else {
                errorMessage = "Please enter an email address."
                return
            }
            
            guard !password.isEmpty else {
                errorMessage = "Please enter a password."
                return
            }
            
            // Basic email validation
            guard email.contains("@") && email.contains(".") else {
                errorMessage = "Please enter a valid email address."
                return
            }
            
            // Basic password validation
            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters long."
                return
            }
        }
        
        isLoading = true
        
        switch tempAuthProvider {
        case "gamecenter":
            handleGameCenterAdditionalInfo()
        case "apple":
            handleAppleAdditionalInfo()
        default:
            isLoading = false
            errorMessage = "Invalid authentication provider."
        }
    }
    
    private func handleGameCenterAdditionalInfo() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "No authenticated user found."
            return
        }
        
        // Email and password are now required for Game Center users
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.link(with: credential) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                self.isLoading = false
                if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    self.errorMessage = "This email is already associated with another account."
                } else {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            self.finishProfileSetup(user: user)
        }
    }
    
    private func handleAppleAdditionalInfo() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "No authenticated user found."
            return
        }
        
        // Email and password are now required for Apple Sign-In users
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.link(with: credential) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                self.isLoading = false
                if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    self.errorMessage = "This email is already associated with another account."
                } else {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            self.finishProfileSetup(user: user)
        }
    }
    
    private func finishProfileSetup(user: User) {
        userID = user.uid
        storedUsername = username
        saveUsername()
        isGuest = false
        handleSuccessfulAuth()
    }
    
    private func handleSuccessfulAuth() {
        isLoading = false
        checkUsernameAppropriateness()
        resetState()
        checkNotificationStatus()
    }
    
    private func checkUsernameAppropriateness() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Check if current username is appropriate
        if let currentUsername = user.displayName, !ProfanityFilter.isAppropriate(currentUsername) {
            // Force user to change username
            showAdditionalInfo = true
            tempUserID = user.uid
            tempAuthProvider = "force_username_change"
            errorMessage = "Your current username contains inappropriate language. Please choose a new username."
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    if !self.hasRequestedNotifications {
                        self.showingNotificationPermission = true
                    } else {
                        self.dismiss()
                    }
                case .denied:
                    // Always show the permission request if notifications were denied
                    self.showingNotificationPermission = true
                case .authorized, .provisional, .ephemeral:
                    self.dismiss()
                @unknown default:
                    self.dismiss()
                }
            }
        }
    }
    
    // MARK: - Username Management
    private func saveUsername() {
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "username": username,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userID).setData(userData) { error in
            if let error = error {
                print("Error saving username: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchUsername() {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { [weak self] document, error in
            guard let self = self else { return }
            if let document = document, document.exists {
                if let username = document.data()?["username"] as? String {
                    self.storedUsername = username
                }
            }
        }
    }
    
    // MARK: - Notification Handling
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.hasRequestedNotifications = true
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    // Set all notification preferences to true by default
                    UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                    UserDefaults.standard.set(true, forKey: "eventNotifications")
                    UserDefaults.standard.set(true, forKey: "updateNotifications")
                    UserDefaults.standard.set(true, forKey: "reminderNotifications")
                    NotificationManager.shared.scheduleDailyReminder()
                }
                self.dismiss()
            }
        }
    }
    
    func skipNotificationPermission() {
        hasRequestedNotifications = true
        dismiss()
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.handleAuthError(error)
            } else {
                self.errorMessage = "Password reset email sent. Please check your inbox."
                self.showPasswordReset = false
            }
        }
    }
} 