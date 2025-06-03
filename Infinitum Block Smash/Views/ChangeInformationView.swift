import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ChangeInformationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var connectionTypes: [String] = []
    @State private var lastUsernameChange: Date? = nil
    @State private var canEditUsername = true
    @State private var showingPasswordChange = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var usernameChanged = false
    @State private var emailChanged = false
    @State private var phoneChanged = false
    @State private var passwordChanged = false
    @State private var originalUsername = ""
    @State private var originalEmail = ""
    @State private var originalPhone = ""
    @State private var usernameValidationError = ""
    @State private var emailValidationError = ""
    @State private var passwordValidationError = ""
    @State private var showSuccess = false
    @State private var isVerifyingEmail = false
    @State private var showEmailVerificationAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: username) { newValue in
                            let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue {
                                username = filtered
                            }
                            usernameChanged = username != originalUsername
                            validateUsername()
                        }
                        .disabled(!canEditUsername || isSaving || isVerifyingEmail)
                    if !usernameValidationError.isEmpty {
                        Text(usernameValidationError).foregroundColor(.red).font(.caption)
                    }
                }
                Section(header: Text("Email")) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: email) { newValue in
                            emailChanged = email != originalEmail
                            validateEmail()
                        }
                        .disabled(isSaving || isVerifyingEmail)
                    if !emailValidationError.isEmpty {
                        Text(emailValidationError).foregroundColor(.red).font(.caption)
                    }
                }
                if !phone.isEmpty {
                    Section(header: Text("Phone Number")) {
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                            .disabled(true)
                    }
                }
                Section(header: Text("Connection Types")) {
                    ForEach(connectionTypes, id: \.self) { type in
                        Text(type.capitalized)
                    }
                }
                Section(header: Text("Password")) {
                    SecureField("New Password", text: $newPassword)
                        .onChange(of: newPassword) { _ in validatePassword() }
                        .disabled(isSaving || isVerifyingEmail)
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .onChange(of: confirmPassword) { _ in validatePassword() }
                        .disabled(isSaving || isVerifyingEmail)
                    if !passwordValidationError.isEmpty {
                        Text(passwordValidationError).foregroundColor(.red).font(.caption)
                    }
                }
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Change Information")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Your information has been updated.")
            }
            .alert("Email Verification Required", isPresented: $showEmailVerificationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A verification email has been sent to \(email). Please verify your email address to complete the update.")
            }
            .onAppear { loadUserInfo() }
        }
    }
    
    private var canSave: Bool {
        ((usernameChanged && usernameValidationError.isEmpty && canEditUsername) ||
        (emailChanged && emailValidationError.isEmpty) ||
        (passwordChanged && passwordValidationError.isEmpty && !newPassword.isEmpty)) && !isSaving && !isVerifyingEmail
    }
    
    private func loadUserInfo() {
        guard let user = Auth.auth().currentUser else { return }
        username = user.displayName ?? ""
        originalUsername = username
        email = user.email ?? ""
        originalEmail = email
        phone = user.phoneNumber ?? ""
        originalPhone = phone
        connectionTypes = user.providerData.map { provider in
            switch provider.providerID {
            case "password": return "Email"
            case "phone": return "Phone"
            case "gamecenter.apple.com": return "Game Center"
            default: return provider.providerID
            }
        }
        // Firestore fallback if displayName is empty
        if username.isEmpty {
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).getDocument { snapshot, error in
                if let data = snapshot?.data(), let name = data["username"] as? String {
                    username = name
                    originalUsername = name
                }
            }
        }
        // Load lastUsernameChange from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
        // ... existing code ...
    }
    
    private func saveChanges() {
        guard let user = Auth.auth().currentUser else { return }
        isSaving = true
        
        // Username update
        if usernameChanged && usernameValidationError.isEmpty && canEditUsername {
            let db = Firestore.firestore()
            let now = Date()
            db.collection("users").document(user.uid).setData([
                "username": username,
                "lastUsernameChange": Timestamp(date: now)
            ], merge: true) { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                    return
                }
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                        showingError = true
                        isSaving = false
                        return
                    }
                    originalUsername = username
                    lastUsernameChange = now
                    canEditUsername = false
                    isSaving = false
                    showSuccess = true
                }
            }
        }
        
        // Email update
        if emailChanged && emailValidationError.isEmpty {
            isVerifyingEmail = true
            user.sendEmailVerification(beforeUpdatingEmail: email) { error in
                isVerifyingEmail = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                    return
                }
                showEmailVerificationAlert = true
                originalEmail = email
                isSaving = false
            }
        }
        
        // Password update
        if passwordChanged && passwordValidationError.isEmpty && !newPassword.isEmpty {
            user.updatePassword(to: newPassword) { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                    return
                }
                newPassword = ""
                confirmPassword = ""
                isSaving = false
                showSuccess = true
            }
        }
    }
}

struct ChangeInformationView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeInformationView()
    }
} 