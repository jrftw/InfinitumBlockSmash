import SwiftUI
import GoogleMobileAds

struct ContentView: View {
    @State private var showingGame = false
    @State private var showingLeaderboard = false
    @State private var showingSettings = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @State private var showChangeUsername = false
    @State private var newUsername = ""
    
    var isGuest: Bool {
        !userID.isEmpty && username.isEmpty
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
                        Text("Sign Out")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(Color.red)
                            .cornerRadius(15)
                    }
                }
                
                if isGuest {
                    Button(action: {
                        userID = ""
                        username = ""
                    }) {
                        Text("Sign Up")
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
                // Placeholder SettingsView
                Text("Settings View Coming Soon")
                    .font(.largeTitle)
                    .padding()
            }
            .alert("Change Username", isPresented: $showChangeUsername, actions: {
                TextField("New Username", text: $newUsername)
                Button("Save") {
                    if !newUsername.trimmingCharacters(in: .whitespaces).isEmpty {
                        username = newUsername.trimmingCharacters(in: .whitespaces)
                        newUsername = ""
                    }
                }
                Button("Cancel", role: .cancel) { newUsername = "" }
            }, message: {
                Text("Enter your new username.")
            })
        }
    }
}
