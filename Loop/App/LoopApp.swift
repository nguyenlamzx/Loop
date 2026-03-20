//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import SwiftUI

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var updater = Updater.shared
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.enableWorkspaces) var enableWorkspaces
    @Default(.savedLayouts) var savedLayouts

    var body: some Scene {
        MenuBarExtra(Bundle.main.appName, image: "menubarIcon", isInserted: Binding.constant(!hideMenuBarIcon)) {
            Button {
                if let url = URL(string: "https://github.com/sponsors/MrKai77") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Donate", systemImage: "heart")
            }

            Divider()

            Text(
                "Version \(VersionDisplay.current.fullDisplay)",
                comment: "Format: Version [version, e.g. 1.3.0] ([build number, e.g. 1500])"
            )
            .font(.system(size: 11, weight: .semibold))

            Button {
                Task {
                    await updater.fetchLatestInfo()
                    await updater.showUpdateWindowIfEligible()
                }
            } label: {
                if updater.updateState == .available {
                    Text(
                        "Update…",
                        comment: "Button to update app in menubar dropdown menu"
                    )
                } else {
                    Text(
                        "Check for Updates…",
                        comment: "Button to check for updates in menubar dropdown menu"
                    )
                }
            }

            Button("Settings…") {
                SettingsWindowManager.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)

            if enableWorkspaces {
                Divider()

                Button("Save Layout…") {
                    DispatchQueue.main.async {
                        promptAndSaveLayout()
                    }
                }

                if !savedLayouts.isEmpty {
                    Menu("Apply Layout to Screen") {
                        ForEach(savedLayouts) { layout in
                            Button {
                                if let screen = NSScreen.screenWithMouse ?? NSScreen.main {
                                    LayoutManager.assignLayout(layout, to: screen)
                                }
                            } label: {
                                let isActive = isLayoutActive(layout)
                                if isActive {
                                    Label("\(layout.name) (\(layout.zoneDescription)) ✓", systemImage: "checkmark")
                                } else {
                                    Text("\(layout.name) (\(layout.zoneDescription))")
                                }
                            }
                        }

                        Divider()

                        Button("Remove Layout from Screen") {
                            if let screen = NSScreen.screenWithMouse ?? NSScreen.main {
                                LayoutManager.unassignLayout(from: screen)
                            }
                        }
                    }

                    Menu("Delete Layout") {
                        ForEach(savedLayouts) { layout in
                            Button("Delete \(layout.name)") {
                                LayoutManager.deleteLayout(id: layout.id)
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Quit \(Bundle.main.appName)") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }

    private func promptAndSaveLayout() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Save Layout"
        alert.informativeText = "Capture the current window arrangement as a reusable layout:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.placeholderString = "My Layout"
        textField.stringValue = "Layout \(savedLayouts.count + 1)"
        alert.accessoryView = textField

        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                LayoutManager.captureLayout(name: name)
            }
        }
    }

    private func isLayoutActive(_ layout: SavedLayout) -> Bool {
        guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else { return false }
        let activeMap = Defaults[.activeLayoutPerScreen]
        return activeMap[screen.localizedName] == layout.id.uuidString
    }
}
