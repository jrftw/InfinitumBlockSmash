import SwiftUI

struct BugsView: View {
    @StateObject private var bugsService = BugsService()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.2, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if bugsService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else if let error = bugsService.error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("Failed to load bugs")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        Task {
                            await bugsService.fetchBugs()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            } else if bugsService.bugs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("No Known Bugs")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Everything is running smoothly!")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(bugsService.bugs) { bug in
                            BugCard(bug: bug)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await bugsService.fetchBugs()
        }
    }
}

struct BugCard: View {
    let bug: Bug
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bug.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(bug.date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(bug.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            HStack {
                Text("Status: \(bug.status)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("Priority: \(bug.priority)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
} 