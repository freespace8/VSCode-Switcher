//
//  VSCode_SwitcherApp.swift
//  VSCode-Switcher
//
//  Created by Taylor Ni on 2026/1/10.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox
import ApplicationServices
import os

@main
struct VSCode_SwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowSwitcher = VSCodeWindowSwitcher.shared
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowSwitcher.bootstrap()

        hotKeyManager = HotKeyManager { [weak self] action in
            self?.handleHotKey(action)
        }
        hotKeyManager?.registerDefaultHotKeys()
    }

    private func handleHotKey(_ action: HotKeyAction) {
        switch action {
        case .focusNumber(let number):
            _ = windowSwitcher.focus(number: number)
        }
    }
}

enum HotKeyAction: Hashable {
    case focusNumber(Int)
}

final class HotKeyManager {
    typealias Handler = (HotKeyAction) -> Void

    private let handler: Handler
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    private let hotKeySignature: OSType = OSType(0x56534353)

    init(handler: @escaping Handler) {
        self.handler = handler
        installEventHandler()
    }

    func registerDefaultHotKeys() {
        registerHotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(optionKey), id: 1)
        registerHotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(optionKey), id: 2)
        registerHotKey(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(optionKey), id: 3)
        registerHotKey(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(optionKey), id: 4)
        registerHotKey(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(optionKey), id: 5)
        registerHotKey(keyCode: UInt32(kVK_ANSI_6), modifiers: UInt32(optionKey), id: 6)
        registerHotKey(keyCode: UInt32(kVK_ANSI_7), modifiers: UInt32(optionKey), id: 7)
        registerHotKey(keyCode: UInt32(kVK_ANSI_8), modifiers: UInt32(optionKey), id: 8)
        registerHotKey(keyCode: UInt32(kVK_ANSI_9), modifiers: UInt32(optionKey), id: 9)
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef = eventRef, let userData = userData else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(eventRef)

                return noErr
            },
            1,
            &eventSpec,
            selfPointer,
            &eventHandlerRef
        )
    }

    private func handleHotKeyEvent(_ event: EventRef) {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == hotKeySignature else {
            return
        }

        guard let action = actionFromHotKeyID(hotKeyID.id) else {
            return
        }

        DispatchQueue.main.async { [handler] in
            handler(action)
        }
    }

    private func actionFromHotKeyID(_ id: UInt32) -> HotKeyAction? {
        switch id {
        case 1...9:
            return .focusNumber(Int(id))
        default:
            return nil
        }
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: id)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            return
        }

        hotKeyRefs.append(hotKeyRef)
    }
}

final class VSCodeWindowSwitcher {
    static let shared = VSCodeWindowSwitcher()
    private static let logger = Logger(subsystem: "com.f8soft.VSCode-Switcher", category: "AX")

    private enum Constants {
        static let supportedBundleIdentifiers: [String] = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
        ]

        static let userDefaultsNumberMappingKey = "VSCodeSwitcher.numberMapping"
        static let axWindowNumberAttribute: CFString = "AXWindowNumber" as CFString
        static let accessibilityAlertShownKey = "VSCodeSwitcher.accessibilityAlertShown"
    }

    private struct WindowBookmark: Codable {
        var bundleIdentifier: String
        var windowNumber: Int?
        var title: String?
    }

    func bootstrap() {
        _ = ensureAccessibilityPermission()
    }

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func listOpenVSCodeWindows() -> [VSCodeWindowItem] {
        guard ensureAccessibilityPermission() else {
            return []
        }

        var items: [VSCodeWindowItem] = []

        for bundleIdentifier in Constants.supportedBundleIdentifiers {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            for app in runningApps {
                let pid = app.processIdentifier
                let axApp = AXUIElementCreateApplication(pid)

                var windowsInfo = copyWindowsWithError(from: axApp)
                if windowsInfo.error == .cannotComplete {
                    Self.logger.info("AXWindows cannotComplete; retry after activate. pid=\(pid) bundle=\(bundleIdentifier, privacy: .public)")
#if DEBUG
                    NSLog("AXWindows cannotComplete; retry after activate. pid=%d bundle=%@", pid, bundleIdentifier)
#endif
                    _ = app.activate(options: [.activateAllWindows])
                    usleep(150_000)
                    windowsInfo = copyWindowsWithError(from: axApp)
                }

                if windowsInfo.error != .success {
                    Self.logger.info("AXWindows failed. pid=\(pid) bundle=\(bundleIdentifier, privacy: .public) error=\(windowsInfo.error.rawValue) (\(self.axErrorName(windowsInfo.error), privacy: .public))")
#if DEBUG
                    NSLog("AXWindows failed. pid=%d bundle=%@ error=%d (%@)", pid, bundleIdentifier, windowsInfo.error.rawValue, self.axErrorName(windowsInfo.error))
#endif
                }
                guard let windows = windowsInfo.windows else { continue }

                for window in windows {
                    let title = copyWindowTitle(from: window) ?? "(Untitled)"
                    items.append(
                        VSCodeWindowItem(
                            bundleIdentifier: bundleIdentifier,
                            pid: pid,
                            windowNumber: copyWindowNumber(from: window),
                            title: title,
                            appDisplayName: app.localizedName
                        )
                    )
                }
            }
        }

        items.sort { lhs, rhs in
            if lhs.appDisplayName != rhs.appDisplayName {
                return (lhs.appDisplayName ?? lhs.bundleIdentifier) < (rhs.appDisplayName ?? rhs.bundleIdentifier)
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }

        return items
    }

    func diagnosticsSummary() -> String {
        var lines: [String] = []
        lines.append("AXIsProcessTrusted: \(AXIsProcessTrusted() ? "true" : "false")")
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            lines.append("frontmost: \(frontmost.localizedName ?? "-") (\(frontmost.bundleIdentifier ?? "-")) pid=\(frontmost.processIdentifier)")
        }

        for bundleIdentifier in Constants.supportedBundleIdentifiers {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            lines.append("\(bundleIdentifier): running=\(runningApps.count)")

            for app in runningApps {
                let pid = app.processIdentifier
                let name = app.localizedName ?? "-"
                let axApp = AXUIElementCreateApplication(pid)

                let windowsInfo = copyWindowsWithError(from: axApp)
                lines.append("  pid=\(pid) name=\(name) AXWindows=\(windowsInfo.error.rawValue) (\(axErrorName(windowsInfo.error))) count=\(windowsInfo.windows?.count ?? -1)")
            }
        }

        return lines.joined(separator: "\n")
    }

    func focus(window: VSCodeWindowItem) {
        guard ensureAccessibilityPermission() else {
            return
        }

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: window.bundleIdentifier)
            .first(where: { $0.processIdentifier == window.pid })
            ?? runningApplication(bundleIdentifier: window.bundleIdentifier) else {
            return
        }

        app.activate(options: [.activateAllWindows])

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = copyWindows(from: axApp), !windows.isEmpty else {
            return
        }

        if let targetNumber = window.windowNumber,
           let match = windows.first(where: { copyWindowNumber(from: $0) == targetNumber }) {
            focusWindow(match, in: axApp)
            return
        }

        if let match = windows.first(where: { (copyWindowTitle(from: $0) ?? "") == window.title }) {
            focusWindow(match, in: axApp)
            return
        }

        focusWindow(windows[0], in: axApp)
    }

    func windowNumberAssignment(for window: VSCodeWindowItem) -> Int? {
        let mappings = loadNumberMapping()
        for (number, bookmark) in mappings {
            if bookmark.bundleIdentifier != window.bundleIdentifier {
                continue
            }

            if let windowNumber = bookmark.windowNumber, windowNumber == window.windowNumber {
                return number
            }

            if let title = bookmark.title, title == window.title {
                return number
            }
        }

        return nil
    }

    func setWindowNumberAssignment(_ number: Int?, for window: VSCodeWindowItem) {
        var mappings = loadNumberMapping()

        let windowBookmark = WindowBookmark(
            bundleIdentifier: window.bundleIdentifier,
            windowNumber: window.windowNumber,
            title: window.title
        )

        mappings = mappings.filter { _, bookmark in
            bookmark.bundleIdentifier != windowBookmark.bundleIdentifier ||
            bookmark.windowNumber != windowBookmark.windowNumber ||
            bookmark.title != windowBookmark.title
        }

        if let number {
            guard (1...9).contains(number) else { return }
            mappings[number] = windowBookmark
        }

        saveNumberMapping(mappings)
    }

    @discardableResult
    func focus(number: Int) -> Bool {
        guard (1...9).contains(number) else { return false }
        guard ensureAccessibilityPermission() else { return false }

        let mappings = loadNumberMapping()
        guard let bookmark = mappings[number] else { return false }

        let app: NSRunningApplication?
        app = runningApplication(bundleIdentifier: bookmark.bundleIdentifier) ?? runningVSCodeApplication()
        guard let app else { return false }

        app.activate(options: [.activateAllWindows])

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = copyWindows(from: axApp), !windows.isEmpty else { return false }

        if let match = findBookmarkedWindow(bookmark, in: windows) {
            focusWindow(match, in: axApp)
            return true
        }

        return false
    }

    @discardableResult
    func requestAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        _ = requestAccessibilityIfNeeded()
        showAccessibilityAlertOnce()
        return false
    }

    private func showAccessibilityAlertOnce() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Constants.accessibilityAlertShownKey) {
            return
        }

        defaults.set(true, forKey: Constants.accessibilityAlertShownKey)

        let alert = NSAlert()
        alert.messageText = "需要开启辅助功能权限"
        alert.informativeText = "在“系统设置 → 隐私与安全性 → 辅助功能”中启用 VSCode-Switcher，才能用 Option+1/2/3 切换 VSCode 窗口。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "以后再说")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func runningVSCodeApplication() -> NSRunningApplication? {
        for bundleIdentifier in Constants.supportedBundleIdentifiers {
            if let app = runningApplication(bundleIdentifier: bundleIdentifier) {
                return app
            }
        }

        return nil
    }

    private func runningApplication(bundleIdentifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }

    private func copyWindows(from app: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)

        guard result == .success else {
            return nil
        }

        return value as? [AXUIElement]
    }

    private func copyWindowsWithError(from app: AXUIElement) -> (error: AXError, windows: [AXUIElement]?) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)

        guard error == .success else { return (error, nil) }
        return (error, value as? [AXUIElement])
    }

    private func axErrorName(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown(\(error.rawValue))"
        }
    }

    private func findBookmarkedWindow(_ bookmark: WindowBookmark, in windows: [AXUIElement]) -> AXUIElement? {
        if let windowNumber = bookmark.windowNumber {
            if let match = windows.first(where: { copyWindowNumber(from: $0) == windowNumber }) {
                return match
            }
        }

        if let title = bookmark.title {
            if let match = windows.first(where: { copyWindowTitle(from: $0) == title }) {
                return match
            }
        }

        return nil
    }

    private func focusWindow(_ window: AXUIElement, in app: AXUIElement) {
        unminimizeIfNeeded(window)

        _ = AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, window)
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func unminimizeIfNeeded(_ window: AXUIElement) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value)
        guard result == .success, let number = value as? NSNumber, number.boolValue else {
            return
        }

        _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    private func copyWindowTitle(from window: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func copyWindowNumber(from window: AXUIElement) -> Int? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, Constants.axWindowNumberAttribute, &value)
        guard result == .success, let number = value as? NSNumber else {
            return nil
        }
        return number.intValue
    }

    private func saveNumberMapping(_ mappings: [Int: WindowBookmark]) {
        do {
            let data = try JSONEncoder().encode(mappings)
            UserDefaults.standard.set(data, forKey: Constants.userDefaultsNumberMappingKey)
        } catch {
            return
        }
    }

    private func loadNumberMapping() -> [Int: WindowBookmark] {
        guard let data = UserDefaults.standard.data(forKey: Constants.userDefaultsNumberMappingKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([Int: WindowBookmark].self, from: data)) ?? [:]
    }
}

struct VSCodeWindowItem: Identifiable, Hashable {
    let bundleIdentifier: String
    let pid: pid_t
    let windowNumber: Int?
    let title: String
    let appDisplayName: String?

    var id: String {
        if let windowNumber {
            return "\(bundleIdentifier):\(pid):\(windowNumber)"
        }
        return "\(bundleIdentifier):\(pid):\(title)"
    }
}
