import Foundation

protocol ProfileDiscovery {
    func discoverProfiles() -> [BrowserProfile]
}

enum ProfileDiscoveryService {
    private static let builtInDiscoverers: [ProfileDiscovery] =
        BrowserKind.allCases
            .filter { $0.engine == .chromium }
            .map { ChromiumProfileDiscovery(browser: $0) }
        + [FirefoxProfileDiscovery(), SafariProfileDiscovery()]

    /// - Parameter customBrowsers: the current `AppSettings.customBrowsers`
    ///   to discover profiles for, alongside the fixed built-in browsers.
    static func discoverAll(customBrowsers: [CustomBrowser] = []) -> [BrowserProfile] {
        let customDiscoverers = customBrowsers.map { CustomChromiumProfileDiscovery(customBrowser: $0) }
        return (builtInDiscoverers + customDiscoverers).flatMap { $0.discoverProfiles() }
    }
}
