import SwiftUI
import FirebaseAuth

struct ProfileCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Complete Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please provide your email and username to continue. This information is required for leaderboard participation.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Form
                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Username field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal)
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Submit button
                Button(action: completeProfile) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isLoading ? "Updating..." : "Complete Profile")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || email.isEmpty || username.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadCurrentData()
        }
        .alert("Profile Updated", isPresented: $showingSuccess) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Your profile has been successfully updated. You can now participate in leaderboards!")
        }
    }
    
    private func loadCurrentData() {
        // Load current user data
        if let user = Auth.auth().currentUser {
            email = user.email ?? ""
        }
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        
        // Remove "unknown" username
        if username == "unknown" {
            username = ""
        }
    }
    
    private func completeProfile() {
        guard !email.isEmpty && !username.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        // Validate email
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // Validate username
        guard username.count >= 1 else {
            errorMessage = "Username must be at least 1 character long"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Update email if needed
                if let user = Auth.auth().currentUser, user.email != email {
                    try await user.sendEmailVerification(beforeUpdatingEmail: email)
                }
                
                // Save username
                UserDefaults.standard.set(username, forKey: "username")
                
                // Update user profile in Firebase if needed
                if let user = Auth.auth().currentUser {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = username
                    try await changeRequest.commitChanges()
                }
                
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
} 