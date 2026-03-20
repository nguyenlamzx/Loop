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
/// Focus: save positions of visible windows and restore them accurately
/// using proportional frames for cross-resolution compatibility.
@Loggable(style: .static)
enum WorkspaceManager {
    // MARK: - Save

    /// Saves the current visible window layout as a named workspace.
    ///
    /// - Parameter name: The name for the workspace.
    /// - Returns: The created `SavedWorkspace`, or `nil` if no windows were found.
    @discardableResult
    static func saveCurrentWorkspace(name: String) -> SavedWorkspace? {
        guard Defaults[.enableWorkspaces] else {
            log.info("Workspaces feature is disabled")
            return nil
        }

        let windows = WindowUtility.windowList()
        guard !windows.isEmpty else {
            log.info("No windows found to save")
            return nil
        }

        let screenConfigHash = currentScreenConfigurationHash()
        var entries: [WorkspaceWindowEntry] = []

        for window in windows {
            guard let bundleIdentifier = window.nsRunningApplication?.bundleIdentifier else {
                continue
            }

            // Skip our own app's windows
            guard bundleIdentifier != Bundle.main.bundleIdentifier else {
                continue
            }

            guard let screen = ScreenUtility.screenContaining(window) ?? NSScreen.main else {
                continue
            }

            let frame = window.frame
            let screenFrame = screen.cgSafeScreenFrame

            // Calculate proportional frame relative to screen bounds
            let proportionalFrame = CGRect(
                x: (frame.minX - screenFrame.minX) / screenFrame.width,
                y: (frame.minY - screenFrame.minY) / screenFrame.height,
                width: frame.width / screenFrame.width,
                height: frame.height / screenFrame.height
            )

            let entry = WorkspaceWindowEntry(
                bundleIdentifier: bundleIdentifier,
                windowTitle: window.title,
                frame: frame,
                proportionalFrame: proportionalFrame,
                screenIdentifier: screen.localizedName,
                appName: window.nsRunningApplication?.localizedName
            )

            entries.append(entry)
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

        log.success("Saved workspace '\(name)' with \(entries.count) windows")
        return workspace
    }

    // MARK: - Restore

    /// Restores a saved workspace by ID.
    static func restoreWorkspace(id workspaceID: UUID) {
        guard Defaults[.enableWorkspaces] else { return }

        guard let workspace = Defaults[.savedWorkspaces].first(where: { $0.id == workspaceID }) else {
            log.warn("Workspace not found: \(workspaceID)")
            return
        }

        restoreWorkspace(workspace)
    }

    /// Restores a saved workspace.
    ///
    /// Always uses **proportional frames** for positioning:
    /// - Same resolution: proportional × screen size ≈ original position (< 1px diff)
    /// - Different resolution: automatically scales correctly
    ///
    /// Uses sizeFirst=true for reliable AX behavior, with retry on mismatch.
    static func restoreWorkspace(_ workspace: SavedWorkspace) {
        log.info("Restoring workspace '\(workspace.name)' (\(workspace.windows.count) windows)")

        let currentWindows = WindowUtility.windowList()
        var matchedWindowIDs: Set<CGWindowID> = []
        var restoredCount = 0

        for entry in workspace.windows {
            guard let matchedWindow = findMatchingWindow(
                for: entry,
                from: currentWindows,
                excluding: matchedWindowIDs
            ) else {
                log.info("No match for '\(entry.appName ?? entry.bundleIdentifier)'")
                launchApp(bundleIdentifier: entry.bundleIdentifier)
                continue
            }

            matchedWindowIDs.insert(matchedWindow.cgWindowID)

            // Calculate target frame from proportional
            guard let screen = ScreenUtility.screenContaining(matchedWindow) ?? NSScreen.main else {
                continue
            }

            let screenFrame = screen.cgSafeScreenFrame
            let targetFrame = CGRect(
                x: screenFrame.minX + entry.proportionalFrame.minX * screenFrame.width,
                y: screenFrame.minY + entry.proportionalFrame.minY * screenFrame.height,
                width: entry.proportionalFrame.width * screenFrame.width,
                height: entry.proportionalFrame.height * screenFrame.height
            )

            matchedWindow.setFrame(targetFrame, sizeFirst: true)

            // Verify and retry if needed
            let actualFrame = matchedWindow.frame
            if !actualFrame.approximatelyEqual(to: targetFrame, tolerance: 5) {
                matchedWindow.setFrame(targetFrame, sizeFirst: true)
            }

            restoredCount += 1
        }

        log.success("Restored workspace '\(workspace.name)': \(restoredCount)/\(workspace.windows.count) windows")
    }

    // MARK: - CRUD

    /// Deletes a saved workspace.
    static func deleteWorkspace(id workspaceID: UUID) {
        var savedWorkspaces = Defaults[.savedWorkspaces]
        savedWorkspaces.removeAll { $0.id == workspaceID }
        Defaults[.savedWorkspaces] = savedWorkspaces
        log.info("Deleted workspace: \(workspaceID)")
    }

    /// Renames a saved workspace.
    static func renameWorkspace(id workspaceID: UUID, to newName: String) {
        var savedWorkspaces = Defaults[.savedWorkspaces]
        if let index = savedWorkspaces.firstIndex(where: { $0.id == workspaceID }) {
            savedWorkspaces[index].name = newName
            Defaults[.savedWorkspaces] = savedWorkspaces
        }
    }

    /// Updates a workspace's keybind.
    static func updateKeybind(for workspaceID: UUID, keybind: Set<CGKeyCode>) {
        var savedWorkspaces = Defaults[.savedWorkspaces]
        if let index = savedWorkspaces.firstIndex(where: { $0.id == workspaceID }) {
            savedWorkspaces[index].keybind = keybind
            Defaults[.savedWorkspaces] = savedWorkspaces
        }
    }

    // MARK: - Helpers

    /// Creates a hash representing the current screen configuration.
    private static func currentScreenConfigurationHash() -> String {
        let screens = NSScreen.screens.map { screen in
            "\(screen.localizedName):\(screen.frame)"
        }
        return screens.sorted().joined(separator: "|")
    }

    /// Finds a matching window for a saved workspace entry.
    ///
    /// Priority: 1) Same bundle ID + same title, 2) Same bundle ID (first unmatched)
    private static func findMatchingWindow(
        for entry: WorkspaceWindowEntry,
        from windows: [Window],
        excluding matchedIDs: Set<CGWindowID>
    ) -> Window? {
        let candidates = windows.filter { window in
            !matchedIDs.contains(window.cgWindowID)
                && window.nsRunningApplication?.bundleIdentifier == entry.bundleIdentifier
        }

        // Priority 1: Match by title
        if let titleMatch = entry.windowTitle,
           let window = candidates.first(where: { $0.title == titleMatch }) {
            return window
        }

        // Priority 2: First unmatched window with same bundle ID
        return candidates.first
    }

    /// Attempts to launch an application by its bundle identifier.
    private static func launchApp(bundleIdentifier: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                Self.log.warn("Failed to launch \(bundleIdentifier): \(error.localizedDescription)")
            }
        }
    }
}
