import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var settings: AppSettings
    @Published private(set) var profiles: [BrowserProfile] = []

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var configURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("BrowserPicker", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("config.json")
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("BrowserPicker", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let loadedURL = folder.appendingPathComponent("config.json")

        settings = Self.loadSettings(from: loadedURL, decoder: decoder) ?? .default
    }

    func reloadProfiles() {
        let hidden = Set(settings.hiddenProfiles)
        let discovered = ProfileDiscoveryService.discoverAll(customBrowsers: settings.customBrowsers)
            .filter { !hidden.contains($0.routeTarget) }
        profiles = Self.ordered(discovered, by: settings.profileOrder)
        migrateLegacySafariTargets()
        ensureDefaultTargetIsValid()
        PermissionMonitor.shared.refresh()
    }

    /// Re-read Safari profiles from the menu while Safari is open.
    func rescanSafariProfilesFromMenu() {
        guard SafariRuntime.isRunning else { return }

        var safariProfiles = profiles.filter { $0.browser != .builtIn(.safari) }
        var recordsByID: [String: SafariProfileRecord] = [:]

        for record in SafariProfileStore.discoverProfiles() {
            recordsByID[record.id] = record
        }
        for record in SafariMenuProfileScanner.discoverProfiles() {
            recordsByID[record.id] = record
        }

        if recordsByID.isEmpty {
            recordsByID[SafariProfileRecord.defaultID] = SafariProfileRecord(
                id: SafariProfileRecord.defaultID,
                displayName: "Personal",
                menuName: "Personal"
            )
        }

        let mapped = recordsByID.values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map {
                BrowserProfile(
                    id: $0.id,
                    displayName: $0.displayName,
                    browser: .builtIn(.safari),
                    profilePath: $0.id,
                    internalName: $0.menuName
                )
            }

        safariProfiles.append(contentsOf: mapped)
        profiles = safariProfiles
        migrateLegacySafariTargets()
        ensureDefaultTargetIsValid()
        PermissionMonitor.shared.refresh()
    }

    /// User-triggered Refresh: also brings back any profiles the user removed.
    func refreshProfiles() {
        if !settings.hiddenProfiles.isEmpty {
            updateSettings { $0.hiddenProfiles = [] }
        }
        reloadProfiles()
    }

    /// Hides a discovered profile (persisted) until the next Refresh.
    func removeProfile(_ profile: BrowserProfile) {
        updateSettings { $0.hiddenProfiles.append(profile.routeTarget) }
        profiles.removeAll { $0.browser == profile.browser && $0.id == profile.id }
        ensureDefaultTargetIsValid()
    }

    func moveProfile(_ moving: RouteTarget, onto target: RouteTarget) {
        let reordered = Self.moving(moving, onto: target, in: profiles)
        guard reordered != profiles else { return }
        profiles = reordered
        updateSettings { $0.profileOrder = reordered.map(\.routeTarget) }
    }

    /// Profiles in `order` come first, in that order; new ones keep discovery order after them.
    nonisolated static func ordered(_ profiles: [BrowserProfile], by order: [RouteTarget]) -> [BrowserProfile] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return profiles.enumerated()
            .sorted { (rank[$0.element.routeTarget] ?? .max, $0.offset) < (rank[$1.element.routeTarget] ?? .max, $1.offset) }
            .map(\.element)
    }

    /// Moves `moving` into `target`'s slot (after it when dragging down, before it when dragging up).
    /// Only reorders within the same browser.
    nonisolated static func moving(_ moving: RouteTarget, onto target: RouteTarget, in profiles: [BrowserProfile]) -> [BrowserProfile] {
        guard moving != target, moving.browser == target.browser,
              let from = profiles.firstIndex(where: { $0.routeTarget == moving }),
              let to = profiles.firstIndex(where: { $0.routeTarget == target }) else { return profiles }
        var result = profiles
        result.insert(result.remove(at: from), at: to)
        return result
    }

    func save() {
        do {
            let data = try encoder.encode(settings)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("BrowserPicker: failed to save settings – \(error.localizedDescription)")
        }
    }

    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        transform(&settings)
        save()
    }

    func setDefaultTarget(_ target: RouteTarget) {
        updateSettings { $0.defaultTarget = target }
    }

    func setFallbackMode(_ mode: FallbackMode) {
        updateSettings { $0.fallbackMode = mode }
    }

    func addRule(_ rule: RoutingRule) {
        updateSettings { settings in
            var rule = rule
            rule.priority = (settings.rules.map(\.priority).max() ?? -1) + 1
            settings.rules.append(rule)
        }
    }

    func updateRule(_ rule: RoutingRule) {
        updateSettings { settings in
            guard let index = settings.rules.firstIndex(where: { $0.id == rule.id }) else { return }
            settings.rules[index] = rule
        }
    }

    func deleteRule(id: UUID) {
        updateSettings { settings in
            settings.rules.removeAll { $0.id == id }
            settings.rules.sort { $0.priority < $1.priority }
            for index in settings.rules.indices {
                settings.rules[index].priority = index
            }
        }
    }

    func moveRules(from source: IndexSet, to destination: Int) {
        updateSettings { settings in
            var rules = settings.rules.sorted { $0.priority < $1.priority }
            rules.move(fromOffsets: source, toOffset: destination)
            for index in rules.indices {
                rules[index].priority = index
            }
            settings.rules = rules
        }
    }

    func profile(for target: RouteTarget) -> BrowserProfile? {
        if let match = profiles.first(where: { $0.browser == target.browser && $0.id == target.profileId }) {
            return match
        }

        // Legacy Safari default id from early builds.
        if target.browser == .builtIn(.safari) && target.profileId == "safari-default" {
            return profiles.first { $0.browser == .builtIn(.safari) && $0.id == SafariProfileRecord.defaultID }
                ?? profiles.first { $0.browser == .builtIn(.safari) }
        }

        return nil
    }

    func profiles(for browser: BrowserIdentity) -> [BrowserProfile] {
        profiles.filter { $0.browser == browser }
    }

    /// Human-readable name for a browser identity — resolves `.custom`
    /// against the current custom-browser list so UI labels never show a
    /// raw UUID, even for a `.custom` id that no longer has a matching
    /// `CustomBrowser` (e.g. removed after a rule referencing it was saved).
    func displayName(for identity: BrowserIdentity) -> String {
        switch identity {
        case .builtIn(let kind): return kind.displayName
        case .custom(let id):
            return settings.customBrowsers.first(where: { $0.id == id })?.displayName ?? "Custom Browser"
        }
    }

    /// Every browser selectable in a rule/picker: the fixed built-ins plus
    /// whatever the user has added via "Add Custom Browser…".
    var allBrowserIdentities: [BrowserIdentity] {
        BrowserKind.allCases.map(BrowserIdentity.builtIn)
            + settings.customBrowsers.map { .custom($0.id) }
    }

    /// Adds a user-picked browser app and immediately re-discovers profiles
    /// so it shows up in rule/picker lists without a manual refresh.
    func addCustomBrowser(_ browser: CustomBrowser) {
        updateSettings { $0.customBrowsers.append(browser) }
        reloadProfiles()
    }

    /// Updates a custom browser's fields in place (e.g. after the user sets
    /// a manual "Local State" override path) and re-discovers profiles.
    func updateCustomBrowser(_ browser: CustomBrowser) {
        updateSettings { settings in
            guard let index = settings.customBrowsers.firstIndex(where: { $0.id == browser.id }) else { return }
            settings.customBrowsers[index] = browser
        }
        reloadProfiles()
    }

    /// Removes a custom browser and any rules/default-target pointing at it,
    /// so the settings file never references a browser id nothing knows how
    /// to launch anymore.
    func removeCustomBrowser(id: UUID) {
        let identity = BrowserIdentity.custom(id)
        updateSettings { settings in
            settings.customBrowsers.removeAll { $0.id == id }
            settings.rules.removeAll { $0.target.browser == identity }
        }
        reloadProfiles()
    }

    private func migrateLegacySafariTargets() {
        var changed = false

        if settings.defaultTarget.browser == .builtIn(.safari),
           settings.defaultTarget.profileId == "safari-default" {
            settings.defaultTarget.profileId = SafariProfileRecord.defaultID
            changed = true
        }

        for index in settings.rules.indices {
            if settings.rules[index].target.browser == .builtIn(.safari),
               settings.rules[index].target.profileId == "safari-default" {
                settings.rules[index].target.profileId = SafariProfileRecord.defaultID
                changed = true
            }
        }

        if changed { save() }
    }

    private func ensureDefaultTargetIsValid() {
        if profile(for: settings.defaultTarget) != nil { return }

        if settings.defaultTarget.browser == .builtIn(.safari),
           settings.defaultTarget.profileId == "safari-default",
           let safariDefault = profiles.first(where: { $0.browser == .builtIn(.safari) && $0.id == SafariProfileRecord.defaultID }) {
            settings.defaultTarget = RouteTarget(browser: .builtIn(.safari), profileId: safariDefault.id)
            save()
            return
        }

        if let first = profiles.first {
            settings.defaultTarget = RouteTarget(browser: first.browser, profileId: first.id)
            save()
        }
    }

    private static func loadSettings(from url: URL, decoder: JSONDecoder) -> AppSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AppSettings.self, from: data)
    }
}
