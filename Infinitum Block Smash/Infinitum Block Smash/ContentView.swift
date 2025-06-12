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
    @State private var showingStats = false
    @State private var showingLeaderboardAlert = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false
    @State private var showingNewGameConfirmation = false
    @State private var showingStore = false
    @State private var showingClassicTimedView = false
    @State private var showingAnnouncements = false
    @StateObject private var authViewModel = AuthViewModel()
    @State private var onlineUsersCount = 0
    @State private var dailyPlayersCount = 0
    
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
                    VStack(spacing: 4) {
                        Text("Infinitum Block Smash")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        
                        HStack(spacing: 16) {
                            Text(onlineUsersCountText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            
                            Text("•")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(dailyPlayersCountText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                    }
                    
                    // Menu Buttons
                    VStack(spacing: 15) {
                        if gameState.hasSavedGame() {
                            MenuButton(title: "Resume Game", icon: "play.fill", onDelete: {
                                gameState.deleteSavedGame()
                            }) {
                                showingGameView = true
                            }
                        }
                        
                        MenuButton(title: "Classic", icon: "gamecontroller.fill") {
                            UserDefaults.standard.set(false, forKey: "isTimedMode")
                            showingGameView = true
                        }
                        
                        MenuButton(title: "Classic Timed", icon: "timer") {
                            UserDefaults.standard.set(true, forKey: "isTimedMode")
                            showingClassicTimedView = true
                        }
                        
                        MenuButton(title: "Leaderboard", icon: "trophy.fill") {
                            handleLeaderboardAccess()
                        }
                        
                        MenuButton(title: "Statistics", icon: "chart.bar.fill") {
                            showingStats = true
                        }
                        
                        MenuButton(title: "Change Information", icon: "person.fill") {
                            showingChangeInfo = true
                        }
                        
                        MenuButton(title: "Store", icon: "cart.fill") {
                            showingStore = true
                        }
                        
                        MenuButton(title: "Announcements", icon: "bell.fill") {
                            showingAnnouncements = true
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
                .onChange(of: userID) { newValue in
                    if !newValue.isEmpty {
                        // User logged in, load cloud data
                        Task {
                            await gameState.loadCloudData()
                        }
                    }
                }
            } else {
                AuthView()
            }
        }
        .onAppear {
            // Connect GameState to SceneDelegate
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.gameState = gameState
            }
            
            // Load saved game if it exists
            if gameState.hasSavedGame() {
                Task {
                    do {
                        try await gameState.loadSavedGame()
                        print("[ContentView] Successfully loaded saved game")
                    } catch {
                        print("[ContentView] Error loading saved game: \(error.localizedDescription)")
                    }
                }
            }
            
            setupOnlineUsersTracking()
            setupDailyPlayersTracking()
        }
        .onDisappear {
            cleanup()
        }
        .fullScreenCover(isPresented: $showingGameView) {
            GameView(gameState: gameState)
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(gameState: gameState, showingTutorial: $showingTutorial)
        }
        .fullScreenCover(isPresented: $showingChangeInfo) {
            ChangeInformationView()
        }
        .fullScreenCover(isPresented: $showingAuth) {
            AuthView()
        }
        .sheet(isPresented: $showingStats) {
            StatsView(gameState: gameState)
        }
        .sheet(isPresented: $showingStore) {
            StoreView()
        }
        .fullScreenCover(isPresented: $showingClassicTimedView) {
            ClassicTimedGameView()
        }
        .sheet(isPresented: $showingAnnouncements) {
            AnnouncementsView()
        }
        .sheet(isPresented: $showingNewGameConfirmation) {
            // ... existing code ...
        }
        .alert("Start New Game?", isPresented: $showingNewGameConfirmation) {
            Button("No", role: .cancel) { }
            Button("Yes", role: .destructive) {
                gameState.resetGame()
                showingGameView = true
            }
        } message: {
            Text("This will delete your saved game and start a new one. Are you sure?")
        }
        .alert("Sign in Required", isPresented: $showingLeaderboardAlert) {
            Button("Sign In") {
                showingAuth = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Sign in or create an account to view the leaderboard")
        }
    }
    
    private func handleLeaderboardAccess() {
        if isGuest {
            showingLeaderboardAlert = true
        } else {
            showingLeaderboard = true
        }
    }
    
    private func setupOnlineUsersTracking() {
        // Set initial count
        updateOnlineUsersCount()

        // Observe changes
        NotificationCenter.default.addObserver(
            forName: .onlineUsersCountDidChange,
            object: nil,
            queue: .main
        ) { _ in
            updateOnlineUsersCount()
        }
    }
    
    private func setupDailyPlayersTracking() {
        // Set initial count
        updateDailyPlayersCount()

        // Observe changes
        NotificationCenter.default.addObserver(
            forName: .dailyPlayersCountDidChange,
            object: nil,
            queue: .main
        ) { _ in
            updateDailyPlayersCount()
        }
    }
    
    private func cleanup() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateOnlineUsersCount() {
        Task { @MainActor in
            do {
                onlineUsersCount = try await FirebaseManager.shared.getOnlineUsersCount()
            } catch {
                print("Error getting online users count: \(error)")
                onlineUsersCount = 0
            }
        }
    }
    
    private func updateDailyPlayersCount() {
        Task { @MainActor in
            do {
                dailyPlayersCount = try await FirebaseManager.shared.getDailyPlayersCount()
            } catch {
                print("Error getting daily players count: \(error)")
                dailyPlayersCount = 0
            }
        }
    }
    
    private var onlineUsersCountText: String {
        "\(onlineUsersCount) players online"
    }
    
    private var dailyPlayersCountText: String {
        "\(dailyPlayersCount) players today"
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    var onDelete: (() -> Void)? = nil
    let action: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button
            if onDelete != nil {
                Button(action: {
                    withAnimation(.spring()) {
                        onDelete?()
                        offset = 0
                        isSwiped = false
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 90, height: 50)
                        .background(Color.red)
                        .cornerRadius(15)
                }
                .opacity(isSwiped ? 1 : 0)
                .padding(.trailing, 5)
            }
            
            // Main button
            Button(action: {
                if !isSwiped {
                    action()
                }
            }) {
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
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if onDelete != nil {
                            if gesture.translation.width < 0 {
                                offset = max(gesture.translation.width, -90)
                            }
                        }
                    }
                    .onEnded { gesture in
                        if onDelete != nil {
                            withAnimation(.spring()) {
                                if gesture.translation.width < -50 {
                                    offset = -90
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                    }
            )
        }
    }
}

struct GameModeButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
