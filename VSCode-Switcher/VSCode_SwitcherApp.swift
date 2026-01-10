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

extension Notification.Name {
    static let vsCodeSwitcherRequestRefresh = Notification.Name("VSCodeSwitcher.requestRefresh")
}

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
    private var statusItem: NSStatusItem?
    private var autoTileMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        enforceSingleInstanceOrExit()

        windowSwitcher.bootstrap()

        hotKeyManager = HotKeyManager { [weak self] action in
            self?.handleHotKey(action)
        }
        hotKeyManager?.registerDefaultHotKeys()

        installStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func enforceSingleInstanceOrExit() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let selfPID = ProcessInfo.processInfo.processIdentifier
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard instances.count > 1 else {
            return
        }

        if let existing = instances.first(where: { $0.processIdentifier != selfPID }) {
            _ = existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        NSApp.terminate(nil)
    }

    private func handleHotKey(_ action: HotKeyAction) {
        switch action {
        case .focusNumber(let number):
            windowSwitcher.handleHotKeyFocusNumber(number)
            windowSwitcher.showAppWindowOnTopWithoutActivating()
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.title = "VSCode"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(toggleMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "刷新窗口列表", action: #selector(requestRefresh), keyEquivalent: "r"))

        let autoTile = NSMenuItem(title: "激活后自动平铺", action: #selector(toggleAutoTile), keyEquivalent: "")
        autoTile.state = windowSwitcher.isAutoTileEnabled ? .on : .off
        autoTileMenuItem = autoTile
        menu.addItem(autoTile)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "打开辅助功能设置", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        item.menu = menu
    }

    @objc private func toggleMainWindow() {
        windowSwitcher.toggleAppWindowVisibility()
    }

    @objc private func requestRefresh() {
        NotificationCenter.default.post(name: .vsCodeSwitcherRequestRefresh, object: nil)
    }

    @objc private func toggleAutoTile() {
        windowSwitcher.isAutoTileEnabled.toggle()
        autoTileMenuItem?.state = windowSwitcher.isAutoTileEnabled ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        windowSwitcher.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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
        let modifiers = UInt32(controlKey | optionKey)
        registerHotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: modifiers, id: 1)
        registerHotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: modifiers, id: 2)
        registerHotKey(keyCode: UInt32(kVK_ANSI_3), modifiers: modifiers, id: 3)
        registerHotKey(keyCode: UInt32(kVK_ANSI_4), modifiers: modifiers, id: 4)
        registerHotKey(keyCode: UInt32(kVK_ANSI_5), modifiers: modifiers, id: 5)
        registerHotKey(keyCode: UInt32(kVK_ANSI_6), modifiers: modifiers, id: 6)
        registerHotKey(keyCode: UInt32(kVK_ANSI_7), modifiers: modifiers, id: 7)
        registerHotKey(keyCode: UInt32(kVK_ANSI_8), modifiers: modifiers, id: 8)
        registerHotKey(keyCode: UInt32(kVK_ANSI_9), modifiers: modifiers, id: 9)
        registerHotKey(keyCode: UInt32(kVK_ANSI_0), modifiers: modifiers, id: 10)
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
        case 10:
            return .focusNumber(0)
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
        ]

        static let userDefaultsNumberMappingKey = "VSCodeSwitcher.numberMapping"
        static let axWindowNumberAttribute: CFString = "AXWindowNumber" as CFString
        static let accessibilityAlertShownKey = "VSCodeSwitcher.accessibilityAlertShown"
        static let userDefaultsWindowOrderKey = "VSCodeSwitcher.windowOrder"
        static let userDefaultsWindowAliasesKey = "VSCodeSwitcher.windowAliases"
        static let userDefaultsAutoTileKey = "VSCodeSwitcher.autoTile"
        static let userDefaultsSidebarWidthKey = "VSCodeSwitcher.sidebarWidth"

    }

    private struct WindowBookmark: Codable {
        var bundleIdentifier: String
        var windowNumber: Int?
        var title: String?
    }

    private weak var appWindow: NSWindow?

    var isAutoTileEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Constants.userDefaultsAutoTileKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Constants.userDefaultsAutoTileKey) }
    }

    func bootstrap() {
        _ = ensureAccessibilityPermission(prompt: false)
    }

    func setAppWindow(_ window: NSWindow) {
        appWindow = window
    }

    func isAppWindowVisible() -> Bool {
        appWindow?.isVisible == true
    }

    func toggleAppWindowVisibility() {
        guard let appWindow else { return }

        if appWindow.isVisible {
            if NSApp.isActive && appWindow.isKeyWindow {
                appWindow.orderOut(nil)
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            appWindow.makeKeyAndOrderFront(nil)
            appWindow.orderFrontRegardless()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        appWindow.makeKeyAndOrderFront(nil)
        appWindow.orderFrontRegardless()
    }

    func showAppWindowOnTopWithoutActivating() {
        guard let appWindow else { return }
        appWindow.level = .normal
        appWindow.orderFrontRegardless()
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
        guard ensureAccessibilityPermission(prompt: false) else {
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

    func listOrderedVSCodeWindows() -> [VSCodeWindowItem] {
        let windows = listOpenVSCodeWindows()
        var order = loadWindowOrder()

        if order.isEmpty {
            if !windows.isEmpty {
                order = windows.map(\.id)
                UserDefaults.standard.set(order, forKey: Constants.userDefaultsWindowOrderKey)
            }
            return windows
        }

        let windowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })

        var didChangeOrder = false

        var seenIDs = Set<String>()
        seenIDs.reserveCapacity(order.count)

        var dedupedOrder: [String] = []
        dedupedOrder.reserveCapacity(order.count)
        for id in order {
            if seenIDs.insert(id).inserted {
                dedupedOrder.append(id)
            } else {
                didChangeOrder = true
            }
        }
        order = dedupedOrder

        var emptySlotIndices: [Int] = []
        emptySlotIndices.reserveCapacity(order.count)
        for (index, id) in order.enumerated() where windowsByID[id] == nil {
            emptySlotIndices.append(index)
        }

        var knownIDs = Set(order)
        knownIDs.reserveCapacity(order.count + windows.count)

        var emptySlotCursor = 0
        for window in windows where !knownIDs.contains(window.id) {
            if emptySlotCursor < emptySlotIndices.count {
                let slotIndex = emptySlotIndices[emptySlotCursor]
                emptySlotCursor += 1
                order[slotIndex] = window.id
            } else {
                order.append(window.id)
            }
            knownIDs.insert(window.id)
            didChangeOrder = true
        }

        while order.count > 10, let lastID = order.last, windowsByID[lastID] == nil {
            order.removeLast()
            didChangeOrder = true
        }

        if didChangeOrder {
            UserDefaults.standard.set(order, forKey: Constants.userDefaultsWindowOrderKey)
        }

        var ordered: [VSCodeWindowItem] = []
        ordered.reserveCapacity(windows.count)
        for id in order {
            if let window = windowsByID[id] {
                ordered.append(window)
            }
        }

        return ordered
    }

    func saveWindowOrder(_ windows: [VSCodeWindowItem]) {
        let ids = windows.map(\.id)
        UserDefaults.standard.set(ids, forKey: Constants.userDefaultsWindowOrderKey)
    }

    func slotIndexForWindowID(_ id: String, limit: Int = 10) -> Int? {
        guard limit > 0 else { return nil }
        let order = loadWindowOrder()
        for (index, slotID) in order.prefix(limit).enumerated() where slotID == id {
            return index
        }
        return nil
    }

    func windowAliases() -> [String: String] {
        loadWindowAliases()
    }

    func setWindowAlias(_ alias: String?, forWindowID id: String) {
        var aliases = loadWindowAliases()

        if let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines), !alias.isEmpty {
            aliases[id] = alias
        } else {
            aliases.removeValue(forKey: id)
        }

        saveWindowAliases(aliases)
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

    func frontmostVSCodeWindow() -> VSCodeWindowItem? {
        guard ensureAccessibilityPermission(prompt: false) else { return nil }
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = frontmost.bundleIdentifier,
              Constants.supportedBundleIdentifiers.contains(bundleIdentifier) else {
            return nil
        }

        let pid = frontmost.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let window = value else { return nil }
        let axWindow = unsafeBitCast(window, to: AXUIElement.self)

        return VSCodeWindowItem(
            bundleIdentifier: bundleIdentifier,
            pid: pid,
            windowNumber: copyWindowNumber(from: axWindow),
            title: copyWindowTitle(from: axWindow) ?? "(Untitled)",
            appDisplayName: frontmost.localizedName
        )
    }

    func focus(window: VSCodeWindowItem) {
        guard ensureAccessibilityPermission(prompt: false) else {
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

        let targetWindow: AXUIElement
        if let targetNumber = window.windowNumber,
           let match = windows.first(where: { copyWindowNumber(from: $0) == targetNumber }) {
            targetWindow = match
        } else if let match = windows.first(where: { (copyWindowTitle(from: $0) ?? "") == window.title }) {
            targetWindow = match
        } else {
            targetWindow = windows[0]
        }

        focusWindow(targetWindow, in: axApp)
    }

    func handleHotKeyFocusNumber(_ number: Int) {
        guard (0...9).contains(number) else { return }
        guard ensureAccessibilityPermission(prompt: false) else { return }

        let slotIndex = number == 0 ? 9 : (number - 1)
        let order = loadWindowOrder()
        guard order.indices.contains(slotIndex) else { return }

        let targetID = order[slotIndex]
        let windows = listOpenVSCodeWindows()
        let windowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        guard let window = windowsByID[targetID] else { return }

        focus(window: window)
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
        guard ensureAccessibilityPermission(prompt: false) else { return false }

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

    private func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        showAccessibilityAlertOnce()

        if prompt {
            _ = requestAccessibilityIfNeeded()
        }

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
        alert.informativeText = "在“系统设置 → 隐私与安全性 → 辅助功能”中启用 VSCode-Switcher，才能列出并切换 VSCode 窗口（⌃⌥数字）。"
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

    private func loadWindowOrder() -> [String] {
        (UserDefaults.standard.array(forKey: Constants.userDefaultsWindowOrderKey) as? [String]) ?? []
    }

    private func saveWindowAliases(_ aliases: [String: String]) {
        do {
            let data = try JSONEncoder().encode(aliases)
            UserDefaults.standard.set(data, forKey: Constants.userDefaultsWindowAliasesKey)
        } catch {
            return
        }
    }

    private func loadWindowAliases() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: Constants.userDefaultsWindowAliasesKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
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

        _ = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, window)
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        tileAfterFocusing(vsCodeWindow: window)
    }

    private func tileAfterFocusing(vsCodeWindow: AXUIElement) {
        guard isAutoTileEnabled else {
            return
        }

        guard let targetFrames = computeTilingFrames() else {
            return
        }

        if let appWindow {
            appWindow.setFrame(targetFrames.appWindowFrame, display: true, animate: false)
        }

        setAXFrame(window: vsCodeWindow, frame: targetFrames.vsCodeFrame)
    }

    private func computeTilingFrames() -> (appWindowFrame: CGRect, vsCodeFrame: CGRect)? {
        let screens = NSScreen.screens
        guard let primaryScreen = NSScreen.main ?? screens.first else {
            return nil
        }

        let appScreen = appWindow?.screen ?? primaryScreen
        let visible = appScreen.visibleFrame
        guard visible.width > 0, visible.height > 0 else {
            return nil
        }

        let sidebarWidth = computeSidebarWidth(in: visible)

        if screens.count <= 1 {
            let full = appScreen.frame
            let appFrame = CGRect(x: visible.minX, y: visible.minY, width: sidebarWidth, height: visible.height)
            let codeFrame = CGRect(x: full.minX + sidebarWidth, y: full.minY, width: max(0, full.width - sidebarWidth), height: full.height)
            return (appFrame, codeFrame)
        }

        let codeScreen = screens.first(where: { $0 !== appScreen }) ?? appScreen
        let codeFull = codeScreen.frame
        guard codeFull.width > 0, codeFull.height > 0 else {
            return nil
        }

        let appFrame = CGRect(x: visible.minX, y: visible.minY, width: sidebarWidth, height: visible.height)
        let codeFrame = CGRect(x: codeFull.minX, y: codeFull.minY, width: codeFull.width, height: codeFull.height)
        return (appFrame, codeFrame)
    }

    private func computeSidebarWidth(in visibleFrame: CGRect) -> CGFloat {
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: Constants.userDefaultsSidebarWidthKey) as? Double
        let requested = stored.map { CGFloat($0) } ?? 320
        return min(max(220, requested), visibleFrame.width * 0.5)
    }

    private func setAXFrame(window: AXUIElement, frame: CGRect) {
        var position = CGPoint(x: frame.minX, y: frame.minY)
        var size = CGSize(width: frame.width, height: frame.height)

        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return
        }

        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
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
