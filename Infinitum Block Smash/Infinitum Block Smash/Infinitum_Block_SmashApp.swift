// MARK: - Imports
import SwiftUI
import GoogleMobileAds
import FirebaseCore
import AppTrackingTransparency
import AdSupport

// MARK: - Main App Entry Point
@main
struct Infinitum_Block_SmashApp: App {
    @State private var showGame = false
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("isGuest") private var isGuest: Bool = false

    // MARK: - Initializer
    init() {
        FirebaseApp.configure()
        MobileAds.shared.start { status in
            print("AdMob initialization status: \(status)")
        }
        // Force log out guest on app launch
        if isGuest {
            userID = ""
            username = ""
            isGuest = false
        }
        // Request App Tracking Transparency on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("ATT status: \(status.rawValue)")
                }
            }
        }
    }

    // MARK: - Scene Definition
       var body: some Scene {
           WindowGroup {
               Group {
                   if userID.isEmpty || username.isEmpty {
                       AuthView()
                   } else {
                       ContentView()
                   }
               }
               .onAppear {
                   print("[App Launch] userID: \(userID), username: \(username), isGuest: \(isGuest)")
                   if userID.isEmpty || username.isEmpty {
                       print("[App Launch] Showing AuthView (userID or username is empty)")
                   } else {
                       print("[App Launch] Showing ContentView (user is signed in)")
                   }
               }
           }
       }
   }

// MARK: - HomeView
struct HomeView: View {
    @Binding var showGame: Bool

    var body: some View {
        ZStack {
            Color(.systemIndigo).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text("Infinitum Block Smash")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 8)

                Spacer()

                Button(action: {
                    showGame = true
                }) {
                    Text("Play Classic")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                }

                Spacer()
            }
        }
    }
}
