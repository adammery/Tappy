import Foundation
import Observation

@Observable
@MainActor
final class UpdateChecker {
    static let currentVersion = "0.8.2"
    static let repoOwner = "adammery"
    static let repoName = "Tappy"

    var latestVersion: String?
    var updateURL: String?
    var isChecking = false
    var hasChecked = false

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return latest != Self.currentVersion
    }

    func check() async {
        isChecking = true
        defer { isChecking = false; hasChecked = true }

        guard let url = URL(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

        struct Release: Decodable {
            let tag_name: String
            let html_url: String
        }

        guard let release = try? JSONDecoder().decode(Release.self, from: data) else { return }

        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        latestVersion = version
        updateURL = release.html_url
    }
}
