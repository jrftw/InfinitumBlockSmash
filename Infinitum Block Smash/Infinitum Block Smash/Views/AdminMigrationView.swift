import SwiftUI

struct AdminMigrationView: View {
    @State private var isRunning = false
    @State private var migrationStatus = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Referral Code Migration")
                .font(.title)
                .fontWeight(.bold)
            
            if isRunning {
                ProgressView("Running migration...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Button(action: {
                    Task {
                        await runMigration()
                    }
                }) {
                    Text("Run Migration")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            
            if !migrationStatus.isEmpty {
                Text(migrationStatus)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .alert("Migration Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func runMigration() async {
        isRunning = true
        migrationStatus = "Starting migration...\n"
        
        // Redirect print output to our status text
        let migration = ReferralMigration()
        await migration.migrateAllUsers()
        
        isRunning = false
        showAlert = true
        alertMessage = "Migration completed. Check the status above for details."
    }
} 