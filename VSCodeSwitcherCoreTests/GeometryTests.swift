import XCTest
@testable import VSCodeSwitcherCore

final class GeometryTests: XCTestCase {
    func testClampRect_noopWhenAlreadyInside() {
        let container = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(Geometry.clampRect(rect, into: container), rect)
    }

    func testClampRect_clampsToMinWhenTooFarLeftOrBottom() {
        let container = CGRect(x: 10, y: 20, width: 100, height: 100)
        let rect = CGRect(x: -50, y: -60, width: 30, height: 40)
        let clamped = Geometry.clampRect(rect, into: container)
        XCTAssertEqual(clamped.minX, container.minX)
        XCTAssertEqual(clamped.minY, container.minY)
    }

    func testClampRect_clampsToMaxWhenTooFarRightOrTop() {
        let container = CGRect(x: 10, y: 20, width: 100, height: 100)
        let rect = CGRect(x: 500, y: 600, width: 30, height: 40)
        let clamped = Geometry.clampRect(rect, into: container)
        XCTAssertEqual(clamped.minX, container.maxX - rect.width)
        XCTAssertEqual(clamped.minY, container.maxY - rect.height)
    }

    func testClampRect_containerTooSmallPinsToMin() {
        let container = CGRect(x: 10, y: 20, width: 10, height: 10)
        let rect = CGRect(x: 0, y: 0, width: 30, height: 40)
        let clamped = Geometry.clampRect(rect, into: container)
        XCTAssertEqual(clamped.minX, container.minX)
        XCTAssertEqual(clamped.minY, container.minY)
    }

    func testComputeSidebarWidth_appliesMinAndMaxHalfWidth() {
        let container = CGRect(x: 0, y: 0, width: 1000, height: 800)
        XCTAssertEqual(Geometry.computeSidebarWidth(requested: 10, in: container), 220)
        XCTAssertEqual(Geometry.computeSidebarWidth(requested: 900, in: container), 500)
        XCTAssertEqual(Geometry.computeSidebarWidth(requested: 320, in: container), 320)
    }
}

