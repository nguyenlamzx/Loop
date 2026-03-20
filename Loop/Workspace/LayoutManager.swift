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
        log.info("Deleted layout: \(layoutID)")
    }

    static func renameLayout(id layoutID: UUID, to newName: String) {
        var savedLayouts = Defaults[.savedLayouts]
        if let index = savedLayouts.firstIndex(where: { $0.id == layoutID }) {
            savedLayouts[index].name = newName
            Defaults[.savedLayouts] = savedLayouts
        }
    }
}
