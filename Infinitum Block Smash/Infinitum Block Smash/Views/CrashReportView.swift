import SwiftUI
import FirebaseCrashlytics

struct CrashReportView: View {
    @State private var crashDescription: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Crash Information")) {
                    Text("If you've experienced a crash, please describe what you were doing when it happened. This will help us fix the issue.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $crashDescription)
                        .frame(height: 150)
                }
                
                Section {
                    Button(action: submitCrashReport) {
                        Text("Submit Crash Report")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                }
                
                Section(header: Text("Device Information")) {
                    let device = UIDevice.current
                    InfoRow(title: "Device Model", value: device.model)
                    InfoRow(title: "iOS Version", value: device.systemVersion)
                    if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        InfoRow(title: "App Version", value: appVersion)
                    }
                }
            }
            .navigationTitle("Report Crash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Crash Report", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("Thank you") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func submitCrashReport() {
        guard !crashDescription.isEmpty else {
            alertMessage = "Please describe what you were doing when the crash occurred."
            showingAlert = true
            return
        }
        
        // Log the crash report
        CrashReporter.shared.log("User submitted crash report: \(crashDescription)")
        
        // Set custom values
        CrashReporter.shared.setCustomValue(crashDescription, forKey: "crash_description")
        CrashReporter.shared.setCustomValue(Date(), forKey: "crash_report_time")
        
        // Show success message
        alertMessage = "Thank you for your report! We'll investigate the issue."
        showingAlert = true
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CrashReportView()
} 