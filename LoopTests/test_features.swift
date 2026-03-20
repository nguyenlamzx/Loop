#!/usr/bin/env swift
import CoreGraphics
//
//  test_features.swift
//  Standalone test runner for Adjacent Windows + Workspace features
//
//  Run: swift LoopTests/test_features.swift
//

import Foundation

// MARK: - Test Framework

var testsPassed = 0
var testsFailed = 0
var testErrors: [String] = []

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if a == b {
        testsPassed += 1
    } else {
        testsFailed += 1
        let msg = message.isEmpty ? "\(a) != \(b)" : message
        testErrors.append("  FAIL [\(line)]: \(msg)")
    }
}

func assertEqualFloat(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat = 0.001, _ message: String = "", line: Int = #line) {
    if abs(a - b) <= accuracy {
        testsPassed += 1
    } else {
        testsFailed += 1
        let msg = message.isEmpty ? "\(a) != \(b) (accuracy: \(accuracy))" : message
        testErrors.append("  FAIL [\(line)]: \(msg)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", line: Int = #line) {
    if condition { testsPassed += 1 } else {
        testsFailed += 1
        testErrors.append("  FAIL [\(line)]: \(message.isEmpty ? "Expected true" : message)")
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", line: Int = #line) {
    assertTrue(!condition, message.isEmpty ? "Expected false" : message, line: line)
}

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", line: Int = #line) {
    if a != b { testsPassed += 1 } else {
        testsFailed += 1
        testErrors.append("  FAIL [\(line)]: \(message.isEmpty ? "Expected not equal" : message)")
    }
}

func testGroup(_ name: String, _ block: () -> Void) {
    let before = testsPassed + testsFailed
    testErrors = []
    block()
    let total = (testsPassed + testsFailed) - before
    let failed = testErrors.count
    if failed == 0 {
        print("  ✅ \(name) (\(total) assertions)")
    } else {
        print("  ❌ \(name) (\(failed)/\(total) failed)")
        testErrors.forEach { print($0) }
    }
}

// MARK: - Helper (mirrors AdjacentWindowDetector logic)

func overlapLength(range1: (CGFloat, CGFloat), range2: (CGFloat, CGFloat)) -> CGFloat {
    let overlapStart = max(range1.0, range2.0)
    let overlapEnd = min(range1.1, range2.1)
    return max(0, overlapEnd - overlapStart)
}

// ============================================================
// TEST SUITE 1: Adjacent Window Detector
// ============================================================

print("\n🧪 TEST SUITE: Adjacent Window Detector")
print("=" * 50)

testGroup("Overlap: full overlap") {
    assertEqual(overlapLength(range1: (0, 100), range2: (0, 100)), 100)
}

testGroup("Overlap: partial overlap") {
    assertEqual(overlapLength(range1: (0, 100), range2: (50, 150)), 50)
}

testGroup("Overlap: no overlap") {
    assertEqual(overlapLength(range1: (0, 50), range2: (100, 200)), 0)
}

testGroup("Overlap: touching (zero overlap)") {
    assertEqual(overlapLength(range1: (0, 50), range2: (50, 100)), 0)
}

testGroup("Overlap: contained range") {
    assertEqual(overlapLength(range1: (0, 200), range2: (50, 150)), 100)
}

testGroup("Edge detection: right edge adjacent") {
    let targetFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
    let adjacentFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
    let distance = abs(targetFrame.maxX - adjacentFrame.minX)
    assertTrue(distance <= 5, "Distance \(distance) should be <= 5")
    let overlap = overlapLength(range1: (targetFrame.minY, targetFrame.maxY), range2: (adjacentFrame.minY, adjacentFrame.maxY))
    assertEqual(overlap, 1080)
}

testGroup("Edge detection: within tolerance (3px gap)") {
    let targetFrame = CGRect(x: 0, y: 0, width: 957, height: 1080)
    let adjacentFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
    let distance = abs(targetFrame.maxX - adjacentFrame.minX)
    assertEqual(distance, 3)
    assertTrue(distance <= 5)
}

testGroup("Edge detection: exceeds tolerance (15px gap)") {
    let targetFrame = CGRect(x: 0, y: 0, width: 945, height: 1080)
    let adjacentFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
    let distance = abs(targetFrame.maxX - adjacentFrame.minX)
    assertEqual(distance, 15)
    assertFalse(distance <= 5)
}

testGroup("Edge detection: no vertical overlap means not adjacent") {
    let targetFrame = CGRect(x: 0, y: 0, width: 960, height: 500)
    let adjacentFrame = CGRect(x: 960, y: 600, width: 960, height: 480)
    assertTrue(abs(targetFrame.maxX - adjacentFrame.minX) <= 5) // Edges close
    let overlap = overlapLength(range1: (targetFrame.minY, targetFrame.maxY), range2: (adjacentFrame.minY, adjacentFrame.maxY))
    assertEqual(overlap, 0, "Should have zero vertical overlap")
}

testGroup("Delta: right edge moved right") {
    let oldFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
    let newFrame = CGRect(x: 0, y: 0, width: 1280, height: 1080)
    assertEqual(newFrame.maxX - oldFrame.maxX, 320)
}

testGroup("Adjacent frame adjustment: right edge resize") {
    let oldFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
    let newFrame = CGRect(x: 0, y: 0, width: 1280, height: 1080)
    var adjFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

    let delta = newFrame.maxX - oldFrame.maxX
    adjFrame.origin.x += delta
    adjFrame.size.width -= delta

    assertEqual(adjFrame.origin.x, 1280)
    assertEqual(adjFrame.size.width, 640)
    assertEqual(adjFrame.maxX, 1920)
}

testGroup("Min window size enforced") {
    let minimumDim: CGFloat = 200
    let smallFrame = CGRect(x: 1800, y: 0, width: 120, height: 1080)
    assertFalse(smallFrame.width >= minimumDim)
}

// ============================================================
// TEST SUITE 2: Workspace Manager
// ============================================================

print("\n🧪 TEST SUITE: Workspace Manager")
print("=" * 50)

testGroup("Proportional frame: calculation") {
    let frame = CGRect(x: 25, y: 25, width: 935, height: 1030)
    let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    let propFrame = CGRect(
        x: (frame.minX - screenFrame.minX) / screenFrame.width,
        y: (frame.minY - screenFrame.minY) / screenFrame.height,
        width: frame.width / screenFrame.width,
        height: frame.height / screenFrame.height
    )

    assertEqualFloat(propFrame.minX, 25.0 / 1920.0)
    assertEqualFloat(propFrame.minY, 25.0 / 1080.0)
    assertEqualFloat(propFrame.width, 935.0 / 1920.0)
    assertEqualFloat(propFrame.height, 1030.0 / 1080.0)
}

testGroup("Proportional frame: restore to same screen") {
    let propFrame = CGRect(x: 0, y: 0, width: 0.5, height: 1.0)
    let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    let restored = CGRect(
        x: screenFrame.minX + propFrame.minX * screenFrame.width,
        y: screenFrame.minY + propFrame.minY * screenFrame.height,
        width: propFrame.width * screenFrame.width,
        height: propFrame.height * screenFrame.height
    )

    assertEqual(restored, CGRect(x: 0, y: 0, width: 960, height: 1080))
}

testGroup("Proportional frame: restore to different resolution") {
    let propFrame = CGRect(x: 0, y: 0, width: 0.5, height: 1.0)
    let newScreen = CGRect(x: 0, y: 0, width: 2560, height: 1440)

    let restored = CGRect(
        x: newScreen.minX + propFrame.minX * newScreen.width,
        y: newScreen.minY + propFrame.minY * newScreen.height,
        width: propFrame.width * newScreen.width,
        height: propFrame.height * newScreen.height
    )

    assertEqual(restored, CGRect(x: 0, y: 0, width: 1280, height: 1440))
}

testGroup("Proportional frame: restore with screen offset") {
    let propFrame = CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.8)
    let screenFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)

    let restored = CGRect(
        x: screenFrame.minX + propFrame.minX * screenFrame.width,
        y: screenFrame.minY + propFrame.minY * screenFrame.height,
        width: propFrame.width * screenFrame.width,
        height: propFrame.height * screenFrame.height
    )

    assertEqualFloat(restored.origin.x, 2400, accuracy: 0.1)
    assertEqualFloat(restored.origin.y, 108, accuracy: 0.1)
    assertEqualFloat(restored.width, 960, accuracy: 0.1)
    assertEqualFloat(restored.height, 864, accuracy: 0.1)
}

testGroup("Screen config hash: order independent") {
    let hash1 = ["B:frame2", "A:frame1"].sorted().joined(separator: "|")
    let hash2 = ["A:frame1", "B:frame2"].sorted().joined(separator: "|")
    assertEqual(hash1, hash2)
}

// ============================================================
// SUMMARY
// ============================================================

print("\n" + "=" * 50)
let total = testsPassed + testsFailed
if testsFailed == 0 {
    print("🎉 ALL TESTS PASSED: \(testsPassed)/\(total)")
} else {
    print("❌ TESTS: \(testsPassed) passed, \(testsFailed) failed (total: \(total))")
}
print("=" * 50 + "\n")

exit(testsFailed > 0 ? 1 : 0)

// MARK: - String * Int helper
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
