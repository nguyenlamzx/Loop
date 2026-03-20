//
//  AdjacentWindowDetector.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Scribe
import SwiftUI

/// Describes a shared border between two windows
struct AdjacentEdge {
    /// Which edge of the *resized* window touches the adjacent window
    enum Edge {
        case left, right, top, bottom

        /// Returns the opposite edge
        var opposite: Edge {
            switch self {
            case .left: .right
            case .right: .left
            case .top: .bottom
            case .bottom: .top
            }
        }
    }

    /// The adjacent window
    let window: Window

    /// The edge of the resized window that touches this adjacent window
    let edge: Edge

    /// How many points of the border are shared (overlap length)
    let sharedLength: CGFloat
}

/// Detects windows that are adjacent (share a border) with a given frame.
///
/// Two windows are considered adjacent when one window's edge aligns with another's
/// within a configurable tolerance, AND they have vertical/horizontal overlap.
@Loggable(style: .static)
enum AdjacentWindowDetector {
    /// Finds all windows adjacent to the given frame.
    ///
    /// Uses a frame + windowID instead of a `Window` so we can check adjacency
    /// against the window's *old* frame (before resize), not its current frame.
    ///
    /// - Parameters:
    ///   - targetFrame: The frame to check adjacency against.
    ///   - targetWindowID: The window ID of the target (to exclude from results).
    ///   - allWindows: All on-screen windows to check against.
    ///   - tolerance: Maximum distance (in points) between edges to consider them aligned.
    /// - Returns: Array of `AdjacentEdge` describing each adjacent relationship.
    static func findAdjacentWindows(
        targetFrame: CGRect,
        targetWindowID: CGWindowID,
        from allWindows: [Window],
        tolerance: CGFloat
    ) -> [AdjacentEdge] {
        var adjacent: [AdjacentEdge] = []

        for window in allWindows {
            guard window.cgWindowID != targetWindowID else { continue }

            let frame = window.frame

            // Right edge of target ↔ Left edge of adjacent
            if abs(targetFrame.maxX - frame.minX) <= tolerance {
                let overlap = overlapLength(
                    range1: (targetFrame.minY, targetFrame.maxY),
                    range2: (frame.minY, frame.maxY)
                )
                if overlap > 0 {
                    adjacent.append(AdjacentEdge(window: window, edge: .right, sharedLength: overlap))
                }
            }

            // Left edge of target ↔ Right edge of adjacent
            if abs(targetFrame.minX - frame.maxX) <= tolerance {
                let overlap = overlapLength(
                    range1: (targetFrame.minY, targetFrame.maxY),
                    range2: (frame.minY, frame.maxY)
                )
                if overlap > 0 {
                    adjacent.append(AdjacentEdge(window: window, edge: .left, sharedLength: overlap))
                }
            }

            // Bottom edge of target ↔ Top edge of adjacent
            if abs(targetFrame.maxY - frame.minY) <= tolerance {
                let overlap = overlapLength(
                    range1: (targetFrame.minX, targetFrame.maxX),
                    range2: (frame.minX, frame.maxX)
                )
                if overlap > 0 {
                    adjacent.append(AdjacentEdge(window: window, edge: .bottom, sharedLength: overlap))
                }
            }

            // Top edge of target ↔ Bottom edge of adjacent
            if abs(targetFrame.minY - frame.maxY) <= tolerance {
                let overlap = overlapLength(
                    range1: (targetFrame.minX, targetFrame.maxX),
                    range2: (frame.minX, frame.maxX)
                )
                if overlap > 0 {
                    adjacent.append(AdjacentEdge(window: window, edge: .top, sharedLength: overlap))
                }
            }
        }

        log.info("Found \(adjacent.count) adjacent windows for frame \(targetFrame)")
        return adjacent
    }

    /// Calculates the overlap length between two 1D ranges.
    ///
    /// - Parameters:
    ///   - range1: First range (min, max).
    ///   - range2: Second range (min, max).
    /// - Returns: The overlap length, or 0 if ranges don't overlap.
    private static func overlapLength(
        range1: (CGFloat, CGFloat),
        range2: (CGFloat, CGFloat)
    ) -> CGFloat {
        let overlapStart = max(range1.0, range2.0)
        let overlapEnd = min(range1.1, range2.1)
        return max(0, overlapEnd - overlapStart)
    }
}
