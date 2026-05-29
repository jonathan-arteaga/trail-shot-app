import SwiftUI

struct SettingsView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        TabView {
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

    private var shortcutsPane: some View {
        Form {
            Section {
                Toggle("Enable global shortcuts", isOn: globalShortcutsEnabled)
                Text(store.globalShortcutSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Defaults") {
                ForEach(store.defaultGlobalShortcuts) { shortcut in
                    HStack(spacing: 12) {
                        Image(systemName: shortcut.action.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(shortcut.action.title)
                        Spacer()
                        Text(shortcut.displayValue)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
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
}
