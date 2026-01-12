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
import Darwin
import os

extension Notification.Name {
    static let vsCodeSwitcherRequestRefresh = Notification.Name("VSCodeSwitcher.requestRefresh")
}

final class Diagnostics {
    static let shared = Diagnostics()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let queue = DispatchQueue(label: "com.f8soft.VSCode-Switcher.Diagnostics", qos: .utility)
    private let maxBytes: Int64 = 1_000_000

    private var fileHandle: FileHandle?
    private var logURL: URL?
    private var loggedOnceKeys = Set<String>()
    private var counters: [String: Int] = [:]

    func startSession(extra: String? = nil) {
        log("session start\(extra.map { " | \($0)" } ?? "")")
    }

    func log(_ message: String) {
        queue.async { [weak self] in
            self?.writeLine(message)
        }
    }

    func logOnce(_ key: String, _ message: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.loggedOnceKeys.insert(key).inserted else { return }
            self.writeLine(message)
        }
    }

    func increment(_ key: String, by delta: Int = 1) {
        queue.async { [weak self] in
            guard let self else { return }
            self.counters[key, default: 0] += delta
        }
    }

    func heartbeat() {
        queue.async { [weak self] in
            guard let self else { return }

            if self.counters.isEmpty {
                self.writeLine("heartbeat")
                return
            }

            let pairs = self.counters.keys.sorted().map { key in
                "\(key)=\(self.counters[key] ?? 0)"
            }
            self.writeLine("heartbeat " + pairs.joined(separator: " "))
        }
    }

    private func writeLine(_ message: String) {
        guard let handle = openFileHandle() else {
            return
        }

        let ts = Self.timestampFormatter.string(from: Date())
        let line = "[\(ts)] \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            return
        }
    }

    private func openFileHandle() -> FileHandle? {
        guard let url = ensureLogURL() else {
            return nil
        }

        rotateIfNeeded(url: url)

        if let fileHandle {
            return fileHandle
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            fileHandle = handle
            return handle
        } catch {
            return nil
        }
    }

    private func ensureLogURL() -> URL? {
        if let logURL {
            return logURL
        }

        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let dir = base.appendingPathComponent("VSCode-Switcher", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let url = dir.appendingPathComponent("diagnostics.log", isDirectory: false)
        logURL = url
        return url
    }

    private func rotateIfNeeded(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber,
              size.int64Value >= maxBytes else {
            return
        }

        do {
            try fileHandle?.close()
        } catch {
            // ignore
        }
        fileHandle = nil

        let backupURL = url.appendingPathExtension("1")
        _ = try? FileManager.default.removeItem(at: backupURL)
        _ = try? FileManager.default.moveItem(at: url, to: backupURL)
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
    }
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
    private var diagnosticsHeartbeatTimer: DispatchSourceTimer?
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        Diagnostics.shared.startSession(extra: "version=\(version)(\(build)) pid=\(ProcessInfo.processInfo.processIdentifier) axTrusted=\(AXIsProcessTrusted() ? "true" : "false")")
        installSigtermHandler()
        startDiagnosticsHeartbeat()

        enforceSingleInstanceOrExit()

        windowSwitcher.bootstrap()

        hotKeyManager = HotKeyManager { [weak self] action in
            self?.handleHotKey(action)
        }
        hotKeyManager?.registerDefaultHotKeys()

        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Diagnostics.shared.log("applicationWillTerminate")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        windowSwitcher.handleAppDidBecomeActive()
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

        Diagnostics.shared.log("enforceSingleInstanceOrExit: terminate self (existing instance detected)")
        NSApp.terminate(nil)
    }

    private func handleHotKey(_ action: HotKeyAction) {
        switch action {
        case .focusNumber(let number):
            windowSwitcher.handleHotKeyFocusNumber(number)
            windowSwitcher.showAppWindowOnTopWithoutActivating()
        }
    }

    private func startDiagnosticsHeartbeat() {
        if diagnosticsHeartbeatTimer != nil {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 60, repeating: 60, leeway: .seconds(5))
        timer.setEventHandler {
            Diagnostics.shared.heartbeat()
        }
        timer.resume()
        diagnosticsHeartbeatTimer = timer
    }

    private func installSigtermHandler() {
        if sigtermSource != nil {
            return
        }

        signal(SIGTERM, SIG_IGN)

        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: DispatchQueue.global(qos: .utility))
        source.setEventHandler {
            Diagnostics.shared.log("SIGTERM received")
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        source.resume()
        sigtermSource = source
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
    private static let debugLogger = Logger(subsystem: "com.f8soft.VSCode-Switcher", category: "Debug")
    static let supportedBundleIdentifiers: [String] = [
        "com.microsoft.VSCode",
    ]

    private enum Constants {
        static let userDefaultsNumberMappingKey = "VSCodeSwitcher.numberMapping"
        static let axWindowNumberAttribute: CFString = "AXWindowNumber" as CFString
        static let accessibilityAlertShownKey = "VSCodeSwitcher.accessibilityAlertShown"
        static let userDefaultsWindowOrderKey = "VSCodeSwitcher.windowOrder"
        static let userDefaultsWindowAliasesKey = "VSCodeSwitcher.windowAliases"
        static let userDefaultsAutoTileKey = "VSCodeSwitcher.autoTile"
        static let userDefaultsSidebarWidthKey = "VSCodeSwitcher.sidebarWidth"
        static let userDefaultsLastActiveSlotIndexKey = "VSCodeSwitcher.lastActiveSlotIndex"

    }

    private struct WindowBookmark: Codable, Equatable {
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

    func toggleAppWindowVisibility() {
        guard let appWindow else { return }

#if DEBUG
        let frontmostBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
        Self.debugLogger.info("toggleAppWindowVisibility: begin visible=\(appWindow.isVisible) key=\(appWindow.isKeyWindow) nsapp_active=\(NSApp.isActive) frontmost=\(frontmostBefore, privacy: .public)")
#endif

        if appWindow.isVisible {
            if NSApp.isActive && appWindow.isKeyWindow {
                appWindow.orderOut(nil)
                return
            }

            focusVSCodeAlongsideAppWindowIfPossible()
            showAppWindowOnTopWithoutActivating()
            return
        }

        focusVSCodeAlongsideAppWindowIfPossible()
        showAppWindowOnTopWithoutActivating()
    }

    func handleAppDidBecomeActive() {
        guard let appWindow else { return }

#if DEBUG
        let frontmostBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
        Self.debugLogger.info("handleAppDidBecomeActive: begin appWindow_visible=\(appWindow.isVisible) frontmost=\(frontmostBefore, privacy: .public)")
#endif

        focusVSCodeAlongsideAppWindowIfPossible()
        showAppWindowOnTopWithoutActivating()
    }

    func showAppWindowOnTopWithoutActivating() {
        guard let appWindow else { return }
        pinAppWindowTopIfNeeded()
        appWindow.level = .normal
        appWindow.orderFrontRegardless()
#if DEBUG
        let frontmostAfter = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
        Self.debugLogger.info("showAppWindowOnTopWithoutActivating: done frontmost=\(frontmostAfter, privacy: .public)")
#endif
    }

    private func pinAppWindowTopIfNeeded() {
        guard let appWindow else { return }

        var frame = appWindow.frame
        guard frame.height > 0, frame.width > 0 else { return }

        guard let screen = appWindow.screen else { return }
        let visible = screen.visibleFrame
        guard visible.width > 0, visible.height > 0 else { return }

        if frame.minY != visible.minY {
            frame.origin.y = visible.minY
            appWindow.setFrame(frame, display: true, animate: false)
        }
    }

    private func focusVSCodeAlongsideAppWindowIfPossible() {
        guard ensureAccessibilityPermission(prompt: false) else { return }

#if DEBUG
        Self.debugLogger.info("focusVSCodeAlongsideAppWindowIfPossible: begin")
#endif

        if let slotIndex = loadLastActiveSlotIndex() {
            let ordered = listOrderedVSCodeWindows(allowActivate: true)
            if !ordered.isEmpty {
                let clampedIndex = min(max(slotIndex, 0), ordered.count - 1)
#if DEBUG
                Self.debugLogger.info("focusVSCodeAlongsideAppWindowIfPossible: focusing by slotIndex=\(slotIndex) clamped=\(clampedIndex) windows=\(ordered.count)")
#endif
                focus(window: ordered[clampedIndex])
#if DEBUG
                let frontmostAfter = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
                Self.debugLogger.info("focusVSCodeAlongsideAppWindowIfPossible: after slotIndex focus frontmost=\(frontmostAfter, privacy: .public)")
#endif
                return
            }
        }

        if let first = listOrderedVSCodeWindows(allowActivate: true).first {
#if DEBUG
            Self.debugLogger.info("focusVSCodeAlongsideAppWindowIfPossible: focused first ordered window")
#endif
            focus(window: first)
            return
        }

#if DEBUG
        Self.debugLogger.info("focusVSCodeAlongsideAppWindowIfPossible: no windows; activating app only")
#endif
        runningVSCodeApplication()?.activate(options: [.activateAllWindows])
    }

    func isFrontmostVSCodeApplication() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = frontmost.bundleIdentifier else {
            return false
        }
        return Self.supportedBundleIdentifiers.contains(bundleIdentifier)
    }

    func hasRunningVSCodeApplication() -> Bool {
        runningVSCodeApplication() != nil
    }

    func rememberLastActiveWindow(_ window: VSCodeWindowItem?) {
        guard let window else { return }
#if DEBUG
        Self.debugLogger.info("rememberLastActiveWindow: bundle=\(window.bundleIdentifier, privacy: .public) pid=\(window.pid) title=\(window.title, privacy: .public)")
#endif
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

    func listOpenVSCodeWindows(allowActivate: Bool) -> [VSCodeWindowItem] {
        guard ensureAccessibilityPermission(prompt: false) else {
            return []
        }

        var items: [VSCodeWindowItem] = []

        for bundleIdentifier in Self.supportedBundleIdentifiers {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            for app in runningApps {
                let pid = app.processIdentifier
                let axApp = AXUIElementCreateApplication(pid)

                var windowsInfo = copyWindowsWithError(from: axApp)
                if allowActivate, windowsInfo.error == .cannotComplete {
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

    func listOrderedVSCodeWindows(allowActivate: Bool) -> [VSCodeWindowItem] {
        let windows = listOpenVSCodeWindows(allowActivate: allowActivate)
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

        var normalizedOrder: [String] = []
        normalizedOrder.reserveCapacity(order.count)
        for id in order {
            guard seenIDs.insert(id).inserted else {
                didChangeOrder = true
                continue
            }
            guard windowsByID[id] != nil else {
                didChangeOrder = true
                continue
            }
            normalizedOrder.append(id)
        }
        order = normalizedOrder

        var knownIDs = Set(order)
        knownIDs.reserveCapacity(order.count + windows.count)

        // 新发现窗口统一追加到末尾，避免影响已有窗口的相对顺序（位置/快捷键）
        for window in windows where !knownIDs.contains(window.id) {
            order.append(window.id)
            knownIDs.insert(window.id)
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

        for bundleIdentifier in Self.supportedBundleIdentifiers {
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
              Self.supportedBundleIdentifiers.contains(bundleIdentifier) else {
            return nil
        }

        let pid = frontmost.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let window = value else { return nil }
        guard CFGetTypeID(window) == AXUIElementGetTypeID() else {
            Diagnostics.shared.logOnce(
                "frontmostVSCodeWindow.unexpectedType",
                "frontmostVSCodeWindow: unexpected CFTypeID=\(CFGetTypeID(window)) bundle=\(bundleIdentifier) pid=\(pid)"
            )
            return nil
        }
        let axWindow = unsafeBitCast(window, to: AXUIElement.self)

        return VSCodeWindowItem(
            bundleIdentifier: bundleIdentifier,
            pid: pid,
            windowNumber: copyWindowNumber(from: axWindow),
            title: copyWindowTitle(from: axWindow) ?? "(Untitled)",
            appDisplayName: frontmost.localizedName
        )
    }

    func rememberLastActiveSlotIndex(_ slotIndex: Int?) {
        guard let slotIndex else { return }
        guard slotIndex >= 0 else { return }
        UserDefaults.standard.set(slotIndex, forKey: Constants.userDefaultsLastActiveSlotIndexKey)
#if DEBUG
        Self.debugLogger.info("rememberLastActiveSlotIndex: slotIndex=\(slotIndex)")
#endif
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
        let ordered = listOrderedVSCodeWindows(allowActivate: true)
        guard ordered.indices.contains(slotIndex) else { return }
        focus(window: ordered[slotIndex])
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
        for bundleIdentifier in Self.supportedBundleIdentifiers {
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

        moveToAppWindowScreenIfNeeded(window)
        tileAfterFocusingIfEnabled(vsCodeWindow: window)
    }

    private func tileAfterFocusingIfEnabled(vsCodeWindow: AXUIElement) {
        guard isAutoTileEnabled else { return }
        guard let targetScreen = appWindow?.screen else { return }

        let visibleFrame = targetScreen.visibleFrame
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return }

        let aspectRatio = visibleFrame.width / max(1, visibleFrame.height)
        let isUltrawide = aspectRatio >= 2.2
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

        let sidebarWidth = computeSidebarWidth(in: containerFrame)
        let appFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: sidebarWidth, height: containerFrame.height)
        let codeY: CGFloat = isUltrawide ? 0 : containerFrame.minY
        let codeHeight: CGFloat = isUltrawide ? containerFrame.maxY : containerFrame.height
        let codeFrame = CGRect(
            x: containerFrame.minX + sidebarWidth,
            y: codeY,
            width: max(0, containerFrame.width - sidebarWidth),
            height: codeHeight
        )

        if let appWindow {
            appWindow.setFrame(appFrame, display: true, animate: false)
        }

        setAXFrame(window: vsCodeWindow, frame: codeFrame)
    }

    private func moveToAppWindowScreenIfNeeded(_ window: AXUIElement) {
        guard let targetScreen = appWindow?.screen else {
            return
        }
        let visible = targetScreen.visibleFrame
        guard visible.width > 0, visible.height > 0 else {
            return
        }

        guard let windowFrame = copyAXFrame(from: window) else {
            return
        }

        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(center) })
        if currentScreen === targetScreen {
            return
        }

        var target = windowFrame
        target.origin.x = visible.maxX - target.width
        target.origin.y = windowFrame.minY
        target = clampRect(target, into: visible)

        setAXFrame(window: window, frame: target)
    }

    private func computeSidebarWidth(in visibleFrame: CGRect) -> CGFloat {
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: Constants.userDefaultsSidebarWidthKey) as? Double
        let requested = stored.map { CGFloat($0) } ?? 320
        return min(max(220, requested), visibleFrame.width * 0.5)
    }

    private func clampRect(_ rect: CGRect, into container: CGRect) -> CGRect {
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

    private func copyAXFrame(from window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue else {
            return nil
        }

        let expectedTypeID = AXValueGetTypeID()
        guard CFGetTypeID(positionValue) == expectedTypeID,
              CFGetTypeID(sizeValue) == expectedTypeID else {
            Diagnostics.shared.logOnce(
                "copyAXFrame.invalidTypes",
                "copyAXFrame: unexpected CFTypeID position=\(CFGetTypeID(positionValue)) size=\(CFGetTypeID(sizeValue))"
            )
            return nil
        }

        let positionAXValue = unsafeBitCast(positionValue, to: AXValue.self)
        let sizeAXValue = unsafeBitCast(sizeValue, to: AXValue.self)

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        return CGRect(origin: position, size: size)
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

    private func loadLastActiveSlotIndex() -> Int? {
        let value = UserDefaults.standard.object(forKey: Constants.userDefaultsLastActiveSlotIndexKey)
        return value as? Int
    }
}

final class VSCodeAXWindowMonitor {
    typealias OnChange = () -> Void

    private struct Entry {
        let pid: pid_t
        let observer: AXObserver
        let appElement: AXUIElement
        let runLoopSource: CFRunLoopSource
    }

    private let onChange: OnChange
    private var entriesByPID: [pid_t: Entry] = [:]
    private var debounceWorkItem: DispatchWorkItem?

    init(onChange: @escaping OnChange) {
        self.onChange = onChange
    }

    func start() {
        rebuild()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        for entry in entriesByPID.values {
            _ = AXObserverRemoveNotification(entry.observer, entry.appElement, kAXWindowCreatedNotification as CFString)
            _ = AXObserverRemoveNotification(entry.observer, entry.appElement, kAXUIElementDestroyedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), entry.runLoopSource, .defaultMode)
        }
        entriesByPID.removeAll()
    }

    func rebuild() {
        Diagnostics.shared.increment("ax.monitorRebuild")
        stop()

        guard AXIsProcessTrusted() else {
            return
        }

        for pid in Self.runningVSCodePIDs() {
            installObserver(for: pid)
        }
    }

    private static func runningVSCodePIDs() -> [pid_t] {
        var result: [pid_t] = []
        for bundleIdentifier in VSCodeWindowSwitcher.supportedBundleIdentifiers {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            result.append(contentsOf: apps.map(\.processIdentifier))
        }
        return result
    }

    private func installObserver(for pid: pid_t) {
        var observer: AXObserver?
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let error = AXObserverCreate(pid, Self.axCallback, &observer)
        guard error == .success, let observer else {
            return
        }

        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let appElement = AXUIElementCreateApplication(pid)
        let createdResult = AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, selfPointer)
        if createdResult != .success {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            return
        }

        // 不是所有应用都可靠支持销毁通知；失败就静默降级，交给兜底刷新补齐。
        _ = AXObserverAddNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString, selfPointer)

        entriesByPID[pid] = Entry(pid: pid, observer: observer, appElement: appElement, runLoopSource: runLoopSource)
    }

    private func handleAXNotification() {
        scheduleChange()
    }

    private func scheduleChange() {
        debounceWorkItem?.cancel()

        let work = DispatchWorkItem { [onChange] in
            onChange()
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private static let axCallback: AXObserverCallback = { _, _, _, userData in
        guard let userData else { return }
        let monitor = Unmanaged<VSCodeAXWindowMonitor>.fromOpaque(userData).takeUnretainedValue()
        monitor.handleAXNotification()
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
