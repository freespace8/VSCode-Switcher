import CoreGraphics

public enum Geometry {
    public static func clampRect(_ rect: CGRect, into container: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0, container.width > 0, container.height > 0 else {
            return rect
        }

        var clamped = rect
        let maxX = container.maxX - rect.width
        let maxY = container.maxY - rect.height

        if maxX < container.minX {
            clamped.origin.x = container.minX
        } else {
            clamped.origin.x = min(max(rect.minX, container.minX), maxX)
        }

        if maxY < container.minY {
            clamped.origin.y = container.minY
        } else {
            clamped.origin.y = min(max(rect.minY, container.minY), maxY)
        }

        return clamped
    }

    public static func computeSidebarWidth(requested: CGFloat, in container: CGRect) -> CGFloat {
        let clampedRequested = max(220, requested)
        return min(clampedRequested, container.width * 0.5)
    }
}
