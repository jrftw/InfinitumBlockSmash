import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .bold()
                
                Group {
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .foregroundColor(.secondary)
                    
                    Text("1. Acceptance of Terms")
                        .font(.title2)
                        .bold()
                    
                    Text("By downloading and using Infinitum Block Smash, you agree to these Terms of Service. If you do not agree, please do not use the app.")
                }
                
                Group {
                    Text("2. License")
                        .font(.title2)
                        .bold()
                    
                    Text("We grant you a limited, non-exclusive, non-transferable license to use the app for personal, non-commercial purposes.")
                }
                
                Group {
                    Text("3. User Conduct")
                        .font(.title2)
                        .bold()
                    
                    Text("You agree not to:")
                        .padding(.bottom, 5)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        BulletPoint("Modify or reverse engineer the app")
                        BulletPoint("Use the app for any illegal purpose")
                        BulletPoint("Attempt to gain unauthorized access")
                    }
                }
                
                Group {
                    Text("4. Intellectual Property")
                        .font(.title2)
                        .bold()
                    
                    Text("All content, features, and functionality of the app are owned by us and are protected by international copyright, trademark, and other intellectual property laws.")
                }
                
                Group {
                    Text("5. Disclaimer")
                        .font(.title2)
                        .bold()
                    
                    Text("The app is provided 'as is' without any warranties of any kind, either express or implied.")
                }
                
                Group {
                    Text("6. Limitation of Liability")
                        .font(.title2)
                        .bold()
                    
                    Text("We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the app.")
                }
                
                Group {
                    Text("7. Changes to Terms")
                        .font(.title2)
                        .bold()
                    
                    Text("We reserve the right to modify these terms at any time. We will notify you of any changes by updating the 'Last Updated' date.")
                }
                
                Group {
                    Text("8. Contact")
                        .font(.title2)
                        .bold()
                    
                    Text("For questions about these Terms, please contact us at:")
                        .padding(.bottom, 5)
                    
                    Text("support@infinitumblocksmash.com")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
} 