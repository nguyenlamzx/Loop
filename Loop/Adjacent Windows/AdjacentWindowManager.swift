//
//  AdjacentWindowManager.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import Scribe
import SwiftUI

/// Manages the resizing of windows adjacent to a window being resized.
///
/// When a window is resized via Loop, this manager detects windows that share a border
/// (adjacent windows) and adjusts their frames accordingly to maintain a seamless layout.
///
/// ## Example
/// Window A (left half) + Window B (right half).
/// User resizes A to left two-thirds → B automatically shrinks to right one-third.
///
/// ## Behavior
/// - Only triggers when `Defaults[.resizeAdjacentWindows]` is enabled.
/// - Uses `AdjacentWindowDetector` to find windows sharing borders.
/// - Respects minimum window size (200x200 points).
/// - Does NOT cascade (resizing A adjusts B, but does not then adjust C via B).
/// - Ignores stashed windows.
@Loggable(style: .static)
enum AdjacentWindowManager {
    /// Minimum window size (width or height) to prevent windows from becoming too small
    private static let minimumWindowDimension: CGFloat = 200

    /// Resizes windows adjacent to the resized window to maintain layout continuity.
    ///
    /// Call this **after** a window has been resized by Loop. It will detect adjacent windows
    /// and adjust their frames based on the delta between the old and new frames.
    ///
    /// - Parameters:
    ///   - resizedWindow: The window that was just resized.
    ///   - oldFrame: The window's frame before the resize.
    ///   - newFrame: The window's frame after the resize.
    ///   - screen: The screen the window is on (used to get screen bounds).
    static func resizeAdjacentWindows(
        resizedWindow: Window,
        oldFrame: CGRect,
        newFrame: CGRect,
        screen: NSScreen
    ) {
        guard Defaults[.resizeAdjacentWindows] else { return }

        // Skip if the frame didn't actually change
        guard !oldFrame.approximatelyEqual(to: newFrame) else {
            log.info("Adjacent: Skipping — frame didn't change (old: \(oldFrame), new: \(newFrame))")
            return
        }

        log.info("Adjacent: Checking for windows adjacent to \(resizedWindow.description)")
        log.info("Adjacent: oldFrame=\(oldFrame) → newFrame=\(newFrame)")

        let tolerance = Defaults[.adjacentResizeTolerance]

        // Get all windows on screen, excluding the resized window and stashed windows
        let allWindows = WindowUtility.windowList().filter { window in
            window.cgWindowID != resizedWindow.cgWindowID
                && StashManager.shared.getRevealedFrameForStashedWindow(id: window.cgWindowID) == nil
        }

        log.info("Adjacent: Found \(allWindows.count) candidate windows (tolerance: \(tolerance))")

        // Use the OLD frame to detect adjacency (before the resize happened)
        let adjacentEdges = AdjacentWindowDetector.findAdjacentWindows(
            targetFrame: oldFrame,
            targetWindowID: resizedWindow.cgWindowID,
            from: allWindows,
            tolerance: tolerance
        )

        guard !adjacentEdges.isEmpty else {
            log.info("Adjacent: No adjacent windows found")
            return
        }
        log.info("Adjusting \(adjacentEdges.count) adjacent window(s) after resize of \(resizedWindow.description)")

        let screenBounds = screen.cgSafeScreenFrame

        for adj in adjacentEdges {
            var adjFrame = adj.window.frame

            switch adj.edge {
            case .right:
                // Resized window's right edge moved → adjacent window's left edge must follow
                let delta = newFrame.maxX - oldFrame.maxX
                adjFrame.origin.x += delta
                adjFrame.size.width -= delta

            case .left:
                // Resized window's left edge moved → adjacent window's right edge must follow
                let delta = oldFrame.minX - newFrame.minX
                adjFrame.size.width -= delta

            case .bottom:
                // Resized window's bottom edge moved → adjacent window's top edge must follow
                let delta = newFrame.maxY - oldFrame.maxY
                adjFrame.origin.y += delta
                adjFrame.size.height -= delta

            case .top:
                // Resized window's top edge moved → adjacent window's bottom edge must follow
                let delta = oldFrame.minY - newFrame.minY
                adjFrame.size.height -= delta
            }

            // Validate minimum size
            guard adjFrame.width >= minimumWindowDimension,
                  adjFrame.height >= minimumWindowDimension else {
                log.info("Skipping \(adj.window.description): resulting frame too small (\(adjFrame.size))")
                continue
            }

            // Validate frame is within screen bounds
            guard screenBounds.contains(CGPoint(x: adjFrame.midX, y: adjFrame.midY)) else {
                log.info("Skipping \(adj.window.description): resulting frame outside screen")
                continue
            }

            log.info("Resizing adjacent \(adj.window.description) from \(adj.window.frame) to \(adjFrame)")
            adj.window.setFrame(adjFrame)
        }
    }
}
