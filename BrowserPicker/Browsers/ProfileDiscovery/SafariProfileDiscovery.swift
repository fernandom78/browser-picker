import Foundation

struct SafariProfileDiscovery: ProfileDiscovery {
    let browser: BrowserKind = .safari

    func discoverProfiles() -> [BrowserProfile] {
        guard browser.isInstalled else { return [] }

        var recordsByID: [String: SafariProfileRecord] = [:]

        // Primary, fully language-independent source: profile names + UUIDs read
        // straight from SafariTabs.db (requires Full Disk Access).
        for record in SafariProfileStore.discoverProfiles() {
            recordsByID[record.id] = record
        }

        // Fallback only when the database is unreadable (e.g. Full Disk Access
        // not granted). Reads Safari's menu — never launches it — and is itself
        // language-independent. Skipped when the DB already returned profiles to
        // avoid duplicate entries keyed by name vs. UUID.
        if recordsByID.isEmpty, SafariRuntime.isRunning {
            for record in SafariMenuProfileScanner.discoverProfiles() {
                recordsByID[record.id] = record
            }
        }

        if recordsByID.isEmpty {
            recordsByID[SafariProfileRecord.defaultID] = defaultRecord()
        }

        return recordsByID.values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map { record in
                BrowserProfile(
                    id: record.id,
                    displayName: record.displayName,
                    browser: .safari,
                    profilePath: record.id,
                    internalName: record.menuName
                )
            }
    }

    private func defaultRecord() -> SafariProfileRecord {
        SafariProfileRecord(
            id: SafariProfileRecord.defaultID,
            displayName: "Personal",
            menuName: "Personal"
        )
    }
}
