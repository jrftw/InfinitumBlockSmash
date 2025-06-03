import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .bold()
                
                Group {
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .foregroundColor(.secondary)
                    
                    Text("Information We Collect")
                        .font(.title2)
                        .bold()
                    
                    Text("We collect minimal information necessary for the app to function:")
                        .padding(.bottom, 5)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        BulletPoint("Game progress and high scores")
                        BulletPoint("App preferences and settings")
                        BulletPoint("Device information for app optimization")
                    }
                }
                
                Group {
                    Text("How We Use Your Information")
                        .font(.title2)
                        .bold()
                    
                    Text("Your information is used to:")
                        .padding(.bottom, 5)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        BulletPoint("Save your game progress")
                        BulletPoint("Provide game features and functionality")
                        BulletPoint("Improve app performance and user experience")
                    }
                }
                
                Group {
                    Text("Data Storage")
                        .font(.title2)
                        .bold()
                    
                    Text("All data is stored locally on your device. We do not share your information with third parties.")
                }
                
                Group {
                    Text("Your Rights")
                        .font(.title2)
                        .bold()
                    
                    Text("You have the right to:")
                        .padding(.bottom, 5)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        BulletPoint("Access your stored data")
                        BulletPoint("Delete your data")
                        BulletPoint("Opt out of analytics")
                    }
                }
                
                Group {
                    Text("Contact Us")
                        .font(.title2)
                        .bold()
                    
                    Text("If you have any questions about this Privacy Policy, please contact us at:")
                        .padding(.bottom, 5)
                    
                    Text("support@infinitumblocksmash.com")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text("•")
                .padding(.trailing, 5)
            Text(text)
        }
    }
} 