import Foundation

public enum WindowOrdering {
    public static func normalizeOrder(_ order: [String], existingIDs: Set<String>) -> (order: [String], didChange: Bool) {
        guard !order.isEmpty else { return ([], false) }

        var seen = Set<String>()
        seen.reserveCapacity(order.count)

        var normalized: [String] = []
        normalized.reserveCapacity(order.count)

        var didChange = false
        for id in order {
            guard seen.insert(id).inserted else {
                didChange = true
                continue
            }
            guard existingIDs.contains(id) else {
                didChange = true
                continue
            }
            normalized.append(id)
        }

        return (normalized, didChange)
    }

    public static func applyNewIDsAppendingToEnd(order: [String], existingIDs: Set<String>, inDiscoveryOrder discoveredIDs: [String]) -> (order: [String], didChange: Bool) {
        var next = order
        var known = Set(next)
        known.formUnion(existingIDs)

        var didChange = false
        for id in discoveredIDs {
            guard !known.contains(id) else { continue }
            next.append(id)
            known.insert(id)
            didChange = true
        }
        return (next, didChange)
    }

    public static func orderedIDs(order: [String], existingIDs: Set<String>) -> [String] {
        order.filter { existingIDs.contains($0) }
    }

    public static func slotIndex(forWindowID id: String, in order: [String], limit: Int = 10) -> Int? {
        guard limit > 0 else { return nil }
        for (index, slotID) in order.prefix(limit).enumerated() where slotID == id {
            return index
        }
        return nil
    }
}

