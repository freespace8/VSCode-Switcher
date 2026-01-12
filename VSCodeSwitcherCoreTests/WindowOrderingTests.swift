import XCTest
@testable import VSCodeSwitcherCore

final class WindowOrderingTests: XCTestCase {
    func testNormalizeOrder_emptyReturnsNoChange() {
        let result = WindowOrdering.normalizeOrder([], existingIDs: ["a"])
        XCTAssertEqual(result.order, [])
        XCTAssertFalse(result.didChange)
    }

    func testNormalizeOrder_dedupAndDropMissing() {
        let existing: Set<String> = ["a", "b"]
        let result = WindowOrdering.normalizeOrder(["a", "a", "x", "b"], existingIDs: existing)
        XCTAssertEqual(result.order, ["a", "b"])
        XCTAssertTrue(result.didChange)
    }

    func testApplyNewIDs_appendsOnlyUnknownInDiscoveryOrder() {
        let existing: Set<String> = ["a", "b", "c"]
        let result = WindowOrdering.applyNewIDsAppendingToEnd(
            order: ["a", "b"],
            existingIDs: existing,
            inDiscoveryOrder: ["b", "c", "d", "e", "d"]
        )
        XCTAssertEqual(result.order, ["a", "b", "d", "e"])
        XCTAssertTrue(result.didChange)
    }

    func testOrderedIDs_filtersToExistingOnly() {
        let ids = WindowOrdering.orderedIDs(order: ["a", "x", "b"], existingIDs: ["a", "b"])
        XCTAssertEqual(ids, ["a", "b"])
    }

    func testSlotIndex_respectsLimit() {
        let order = ["a", "b", "c", "d"]
        XCTAssertEqual(WindowOrdering.slotIndex(forWindowID: "b", in: order, limit: 10), 1)
        XCTAssertNil(WindowOrdering.slotIndex(forWindowID: "d", in: order, limit: 3))
        XCTAssertNil(WindowOrdering.slotIndex(forWindowID: "a", in: order, limit: 0))
    }
}

