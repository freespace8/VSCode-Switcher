import AppKit
import ApplicationServices

enum WindowPreview {
    static func hasScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenCapturePermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openScreenCaptureSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func captureWindowImage(windowID: CGWindowID) -> NSImage? {
        let options: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, options) else {
            return nil
        }

        let size = NSSize(width: image.width, height: image.height)
        return NSImage(cgImage: image, size: size)
    }
}

