//
//  LayoutManager.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import Scribe
import SwiftUI

/// Manages saving custom screen layouts and applying them via overlay.
///
/// A Layout = set of proportional zones on a screen.
/// No app binding — any window can be snapped into any zone.
@Loggable(style: .static)
enum LayoutManager {
    // MARK: - Capture

    /// Captures the current window arrangement on the focused screen as a named layout.
    ///
    /// Extracts proportional zones from visible window positions.
    /// - Parameter name: The name for the layout.
    /// - Returns: The created `SavedLayout`, or `nil` if no windows were found.
    @discardableResult
    static func captureLayout(name: String) -> SavedLayout? {
        guard Defaults[.enableWorkspaces] else {
            log.info("Workspaces feature is disabled")
            return nil
        }

        guard let focusedScreen = NSScreen.screenWithMouse ?? NSScreen.main else {
            log.info("No screen found")
            return nil
        }

        let windows = WindowUtility.windowList()
        let screenFrame = focusedScreen.cgSafeScreenFrame

        // Only windows on the focused screen
        let screenWindows = windows.filter { window in
            guard let windowScreen = ScreenUtility.screenContaining(window) else { return false }
            return windowScreen.isSameScreen(focusedScreen)
        }.filter { window in
            window.nsRunningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
        }

        guard !screenWindows.isEmpty else {
            log.info("No windows found on focused screen")
            return nil
        }

        // Convert window frames to proportional zones
        let zones = screenWindows.map { window -> LayoutZone in
            let frame = window.frame
            let proportionalFrame = CGRect(
                x: (frame.minX - screenFrame.minX) / screenFrame.width,
                y: (frame.minY - screenFrame.minY) / screenFrame.height,
                width: frame.width / screenFrame.width,
                height: frame.height / screenFrame.height
            )
            return LayoutZone(frame: proportionalFrame)
        }

        let layout = SavedLayout(name: name, zones: zones)

        var savedLayouts = Defaults[.savedLayouts]
        savedLayouts.append(layout)
        Defaults[.savedLayouts] = savedLayouts

        log.success("Captured layout '\(name)' with \(zones.count) zones")
        return layout
    }

    // MARK: - Apply

    /// Snaps the frontmost window to a specific zone of a layout on the current screen.
    ///
    /// - Parameters:
    ///   - zone: The layout zone to snap to.
    ///   - screen: The target screen (defaults to screen with mouse).
    static func snapToZone(_ zone: LayoutZone, screen: NSScreen? = nil) {
        guard let targetScreen = screen ?? NSScreen.screenWithMouse ?? NSScreen.main else {
            log.info("No screen found")
            return
        }

        guard let window = try? WindowUtility.frontmostWindow() else {
            log.info("No frontmost window to snap")
            return
        }

        let screenFrame = targetScreen.cgSafeScreenFrame
        let targetFrame = CGRect(
            x: screenFrame.minX + zone.frame.minX * screenFrame.width,
            y: screenFrame.minY + zone.frame.minY * screenFrame.height,
            width: zone.frame.width * screenFrame.width,
            height: zone.frame.height * screenFrame.height
        )

        log.info("Snapping to zone: \(targetFrame)")
        window.setFrame(targetFrame, sizeFirst: true)

        // Verify and retry
        let actualFrame = window.frame
        if !actualFrame.approximatelyEqual(to: targetFrame, tolerance: 5) {
            window.setFrame(targetFrame, sizeFirst: true)
        }
    }

    // MARK: - CRUD

    static func deleteLayout(id layoutID: UUID) {
        var savedLayouts = Defaults[.savedLayouts]
        savedLayouts.removeAll { $0.id == layoutID }
        Defaults[.savedLayouts] = savedLayouts

        // Also remove from active assignments
        var activeMap = Defaults[.activeLayoutPerScreen]
        activeMap = activeMap.filter { $0.value != layoutID.uuidString }
        Defaults[.activeLayoutPerScreen] = activeMap

        log.info("Deleted layout: \(layoutID)")
    }

    static func renameLayout(id layoutID: UUID, to newName: String) {
        var savedLayouts = Defaults[.savedLayouts]
        if let index = savedLayouts.firstIndex(where: { $0.id == layoutID }) {
            savedLayouts[index].name = newName
            Defaults[.savedLayouts] = savedLayouts
        }
    }

    // MARK: - Screen Assignment

    /// Assigns a layout to a screen. When the screen has an active layout,
    /// the Loop trigger will show layout zones instead of the radial menu.
    static func assignLayout(_ layout: SavedLayout, to screen: NSScreen) {
        var activeMap = Defaults[.activeLayoutPerScreen]
        activeMap[screen.localizedName] = layout.id.uuidString
        Defaults[.activeLayoutPerScreen] = activeMap
        log.success("Assigned layout '\(layout.name)' to screen '\(screen.localizedName)'")
    }

    /// Removes the layout assignment from a screen.
    static func unassignLayout(from screen: NSScreen) {
        var activeMap = Defaults[.activeLayoutPerScreen]
        activeMap.removeValue(forKey: screen.localizedName)
        Defaults[.activeLayoutPerScreen] = activeMap
        log.info("Unassigned layout from screen '\(screen.localizedName)'")
    }

    /// Returns the active layout for a given screen, if any.
    static func activeLayout(for screen: NSScreen) -> SavedLayout? {
        guard Defaults[.enableWorkspaces] else { return nil }

        let activeMap = Defaults[.activeLayoutPerScreen]
        guard let layoutIDString = activeMap[screen.localizedName] else { return nil }

        return Defaults[.savedLayouts].first { $0.id.uuidString == layoutIDString }
    }

    // MARK: - Zone Matching

    /// Finds which layout zone contains the given proportional point (0.0-1.0).
    /// Used by the trigger system to determine which zone the mouse is hovering over.
    static func zoneContaining(
        proportionalPoint point: CGPoint,
        in layout: SavedLayout
    ) -> LayoutZone? {
        layout.zones.first { zone in
            zone.frame.contains(point)
        }
    }

    /// Converts a LayoutZone into a WindowAction with a custom frame.
    /// This allows the zone to work with Loop's existing preview and snap system.
    static func windowAction(for zone: LayoutZone, at index: Int) -> WindowAction {
        WindowAction(
            .custom,
            keybind: [],
            name: "Layout Zone \(index + 1)",
            unit: .percentage,
            anchor: .topLeft,
            width: zone.frame.width * 100,
            height: zone.frame.height * 100,
            xPoint: zone.frame.minX * 100,
            yPoint: zone.frame.minY * 100,
            positionMode: .coordinates
        )
    }
}

