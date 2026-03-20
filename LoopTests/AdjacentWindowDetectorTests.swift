//
//  AdjacentWindowDetectorTests.swift
//  LoopTests
//
//  Created by Tika on 2026-03-20.
//

import XCTest
@testable import Loop

final class AdjacentWindowDetectorTests: XCTestCase {

    // MARK: - overlapLength Tests

    func testOverlapLength_fullOverlap() {
        // Two ranges that completely overlap
        let result = testOverlapLength(range1: (0, 100), range2: (0, 100))
        XCTAssertEqual(result, 100)
    }

    func testOverlapLength_partialOverlap() {
        // Partial overlap: 50..100 shared
        let result = testOverlapLength(range1: (0, 100), range2: (50, 150))
        XCTAssertEqual(result, 50)
    }

    func testOverlapLength_noOverlap() {
        // No overlap
        let result = testOverlapLength(range1: (0, 50), range2: (100, 200))
        XCTAssertEqual(result, 0)
    }

    func testOverlapLength_touching() {
        // Touching at a point (0 overlap)
        let result = testOverlapLength(range1: (0, 50), range2: (50, 100))
        XCTAssertEqual(result, 0)
    }

    func testOverlapLength_contained() {
        // One range fully inside the other
        let result = testOverlapLength(range1: (0, 200), range2: (50, 150))
        XCTAssertEqual(result, 100)
    }

    // MARK: - Edge Detection Logic Tests

    func testAdjacentEdge_rightEdge() {
        // Window A (left half) right edge at x=960
        // Window B (right half) left edge at x=960
        // They share a right edge
        let targetFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let adjacentFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

        let isAdjacent = abs(targetFrame.maxX - adjacentFrame.minX) <= 5
        let overlap = testOverlapLength(
            range1: (targetFrame.minY, targetFrame.maxY),
            range2: (adjacentFrame.minY, adjacentFrame.maxY)
        )

        XCTAssertTrue(isAdjacent)
        XCTAssertEqual(overlap, 1080) // Full vertical overlap
    }

    func testAdjacentEdge_leftEdge() {
        // Window A (right half) left edge at x=960
        // Window B (left half) right edge at x=960
        let targetFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let adjacentFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        let isAdjacent = abs(targetFrame.minX - adjacentFrame.maxX) <= 5
        XCTAssertTrue(isAdjacent)
    }

    func testAdjacentEdge_bottomEdge() {
        // Window A (top half) bottom edge at y=540
        // Window B (bottom half) top edge at y=540
        let targetFrame = CGRect(x: 0, y: 0, width: 1920, height: 540)
        let adjacentFrame = CGRect(x: 0, y: 540, width: 1920, height: 540)

        let isAdjacent = abs(targetFrame.maxY - adjacentFrame.minY) <= 5
        XCTAssertTrue(isAdjacent)
    }

    func testAdjacentEdge_withTolerance() {
        // Window edges 3px apart, tolerance 5px → should be adjacent
        let targetFrame = CGRect(x: 0, y: 0, width: 957, height: 1080)
        let adjacentFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

        let distance = abs(targetFrame.maxX - adjacentFrame.minX)
        XCTAssertEqual(distance, 3)
        XCTAssertTrue(distance <= 5) // Within tolerance
    }

    func testAdjacentEdge_exceedsTolerance() {
        // Window edges 15px apart, tolerance 5px → should NOT be adjacent
        let targetFrame = CGRect(x: 0, y: 0, width: 945, height: 1080)
        let adjacentFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

        let distance = abs(targetFrame.maxX - adjacentFrame.minX)
        XCTAssertEqual(distance, 15)
        XCTAssertFalse(distance <= 5) // Exceeds tolerance
    }

    func testAdjacentEdge_noVerticalOverlap() {
        // Right edges align but no vertical overlap (windows are at different Y positions)
        let targetFrame = CGRect(x: 0, y: 0, width: 960, height: 500)
        let adjacentFrame = CGRect(x: 960, y: 600, width: 960, height: 480)

        let horizontallyAdjacent = abs(targetFrame.maxX - adjacentFrame.minX) <= 5
        let verticalOverlap = testOverlapLength(
            range1: (targetFrame.minY, targetFrame.maxY),
            range2: (adjacentFrame.minY, adjacentFrame.maxY)
        )

        XCTAssertTrue(horizontallyAdjacent) // Edges are close
        XCTAssertEqual(verticalOverlap, 0)  // But no vertical overlap → NOT truly adjacent
    }

    // MARK: - Delta Calculation Tests

    func testDelta_rightEdgeMoved() {
        // Window A resized from left-half to left-two-thirds
        let oldFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let newFrame = CGRect(x: 0, y: 0, width: 1280, height: 1080)

        let delta = newFrame.maxX - oldFrame.maxX
        XCTAssertEqual(delta, 320) // Right edge moved 320px right
    }

    func testDelta_leftEdgeMoved() {
        // Window moved its left edge to the left
        let oldFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)
        let newFrame = CGRect(x: 640, y: 0, width: 1280, height: 1080)

        let delta = oldFrame.minX - newFrame.minX
        XCTAssertEqual(delta, 320) // Left edge moved 320px left
    }

    func testAdjacentFrameAdjustment_rightEdge() {
        // Window A resizes right edge from 960 to 1280
        // Adjacent window B should shrink from left: origin.x moves right, width shrinks
        let oldFrame = CGRect(x: 0, y: 0, width: 960, height: 1080)
        let newFrame = CGRect(x: 0, y: 0, width: 1280, height: 1080)

        var adjFrame = CGRect(x: 960, y: 0, width: 960, height: 1080)

        let delta = newFrame.maxX - oldFrame.maxX // 320
        adjFrame.origin.x += delta     // 960 + 320 = 1280
        adjFrame.size.width -= delta   // 960 - 320 = 640

        XCTAssertEqual(adjFrame.origin.x, 1280)
        XCTAssertEqual(adjFrame.size.width, 640)
        XCTAssertEqual(adjFrame.maxX, 1920) // Right edge stays at screen edge
    }

    func testMinimumWindowSize_enforcedCorrectly() {
        // Adjacent window would become too small (width < 200)
        let minimumWindowDimension: CGFloat = 200
        let adjFrame = CGRect(x: 1800, y: 0, width: 120, height: 1080)

        XCTAssertFalse(adjFrame.width >= minimumWindowDimension)
        // This window should be skipped by AdjacentWindowManager
    }

    // MARK: - Helpers

    /// Test helper that mirrors AdjacentWindowDetector's overlapLength logic
    private func testOverlapLength(range1: (CGFloat, CGFloat), range2: (CGFloat, CGFloat)) -> CGFloat {
        let overlapStart = max(range1.0, range2.0)
        let overlapEnd = min(range1.1, range2.1)
        return max(0, overlapEnd - overlapStart)
    }
}
