import SwiftUI

@MainActor
struct CaptureSidebarView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        List(selection: $store.selectedCaptureID) {
            if !store.pinnedCaptures.isEmpty {
                Section {
                    ForEach(store.pinnedCaptures) { pinnedCapture in
                        PinnedCaptureRowView(pinnedCapture: pinnedCapture, store: store)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack {
                        Text("Pinned")
                        Spacer()
                        Button {
                            store.closeAllPinnedCaptures()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Close all pinned captures")
                    }
                }
            }

            Section("Captures") {
                if store.captures.isEmpty {
                    ContentUnavailableView("No captures yet", systemImage: "camera.viewfinder", description: Text("Use Capture to start a TrailShot."))
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(store.captures) { capture in
                        CaptureRowView(capture: capture, store: store)
                            .tag(capture.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                TrailShotLogo(size: 24)
                Text("TrailShot")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

@MainActor
private struct PinnedCaptureRowView: View {
    let pinnedCapture: PinnedCapture
    @Bindable var store: CaptureStore
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "pin.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(pinnedCapture.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(Int(pinnedCapture.pixelSize.width)) x \(Int(pinnedCapture.pixelSize.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.unpinCapture(id: pinnedCapture.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Close pin")
            .opacity(isHovered ? 1 : 0.45)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            store.focusPinnedCapture(pinnedCapture)
        }
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        isHovered ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.65)
    }
}

@MainActor
private struct CaptureRowView: View {
    let capture: CaptureItem
    @Bindable var store: CaptureStore

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: capture.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 46, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(.separator, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(capture.name)
                    .lineLimit(1)
                Text("\(Int(capture.pixelSize.width)) x \(Int(capture.pixelSize.height))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy") {
                store.selectedCaptureID = capture.id
                store.copySelectedCapture()
            }

            Button("Pin to Screen") {
                store.selectedCaptureID = capture.id
                store.pinSelectedCapture()
            }

            Divider()

            Button("Delete", role: .destructive) {
                store.deleteCapture(id: capture.id)
            }
        }
    }
}
