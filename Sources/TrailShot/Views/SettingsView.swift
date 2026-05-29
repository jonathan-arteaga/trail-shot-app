import SwiftUI

@MainActor
struct SettingsView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        TabView {
            capturePane
                .tabItem {
                    Label("Capture", systemImage: "camera.viewfinder")
                }

            shortcutsPane
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            privacyPane
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
        }
        .frame(width: 520, height: 430)
    }

    private var capturePane: some View {
        Form {
            Section("After Capture") {
                Toggle("Copy new screenshots to clipboard", isOn: autoCopyAfterCaptureEnabled)
                Text("Keeps the fastest path one click away in chat, documents, and Salesforce workflows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Show quick-access bubble", isOn: quickAccessAfterCaptureEnabled)
                Text("Shows copy, save, pin, and annotate actions right after each capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Safety") {
                Toggle("Auto-detect sensitive text after capture", isOn: autoRedactAfterCaptureEnabled)
                Text("Scans new screenshots on this Mac and covers matching text with editable redaction blocks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcutsPane: some View {
        Form {
            Section {
                Toggle("Enable global shortcuts", isOn: globalShortcutsEnabled)
                Text(store.globalShortcutSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = store.shortcutEditingMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Shortcuts") {
                ForEach(GlobalShortcutAction.allCases) { action in
                    let shortcut = store.shortcut(for: action)
                    HStack(spacing: 12) {
                        Image(systemName: action.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(action.title)
                        Spacer()
                        ShortcutRecorderView(shortcut: shortcut) { newShortcut in
                            store.updateGlobalShortcut(newShortcut)
                        }
                        .frame(width: 82, height: 26)

                        Button {
                            store.resetGlobalShortcut(action: action)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reset \(action.title)")
                    }
                }

                Button {
                    store.resetAllGlobalShortcuts()
                } label: {
                    Label("Reset All", systemImage: "arrow.counterclockwise.circle")
                }
            }

            Section {
                Text("These shortcuts avoid Apple’s built-in screenshot keys, so TrailShot can run without asking people to change system settings first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var privacyPane: some View {
        Form {
            Section("Screen Recording") {
                HStack {
                    Image(systemName: store.hasScreenRecordingPermission ? "checkmark.shield" : "lock.shield")
                        .foregroundStyle(store.hasScreenRecordingPermission ? Color.green : Color.secondary)
                    Text(store.hasScreenRecordingPermission ? "Access granted" : "Access required")
                    Spacer()
                    Button {
                        store.refreshScreenRecordingPermission()
                    } label: {
                        Label("Check", systemImage: "arrow.clockwise")
                    }
                }

                HStack {
                    Button {
                        store.requestScreenRecordingPermission()
                    } label: {
                        Label("Allow", systemImage: "checkmark.circle")
                    }

                    Button {
                        store.openScreenRecordingSettings()
                    } label: {
                        Label("System Settings", systemImage: "gear")
                    }
                }
            }

            Section("Local First") {
                Label("Screenshots stay on this Mac unless you share them.", systemImage: "internaldrive")
                Label("Sensitive-text detection runs locally with Vision OCR.", systemImage: "text.viewfinder")
                Label("Recordings save to Movies/TrailShot.", systemImage: "film")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var globalShortcutsEnabled: Binding<Bool> {
        Binding(
            get: { store.areGlobalShortcutsEnabled },
            set: { store.setGlobalShortcutsEnabled($0) }
        )
    }

    private var autoCopyAfterCaptureEnabled: Binding<Bool> {
        Binding(
            get: { store.isAutoCopyAfterCaptureEnabled },
            set: { store.setAutoCopyAfterCaptureEnabled($0) }
        )
    }

    private var quickAccessAfterCaptureEnabled: Binding<Bool> {
        Binding(
            get: { store.isQuickAccessAfterCaptureEnabled },
            set: { store.setQuickAccessAfterCaptureEnabled($0) }
        )
    }

    private var autoRedactAfterCaptureEnabled: Binding<Bool> {
        Binding(
            get: { store.isAutoRedactAfterCaptureEnabled },
            set: { store.setAutoRedactAfterCaptureEnabled($0) }
        )
    }
}
