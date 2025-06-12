import Foundation

struct Bug: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let date: String
    let status: String
    let priority: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case date
        case status
        case priority
    }
}

@MainActor
class BugsService: ObservableObject {
    @Published var bugs: [Bug] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let bugsURL = "https://raw.githubusercontent.com/jrftw/blocksmashannouncements/main/bugs.json"
    
    func fetchBugs() async {
        isLoading = true
        error = nil
        
        do {
            guard let url = URL(string: bugsURL) else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let bugs = try decoder.decode([Bug].self, from: data)
            
            // Sort by priority first (higher numbers first), then by date (newest first)
            self.bugs = bugs.sorted { b1, b2 in
                if b1.priority != b2.priority {
                    return b1.priority > b2.priority
                }
                return b1.date > b2.date
            }
            self.isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
} 