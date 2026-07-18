import AppKit
import SwiftUI

enum BrowserIconProvider {
    static func icon(for browser: BrowserKind, size: CGFloat = 20) -> NSImage {
        if let appURL = browser.installedAppURL {
            let image = NSWorkspace.shared.icon(forFile: appURL.path)
            image.size = NSSize(width: size, height: size)
            return image
        }
        return fallbackIcon(for: browser, size: size)
    }

    /// - Parameter customBrowsers: the current `AppSettings.customBrowsers`,
    ///   needed when `identity` is a `.custom` browser — it has no
    ///   `BrowserKind`, so its icon comes from its own resolved app path
    ///   instead of the `BrowserKind`-based lookup below.
    static func icon(for identity: BrowserIdentity, customBrowsers: [CustomBrowser] = [], size: CGFloat = 20) -> NSImage {
        switch identity {
        case .builtIn(let kind):
            return icon(for: kind, size: size)
        case .custom(let id):
            if let custom = customBrowsers.first(where: { $0.id == id }),
               custom.isInstalled {
                let image = NSWorkspace.shared.icon(forFile: custom.appPath)
                image.size = NSSize(width: size, height: size)
                return image
            }
            let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Custom browser") ?? NSImage(size: NSSize(width: size, height: size))
            image.size = NSSize(width: size, height: size)
            return image
        }
    }

    static func icon(for profile: BrowserProfile, customBrowsers: [CustomBrowser] = [], size: CGFloat = 20) -> NSImage {
        icon(for: profile.browser, customBrowsers: customBrowsers, size: size)
    }

    private static func fallbackIcon(for browser: BrowserKind, size: CGFloat) -> NSImage {
        if let bundled = bundledSVGIcon(for: browser, size: size) {
            return bundled
        }

        let symbolName: String
        switch browser {
        case .chrome, .edge, .brave, .vivaldi, .opera, .arc: symbolName = "globe"
        case .firefox: symbolName = "flame"
        case .safari: symbolName = "safari"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: browser.displayName) {
            image.size = NSSize(width: size, height: size)
            return image
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.secondaryLabelColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        image.unlockFocus()
        return image
    }

    private static func bundledSVGIcon(for browser: BrowserKind, size: CGFloat) -> NSImage? {
        guard let url = Bundle.main.url(
            forResource: browser.rawValue,
            withExtension: "svg",
            subdirectory: "Resources/Icons/browsers"
        ) else { return nil }

        guard let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: size, height: size)
        return image
    }
}

struct BrowserIconView: View {
    // See ProfileIconView below — same reasoning for reading the environment
    // instead of threading a `customBrowsers` parameter through call sites.
    @EnvironmentObject private var settingsStore: SettingsStore
    let browser: BrowserIdentity
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: BrowserIconProvider.icon(for: browser, customBrowsers: settingsStore.settings.customBrowsers, size: size))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

struct ProfileIconView: View {
    // Read from the environment (already injected at every window root)
    // rather than adding a `customBrowsers` parameter to every call site —
    // this view only needs it to resolve `.custom` browser icons.
    @EnvironmentObject private var settingsStore: SettingsStore
    let profile: BrowserProfile
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: BrowserIconProvider.icon(for: profile, customBrowsers: settingsStore.settings.customBrowsers, size: size))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
