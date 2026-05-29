import SwiftUI

@MainActor
struct HeaderView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        HStack(spacing: 14) {
            TrailShotLogo(size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("TrailShot")
                    .font(.system(size: 15, weight: .semibold))
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await store.toggleRecording() }
            } label: {
                Label(store.isRecording ? "Stop" : "Record", systemImage: store.isRecording ? "stop.circle.fill" : "record.circle")
            }
            .tint(store.isRecording ? .red : nil)

            if !store.hasScreenRecordingPermission {
                Button {
                    store.openScreenRecordingSettings()
                } label: {
                    Label("Settings", systemImage: "lock.shield")
                }
                .help("Open Screen Recording settings")
            }

            Button {
                Task { await store.captureTargetedWindow() }
            } label: {
                Label("Window", systemImage: "macwindow.on.rectangle")
            }

            Button {
                Task { await store.captureFullScreen() }
            } label: {
                Label("Full", systemImage: "macwindow")
            }

            Button {
                Task { await store.captureArea() }
            } label: {
                Label("Capture", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var statusText: String {
        switch store.status {
        case .ready:
            store.hasScreenRecordingPermission ? "Ready" : "Screen Recording access off"
        case .selectingArea:
            "Drag to select an area"
        case .working(let message):
            message
        case .failed(let message):
            message
        }
    }
}
