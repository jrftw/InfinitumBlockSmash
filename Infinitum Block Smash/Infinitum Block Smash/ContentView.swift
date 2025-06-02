import SwiftUI
import GoogleMobileAds

struct ContentView: View {
    @State private var showingGame = false
    @State private var showingLeaderboard = false
    @State private var showingSettings = false
    @State private var showingAuth = false
    @State private var showingChangeInfo = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @State private var gameState = GameState()
    @State private var showingTutorial = false
    
    var isGuest: Bool {
        userID.isEmpty
    }
    
    var isLoggedIn: Bool {
        !userID.isEmpty && !username.isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Infinitum Block Smash")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Button(action: { showingGame = true }) {
                    Text("Play Classic")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(Color.blue)
                        .cornerRadius(15)
                }
                
                Button(action: { showingLeaderboard = true }) {
                    Text("Leaderboards")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(Color.green)
                        .cornerRadius(15)
                }
                
                if isLoggedIn {
                    Button(action: { showingChangeInfo = true }) {
                        Text("Change Information")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(Color.purple)
                            .cornerRadius(15)
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Text("Settings")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(Color.gray)
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        userID = ""
                        username = ""
                    }) {
                        Text("Log Out")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(Color.red)
                            .cornerRadius(15)
                    }
                } else {
                    Button(action: { showingAuth = true }) {
                        Text("Sign In / Sign Up")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(Color.orange)
                            .cornerRadius(15)
                    }
                }
                
                Spacer()
                
                // Add banner ad at the bottom
                BannerAdView(adUnitID: "ca-app-pub-6815311336585204/5099168416")
                    .frame(height: 50)
                    .padding(.bottom, 8)
            }
            .padding()
            .fullScreenCover(isPresented: $showingGame) {
                GameView()
            }
            .sheet(isPresented: $showingLeaderboard) {
                LeaderboardView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(gameState: gameState, showingTutorial: $showingTutorial)
            }
            .sheet(isPresented: $showingAuth) {
                AuthView()
            }
            .sheet(isPresented: $showingChangeInfo) {
                ChangeInfoView()
            }
        }
    }
}

struct ChangeInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("username") private var username: String = ""
    @AppStorage("email") private var email: String = ""
    @AppStorage("phoneNumber") private var phoneNumber: String = ""
    @State private var newUsername: String = ""
    @State private var newEmail: String = ""
    @State private var newPhoneNumber: String = ""
    @State private var showingPasswordChange = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    TextField("Username", text: $newUsername)
                        .textContentType(.username)
                    TextField("Email", text: $newEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    TextField("Phone Number", text: $newPhoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section {
                    Button("Change Password") {
                        showingPasswordChange = true
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        if !newUsername.isEmpty {
                            username = newUsername
                        }
                        if !newEmail.isEmpty {
                            email = newEmail
                        }
                        if !newPhoneNumber.isEmpty {
                            phoneNumber = newPhoneNumber
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Change Information")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .onAppear {
                newUsername = username
                newEmail = email
                newPhoneNumber = phoneNumber
            }
            .sheet(isPresented: $showingPasswordChange) {
                ChangePasswordView()
            }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
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
                        if newPassword != confirmPassword {
                            errorMessage = "New passwords do not match"
                            showingError = true
                            return
                        }
                        // TODO: Implement password change logic
                        dismiss()
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}
