import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appState: AppState
    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 232)

            Divider()

            Group {
                switch selection {
                case .general:
                    GeneralSettingsTab()
                case .rules:
                    RulesListView()
                case .browsers:
                    BrowsersSettingsTab()
                }
            }
            .environmentObject(settingsStore)
            .environmentObject(appState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    SidebarRow(
                        section: section,
                        isSelected: selection == section,
                        action: { selection = section }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer(minLength: 0)

            sidebarFooter
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text("Browser Picker")
                    .font(.headline)
                Text("v\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.isDefaultBrowser ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(appState.isDefaultBrowser ? "Default browser" : "Not default")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

private struct SidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(section.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.07) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsDetailScaffold(title: "General", subtitle: "Control how Browser Picker handles links.", icon: "gearshape.fill") {
            if appState.isDefaultBrowser {
                StatusBanner(
                    style: .success,
                    title: "Default browser active",
                    message: "Links from other apps are routed through Browser Picker."
                )
            } else {
                StatusBanner(
                    style: .warning,
                    title: "Not the default browser",
                    message: "Set Browser Picker as default to intercept links system-wide.",
                    actionTitle: "Make Default",
                    action: appState.registerAsDefaultBrowser
                )
            }

            SettingsCard(
                title: "When no rule matches",
                subtitle: "Choose what happens for links that don't match any rule."
            ) {
                VStack(spacing: 8) {
                    SettingsOptionRow(
                        title: "Use menu bar selection",
                        subtitle: "Open links silently in your current menu bar choice.",
                        systemImage: "menubar.rectangle",
                        isSelected: settingsStore.settings.fallbackMode == .silent,
                        action: { settingsStore.setFallbackMode(.silent) }
                    )
                    SettingsOptionRow(
                        title: "Show picker",
                        subtitle: "Ask which browser and profile to use each time.",
                        systemImage: "list.bullet.rectangle.portrait",
                        isSelected: settingsStore.settings.fallbackMode == .picker,
                        action: { settingsStore.setFallbackMode(.picker) }
                    )
                }
            }

            SettingsCard(
                title: "Menu bar selection",
                subtitle: "This browser and profile are used when no rule matches and fallback is silent."
            ) {
                if let profile = settingsStore.profile(for: settingsStore.settings.defaultTarget) {
                    ProfileSummaryRow(profile: profile)
                        .padding(.horizontal, 4)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                        Text("No profile selected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SettingsCard(
                title: "Quick tip",
                subtitle: nil
            ) {
                Label {
                    Text("Change the active profile from the menu bar icon anytime.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

private struct BrowsersSettingsTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var permissions: PermissionMonitor

    var body: some View {
        SettingsDetailScaffold(
            title: "Browsers",
            subtitle: "Profiles discovered from installed browsers on this Mac.",
            icon: "globe",
            action: {
                settingsStore.refreshProfiles()
                permissions.refresh()
            },
            actionTitle: "Refresh",
            actionIcon: "arrow.clockwise"
        ) {
            if settingsStore.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Browsers Found", systemImage: "globe")
                } description: {
                    Text("Install Chrome, Firefox, or Safari, then refresh profiles.")
                } actions: {
                    Button("Refresh Profiles") {
                        settingsStore.refreshProfiles()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                // Built-ins and custom browsers are both just
                // `BrowserIdentity` values here — one loop covers both, same
                // as the menu bar's profile switcher.
                ForEach(settingsStore.allBrowserIdentities, id: \.self) { browser in
                    let profiles = settingsStore.profiles(for: browser)
                    if !profiles.isEmpty {
                        BrowserProfilesCard(
                            browser: browser,
                            title: settingsStore.displayName(for: browser),
                            profiles: profiles
                        )
                    }
                }
            }

            customBrowsersCard

            safariPermissionsCard

            if !permissions.canReadSafariDatabase {
                SettingsCard(title: "Full Disk Access", subtitle: "Needed to read Safari profile names from disk.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("macOS blocks access to Safari's profile database without Full Disk Access. Add Browser Picker in System Settings → Privacy & Security → Full Disk Access, then restart the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Open Full Disk Access Settings") {
                            permissions.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onAppear {
            permissions.refresh()
        }
    }

    @ViewBuilder
    private var safariPermissionsCard: some View {
        SettingsCard(title: "Safari automation", subtitle: "Required to open links in a specific Safari profile.") {
            VStack(alignment: .leading, spacing: 12) {
                if permissions.isAccessibilityTrusted {
                    Label {
                        Text("Accessibility access is enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Label {
                        Text("Enable Browser Picker in System Settings → Privacy & Security → Accessibility, then quit and reopen this app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    Text(permissions.applicationPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(2)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button("Grant Access") {
                                permissions.requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Open Settings") {
                                permissions.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 8) {
                            Button("Quit & Reopen") {
                                permissions.restartApplication()
                            }
                            .buttonStyle(.bordered)

                            Button("Check Again") {
                                permissions.refresh()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Divider()

                if SafariRuntime.isRunning {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Safari is running")
                                .font(.subheadline.weight(.medium))
                            Text("Scan the File → New Window menu to detect profile names.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Scan Safari Profiles") {
                            settingsStore.rescanSafariProfilesFromMenu()
                            permissions.refresh()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!permissions.isAccessibilityTrusted)
                    }
                } else {
                    Label {
                        Text("Open Safari first, then use “Scan Safari Profiles” to detect profile names without launching Safari from Refresh.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "safari")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Lists every user-added browser regardless of whether it currently has
    /// discovered profiles, so a custom browser that's uninstalled or whose
    /// "Local State" auto-detection failed can still be managed (given a
    /// manual override path, or removed) rather than silently disappearing
    /// from the tab the way an uninstalled built-in browser would.
    private var customBrowsersCard: some View {
        SettingsCard(
            title: "Custom Browsers",
            subtitle: "Browsers you've added manually, beyond the built-in list above."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if settingsStore.settings.customBrowsers.isEmpty {
                    Text("No custom browsers added yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(settingsStore.settings.customBrowsers.enumerated()), id: \.element.id) { index, custom in
                            CustomBrowserRow(
                                custom: custom,
                                onSetOverride: { presentLocalStateOverridePanel(for: custom) },
                                onRemove: { settingsStore.removeCustomBrowser(id: custom.id) }
                            )
                            .padding(.vertical, 8)

                            if index < settingsStore.settings.customBrowsers.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                Button("Add Custom Browser…", action: presentAddCustomBrowserPanel)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func presentAddCustomBrowserPanel() {
        let panel = NSOpenPanel()
        panel.title = "Choose Browser App"
        panel.message = "Pick the .app for the browser you want to add."
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Bundle name is what the app calls itself (e.g. "Opera"), which
        // reads better than a raw filename if that ever differs.
        let displayName = Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        settingsStore.addCustomBrowser(CustomBrowser(displayName: displayName, appPath: url.path))
    }

    private func presentLocalStateOverridePanel(for custom: CustomBrowser) {
        let panel = NSOpenPanel()
        panel.title = "Choose \u{201C}Local State\u{201D} File"
        panel.message = "If \(custom.displayName)'s profiles weren't found automatically, locate its \u{201C}Local State\u{201D} file (inside its folder under ~/Library/Application Support) to fix profile detection."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var updated = custom
        updated.localStateOverridePath = url.path
        settingsStore.updateCustomBrowser(updated)
    }
}

private struct CustomBrowserRow: View {
    let custom: CustomBrowser
    let onSetOverride: () -> Void
    let onRemove: () -> Void
    @State private var showRemoveConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(custom.displayName)
                    .font(.body.weight(.medium))
                if !custom.isInstalled {
                    Text("Not installed at \(custom.appPath)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if custom.localStateOverridePath != nil {
                    Text("Using a manual profile data location")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)

            Button("Set Profile Location…", action: onSetOverride)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .confirmationDialog(
            "Remove \u{201C}\(custom.displayName)\u{201D}?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Any rules pointing at this browser will also be removed.")
        }
    }

    private var appIcon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: custom.appPath)
        image.size = NSSize(width: 28, height: 28)
        return image
    }
}

private struct BrowserProfilesCard: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    let browser: BrowserIdentity
    let title: String
    let profiles: [BrowserProfile]
    @State private var dropTargetID: String?

    var body: some View {
        SettingsCard(
            title: title,
            subtitle: "\(profiles.count) profile\(profiles.count == 1 ? "" : "s") detected"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .frame(width: 20, height: 28)
                            .contentShape(Rectangle())
                            .help("Drag to reorder")
                            .draggable(dragKey(profile)) {
                                ProfileSummaryRow(profile: profile)
                                    .padding(8)
                                    .frame(width: 260)
                            }
                        ProfileSummaryRow(profile: profile)
                        Button(role: .destructive) {
                            settingsStore.removeProfile(profile)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Hide this profile until the next Refresh")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(dropTargetID == profile.id ? Color.accentColor.opacity(0.12) : .clear)
                    )
                    .dropDestination(for: String.self) { keys, _ in
                        guard let key = keys.first,
                              let dragged = profiles.first(where: { dragKey($0) == key }) else { return false }
                        settingsStore.moveProfile(dragged.routeTarget, onto: profile.routeTarget)
                        return true
                    } isTargeted: { targeted in
                        if targeted { dropTargetID = profile.id } else if dropTargetID == profile.id { dropTargetID = nil }
                    }

                    if index < profiles.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    /// Includes the browser so a same-named profile dragged from another browser's card doesn't match.
    private func dragKey(_ profile: BrowserProfile) -> String {
        "\(profile.browser)|\(profile.id)"
    }
}
