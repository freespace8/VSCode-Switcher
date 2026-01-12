import CoreGraphics

public struct TilingLayoutInput: Sendable {
    public var visibleFrame: CGRect
    public var requestedSidebarWidth: CGFloat
    public var ultrawideAspectThreshold: CGFloat

    public init(visibleFrame: CGRect, requestedSidebarWidth: CGFloat, ultrawideAspectThreshold: CGFloat = 2.2) {
        self.visibleFrame = visibleFrame
        self.requestedSidebarWidth = requestedSidebarWidth
        self.ultrawideAspectThreshold = ultrawideAspectThreshold
    }
}

public struct TilingLayoutOutput: Sendable {
    public var isUltrawide: Bool
    public var containerFrame: CGRect
    public var appFrame: CGRect
    public var codeFrame: CGRect
}

public enum TilingLayout {
    public static func compute(_ input: TilingLayoutInput) -> TilingLayoutOutput? {
        let visibleFrame = input.visibleFrame
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }

        let aspect = visibleFrame.width / max(1, visibleFrame.height)
        let isUltrawide = aspect >= input.ultrawideAspectThreshold

        let containerFrame: CGRect
        if isUltrawide {
            containerFrame = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width * 0.5,
                height: visibleFrame.height
            )
        } else {
            containerFrame = visibleFrame
        }

        let sidebarWidth = Geometry.computeSidebarWidth(requested: input.requestedSidebarWidth, in: containerFrame)
        let appFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: sidebarWidth, height: containerFrame.height)

        let codeFrame = CGRect(
            x: containerFrame.minX + sidebarWidth,
            y: containerFrame.minY,
            width: max(0, containerFrame.width - sidebarWidth),
            height: containerFrame.height
        )

        return TilingLayoutOutput(
            isUltrawide: isUltrawide,
            containerFrame: containerFrame,
            appFrame: appFrame,
            codeFrame: codeFrame
        )
    }
}
