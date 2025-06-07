import SwiftUI

struct ReferralView: View {
    @StateObject private var referralManager = ReferralManager.shared
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Refer Friends")
                .font(.title)
                .fontWeight(.bold)
            
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
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Referral Stats")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Referrals")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("\(referralManager.totalReferrals)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Ad-Free Time")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(referralManager.getAdFreeTimeRemaining())
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Text("Share your referral code with friends and get 24 hours of ad-free time for each friend who signs up!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Referral Code")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 