import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GameKit
import AuthenticationServices

// MARK: - AuthView

struct AuthView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var showPhoneSignIn = false
    @State private var showGameCenterSignIn = false
    @State private var showAdditionalInfo = false
    @State private var tempUserID = ""
    @State private var tempAuthProvider = ""
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var storedUsername: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false

    // MARK: - Body
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
                // App icon or illustration (optional, use system icon for now)
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(radius: 12)
                    .padding(.bottom, 8)
                // Modern title
                Text("Welcome to\nInfinitum Block Smash!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 8)
                Text("Stack, smash, and climb the leaderboards!")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                // Card-like container for sign-in options
                VStack(spacing: 18) {
                    if !showSignUp && !showSignIn && !showPhoneSignIn && !showGameCenterSignIn && !showAdditionalInfo {
                        Button(action: { showSignIn = true }) {
                            Label("Sign In", systemImage: "person.crop.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 40)
                        }
                        .buttonStyle(ModernButtonStyle())

                        Button(action: { showSignUp = true }) {
                            Label("Sign Up with Email", systemImage: "envelope.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ModernButtonStyle(filled: false))

                        Button(action: { showPhoneSignIn = true }) {
                            Label("Sign Up with Phone", systemImage: "phone.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ModernButtonStyle(filled: false))

                        Button(action: { signInWithGameCenter() }) {
                            Label("Sign In with Game Center", systemImage: "gamecontroller.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ModernButtonStyle(filled: false, accent: .green))

                        Button(action: {
                            userID = UUID().uuidString
                            isGuest = true
                            dismiss()
                        }) {
                            Label("Continue as Guest", systemImage: "person.fill.questionmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
                    }
                    
                    if showSignUp {
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textFieldStyle(ModernTextFieldStyle())
                            SecureField("Password", text: $password)
                                .textFieldStyle(ModernTextFieldStyle())
                            TextField("Username", text: $username)
                                .textFieldStyle(ModernTextFieldStyle())
                            Button("Create Account") {
                                signUpWithEmail()
                            }
                            .buttonStyle(ModernButtonStyle())
                            Button("Back") { showSignUp = false }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 40)
                                .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
                        }
                    }
                    
                    if showSignIn {
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textFieldStyle(ModernTextFieldStyle())
                            SecureField("Password", text: $password)
                                .textFieldStyle(ModernTextFieldStyle())
                            Button("Sign In") {
                                signInWithEmail()
                            }
                            .buttonStyle(ModernButtonStyle())
                            Button("Back") { showSignIn = false }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 40)
                                .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
                        }
                    }
                    
                    if showPhoneSignIn {
                        PhoneSignInView(isSignedIn: $showPhoneSignIn, userID: $userID, storedUsername: $storedUsername)
                        Button("Back") { showPhoneSignIn = false }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
                    }
                    
                    if showAdditionalInfo {
                        VStack(spacing: 12) {
                            Text("Complete Your Profile")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.bottom, 8)
                            
                            TextField("Username", text: $username)
                                .textFieldStyle(ModernTextFieldStyle())
                            
                            if tempAuthProvider == "gamecenter" {
                                TextField("Email", text: $email)
                                    .textFieldStyle(ModernTextFieldStyle())
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                            
                            Button("Complete Setup") {
                                completeAdditionalInfo()
                            }
                            .buttonStyle(ModernButtonStyle())
                            
                            Button("Cancel") {
                                showAdditionalInfo = false
                                tempUserID = ""
                                tempAuthProvider = ""
                                email = ""
                                password = ""
                                username = ""
                            }
                            .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
                        }
                        .padding(24)
                        .background(BlurView(style: .systemUltraThinMaterialDark))
                        .cornerRadius(28)
                        .padding(.horizontal, 24)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
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
            // Remove automatic check for signed in user
            // checkIfSignedIn()
        }
    }

    // MARK: - Notification Handling
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleSignInSuccess"),
            object: nil,
            queue: .main
        ) { notification in
            if let credential = notification.userInfo?["credential"] as? ASAuthorizationAppleIDCredential {
                handleAppleSignInSuccess(credential)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleSignInError"),
            object: nil,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?["error"] as? Error {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    private func handleAppleSignInSuccess(_ credential: ASAuthorizationAppleIDCredential) {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to fetch identity token"
            return
        }
        
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: ""
        )
        
        // Sign in with Firebase
        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            if let user = result?.user {
                tempUserID = user.uid
                tempAuthProvider = "apple"
                
                // If we don't have the user's email, show additional info form
                if user.email == nil {
                    showAdditionalInfo = true
                } else {
                    // If we have email but no username, just ask for username
                    if storedUsername.isEmpty {
                        showAdditionalInfo = true
                    } else {
                        userID = user.uid
                        isGuest = false
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Auth Methods

    private func checkIfSignedIn() {
        if let user = Auth.auth().currentUser {
            userID = user.uid
            fetchUsername()
            dismiss()
        }
    }

    private func signUpWithEmail() {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            guard let user = result?.user else { return }
            userID = user.uid
            storedUsername = username
            saveUsername()
            isGuest = false
            dismiss()
        }
    }

    private func signInWithEmail() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            guard let user = result?.user else { return }
            userID = user.uid
            fetchUsername()
            isGuest = false
            dismiss()
        }
    }

    private func signInWithGameCenter() {
        isLoading = true
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { vc, error in
            if let vc = vc {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(vc, animated: true)
                }
            } else if localPlayer.isAuthenticated {
                // Get the Game Center credential
                GameCenterAuthProvider.getCredential { credential, error in
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
                    
                    // Sign in with Firebase using the Game Center credential
                    Auth.auth().signIn(with: credential) { result, error in
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
            } else if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            } else {
                self.isLoading = false
                self.errorMessage = "Game Center authentication failed"
            }
        }
    }

    private func completeAdditionalInfo() {
        guard !username.isEmpty else {
            errorMessage = "Please enter a username."
            return
        }
        isLoading = true
        
        switch tempAuthProvider {
        case "gamecenter":
            guard let user = Auth.auth().currentUser else {
                isLoading = false
                errorMessage = "No authenticated user found."
                return
            }
            // If email and password are provided, try to link them
            if !email.isEmpty && !password.isEmpty {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                user.link(with: credential) { result, error in
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
                // Just update the username
                finishProfileSetup(user: user)
            }
        case "apple":
            if let user = Auth.auth().currentUser {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    isLoading = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }
                    userID = user.uid
                    storedUsername = username
                    saveUsername()
                    isGuest = false
                    dismiss()
                }
            } else {
                isLoading = false
                errorMessage = "No authenticated user found."
            }
        default:
            isLoading = false
            errorMessage = "Invalid authentication provider."
        }
    }

    private func finishProfileSetup(user: User) {
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = self.username
        changeRequest.commitChanges { error in
            self.isLoading = false
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.userID = user.uid
            self.storedUsername = self.username
            self.saveUsername()
            self.isGuest = false
            self.dismiss()
        }
    }

    private func saveUsername() {
        guard !userID.isEmpty, !storedUsername.isEmpty else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userID).setData([
            "username": storedUsername
        ], merge: true)
    }

    private func fetchUsername() {
        guard !userID.isEmpty else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { snapshot, error in
            if let data = snapshot?.data(), let name = data["username"] as? String {
                storedUsername = name
            }
        }
    }
}

// MARK: - Modern Button Style

struct ModernButtonStyle: ButtonStyle {
    var filled: Bool = true
    var accent: Color = Color.accentColor
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let backgroundColor: Color = filled ? accent : Color(UIColor.systemBackground).opacity(0.85)
        let foregroundColor: Color = filled ? Color(UIColor.systemBackground) : accent
        let borderColor: Color = filled ? .clear : accent

        return configuration.label
            .padding(.vertical, 14)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: filled ? 0 : 2)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: filled ? 8 : 2, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - Modern Text Field Style

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - PhoneSignInView

struct PhoneSignInView: View {
    @Binding var isSignedIn: Bool
    @Binding var userID: String
    @Binding var storedUsername: String
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationID: String? = nil
    @State private var isVerifying = false
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    @State private var step: Int = 0 // 0: enter phone, 1: enter code

    var body: some View {
        VStack(spacing: 16) {
            if step == 0 {
                Text("Sign Up with Phone")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                TextField("Phone Number (+1...)", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(ModernTextFieldStyle())
                TextField("Username", text: $storedUsername)
                    .textFieldStyle(ModernTextFieldStyle())
                Button(action: sendCode) {
                    Text("Send Verification Code")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle())
            } else {
                Text("Enter Verification Code")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                TextField("6-digit Code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(ModernTextFieldStyle())
                Button(action: verifyCode) {
                    Text("Verify & Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle())
            }
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .cornerRadius(20)
        .padding(.horizontal, 8)
    }

    private func sendCode() {
        errorMessage = ""
        guard !phoneNumber.isEmpty, !storedUsername.isEmpty else {
            errorMessage = "Please enter your phone number and username."
            return
        }
        isLoading = true
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            self.verificationID = verificationID
            self.step = 1
        }
    }

    private func verifyCode() {
        errorMessage = ""
        guard let verificationID = verificationID, !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code."
            return
        }
        isLoading = true
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        Auth.auth().signIn(with: credential) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            guard let user = result?.user else {
                errorMessage = "Failed to sign in."
                return
            }
            userID = user.uid
            saveUsernameToFirestore()
            isSignedIn = true
        }
    }

    private func saveUsernameToFirestore() {
        guard !userID.isEmpty, !storedUsername.isEmpty else { return }
        let db = Firestore.firestore()
        db.collection("users").document(userID).setData([
            "username": storedUsername
        ], merge: true)
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .preferredColorScheme(.dark) // Since the view uses a dark theme
}
