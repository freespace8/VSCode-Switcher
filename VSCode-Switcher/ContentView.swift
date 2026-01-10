//
//  ContentView.swift
//  VSCode-Switcher
//
//  Created by Taylor Ni on 2026/1/10.
//

import SwiftUI
import Combine
import AppKit

@MainActor
final class VSCodeWindowsViewModel: ObservableObject {
    @Published private(set) var hasAccessibilityPermission: Bool = false
    @Published private(set) var windows: [VSCodeWindowItem] = []
    @Published private(set) var windowAliases: [String: String] = [:]
    @Published private(set) var diagnosticsText: String = ""
    @Published private(set) var activeWindow: VSCodeWindowItem?

    private let switcher: VSCodeWindowSwitcher
    private var activePollTask: Task<Void, Never>?
    private var notificationObserver: RefreshNotificationObserver?

    init(switcher: VSCodeWindowSwitcher? = nil) {
        self.switcher = switcher ?? .shared
    }

    func refresh() {
        hasAccessibilityPermission = switcher.hasAccessibilityPermission()
        windows = switcher.listOrderedVSCodeWindows()
        windowAliases = switcher.windowAliases()
        diagnosticsText = switcher.diagnosticsSummary()
        activeWindow = switcher.frontmostVSCodeWindow()
    }

    func startActiveWindowPolling() {
        if activePollTask != nil { return }

        activePollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                self?.pollPermissionAndActiveWindow()
            }
        }
    }

    func stopActiveWindowPolling() {
        activePollTask?.cancel()
        activePollTask = nil
    }

    func startAutoRefreshObservers() {
        if notificationObserver != nil { return }

        let observer = RefreshNotificationObserver(viewModel: self)
        notificationObserver = observer

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(observer, selector: #selector(RefreshNotificationObserver.handle(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspaceCenter.addObserver(observer, selector: #selector(RefreshNotificationObserver.handle(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspaceCenter.addObserver(observer, selector: #selector(RefreshNotificationObserver.handle(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        NotificationCenter.default.addObserver(observer, selector: #selector(RefreshNotificationObserver.handle(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    func stopAutoRefreshObservers() {
        guard let observer = notificationObserver else { return }

        NSWorkspace.shared.notificationCenter.removeObserver(observer)
        NotificationCenter.default.removeObserver(observer)
        notificationObserver = nil
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

    func focusAndTile(_ window: VSCodeWindowItem) {
        switcher.focusAndTile(window: window)
    }

    func moveWindow(id: String, before targetID: String?) {
        guard let fromIndex = windows.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.interpolatingSpring(stiffness: 380, damping: 32)) {
            let window = windows.remove(at: fromIndex)

            let toIndex: Int
            if let targetID, let targetIndex = windows.firstIndex(where: { $0.id == targetID }) {
                toIndex = targetIndex
            } else {
                toIndex = windows.count
            }

            windows.insert(window, at: min(toIndex, windows.count))
        }
        switcher.saveWindowOrder(windows)
    }

    func moveWindowUp(id: String) {
        guard let index = windows.firstIndex(where: { $0.id == id }), index > 0 else { return }
        withAnimation(.interpolatingSpring(stiffness: 380, damping: 32)) {
            windows.swapAt(index, index - 1)
        }
        switcher.saveWindowOrder(windows)
    }

    func moveWindowDown(id: String) {
        guard let index = windows.firstIndex(where: { $0.id == id }), index + 1 < windows.count else { return }
        withAnimation(.interpolatingSpring(stiffness: 380, damping: 32)) {
            windows.swapAt(index, index + 1)
        }
        switcher.saveWindowOrder(windows)
    }

    func assignedNumber(for window: VSCodeWindowItem) -> Int? {
        switcher.windowNumberAssignment(for: window)
    }

    func setAssignedNumber(_ number: Int?, for window: VSCodeWindowItem) {
        switcher.setWindowNumberAssignment(number, for: window)
        refresh()
    }

    func alias(forWindowID id: String) -> String? {
        windowAliases[id]
    }

    func setAlias(_ alias: String?, forWindowID id: String) {
        switcher.setWindowAlias(alias, forWindowID: id)
        windowAliases = switcher.windowAliases()
    }

    var statusLine: String {
        "AX: \(hasAccessibilityPermission ? "✅" : "❌")  Windows: \(windows.count)"
    }
}

@MainActor
private final class RefreshNotificationObserver: NSObject {
    private weak var viewModel: VSCodeWindowsViewModel?

    init(viewModel: VSCodeWindowsViewModel) {
        self.viewModel = viewModel
    }

    @objc func handle(_ notification: Notification) {
        viewModel?.refresh()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = VSCodeWindowsViewModel()
    @State private var isAliasEditorPresented: Bool = false
    @State private var aliasEditorWindowID: String?
    @State private var aliasEditorWindowTitle: String = ""
    @State private var aliasDraft: String = ""
    @State private var isSorting: Bool = false

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
        .alert("窗口别名", isPresented: $isAliasEditorPresented) {
            TextField("别名", text: $aliasDraft)

            Button("取消", role: .cancel) {
                aliasEditorWindowID = nil
            }

            Button("保存") {
                if let aliasEditorWindowID {
                    viewModel.setAlias(aliasDraft, forWindowID: aliasEditorWindowID)
                }
                aliasEditorWindowID = nil
            }
        } message: {
            Text(aliasEditorWindowTitle.isEmpty ? "为窗口设置一个易识别的名字。" : "窗口: \(aliasEditorWindowTitle)")
        }
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
            Button(isSorting ? "完成" : "排序") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSorting.toggle()
                }
            }

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
            ForEach(viewModel.windows) { window in
                let hotKey = hotKeyLabel(for: window)
                let alias = viewModel.alias(forWindowID: window.id)
                let displayTitle = alias ?? window.title
                let shouldShowOriginalTitle = alias != nil && alias != window.title
                let index = viewModel.windows.firstIndex(where: { $0.id == window.id }) ?? 0
                HStack(spacing: 10) {
                    Color.clear
                        .frame(width: 22)

                    Button {
                        viewModel.focusAndTile(window)
                        viewModel.refreshActiveWindow()
                    } label: {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayTitle)
                                    .lineLimit(1)

                                if !hotKey.isEmpty || shouldShowOriginalTitle {
                                    HStack(spacing: 8) {
                                        if !hotKey.isEmpty {
                                            Text(hotKey)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        if shouldShowOriginalTitle {
                                            Text(window.title)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSorting)
                    .contextMenu {
                        Button("编辑别名") {
                            aliasEditorWindowID = window.id
                            aliasEditorWindowTitle = window.title
                            aliasDraft = alias ?? ""
                            isAliasEditorPresented = true
                        }

                        if alias != nil {
                            Button("清空别名") {
                                viewModel.setAlias(nil, forWindowID: window.id)
                            }
                        }
                    }

                    if isSorting {
                        HStack(spacing: 8) {
                            Button {
                                viewModel.moveWindowUp(id: window.id)
                            } label: {
                                Text("上移")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(index == 0)

                            Button {
                                viewModel.moveWindowDown(id: window.id)
                            } label: {
                                Text("下移")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(index + 1 >= viewModel.windows.count)
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(isActive(window) ? Color.accentColor.opacity(0.18) : Color.clear)
            }
        }
        .animation(.interpolatingSpring(stiffness: 380, damping: 32), value: viewModel.windows)
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
