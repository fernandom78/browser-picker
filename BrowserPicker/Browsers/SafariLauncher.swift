import Foundation

struct SafariLauncher {
    func open(url: URL, profile: BrowserProfile) throws {
        let menuName = profile.internalName ?? profile.displayName
        let script = appleScript(urlString: url.absoluteString, menuName: menuName)

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw BrowserPickerError.launchFailed(message?.isEmpty == false ? message! : "Safari automation failed. Grant Accessibility access in System Settings.")
        }
    }

    private func appleScript(urlString: String, menuName: String) -> String {
        let escapedURL = escapeAppleScript(urlString)
        let escapedMenuName = escapeAppleScript(menuName)

        return """
        on run
            set targetURL to "\(escapedURL)"
            set profileMenuName to "\(escapedMenuName)"

            tell application "Safari" to activate
            delay 0.4

            set targetWindow to missing value
            tell application "Safari"
                repeat with w in windows
                    if profileMenuName is "Personal" then
                        set windowName to name of w
                        if windowName is "Safari" or windowName starts with "Personal" then
                            set targetWindow to w
                            exit repeat
                        end if
                    else if name of w starts with profileMenuName then
                        set targetWindow to w
                        exit repeat
                    end if
                end repeat
            end tell

            if targetWindow is not missing value then
                tell application "Safari"
                    tell targetWindow
                        set newTab to make new tab with properties {URL:targetURL}
                        set current tab to newTab
                    end tell
                    set index of targetWindow to 1
                end tell
                tell application "Safari" to activate
                return
            end if

            set didClick to false

            if profileMenuName is "Personal" then
                -- Default profile: just open a fresh window. This avoids the
                -- menu bar entirely, so it is independent of the system language.
                tell application "Safari" to make new document
                set didClick to true
            else
                -- Named profile: click the File-menu item that references the
                -- profile by name. The File menu is accessed by position
                -- (menu bar item 3) instead of the localized title "File", so
                -- this also works on non-English systems (e.g. "Ablage" in
                -- German). Menu items are matched by *containing* the profile
                -- name because the surrounding text ("New … Window") is localized.
                tell application "System Events"
                    tell process "Safari"
                        set fileMenu to menu 1 of menu bar item 3 of menu bar 1

                        -- 1) direct items in the File menu
                        repeat with mi in (menu items of fileMenu)
                            try
                                if name of mi contains profileMenuName then
                                    click mi
                                    set didClick to true
                                    exit repeat
                                end if
                            end try
                        end repeat

                        -- 2) one level of submenus (e.g. a "New Window" submenu listing profiles)
                        if not didClick then
                            repeat with mi in (menu items of fileMenu)
                                try
                                    if (count of menus of mi) > 0 then
                                        set subMenu to menu 1 of mi
                                        repeat with smi in (menu items of subMenu)
                                            try
                                                if name of smi contains profileMenuName then
                                                    click smi
                                                    set didClick to true
                                                    exit repeat
                                                end if
                                            end try
                                        end repeat
                                    end if
                                end try
                                if didClick then exit repeat
                            end repeat
                        end if
                    end tell
                end tell
            end if

            if not didClick then
                error "Could not find a Safari menu item for profile \\"" & profileMenuName & "\\". Open Safari and verify the profile name."
            end if

            delay 0.6
            tell application "Safari"
                if (count of windows) > 0 then
                    set URL of current tab of front window to targetURL
                end if
            end tell
        end run
        """
    }

    private func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
