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
