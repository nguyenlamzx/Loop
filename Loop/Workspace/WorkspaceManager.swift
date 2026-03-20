//
//  WorkspaceManager.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import Scribe
import SwiftUI

/// Manages saving and restoring window workspace layouts.
///
/// `WorkspaceManager` captures the current on-screen window layout as a named workspace,
/// and can restore it later. It handles:
/// - Capturing all visible windows and their positions/sizes
/// - Saving workspaces to persistent storage via `Defaults`
/// - Restoring workspaces by matching windows to saved entries
/// - Handling multi-monitor setups with proportional scaling
/// - Launching apps that are not currently running
@Loggable(style: .static)
enum WorkspaceManager {
    // MARK: - Save

    /// Saves the current window layout as a named workspace.
    ///
    /// Captures **all** windows including minimized ones. For each window, saves:
    /// - Frame and proportional frame (for visible windows)
    /// - `isMinimized` flag
    /// - For minimized windows: uses their pre-minimize frame if available
    ///
    /// - Parameter name: The name for the workspace.
    /// - Returns: The created `SavedWorkspace`, or `nil` if no windows were found.
    @discardableResult
    static func saveCurrentWorkspace(name: String) -> SavedWorkspace? {
        guard Defaults[.enableWorkspaces] else {
            log.info("Workspaces feature is disabled")
            return nil
        }

        let screenConfigHash = currentScreenConfigurationHash()
        var entries: [WorkspaceWindowEntry] = []

        // Get ALL windows (visible + minimized) via AXUIElement per running app
        let allWindows = getAllWindows()

        guard !allWindows.isEmpty else {
            log.info("No windows found to save")
            return nil
        }

        for (window, isMinimized) in allWindows {
            guard let bundleIdentifier = window.nsRunningApplication?.bundleIdentifier else {
                continue
            }

            // Skip our own app's windows
            guard bundleIdentifier != Bundle.main.bundleIdentifier else {
                continue
            }

            let frame = window.frame
            let screen: NSScreen

            if isMinimized {
                // Minimized windows might not be on any screen,
                // use main screen for proportional calculation
                screen = NSScreen.main ?? NSScreen.screens[0]
            } else {
                guard let s = ScreenUtility.screenContaining(window) ?? NSScreen.main else {
                    continue
                }
                screen = s
            }

            let screenFrame = screen.cgSafeScreenFrame

            // Calculate proportional frame relative to screen bounds
            let proportionalFrame: CGRect
            if frame.width > 0 && frame.height > 0 && !isMinimized {
                proportionalFrame = CGRect(
                    x: (frame.minX - screenFrame.minX) / screenFrame.width,
                    y: (frame.minY - screenFrame.minY) / screenFrame.height,
                    width: frame.width / screenFrame.width,
                    height: frame.height / screenFrame.height
                )
            } else {
                // Minimized window: frame may be zero/stale, store as-is
                // When restored and unminimized, frame will be set from saved proportional
                proportionalFrame = CGRect(
                    x: (frame.minX - screenFrame.minX) / screenFrame.width,
                    y: (frame.minY - screenFrame.minY) / screenFrame.height,
                    width: max(0.2, frame.width / screenFrame.width),
                    height: max(0.2, frame.height / screenFrame.height)
                )
            }

            let entry = WorkspaceWindowEntry(
                bundleIdentifier: bundleIdentifier,
                windowTitle: window.title,
                frame: frame,
                proportionalFrame: proportionalFrame,
                screenIdentifier: screen.localizedName,
                appName: window.nsRunningApplication?.localizedName,
                isMinimized: isMinimized
            )

            entries.append(entry)
            let state = isMinimized ? "minimized" : "visible"
            log.info("Captured [\(state)] \(entry.appName ?? bundleIdentifier): \(frame)")
        }

        guard !entries.isEmpty else {
            log.info("No valid window entries to save")
            return nil
        }

        let workspace = SavedWorkspace(
            name: name,
            windows: entries,
            screenConfigurationHash: screenConfigHash
        )

        var savedWorkspaces = Defaults[.savedWorkspaces]
        savedWorkspaces.append(workspace)
        Defaults[.savedWorkspaces] = savedWorkspaces

        let visibleCount = entries.filter { !$0.isMinimized }.count
        let minimizedCount = entries.filter { $0.isMinimized }.count
        log.success("Saved workspace '\(name)': \(visibleCount) visible + \(minimizedCount) minimized windows")
        return workspace
    }

    // MARK: - Restore

    /// Restores a saved workspace by matching windows and setting their frames.
    ///
    /// - Parameter workspaceID: The ID of the workspace to restore.
    static func restoreWorkspace(id workspaceID: UUID) {
        guard Defaults[.enableWorkspaces] else {
            log.info("Workspaces feature is disabled")
            return
        }

        guard let workspace = Defaults[.savedWorkspaces].first(where: { $0.id == workspaceID }) else {
            log.warn("Workspace not found: \(workspaceID)")
            return
        }

        restoreWorkspace(workspace)
    }

    /// Restores a saved workspace.
    ///
    /// Handles minimize/unminimize transitions:
    /// - If saved as minimized → minimize the window
    /// - If saved as visible but currently minimized → unminimize, then set frame
    /// - If saved as visible and currently visible → just set frame
    ///
    /// Uses proportional frames for cross-resolution compatibility.
    static func restoreWorkspace(_ workspace: SavedWorkspace) {
        log.info("Restoring workspace '\(workspace.name)' (\(workspace.windows.count) windows)")

        // Get ALL windows including minimized for matching
        let allWindows = getAllWindows()
        log.info("Available windows: \(allWindows.count) (visible + minimized)")

        var matchedWindowIDs: Set<CGWindowID> = []
        var restoredCount = 0

        for entry in workspace.windows {
            // Find matching window from ALL windows (visible + minimized)
            guard let (matchedWindow, currentlyMinimized) = findMatchingWindow(
                for: entry,
                from: allWindows,
                excluding: matchedWindowIDs
            ) else {
                log.info("⚠️ No match for '\(entry.appName ?? entry.bundleIdentifier)' (\(entry.windowTitle ?? "no title"))")
                launchApp(bundleIdentifier: entry.bundleIdentifier)
                continue
            }

            matchedWindowIDs.insert(matchedWindow.cgWindowID)

            if entry.isMinimized {
                // Window should be minimized in this workspace
                if !currentlyMinimized {
                    log.info("Minimizing '\(entry.appName ?? entry.bundleIdentifier)'")
                    matchedWindow.minimized = true
                } else {
                    log.info("Already minimized: '\(entry.appName ?? entry.bundleIdentifier)'")
                }
            } else {
                // Window should be visible in this workspace
                if currentlyMinimized {
                    log.info("Unminimizing '\(entry.appName ?? entry.bundleIdentifier)'")
                    matchedWindow.minimized = false
                    // Small delay for window to appear on screen before setting frame
                    usleep(200_000) // 200ms
                }

                // Calculate target frame from proportional
                guard let screen = NSScreen.main else { continue }

                let screenFrame = screen.cgSafeScreenFrame
                let targetFrame = CGRect(
                    x: screenFrame.minX + entry.proportionalFrame.minX * screenFrame.width,
                    y: screenFrame.minY + entry.proportionalFrame.minY * screenFrame.height,
                    width: entry.proportionalFrame.width * screenFrame.width,
                    height: entry.proportionalFrame.height * screenFrame.height
                )

                let currentFrame = matchedWindow.frame
                log.info("Restoring '\(entry.appName ?? entry.bundleIdentifier)': \(currentFrame) → \(targetFrame)")

                matchedWindow.setFrame(targetFrame, sizeFirst: true)

                // Verify and retry
                let actualFrame = matchedWindow.frame
                if !actualFrame.approximatelyEqual(to: targetFrame, tolerance: 5) {
                    log.info("⚠️ Frame mismatch: expected \(targetFrame), got \(actualFrame) — retrying")
                    matchedWindow.setFrame(targetFrame, sizeFirst: true)
                }
            }

            restoredCount += 1
        }

        log.success("Restored workspace '\(workspace.name)': \(restoredCount)/\(workspace.windows.count) windows")
    }

    // MARK: - CRUD

    /// Deletes a saved workspace.
    ///
    /// - Parameter workspaceID: The ID of the workspace to delete.
    static func deleteWorkspace(id workspaceID: UUID) {
        var savedWorkspaces = Defaults[.savedWorkspaces]
        savedWorkspaces.removeAll { $0.id == workspaceID }
        Defaults[.savedWorkspaces] = savedWorkspaces
        log.info("Deleted workspace: \(workspaceID)")
    }

    /// Renames a saved workspace.
    ///
    /// - Parameters:
    ///   - workspaceID: The ID of the workspace to rename.
    ///   - newName: The new name for the workspace.
    static func renameWorkspace(id workspaceID: UUID, to newName: String) {
        var savedWorkspaces = Defaults[.savedWorkspaces]
        if let index = savedWorkspaces.firstIndex(where: { $0.id == workspaceID }) {
            savedWorkspaces[index].name = newName
            Defaults[.savedWorkspaces] = savedWorkspaces
            log.info("Renamed workspace \(workspaceID) to '\(newName)'")
        }
    }

    /// Updates a workspace's keybind.
    ///
    /// - Parameters:
    ///   - workspaceID: The ID of the workspace to update.
    ///   - keybind: The new keybind.
    static func updateKeybind(for workspaceID: UUID, keybind: Set<CGKeyCode>) {
        var savedWorkspaces = Defaults[.savedWorkspaces]
        if let index = savedWorkspaces.firstIndex(where: { $0.id == workspaceID }) {
            savedWorkspaces[index].keybind = keybind
            Defaults[.savedWorkspaces] = savedWorkspaces
            log.info("Updated keybind for workspace \(workspaceID)")
        }
    }

    // MARK: - Helpers

    /// Creates a hash representing the current screen configuration.
    /// Used to detect when monitors change (resolution, count, arrangement).
    private static func currentScreenConfigurationHash() -> String {
        let screens = NSScreen.screens.map { screen in
            "\(screen.localizedName):\(screen.frame)"
        }
        return screens.sorted().joined(separator: "|")
    }

    /// Gets ALL windows from ALL running applications, including minimized ones.
    ///
    /// Uses AXUIElement to enumerate windows per app, which includes minimized windows
    /// that CGWindowListCopyWindowInfo(.optionOnScreenOnly) would miss.
    ///
    /// - Returns: Array of (Window, isMinimized) tuples
    private static func getAllWindows() -> [(Window, Bool)] {
        var result: [(Window, Bool)] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowsRef: CFTypeRef?
            let axError = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            guard axError == .success,
                  let windowElements = windowsRef as? [AXUIElement] else {
                continue
            }

            for element in windowElements {
                guard let window = try? Window(element: element) else { continue }

                // Check if standard window (has a title or is resizable)
                let title = window.title
                let hasTitle = title != nil && !title!.isEmpty

                // Skip utility/panel windows
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                let role = roleRef as? String
                if role != "AXWindow" { continue }

                // Check subrole — skip dialogs, popovers, etc.
                var subroleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
                let subrole = subroleRef as? String
                if subrole != "AXStandardWindow" && subrole != nil { continue }

                let isMinimized = window.minimized

                // Only include windows that have a title or are visible
                if hasTitle || !isMinimized {
                    result.append((window, isMinimized))
                }
            }
        }

        return result
    }

    /// Finds a matching window for a saved workspace entry from all windows (visible + minimized).
    ///
    /// Matching priority:
    /// 1. Same bundleIdentifier + same windowTitle
    /// 2. Same bundleIdentifier (first unmatched window)
    ///
    /// - Parameters:
    ///   - entry: The saved window entry to match.
    ///   - allWindows: All available windows with minimize state.
    ///   - excluding: Window IDs already matched (to avoid double-matching).
    /// - Returns: The best matching (Window, currentlyMinimized) tuple, if found.
    private static func findMatchingWindow(
        for entry: WorkspaceWindowEntry,
        from allWindows: [(Window, Bool)],
        excluding matchedIDs: Set<CGWindowID>
    ) -> (Window, Bool)? {
        let candidates = allWindows.filter { (window, _) in
            !matchedIDs.contains(window.cgWindowID)
                && window.nsRunningApplication?.bundleIdentifier == entry.bundleIdentifier
        }

        // Priority 1: Match by title
        if let titleMatch = entry.windowTitle,
           let match = candidates.first(where: { $0.0.title == titleMatch }) {
            return match
        }

        // Priority 2: First unmatched window with same bundle ID
        return candidates.first
    }

    /// Attempts to launch an application by its bundle identifier.
    ///
    /// - Parameter bundleIdentifier: The bundle identifier of the application to launch.
    private static func launchApp(bundleIdentifier: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            log.warn("Cannot find app with bundle identifier: \(bundleIdentifier)")
            return
        }

        log.info("Launching app: \(bundleIdentifier)")

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                Self.log.warn("Failed to launch \(bundleIdentifier): \(error.localizedDescription)")
            }
        }
    }
}
