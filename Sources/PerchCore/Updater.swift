import Foundation

/// Checks GitHub for a newer Perch release. Uses the public releases API, so it
/// works once the repo is public; on a private repo (or offline) it fails
/// gracefully and callers fall back to opening the releases page.
public final class Updater {
    public static let releasesPage = URL(string: "https://github.com/gitLRD/perch/releases/latest")!
    private let apiURL = URL(string: "https://api.github.com/repos/gitLRD/perch/releases/latest")!
    private let currentVersion: String
    private let lastCheckKey = "PerchLastUpdateCheck"

    public init(currentVersion: String) { self.currentVersion = currentVersion }

    public enum Result: Sendable {
        case upToDate(String)
        case updateAvailable(tag: String, url: URL)
        case failed(String)
    }

    /// True if it's been longer than `interval` (default 7 days) since the last check.
    public func checkDue(interval: TimeInterval = 7 * 24 * 3600) -> Bool {
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        return last == 0 || Date().timeIntervalSince1970 - last > interval
    }

    public func check(completion: @escaping @Sendable (Result) -> Void) {
        var req = URLRequest(url: apiURL, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Perch", forHTTPHeaderField: "User-Agent")
        let key = lastCheckKey
        let current = currentVersion
        URLSession.shared.dataTask(with: req) { data, resp, err in
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
            if let err = err { completion(.failed(err.localizedDescription)); return }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else {
                completion(.failed("no release info (is the repo public?)")); return
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let url = (obj["html_url"] as? String).flatMap(URL.init) ?? Updater.releasesPage
            if Updater.isNewer(latest, than: current) {
                completion(.updateAvailable(tag: tag, url: url))
            } else {
                completion(.upToDate(current))
            }
        }.resume()
    }

    /// Numeric component-wise semver comparison ("0.10.0" > "0.9.0").
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
