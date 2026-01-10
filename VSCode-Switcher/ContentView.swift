//
//  ContentView.swift
//  VSCode-Switcher
//
//  Created by Taylor Ni on 2026/1/10.
//

import SwiftUI
import Combine

@MainActor
final class VSCodeWindowsViewModel: ObservableObject {
    @Published private(set) var hasAccessibilityPermission: Bool = false
    @Published private(set) var windows: [VSCodeWindowItem] = []
    @Published private(set) var diagnosticsText: String = ""

    private let switcher: VSCodeWindowSwitcher

    init(switcher: VSCodeWindowSwitcher? = nil) {
        self.switcher = switcher ?? .shared
    }

    func refresh() {
        hasAccessibilityPermission = switcher.hasAccessibilityPermission()
        windows = switcher.listOpenVSCodeWindows()
        diagnosticsText = switcher.diagnosticsSummary()
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

    var body: some View {
        VStack(spacing: 0) {
            header

            if !viewModel.hasAccessibilityPermission {
                permissionView
            } else if viewModel.windows.isEmpty {
                emptyView
            } else {
                windowList
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VSCode Windows")
                    .font(.headline)
                Text(viewModel.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Request Permission") {
                viewModel.requestAccessibilityPermission()
            }

            Button("Refresh") {
                viewModel.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding()
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

            if !viewModel.diagnosticsText.isEmpty {
                Text(viewModel.diagnosticsText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var windowList: some View {
        List(viewModel.windows) { window in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.title)
                        .lineLimit(1)

                    Text(window.appDisplayName ?? window.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    Button("Clear") {
                        viewModel.setAssignedNumber(nil, for: window)
                    }
                    Divider()
                    ForEach(1...9, id: \.self) { number in
                        Button("Option+\(number)") {
                            viewModel.setAssignedNumber(number, for: window)
                        }
                    }
                } label: {
                    let label = viewModel.assignedNumber(for: window).map { "\($0)" } ?? "—"
                    Text(label)
                        .frame(width: 28)
                }
                .menuStyle(.borderlessButton)

                Button("Switch") {
                    viewModel.focus(window)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    ContentView()
}
