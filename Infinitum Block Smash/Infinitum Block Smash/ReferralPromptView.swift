import SwiftUI

struct ReferralPromptView: View {
    @StateObject private var referralManager = ReferralManager.shared
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appOpenManager = AppOpenManager.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Refer Friends")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Share your referral code with friends and get 24 hours of ad-free time for each friend who signs up!")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Referral Code")
                        .font(.headline)
                    
                    HStack {
                        Text(referralManager.referralCode)
                            .font(.system(.title2, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button(action: {
                            UIPasteboard.general.string = referralManager.referralCode
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                
                HStack(spacing: 20) {
                    Button(action: {
                        appOpenManager.markReferralAsShown()
                    }) {
                        Text("Maybe Later")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
        .sheet(isPresented: $showingShareSheet) {
            let message = """
            Join me in playing Infinitum Block Smash! Use my referral code \(referralManager.referralCode) when you sign up and we both get 24 hours of ad-free time!

            Download the game here:
            https://apps.apple.com/us/app/infinitum-block-smash/id6746708231
            """
            ShareSheet(activityItems: [message])
        }
    }
}
