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
        
        guard ProfanityFilter.isAppropriate(username) else {
            errorMessage = "Username contains inappropriate language."
            return
        }
        
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.handleAuthError(error)
                return
            }
            
            guard let user = result?.user else {
                self.errorMessage = "Failed to create user account."
                return
            }
            
            self.userID = user.uid
            self.storedUsername = self.username
            self.saveUsername()
            self.isGuest = false
            
            // Track account creation for this device
            Task {
                do {
                    try await DeviceManager.shared.trackAccountCreation(userID: user.uid)
                    
                    // Handle referral code if provided
                    if !self.referralCode.isEmpty {
                        do {
                            try await ReferralManager.shared.applyReferralCode(self.referralCode, forUserID: user.uid)
                            print("Referral code applied successfully.")
                        } catch {
                            print("Failed to apply referral code: \(error.localizedDescription)")
                            // Show error to user if it's not the device limit error
                            if (error as NSError).code != 3 {
                                await MainActor.run {
                                    self.errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                } catch {
                    print("Failed to track account creation: \(error.localizedDescription)")
                }
            }
            
            self.handleSuccessfulAuth()
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
            errorMessage = "Invalid email address."
        case AuthErrorCode.weakPassword.rawValue:
            errorMessage = "Password is too weak. Please use a stronger password."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            errorMessage = "This email is already in use."
        case AuthErrorCode.wrongPassword.rawValue:
            errorMessage = "Incorrect password."
        case AuthErrorCode.userNotFound.rawValue:
            errorMessage = "No account found with this email."
        case AuthErrorCode.networkError.rawValue:
            errorMessage = "Network error. Please check your connection."
        default:
            errorMessage = error.localizedDescription
        }
    }
    
    func signInWithGameCenter() {
        isLoading = true
        let localPlayer = GKLocalPlayer.local
        
        // Handle view controller presentation separately
        let presentViewController = { (vc: UIViewController) in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(vc, animated: true)
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
                    self.tempUserID = user.uid
                    self.tempAuthProvider = "gamecenter"
                    self.showAdditionalInfo = true
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
        
        if !email.isEmpty && !password.isEmpty {
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
        } else {
            finishProfileSetup(user: user)
        }
    }
    
    private func handleAppleAdditionalInfo() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "No authenticated user found."
            return
        }
        
        if !email.isEmpty && !password.isEmpty {
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
        } else {
            finishProfileSetup(user: user)
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
        resetState()
        checkNotificationStatus()
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