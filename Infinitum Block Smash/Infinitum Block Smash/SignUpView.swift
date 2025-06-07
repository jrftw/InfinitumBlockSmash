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
        password == confirmPassword && password.count >= 6 &&
        ProfanityFilter.isAppropriate(username)
    }
    
    private func createAccount() async {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
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
                    referralErrorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
} 