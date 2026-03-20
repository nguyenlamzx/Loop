//
//  LayoutPickerController.swift
//  Loop
//
//  Created by Tika on 2026-03-20.
//

import Defaults
import Scribe
import SwiftUI

/// Controls the layout picker HUD panel.
///
/// Triggered by Trigger + W (restoreWorkspace action).
/// Shows all saved layouts in a centered card grid.
/// Clicking a layout assigns it to the current screen.
@Loggable(style: .static)
@MainActor
final class LayoutPickerController {
    static let shared = LayoutPickerController()

    private var panel: NSPanel?
    private var eventMonitor: Any?

    private init() {}

    /// Shows the layout picker on the current screen.
    func show() {
        close()

        guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else {
            Self.log.info("No screen found for layout picker")
            return
        }

        let layouts = Defaults[.savedLayouts]
        let screenName = screen.localizedName

        let pickerView = LayoutPickerView(
            layouts: layouts,
            currentScreenName: screenName,
            onSelect: { [weak self] layout in
                LayoutManager.assignLayout(layout, to: screen)
                self?.close()
            },
            onRemove: { [weak self] in
                LayoutManager.unassignLayout(from: screen)
                self?.close()
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
        panel.ignoresMouseEvents = false
        panel.contentView = NSHostingView(rootView: pickerView)
        panel.setFrame(screen.frame, display: true)
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

        Self.log.info("Layout picker opened with \(layouts.count) layouts")
    }

    func close() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    var isShowing: Bool {
        panel != nil
    }
}
