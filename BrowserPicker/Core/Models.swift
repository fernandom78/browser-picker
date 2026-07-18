import AppKit
import Foundation

enum BrowserEngine {
    case chromium
    case gecko
    case webkit
}

enum BrowserKind: String, Codable, CaseIterable, Identifiable {
    case chrome
    case edge
    case brave
    case vivaldi
    case opera
    case arc
    case firefox
    case safari

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .edge: return "Edge"
        case .brave: return "Brave"
        case .vivaldi: return "Vivaldi"
        case .opera: return "Opera"
        case .arc: return "Arc"
        case .firefox: return "Firefox"
        case .safari: return "Safari"
        }
    }

    var engine: BrowserEngine {
        switch self {
        case .chrome, .edge, .brave, .vivaldi, .opera, .arc: return .chromium
        case .firefox: return .gecko
        case .safari: return .webkit
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .opera: return "com.operasoftware.Opera"
        case .arc: return "company.thebrowser.Browser"
        case .firefox: return "org.mozilla.firefox"
        case .safari: return "com.apple.Safari"
        }
    }

    /// Default install location, used as a fallback when bundle-ID lookup fails.
    private var defaultAppPath: String {
        switch self {
        case .chrome: return "/Applications/Google Chrome.app"
        case .edge: return "/Applications/Microsoft Edge.app"
        case .brave: return "/Applications/Brave Browser.app"
        case .vivaldi: return "/Applications/Vivaldi.app"
        case .opera: return "/Applications/Opera.app"
        case .arc: return "/Applications/Arc.app"
        case .firefox: return "/Applications/Firefox.app"
        case .safari: return "/Applications/Safari.app"
        }
    }

    /// Resolves the installed app URL by bundle identifier (any location), else the default path.
    var installedAppURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }
        if FileManager.default.fileExists(atPath: defaultAppPath) {
            return URL(fileURLWithPath: defaultAppPath)
        }
        return nil
    }

    var isInstalled: Bool { installedAppURL != nil }

    var appPath: String {
        installedAppURL?.path ?? defaultAppPath
    }

    /// Absolute path to the launchable executable inside the resolved app bundle.
    var executablePath: String {
        if let appURL = installedAppURL,
           let executableURL = Bundle(url: appURL)?.executableURL {
            return executableURL.path
        }
        return "\(defaultAppPath)/Contents/MacOS/\(defaultExecutableName)"
    }

    private var defaultExecutableName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .edge: return "Microsoft Edge"
        case .brave: return "Brave Browser"
        case .vivaldi: return "Vivaldi"
        case .opera: return "Opera"
        case .arc: return "Arc"
        case .firefox: return "firefox"
        case .safari: return "Safari"
        }
    }

    /// Path (relative to `~/Library/Application Support`) of the Chromium "Local State" file.
    ///
    /// Most Chromium forks nest their profile data under a "<Vendor>/<Product>"
    /// folder (Chrome, Edge, Brave, Vivaldi). Opera is the odd one out and uses
    /// its bundle identifier as the folder name directly, with no "User Data"
    /// segment. Arc nests under a plain "Arc/User Data" folder. Both were
    /// confirmed against real installs rather than assumed, since a wrong path
    /// here silently degrades to a single "Default" profile (see
    /// `ChromiumProfileDiscovery`) instead of failing loudly.
    var chromiumLocalStateRelativePath: String? {
        switch self {
        case .chrome: return "Google/Chrome/Local State"
        case .edge: return "Microsoft Edge/Local State"
        case .brave: return "BraveSoftware/Brave-Browser/Local State"
        case .vivaldi: return "Vivaldi/Local State"
        case .opera: return "com.operasoftware.Opera/Local State"
        case .arc: return "Arc/User Data/Local State"
        case .firefox, .safari: return nil
        }
    }
}

/// A user-added browser that isn't one of the built-in `BrowserKind` cases.
///
/// Every Mac browser worth supporting that we *don't* ship native support for
/// turns out, in practice, to be a Chromium fork — there's no other WebKit
/// browser besides Safari and no other notable Gecko browser besides Firefox
/// on macOS. So a custom browser is always assumed to be Chromium-engine:
/// same `--profile-directory=`/`--incognito` launch args, same `Local
/// State`/`info_cache` profile discovery as the built-in Chromium browsers
/// (see `ChromiumProfileDiscovery`), just pointed at a user-chosen app.
struct CustomBrowser: Codable, Identifiable, Hashable {
    var id: UUID
    var displayName: String
    /// Absolute path to the .app bundle, chosen via an NSOpenPanel in Settings.
    var appPath: String
    /// Manual override for the Chromium "Local State" file when
    /// auto-detection (a handful of common Chromium folder-naming
    /// conventions, tried in `CustomChromiumProfileDiscovery`) can't find it.
    /// When both auto-detection and this are unavailable, discovery falls
    /// back to a single "Default" profile rather than failing outright.
    var localStateOverridePath: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        appPath: String,
        localStateOverridePath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.appPath = appPath
        self.localStateOverridePath = localStateOverridePath
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    /// Absolute path to the launchable executable inside the app bundle.
    var executablePath: String {
        Bundle(path: appPath)?.executableURL?.path ?? appPath
    }
}

/// Identifies which browser a profile or routing target belongs to: either
/// one of the fixed, native `BrowserKind` cases, or a `CustomBrowser` added
/// by the user (looked up by id in `AppSettings.customBrowsers`).
///
/// Encodes as a single JSON string so it stays wire-compatible with the
/// original `BrowserKind`-typed field it replaces — a built-in encodes
/// exactly as its raw value ("chrome", "safari", ...), so every rule already
/// saved in an existing `config.json` decodes unchanged with no migration
/// step. A custom browser encodes as "custom:<uuid>", a prefix that can
/// never collide with a `BrowserKind` raw value.
enum BrowserIdentity: Hashable {
    case builtIn(BrowserKind)
    case custom(UUID)

    private static let customPrefix = "custom:"

    var displayName: String {
        switch self {
        case .builtIn(let kind): return kind.displayName
        case .custom: return "Custom"
        }
    }
}

extension BrowserIdentity: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw.hasPrefix(Self.customPrefix),
           let uuid = UUID(uuidString: String(raw.dropFirst(Self.customPrefix.count))) {
            self = .custom(uuid)
        } else if let kind = BrowserKind(rawValue: raw) {
            self = .builtIn(kind)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown browser identity: \(raw)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .builtIn(let kind): try container.encode(kind.rawValue)
        case .custom(let id): try container.encode("\(Self.customPrefix)\(id.uuidString)")
        }
    }
}

/// The concrete engine/executable/install info behind a `BrowserIdentity`,
/// resolved against the current list of custom browsers. Centralizes the
/// built-in-vs-custom branch so callers (launcher, icon provider) don't each
/// need their own `switch` over `BrowserIdentity`.
struct ResolvedBrowser {
    let engine: BrowserEngine
    let executablePath: String
    let isInstalled: Bool
    let displayName: String
}

extension BrowserIdentity {
    /// Returns nil only for a `.custom` identity whose `CustomBrowser` was
    /// removed from settings after a rule/profile referencing it was saved.
    func resolved(customBrowsers: [CustomBrowser]) -> ResolvedBrowser? {
        switch self {
        case .builtIn(let kind):
            return ResolvedBrowser(
                engine: kind.engine,
                executablePath: kind.executablePath,
                isInstalled: kind.isInstalled,
                displayName: kind.displayName
            )
        case .custom(let id):
            guard let custom = customBrowsers.first(where: { $0.id == id }) else { return nil }
            return ResolvedBrowser(
                engine: .chromium,
                executablePath: custom.executablePath,
                isInstalled: custom.isInstalled,
                displayName: custom.displayName
            )
        }
    }
}

struct BrowserProfile: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var browser: BrowserIdentity
    var profilePath: String?
    /// Firefox `profiles.ini` Name field — used for `-P` launch fallback.
    var internalName: String?

    static func defaultProfile(for browser: BrowserKind) -> BrowserProfile {
        BrowserProfile(
            id: "\(browser.rawValue)-default",
            displayName: "Default",
            browser: .builtIn(browser),
            profilePath: nil,
            internalName: nil
        )
    }

    static func defaultProfile(for custom: CustomBrowser) -> BrowserProfile {
        BrowserProfile(
            id: "custom-\(custom.id.uuidString)-default",
            displayName: "Default",
            browser: .custom(custom.id),
            profilePath: nil,
            internalName: nil
        )
    }
}

struct RouteTarget: Codable, Hashable {
    var browser: BrowserIdentity
    var profileId: String

    var label: String {
        "\(browser.displayName) · \(profileId)"
    }
}

enum FallbackMode: String, Codable, CaseIterable, Identifiable {
    case silent
    case picker

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .silent: return "Use menu bar selection"
        case .picker: return "Show picker"
        }
    }
}

enum RuleMatcherKind: String, Codable, CaseIterable, Identifiable {
    case urlContains
    case hostEquals
    case hostSuffix

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .urlContains: return "URL contains"
        case .hostEquals: return "Host equals"
        case .hostSuffix: return "Host suffix"
        }
    }
}

struct RuleMatcher: Codable, Hashable {
    var kind: RuleMatcherKind
    var value: String

    func matches(url: URL, sourceApp: String?) -> Bool {
        let urlString = url.absoluteString.lowercased()
        let host = (url.host ?? "").lowercased()
        let valueLower = value.lowercased()

        switch kind {
        case .urlContains:
            return urlString.contains(valueLower)
        case .hostEquals:
            return host == valueLower
        case .hostSuffix:
            return host.hasSuffix(valueLower.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
                || host == valueLower.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
}

struct RoutingRule: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var enabled: Bool
    var priority: Int
    var matcher: RuleMatcher
    var target: RouteTarget
    /// When true, matched links open in a private/incognito window instead
    /// of a normal one, still scoped to `target`'s browser + profile.
    var openPrivately: Bool

    init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        priority: Int,
        matcher: RuleMatcher,
        target: RouteTarget,
        openPrivately: Bool = false
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.priority = priority
        self.matcher = matcher
        self.target = target
        self.openPrivately = openPrivately
    }

    // Manual Decodable so rules saved by older builds (before `openPrivately`
    // existed) keep loading instead of failing to decode the whole config —
    // a missing key just defaults to false rather than an error.
    enum CodingKeys: String, CodingKey {
        case id, name, enabled, priority, matcher, target, openPrivately
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        priority = try container.decode(Int.self, forKey: .priority)
        matcher = try container.decode(RuleMatcher.self, forKey: .matcher)
        target = try container.decode(RouteTarget.self, forKey: .target)
        openPrivately = try container.decodeIfPresent(Bool.self, forKey: .openPrivately) ?? false
    }
}

struct AppSettings: Codable {
    var fallbackMode: FallbackMode
    var defaultTarget: RouteTarget
    var rules: [RoutingRule]
    /// Browsers the user added manually via Settings → Browsers → "Add
    /// Custom Browser…", beyond the native `BrowserKind` list.
    var customBrowsers: [CustomBrowser]

    static var `default`: AppSettings {
        AppSettings(
            fallbackMode: .silent,
            defaultTarget: RouteTarget(browser: .builtIn(.safari), profileId: SafariProfileRecord.defaultID),
            rules: [],
            customBrowsers: []
        )
    }

    // Manual Decodable so existing config.json files (saved before
    // `customBrowsers` existed) still load — a missing key just defaults to
    // an empty array instead of failing to decode the whole settings file.
    enum CodingKeys: String, CodingKey {
        case fallbackMode, defaultTarget, rules, customBrowsers
    }

    init(fallbackMode: FallbackMode, defaultTarget: RouteTarget, rules: [RoutingRule], customBrowsers: [CustomBrowser]) {
        self.fallbackMode = fallbackMode
        self.defaultTarget = defaultTarget
        self.rules = rules
        self.customBrowsers = customBrowsers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fallbackMode = try container.decode(FallbackMode.self, forKey: .fallbackMode)
        defaultTarget = try container.decode(RouteTarget.self, forKey: .defaultTarget)
        rules = try container.decode([RoutingRule].self, forKey: .rules)
        customBrowsers = try container.decodeIfPresent([CustomBrowser].self, forKey: .customBrowsers) ?? []
    }
}

struct RoutingContext {
    let url: URL
    let sourceApp: String?
}

enum BrowserPickerError: LocalizedError {
    /// Carries a display name rather than `BrowserKind` so it can also
    /// report a missing custom browser.
    case browserNotInstalled(String)
    case profileNotFound
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .browserNotInstalled(let displayName):
            return "\(displayName) is not installed."
        case .profileNotFound:
            return "The selected browser profile could not be found."
        case .launchFailed(let message):
            return "Failed to open link: \(message)"
        }
    }
}
