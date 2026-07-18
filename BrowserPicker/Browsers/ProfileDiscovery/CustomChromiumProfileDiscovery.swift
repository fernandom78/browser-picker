import Foundation

/// Discovers profiles for a user-added Chromium-based browser (see
/// `CustomBrowser`), reusing the same `Local State`/`info_cache` parsing as
/// the built-in Chromium browsers (`ChromiumLocalStateParser`).
///
/// Unlike a built-in `BrowserKind`, we don't know a custom browser's
/// vendor/app-name folder convention ahead of time. This tries the user's
/// manual override first, then a short list of naming conventions that cover
/// the Chromium forks actually seen in the wild:
///   - "<AppName>/Local State"
///   - "<AppName>/User Data/Local State"        (Chrome/Edge/Brave/Arc-style)
///   - "<BundleIdentifier>/Local State"         (Opera-style)
///   - "<BundleIdentifier>/User Data/Local State"
/// If none of those exist, this falls back to a single "Default" profile
/// rather than failing outright — the browser is still usable, just without
/// per-profile routing until the user supplies an override path in Settings.
struct CustomChromiumProfileDiscovery: ProfileDiscovery {
    let customBrowser: CustomBrowser

    func discoverProfiles() -> [BrowserProfile] {
        guard customBrowser.isInstalled else { return [] }

        guard let localStateURL = resolvedLocalStateURL(),
              let entries = ChromiumLocalStateParser.parseProfiles(at: localStateURL) else {
            return [BrowserProfile.defaultProfile(for: customBrowser)]
        }

        return entries.map { entry in
            BrowserProfile(
                id: entry.key,
                displayName: entry.name,
                browser: .custom(customBrowser.id),
                profilePath: entry.key,
                internalName: nil
            )
        }
    }

    private func resolvedLocalStateURL() -> URL? {
        let fileManager = FileManager.default
        let appSupport = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")

        if let override = customBrowser.localStateOverridePath {
            return fileManager.fileExists(atPath: override) ? URL(fileURLWithPath: override) : nil
        }

        let appName = URL(fileURLWithPath: customBrowser.appPath)
            .deletingPathExtension()
            .lastPathComponent
        let bundleIdentifier = Bundle(path: customBrowser.appPath)?.bundleIdentifier

        var candidates = [
            appSupport.appendingPathComponent("\(appName)/Local State"),
            appSupport.appendingPathComponent("\(appName)/User Data/Local State")
        ]
        if let bundleIdentifier {
            candidates.append(appSupport.appendingPathComponent("\(bundleIdentifier)/Local State"))
            candidates.append(appSupport.appendingPathComponent("\(bundleIdentifier)/User Data/Local State"))
        }

        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }
}
