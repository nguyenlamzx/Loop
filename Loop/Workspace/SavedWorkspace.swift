//
//  SavedWorkspace.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import SwiftUI

/// Represents a single window's state in a saved workspace
struct WorkspaceWindowEntry: Codable, Defaults.Serializable, Hashable {
    /// The bundle identifier of the application (e.g., "com.apple.Safari")
    let bundleIdentifier: String

    /// Optional window title for more precise matching when an app has multiple windows
    let windowTitle: String?

    /// The window's frame (position + size) in screen coordinates
    let frame: CGRect

    /// Proportional frame relative to the screen bounds (0.0 - 1.0)
    /// Used for cross-resolution restore
    let proportionalFrame: CGRect

    /// Display identifier to track which monitor this window belongs to
    let screenIdentifier: String

    /// The name of the application for display purposes
    let appName: String?

    /// Whether the window was minimized when the workspace was saved
    let isMinimized: Bool
}

/// Represents a complete workspace layout
struct SavedWorkspace: Codable, Identifiable, Hashable, Defaults.Serializable {
    let id: UUID
    var name: String
    var windows: [WorkspaceWindowEntry]
    var keybind: Set<CGKeyCode>
    var createdAt: Date

    /// Hash of the screen configuration when workspace was saved
    /// Used to detect if monitors have changed and proportional scaling is needed
    var screenConfigurationHash: String

    init(
        name: String,
        windows: [WorkspaceWindowEntry],
        keybind: Set<CGKeyCode> = [],
        screenConfigurationHash: String
    ) {
        self.id = UUID()
        self.name = name
        self.windows = windows
        self.keybind = keybind
        self.createdAt = Date()
        self.screenConfigurationHash = screenConfigurationHash
    }
}
