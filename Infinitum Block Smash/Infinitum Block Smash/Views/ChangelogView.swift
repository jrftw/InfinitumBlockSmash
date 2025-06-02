import SwiftUI

struct ChangelogView: View {
    var body: some View {
        List {
            ForEach(Array(AppVersion.changelog.keys.sorted(by: >)), id: \.self) { version in
                Section(header: Text("Version \(version)")) {
                    ForEach(AppVersion.changelog[version] ?? [], id: \.self) { change in
                        Text(change)
                            .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Changelog")
    }
} 