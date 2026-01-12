import XCTest
@testable import VSCodeSwitcherCore

final class TilingLayoutTests: XCTestCase {
    func testCompute_returnsNilForInvalidFrame() {
        let input = TilingLayoutInput(visibleFrame: .zero, requestedSidebarWidth: 320)
        XCTAssertNil(TilingLayout.compute(input))
    }

    func testCompute_nonUltrawideUsesFullVisibleFrameAndMinY() {
        let visible = CGRect(x: 100, y: 50, width: 1600, height: 900) // 16:9
        let output = TilingLayout.compute(.init(visibleFrame: visible, requestedSidebarWidth: 320))!
        XCTAssertFalse(output.isUltrawide)
        XCTAssertEqual(output.containerFrame, visible)
        XCTAssertEqual(output.appFrame.minX, visible.minX)
        XCTAssertEqual(output.appFrame.minY, visible.minY)
        XCTAssertEqual(output.codeFrame.minY, visible.minY)
        XCTAssertEqual(output.appFrame.maxY, visible.maxY)
        XCTAssertEqual(output.codeFrame.height, visible.height)
    }

    func testCompute_ultrawideUsesLeftHalfAndUsesContainerMinY() {
        let visible = CGRect(x: 0, y: 25, width: 2520, height: 1080) // 21:9-ish
        let output = TilingLayout.compute(.init(visibleFrame: visible, requestedSidebarWidth: 320))!
        XCTAssertTrue(output.isUltrawide)
        XCTAssertEqual(output.containerFrame.width, visible.width * 0.5, accuracy: 0.001)
        XCTAssertEqual(output.containerFrame.minX, visible.minX)
        XCTAssertEqual(output.containerFrame.minY, visible.minY)
        XCTAssertEqual(output.codeFrame.minY, output.containerFrame.minY)
        XCTAssertEqual(output.codeFrame.maxY, output.containerFrame.maxY)
    }

    func testCompute_framesDoNotOverflowContainerHorizontally() {
        let visible = CGRect(x: 10, y: 20, width: 3000, height: 1000)
        let output = TilingLayout.compute(.init(visibleFrame: visible, requestedSidebarWidth: 10000))!
        XCTAssertLessThanOrEqual(output.appFrame.maxX, output.containerFrame.maxX + 0.001)
        XCTAssertEqual(output.codeFrame.maxX, output.containerFrame.maxX, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(output.codeFrame.width, 0)
    }
}
