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

    func testWindowDiscoveryAndRemoval_keepsRelativeOrderAndShiftsSlots() {
        // Step 1: discover A
        var order: [String] = ["A"]

        // Step 2: discover B, append to tail
        do {
            let existing: Set<String> = ["A", "B"]
            let normalized = WindowOrdering.normalizeOrder(order, existingIDs: existing)
            XCTAssertEqual(normalized.order, ["A"])
            XCTAssertFalse(normalized.didChange)

            let appended = WindowOrdering.applyNewIDsAppendingToEnd(
                order: normalized.order,
                existingIDs: Set(normalized.order),
                inDiscoveryOrder: ["A", "B"]
            )
            XCTAssertEqual(appended.order, ["A", "B"])
            XCTAssertTrue(appended.didChange)
            order = appended.order
        }

        // Step 3: A disappears, remove A without changing other order
        do {
            let existing: Set<String> = ["B"]
            let normalized = WindowOrdering.normalizeOrder(order, existingIDs: existing)
            XCTAssertEqual(normalized.order, ["B"])
            XCTAssertTrue(normalized.didChange)
            order = normalized.order
        }

        // Slot indices should shift up when an earlier window disappears.
        XCTAssertEqual(WindowOrdering.slotIndex(forWindowID: "B", in: order, limit: 10), 0)

        // Example: if A was slot 2, B should become slot 2 after A is removed.
        let before = ["X", "A", "B"] // A is slot 2 (index 1), B is slot 3 (index 2)
        let after = WindowOrdering.normalizeOrder(before, existingIDs: ["X", "B"]).order
        XCTAssertEqual(after, ["X", "B"])
        XCTAssertEqual(WindowOrdering.slotIndex(forWindowID: "B", in: before, limit: 10), 2)
        XCTAssertEqual(WindowOrdering.slotIndex(forWindowID: "B", in: after, limit: 10), 1)
    }
}
