//
//  SavedLayout.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import SwiftUI

/// A layout zone — a proportional area on the screen (0.0 - 1.0)
struct LayoutZone: Codable, Defaults.Serializable, Hashable, Identifiable {
    let id: UUID
    /// Proportional frame relative to usable screen area
    let frame: CGRect

    init(frame: CGRect) {
        self.id = UUID()
        self.frame = frame
    }
}

/// A saved layout — a set of zones that tile the screen
struct SavedLayout: Codable, Identifiable, Hashable, Defaults.Serializable {
    let id: UUID
    var name: String
    var zones: [LayoutZone]
    var createdAt: Date

    init(name: String, zones: [LayoutZone]) {
        self.id = UUID()
        self.name = name
        self.zones = zones
        self.createdAt = Date()
    }

    /// Human-readable description of zone arrangement
    var zoneDescription: String {
        "\(zones.count) zones"
    }
}
