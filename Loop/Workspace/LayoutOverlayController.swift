//
//  LayoutOverlayController.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import Scribe
import SwiftUI

/// Controls the layout overlay panel that shows zones on screen.
///
/// When activated, shows a full-screen transparent panel with clickable zones.
/// Clicking a zone snaps the frontmost window to that zone's proportional frame.
@Loggable(style: .static)
@MainActor
final class LayoutOverlayController {
    static let shared = LayoutOverlayController()

    private var panel: NSPanel?
    private var eventMonitor: Any?

    private init() {}

    /// Shows the layout overlay for the given layout on the focused screen.
    func show(layout: SavedLayout) {
        // Close any existing overlay first
        close()

        guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else {
            Self.log.info("No screen found for layout overlay")
            return
        }

        let screenFrame = screen.cgSafeScreenFrame

        let overlayView = LayoutOverlayView(
            layout: layout,
            screenFrame: screenFrame,
            onZoneClicked: { [weak self] zone in
                LayoutManager.snapToZone(zone, screen: screen)
                // Brief delay to let the window snap before potential auto-dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Re-activate the overlay panel so it stays on top
                    self?.panel?.makeKeyAndOrderFront(nil)
                }
            },
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = NSHostingView(rootView: overlayView)
        panel.setFrame(screen.frame, display: true)

        // Make clickable
        panel.ignoresMouseEvents = false

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // ESC key handler
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.close()
                return nil
            }
            return event
        }

        Self.log.info("Layout overlay opened: '\(layout.name)' with \(layout.zones.count) zones")
    }

    /// Closes the overlay panel.
    func close() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        panel?.orderOut(nil)
        panel?.close()
        panel = nil

        Self.log.info("Layout overlay closed")
    }

    var isShowing: Bool {
        panel != nil
    }
}
