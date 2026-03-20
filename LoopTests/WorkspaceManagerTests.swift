//
//  WorkspaceManagerTests.swift
//  LoopTests
//
//  Created by Tika on 2026-03-20.
//

import XCTest
@testable import Loop

final class WorkspaceManagerTests: XCTestCase {

    // MARK: - SavedWorkspace Model Tests

    func testWorkspaceWindowEntry_codable() throws {
        let entry = WorkspaceWindowEntry(
            bundleIdentifier: "com.apple.Safari",
            windowTitle: "Apple",
            frame: CGRect(x: 0, y: 0, width: 960, height: 1080),
            proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1.0),
            screenIdentifier: "Built-in Display",
            appName: "Safari"
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(WorkspaceWindowEntry.self, from: data)

        XCTAssertEqual(entry.bundleIdentifier, decoded.bundleIdentifier)
        XCTAssertEqual(entry.windowTitle, decoded.windowTitle)
        XCTAssertEqual(entry.frame, decoded.frame)
        XCTAssertEqual(entry.proportionalFrame, decoded.proportionalFrame)
        XCTAssertEqual(entry.screenIdentifier, decoded.screenIdentifier)
        XCTAssertEqual(entry.appName, decoded.appName)
    }

    func testSavedWorkspace_codable() throws {
        let entries = [
            WorkspaceWindowEntry(
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Apple",
                frame: CGRect(x: 0, y: 0, width: 960, height: 1080),
                proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1.0),
                screenIdentifier: "Built-in Display",
                appName: "Safari"
            ),
            WorkspaceWindowEntry(
                bundleIdentifier: "com.apple.Terminal",
                windowTitle: "Terminal",
                frame: CGRect(x: 960, y: 0, width: 960, height: 1080),
                proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0),
                screenIdentifier: "Built-in Display",
                appName: "Terminal"
            )
        ]

        let workspace = SavedWorkspace(
            name: "Test Workspace",
            windows: entries,
            screenConfigurationHash: "Built-in Display:(0.0, 0.0, 1920.0, 1080.0)"
        )

        let data = try JSONEncoder().encode(workspace)
        let decoded = try JSONDecoder().decode(SavedWorkspace.self, from: data)

        XCTAssertEqual(workspace.id, decoded.id)
        XCTAssertEqual(workspace.name, decoded.name)
        XCTAssertEqual(workspace.windows.count, decoded.windows.count)
        XCTAssertEqual(workspace.windows[0].bundleIdentifier, decoded.windows[0].bundleIdentifier)
        XCTAssertEqual(workspace.windows[1].bundleIdentifier, decoded.windows[1].bundleIdentifier)
        XCTAssertEqual(workspace.screenConfigurationHash, decoded.screenConfigurationHash)
    }

    // MARK: - Proportional Frame Tests

    func testProportionalFrame_calculation() {
        // Window at left half of 1920x1080 screen
        let frame = CGRect(x: 25, y: 25, width: 935, height: 1030)
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let proportionalFrame = CGRect(
            x: (frame.minX - screenFrame.minX) / screenFrame.width,
            y: (frame.minY - screenFrame.minY) / screenFrame.height,
            width: frame.width / screenFrame.width,
            height: frame.height / screenFrame.height
        )

        XCTAssertEqual(proportionalFrame.minX, 25.0 / 1920.0, accuracy: 0.001)
        XCTAssertEqual(proportionalFrame.minY, 25.0 / 1080.0, accuracy: 0.001)
        XCTAssertEqual(proportionalFrame.width, 935.0 / 1920.0, accuracy: 0.001)
        XCTAssertEqual(proportionalFrame.height, 1030.0 / 1080.0, accuracy: 0.001)
    }

    func testProportionalFrame_restoreToSameScreen() {
        // Proportional frame: left half
        let proportionalFrame = CGRect(x: 0, y: 0, width: 0.5, height: 1.0)
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let restoredFrame = CGRect(
            x: screenFrame.minX + proportionalFrame.minX * screenFrame.width,
            y: screenFrame.minY + proportionalFrame.minY * screenFrame.height,
            width: proportionalFrame.width * screenFrame.width,
            height: proportionalFrame.height * screenFrame.height
        )

        XCTAssertEqual(restoredFrame, CGRect(x: 0, y: 0, width: 960, height: 1080))
    }

    func testProportionalFrame_restoreToDifferentResolution() {
        // Saved on 1920x1080, restore on 2560x1440
        let proportionalFrame = CGRect(x: 0, y: 0, width: 0.5, height: 1.0) // Left half

        let newScreenFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)

        let restoredFrame = CGRect(
            x: newScreenFrame.minX + proportionalFrame.minX * newScreenFrame.width,
            y: newScreenFrame.minY + proportionalFrame.minY * newScreenFrame.height,
            width: proportionalFrame.width * newScreenFrame.width,
            height: proportionalFrame.height * newScreenFrame.height
        )

        // Should be left half of new screen
        XCTAssertEqual(restoredFrame, CGRect(x: 0, y: 0, width: 1280, height: 1440))
    }

    func testProportionalFrame_restoreWithOffset() {
        // Screen starts at x=1920 (second monitor)
        let proportionalFrame = CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.8)
        let screenFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)

        let restoredFrame = CGRect(
            x: screenFrame.minX + proportionalFrame.minX * screenFrame.width,
            y: screenFrame.minY + proportionalFrame.minY * screenFrame.height,
            width: proportionalFrame.width * screenFrame.width,
            height: proportionalFrame.height * screenFrame.height
        )

        XCTAssertEqual(restoredFrame.origin.x, 1920 + 480, accuracy: 0.1) // 1920 + 0.25*1920
        XCTAssertEqual(restoredFrame.origin.y, 108, accuracy: 0.1)        // 0.1*1080
        XCTAssertEqual(restoredFrame.width, 960, accuracy: 0.1)           // 0.5*1920
        XCTAssertEqual(restoredFrame.height, 864, accuracy: 0.1)          // 0.8*1080
    }

    // MARK: - Screen Configuration Hash Tests

    func testScreenConfigurationHash_format() {
        // Test the hash format (we can't test with real screens, but test the logic)
        let screen1 = "Built-in Display:(0.0, 0.0, 1920.0, 1080.0)"
        let screen2 = "External:(1920.0, 0.0, 2560.0, 1440.0)"
        let hash = [screen1, screen2].sorted().joined(separator: "|")

        XCTAssertTrue(hash.contains("Built-in Display"))
        XCTAssertTrue(hash.contains("External"))
        XCTAssertTrue(hash.contains("|"))
    }

    func testScreenConfigurationHash_differentOrderSameResult() {
        let screens1 = ["B:frame2", "A:frame1"].sorted().joined(separator: "|")
        let screens2 = ["A:frame1", "B:frame2"].sorted().joined(separator: "|")

        // Sorting ensures same hash regardless of screen order
        XCTAssertEqual(screens1, screens2)
    }

    // MARK: - Workspace Data Integrity

    func testWorkspace_uniqueIDs() {
        let workspace1 = SavedWorkspace(name: "WS1", windows: [], screenConfigurationHash: "hash")
        let workspace2 = SavedWorkspace(name: "WS2", windows: [], screenConfigurationHash: "hash")

        XCTAssertNotEqual(workspace1.id, workspace2.id)
    }

    func testWorkspace_mutableName() {
        var workspace = SavedWorkspace(name: "Original", windows: [], screenConfigurationHash: "hash")
        workspace.name = "Renamed"
        XCTAssertEqual(workspace.name, "Renamed")
    }

    func testWorkspace_mutableKeybind() {
        var workspace = SavedWorkspace(name: "WS", windows: [], screenConfigurationHash: "hash")
        XCTAssertNil(workspace.keybind)

        workspace.keybind = [0, 1, 2]
        XCTAssertEqual(workspace.keybind, [0, 1, 2])
    }
}
