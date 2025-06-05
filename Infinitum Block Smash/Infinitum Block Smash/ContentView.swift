import SwiftUI
import GoogleMobileAds
import FirebaseAuth

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @State private var showingTutorial = false
    @State private var showingLeaderboard = false
    @State private var showingSettings = false
    @State private var showingChangeInfo = false
    @State private var showingGameView = false
    @State private var showingAuth = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false
    
    var isLoggedIn: Bool {
        !userID.isEmpty && (!username.isEmpty || isGuest)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.2, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isLoggedIn {
                VStack(spacing: 20) {
                    // App Icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // App Title
                    Text("Infinitum Block Smash")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                    
                    // Menu Buttons
                    VStack(spacing: 15) {
                        if gameState.hasSavedGame() {
                            MenuButton(title: "Resume Game", icon: "play.fill") {
                                do {
                                    try gameState.loadSavedGame()
                                    showingGameView = true
                                } catch {
                                    print("[MainMenu] Error loading saved game: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        MenuButton(title: "Play Classic", icon: "gamecontroller.fill") {
                            gameState.deleteSavedGame() // Delete any existing saved game when starting a new one
                            showingGameView = true
                        }
                        
                        MenuButton(title: "Leaderboard", icon: "trophy.fill") {
                            showingLeaderboard = true
                        }
                        
                        MenuButton(title: "Change Information", icon: "person.fill") {
                            showingChangeInfo = true
                        }
                        
                        MenuButton(title: "Settings", icon: "gear") {
                            showingSettings = true
                        }
                        
                        MenuButton(title: "Log Out", icon: "rectangle.portrait.and.arrow.right") {
                            userID = ""
                            username = ""
                            isGuest = false
                        }
                    }
                    .padding(.top, 20)
                }
                .padding()
            } else {
                Button(action: { showingAuth = true }) {
                    Text("Sign In / Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showingGameView) {
            GameView()
        }
        .fullScreenCover(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(gameState: gameState, showingTutorial: $showingTutorial)
        }
        .fullScreenCover(isPresented: $showingChangeInfo) {
            ChangeInformationView()
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}
