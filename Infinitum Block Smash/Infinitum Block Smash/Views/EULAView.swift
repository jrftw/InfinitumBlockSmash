import SwiftUI

struct EULAView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var eulaText: String = ""
    
    var body: some View {
        ScrollView {
            Text(eulaText)
                .padding()
                .font(.body)
        }
        .navigationTitle("End User License Agreement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadEULA()
        }
    }
    
    private func loadEULA() {
        if let path = Bundle.main.path(forResource: "EULA", ofType: "md") {
            do {
                eulaText = try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                eulaText = "Error loading EULA. Please try again later."
            }
        } else {
            // Fallback to hardcoded EULA if file is not found
            eulaText = """
            # End User License Agreement (EULA)

            Last Updated: [Current Date]

            ## 1. Acceptance of Terms

            By downloading, installing, or using Infinitum Block Smash ("the App"), you agree to be bound by this End User License Agreement ("EULA"). If you do not agree to these terms, please do not use the App.

            ## 2. License Grant

            Subject to your compliance with this EULA, we grant you a limited, non-exclusive, non-transferable, revocable license to use the App on your iOS device.

            ## 3. Subscription Terms

            ### 3.1 Subscription Plans
            The App offers auto-renewable subscriptions with the following terms:
            - Subscription Title: Infinitum Block Smash Premium
            - Subscription Length: Monthly
            - Price: [Your subscription price]
            - Price per unit: [Price per month]

            ### 3.2 Auto-Renewal
            - Your subscription will automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period
            - Your account will be charged for renewal within 24 hours prior to the end of the current period
            - You can manage and cancel your subscriptions by going to your account settings on the App Store after purchase

            ### 3.3 Free Trial
            If offered, any free trial period will automatically convert to a paid subscription unless cancelled at least 24 hours before the trial period ends.

            ## 4. User Content and Conduct

            You agree not to:
            - Use the App for any illegal purpose
            - Attempt to gain unauthorized access to the App
            - Interfere with the proper functioning of the App
            - Use the App to harass, abuse, or harm others

            ## 5. Intellectual Property

            All content, features, and functionality of the App are owned by us and are protected by international copyright, trademark, and other intellectual property laws.

            ## 6. Termination

            We may terminate or suspend your access to the App immediately, without prior notice, for any reason, including if you breach this EULA.

            ## 7. Disclaimer of Warranties

            The App is provided "as is" without warranties of any kind, either express or implied.

            ## 8. Limitation of Liability

            To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages.

            ## 9. Changes to EULA

            We reserve the right to modify this EULA at any time. We will notify you of any changes by posting the new EULA on this page.

            ## 10. Contact Information

            For any questions about this EULA, please contact us at [Your Contact Information].

            ## 11. Governing Law

            This EULA shall be governed by and construed in accordance with the laws of [Your Jurisdiction].
            """
        }
    }
}

#Preview {
    NavigationView {
        EULAView()
    }
} 