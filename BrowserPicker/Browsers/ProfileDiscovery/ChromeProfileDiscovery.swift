import Foundation

/// Shared "Local State" JSON parsing used by both the built-in
/// `ChromiumProfileDiscovery` (below) and `CustomChromiumProfileDiscovery`
/// (for user-added Chromium-based browsers) — every Chromium build stores
/// its profile list the same way, regardless of which fork it is.
enum ChromiumLocalStateParser {
    /// Parses `profile.info_cache` into (profileKey, displayName) pairs,
    /// sorted by key. Returns nil if the file is missing or not in the
    /// expected shape — callers fall back to a single "Default" profile.
    static func parseProfiles(at url: URL) -> [(key: String, name: String)]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            return nil
        }

        return infoCache.keys.sorted().map { key in
            let entry = infoCache[key] as? [String: Any]
            let name = entry?["name"] as? String ?? key
            return (key: key, name: name)
        }
    }
}

/// Discovers profiles for any Chromium-based browser (Chrome, Edge, Brave, Vivaldi)
/// by reading the browser's `Local State` JSON.
struct ChromiumProfileDiscovery: ProfileDiscovery {
    let browser: BrowserKind

    private var localStateURL: URL? {
        guard let relativePath = browser.chromiumLocalStateRelativePath else { return nil }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(relativePath)")
    }

    func discoverProfiles() -> [BrowserProfile] {
        guard browser.isInstalled else { return [] }

        guard let localStateURL,
              let entries = ChromiumLocalStateParser.parseProfiles(at: localStateURL) else {
            return [BrowserProfile.defaultProfile(for: browser)]
        }

        return entries.map { entry in
            BrowserProfile(
                id: entry.key,
                displayName: entry.name,
                browser: .builtIn(browser),
                profilePath: entry.key,
                internalName: nil
            )
        }
    }
}
