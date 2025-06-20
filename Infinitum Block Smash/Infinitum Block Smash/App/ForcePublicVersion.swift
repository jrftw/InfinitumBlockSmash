/******************************************************
 * FILE: ForcePublicVersion.swift
 * MARK: Public Version Update Enforcer
 * CREATED:   6/19/2025 by @jrftw
 * MODIFIED LAST:   6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Manages forced updates to public versions, preventing users from using
 * beta versions and directing them to download the latest public release.
 *
 * KEY RESPONSIBILITIES:
 * - Display update prompt for beta version users
 * - Manage update prompt state persistence
 * - Provide App Store download link
 * - Handle update window presentation
 * - Prevent app usage until public version is installed
 *
 * MAJOR DEPENDENCIES:
 * - SwiftUI: UI framework for update prompt interface
 * - UIKit: Window management and app state
 * - UserDefaults: Persistent storage for update state
 * - UIApplication: App state and URL handling
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Modern declarative UI framework
 * - UIKit: iOS UI framework for window management
 * - Foundation: Core framework for data structures
 *
 * ARCHITECTURE ROLE:
 * Acts as a version enforcement layer that ensures users are using
 * the appropriate public version of the app.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Update prompt must be displayed before main app interface
 * - Window level must be higher than normal UI
 * - App Store link must be valid and accessible
 * - Update state persists across app launches
 */

/******************************************************
 * REVIEW NOTES:
 * - Critical for beta version management
 * - App Store URL is hardcoded and must be maintained
 * - Window management requires careful memory handling
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add version comparison logic
 * - Implement automatic update detection
 * - Add update progress tracking
 ******************************************************/

import SwiftUI

class ForcePublicVersion {
    static let shared = ForcePublicVersion()
    
    private init() {}
    
    @AppStorage("forcePublicVersion") var isEnabled = false
    
    func showUpdatePrompt() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                print("No window scene available")
                return
            }
            
            let updateWindow = UIWindow(windowScene: windowScene)
            updateWindow.windowLevel = .alert + 1
            
            // Create the update view
            let updateView = PublicVersionUpdateView()
            let hostingController = UIHostingController(rootView: updateView)
            hostingController.view.backgroundColor = .clear
            
            updateWindow.rootViewController = hostingController
            updateWindow.makeKeyAndVisible()
            
            // Store the window to prevent it from being deallocated
            objc_setAssociatedObject(UIApplication.shared, "updateWindow", updateWindow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

struct PublicVersionUpdateView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Update Required")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("No beta versions are available. Please download the latest public version to continue.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/id6746708231") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Download Latest Version")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
} 
