import AppKit
import Foundation

struct BrowserLauncher {
    /// - Parameter customBrowsers: the current `AppSettings.customBrowsers`,
    ///   needed to resolve `profile.browser` when it's a `.custom` identity.
    /// - Parameter openPrivately: opens a private/incognito window instead
    ///   of a normal one, still scoped to `profile`'s browser + profile
    ///   (except Safari — see `SafariLauncher`'s private-window path).
    func open(
        url: URL,
        profile: BrowserProfile,
        customBrowsers: [CustomBrowser] = [],
        openPrivately: Bool = false,
        safariProfileNames: [String] = []
    ) async throws {
        guard let resolved = profile.browser.resolved(customBrowsers: customBrowsers) else {
            throw BrowserPickerError.profileNotFound
        }
        guard resolved.isInstalled else {
            throw BrowserPickerError.browserNotInstalled(resolved.displayName)
        }

        switch resolved.engine {
        case .chromium:
            try launchChromium(url: url, profile: profile, resolved: resolved, openPrivately: openPrivately)
        case .gecko:
            try launchFirefox(url: url, profile: profile, resolved: resolved, openPrivately: openPrivately)
        case .webkit:
            try SafariLauncher().open(
                url: url,
                profile: profile,
                allProfileNames: safariProfileNames,
                openPrivately: openPrivately
            )
        }
    }

    private func launchChromium(url: URL, profile: BrowserProfile, resolved: ResolvedBrowser, openPrivately: Bool) throws {
        let directory = profile.profilePath ?? "Default"
        var arguments = ["--profile-directory=\(directory)"]
        // Chromium opens the incognito window inside the given profile's
        // identity (separate cookie jar, but still "signed in" as that
        // profile) — exactly the "clean tab, same identity" QA testing
        // usually wants, rather than a fully anonymous session.
        if openPrivately { arguments.append("--incognito") }
        arguments.append(url.absoluteString)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolved.executablePath)
        process.arguments = arguments
        try process.run()
    }

    private func launchFirefox(url: URL, profile: BrowserProfile, resolved: ResolvedBrowser, openPrivately: Bool) throws {
        // "-private-window <url>" both requests a private window and
        // supplies the URL to open in it, replacing the plain "-url" pair
        // used for a normal window.
        let urlArguments = openPrivately
            ? ["-private-window", url.absoluteString]
            : ["-url", url.absoluteString]

        var attempts: [[String]] = []

        if let profilePath = profile.profilePath,
           profile.id != "\(BrowserKind.firefox.rawValue)-default" {
            attempts.append(["--profile", profilePath] + urlArguments)
            if let internalName = profile.internalName {
                attempts.append(["-P", internalName] + urlArguments)
                attempts.append(["-P", internalName, "-no-remote"] + urlArguments)
            }
        } else {
            attempts.append(urlArguments)
        }

        var lastError: Error?
        for arguments in attempts {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: resolved.executablePath)
            process.arguments = arguments
            do {
                try process.run()
                return
            } catch {
                lastError = error
            }
        }

        throw BrowserPickerError.launchFailed(lastError?.localizedDescription ?? "Unknown error")
    }
}
