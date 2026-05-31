//
//  UpdateChecker.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/20.
//

import Foundation
import Combine

struct ReleaseInfo: Decodable {
    let tagName: String
    let htmlUrl: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case name
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var latestReleaseUrl: String?
    @Published var errorMessage: String?

    private let repo = "Fran0K/NotchRoller"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil

        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self else { return }
                self.isChecking = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let data,
                      let release = try? JSONDecoder().decode(ReleaseInfo.self, from: data) else {
                    self.errorMessage = "Failed to parse release info"
                    return
                }

                let remote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                self.latestVersion = remote
                self.latestReleaseUrl = release.htmlUrl
                self.updateAvailable = self.isNewer(remote: remote, local: self.currentVersion)
            }
        }.resume()
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(remoteParts.count, localParts.count)

        for i in 0..<maxLen {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}
