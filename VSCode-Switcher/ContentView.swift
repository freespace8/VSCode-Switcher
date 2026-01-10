//
//  ContentView.swift
//  VSCode-Switcher
//
//  Created by Taylor Ni on 2026/1/10.
//

import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
final class VSCodeWindowsViewModel: ObservableObject {
    @Published private(set) var hasAccessibilityPermission: Bool = false
    @Published private(set) var windows: [VSCodeWindowItem] = []
    @Published private(set) var diagnosticsText: String = ""
    @Published private(set) var activeWindow: VSCodeWindowItem?

    private let switcher: VSCodeWindowSwitcher
    private var activePollTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var didBecomeActiveObserver: NSObjectProtocol?

    init(switcher: VSCodeWindowSwitcher? = nil) {
        self.switcher = switcher ?? .shared
    }

    func refresh() {
        hasAccessibilityPermission = switcher.hasAccessibilityPermission()
        windows = switcher.listOrderedVSCodeWindows()
        diagnosticsText = switcher.diagnosticsSummary()
        activeWindow = switcher.frontmostVSCodeWindow()
    }

    func startActiveWindowPolling() {
        if activePollTask != nil { return }

        activePollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await self?.pollPermissionAndActiveWindow()
            }
        }
    }

    func stopActiveWindowPolling() {
        activePollTask?.cancel()
        activePollTask = nil
    }

    func startAutoRefreshObservers() {
        if !workspaceObservers.isEmpty { return }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let refreshHandler: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        workspaceObservers = [
            workspaceCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: refreshHandler),
            workspaceCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: refreshHandler),
            workspaceCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: refreshHandler),
        ]

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main,
            using: refreshHandler
        )
    }

    func stopAutoRefreshObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            workspaceCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            self.didBecomeActiveObserver = nil
        }
    }

    func refreshActiveWindow() {
        activeWindow = switcher.frontmostVSCodeWindow()
    }

    func pollPermissionAndActiveWindow() {
        if !hasAccessibilityPermission {
            let granted = switcher.hasAccessibilityPermission()
            if granted {
                refresh()
                return
            }
        }

        refreshActiveWindow()
    }

    func openAccessibilitySettings() {
        switcher.openAccessibilitySettings()
    }

    func requestAccessibilityPermission() {
        _ = switcher.requestAccessibilityIfNeeded()
        refresh()
    }

    func focus(_ window: VSCodeWindowItem) {
        switcher.focus(window: window)
    }

    func moveWindow(id: String, before targetID: String?) {
        guard let fromIndex = windows.firstIndex(where: { $0.id == id }) else { return }
        let window = windows.remove(at: fromIndex)

        let toIndex: Int
        if let targetID, let targetIndex = windows.firstIndex(where: { $0.id == targetID }) {
            toIndex = targetIndex
        } else {
            toIndex = windows.count
        }

        windows.insert(window, at: min(toIndex, windows.count))
        switcher.saveWindowOrder(windows)
    }

    func assignedNumber(for window: VSCodeWindowItem) -> Int? {
        switcher.windowNumberAssignment(for: window)
    }

    func setAssignedNumber(_ number: Int?, for window: VSCodeWindowItem) {
        switcher.setWindowNumberAssignment(number, for: window)
        refresh()
    }

    var statusLine: String {
        "AX: \(hasAccessibilityPermission ? "✅" : "❌")  Windows: \(windows.count)"
    }
}

struct ContentView: View {
    @StateObject private var viewModel = VSCodeWindowsViewModel()
    @State private var draggingID: String?

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if !viewModel.hasAccessibilityPermission {
                permissionView
            } else if viewModel.windows.isEmpty {
                emptyView
            } else {
                windowList
            }
        }
        .frame(minWidth: 260, minHeight: 420)
        .background(AppWindowAccessor())
        .onAppear {
            viewModel.refresh()
            viewModel.startActiveWindowPolling()
            viewModel.startAutoRefreshObservers()
        }
        .onDisappear {
            viewModel.stopActiveWindowPolling()
            viewModel.stopAutoRefreshObservers()
        }
    }

    private var sidebarHeader: some View {
        HStack {
            Spacer()
            Button("Refresh") {
                viewModel.refresh()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accessibility permission required")
                .font(.title2)

            Text("Enable Accessibility for VSCode-Switcher in System Settings so it can list and focus VSCode windows.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Open System Settings") {
                    viewModel.openAccessibilitySettings()
                }

                Button("Try Again") {
                    viewModel.refresh()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No VSCode windows found")
                .font(.title2)

            Text("Open VSCode (or VSCode Insiders), then hit Refresh.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var windowList: some View {
        List {
            ForEach(Array(viewModel.windows.prefix(10))) { window in
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .center)
                        .onDrag {
                            draggingID = window.id
                            return NSItemProvider(object: window.id as NSString)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.title)
                            .lineLimit(1)

                        Text(hotKeyLabel(for: window))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .listRowBackground(isActive(window) ? Color.accentColor.opacity(0.18) : Color.clear)
                .onTapGesture {
                    viewModel.focus(window)
                    viewModel.refreshActiveWindow()
                }
                .onDrop(of: [UTType.plainText.identifier], delegate: WindowRowDropDelegate(
                    item: window,
                    draggingID: $draggingID,
                    viewModel: viewModel
                ))
            }
        }
    }

    private func isActive(_ window: VSCodeWindowItem) -> Bool {
        guard let active = viewModel.activeWindow else { return false }
        return active.id == window.id
    }

    private func hotKeyLabel(for window: VSCodeWindowItem) -> String {
        guard let index = viewModel.windows.prefix(10).firstIndex(where: { $0.id == window.id }) else {
            return ""
        }
        let number = index == 9 ? "0" : String(index + 1)
        return "⌃⌥\(number)"
    }
}

private struct WindowRowDropDelegate: DropDelegate {
    let item: VSCodeWindowItem
    @Binding var draggingID: String?
    let viewModel: VSCodeWindowsViewModel

    func dropEntered(_ info: DropInfo) {
        guard let draggingID, draggingID != item.id else { return }
        viewModel.moveWindow(id: draggingID, before: item.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

#Preview {
    ContentView()
}

private struct AppWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> AppWindowAccessorView {
        AppWindowAccessorView()
    }

    func updateNSView(_ nsView: AppWindowAccessorView, context: Context) {}
}

private final class AppWindowAccessorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            VSCodeWindowSwitcher.shared.setAppWindow(window)
        }
    }
}
