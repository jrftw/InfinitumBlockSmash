import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var isDeleting = false
    @State private var showingLinkEmail = false
    @State private var showingLinkGameCenter = false
    @State private var linkEmail = ""
    @State private var linkPassword = ""
    @State private var showingLinkError = false
    @State private var linkErrorMessage = ""
    
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
                        .disabled(!canEditUsername)
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
                        .disabled(isSaving)
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
                        HStack {
                            Text(type.capitalized)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !connectionTypes.contains("Email") {
                        Button("Link Email Account") {
                            showingLinkEmail = true
                        }
                    }
                    
                    if !connectionTypes.contains("Game Center") {
                        Button("Link Game Center") {
                            showingLinkGameCenter = true
                        }
                    }
                }
                Section(header: Text("Password")) {
                    SecureField("New Password", text: $newPassword)
                        .onChange(of: newPassword) { _ in validatePassword() }
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .onChange(of: confirmPassword) { _ in validatePassword() }
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
                
                Section {
                    Button("Delete Profile") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(isDeleting)
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
            .alert("Delete Profile", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProfile()
                }
            } message: {
                Text("Are you sure you want to delete your profile? This action cannot be undone and all your data will be permanently deleted.")
            }
            .alert("Error", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
            .alert("Error", isPresented: $showingLinkError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(linkErrorMessage)
            }
            .sheet(isPresented: $showingLinkEmail) {
                NavigationView {
                    Form {
                        Section(header: Text("Link Email Account")) {
                            TextField("Email", text: $linkEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            SecureField("Password", text: $linkPassword)
                                .textContentType(.password)
                        }
                        
                        Section {
                            Button("Link Account") {
                                linkEmailAccount()
                            }
                            .disabled(linkEmail.isEmpty || linkPassword.isEmpty)
                        }
                    }
                    .navigationTitle("Link Email")
                    .navigationBarItems(trailing: Button("Cancel") {
                        showingLinkEmail = false
                    })
                }
            }
            .onAppear { loadUserInfo() }
        }
    }
    
    private var canSave: Bool {
        (usernameChanged && usernameValidationError.isEmpty && canEditUsername) ||
        (emailChanged && emailValidationError.isEmpty) ||
        (passwordChanged && passwordValidationError.isEmpty && !newPassword.isEmpty)
    }
    
    private func loadUserInfo() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Load user data from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                // Get username from Firestore
                username = data["username"] as? String ?? ""
                originalUsername = username
                
                // Get last username change timestamp
                if let ts = data["lastUsernameChange"] as? Timestamp {
                    lastUsernameChange = ts.dateValue()
                    canEditUsername = canChangeUsername()
                } else {
                    canEditUsername = true
                }
            }
            
            // Load other user info from Auth
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
        }
    }
    
    private func canChangeUsername() -> Bool {
        guard let last = lastUsernameChange else { return true }
        return Date().timeIntervalSince(last) > 30 * 24 * 60 * 60
    }
    
    private func validateUsername() {
        if username.isEmpty {
            usernameValidationError = "Username cannot be empty."
        } else if username != username.lowercased() {
            usernameValidationError = "Username must be lowercase."
        } else if username.contains(" ") {
            usernameValidationError = "Username cannot contain spaces."
        } else if username.range(of: "[^a-z0-9_]", options: .regularExpression) != nil {
            usernameValidationError = "Only lowercase letters, numbers, and underscores allowed."
        } else if !canEditUsername {
            usernameValidationError = "You can only change your username once every 30 days."
        } else if !ProfanityFilter.isAppropriate(username) {
            usernameValidationError = "Username contains inappropriate language."
        } else {
            usernameValidationError = ""
        }
    }
    
    private func validateEmail() {
        if email.isEmpty {
            emailValidationError = "Email cannot be empty."
        } else if !email.contains("@") || !email.contains(".") {
            emailValidationError = "Invalid email address."
        } else {
            emailValidationError = ""
        }
    }
    
    private func validatePassword() {
        if !newPassword.isEmpty || !confirmPassword.isEmpty {
            passwordChanged = true
            if newPassword.count < 6 {
                passwordValidationError = "Password must be at least 6 characters."
            } else if newPassword != confirmPassword {
                passwordValidationError = "Passwords do not match."
            } else {
                passwordValidationError = ""
            }
        } else {
            passwordChanged = false
            passwordValidationError = ""
        }
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
            user.sendEmailVerification(beforeUpdatingEmail: email) { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                    return
                }
                originalEmail = email
                isSaving = false
                showSuccess = true
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
    
    private func deleteProfile() {
        guard let user = Auth.auth().currentUser else { return }
        isDeleting = true
        
        // Delete user data from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).delete { error in
            if let error = error {
                deleteErrorMessage = "Failed to delete user data: \(error.localizedDescription)"
                showingDeleteError = true
                isDeleting = false
                return
            }
            
            // Delete the user account
            user.delete { error in
                if let error = error {
                    deleteErrorMessage = "Failed to delete account: \(error.localizedDescription)"
                    showingDeleteError = true
                    isDeleting = false
                    return
                }
                
                // Sign out and dismiss the view
                do {
                    try Auth.auth().signOut()
                    dismiss()
                } catch {
                    deleteErrorMessage = "Failed to sign out: \(error.localizedDescription)"
                    showingDeleteError = true
                    isDeleting = false
                }
            }
        }
    }
    
    private func linkEmailAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Create credential with email and password
        let credential = EmailAuthProvider.credential(withEmail: linkEmail, password: linkPassword)
        
        // Link the credential to the current user
        user.link(with: credential) { result, error in
            if let error = error {
                linkErrorMessage = error.localizedDescription
                showingLinkError = true
                return
            }
            
            // Update connection types
            connectionTypes.append("Email")
            
            // Clear form and dismiss
            linkEmail = ""
            linkPassword = ""
            showingLinkEmail = false
            showSuccess = true
        }
    }
    
    private func linkGameCenter() {
        // Implement Game Center linking
        // This would require additional Game Center integration
        // and handling of Game Center authentication
        showingLinkGameCenter = false
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Change Password")) {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                }
                
                Section {
                    Button("Update Password") {
                        updatePassword()
                    }
                    .disabled(!isValidInput)
                }
            }
            .navigationTitle("Change Password")
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
        !currentPassword.isEmpty && !newPassword.isEmpty &&
        newPassword == confirmPassword && newPassword.count >= 6
    }
    
    private func updatePassword() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Reauthenticate user before changing password
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        
        user.reauthenticate(with: credential) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            } else {
                user.updatePassword(to: newPassword) { error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                        showingError = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
} 