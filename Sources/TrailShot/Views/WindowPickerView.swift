import SwiftUI

@MainActor
struct WindowPickerView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                TrailShotLogo(size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture Window")
                        .font(.headline)
                    Text("Choose a visible window to capture.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    Task { await store.showWindowPicker() }
                }
            }
            .padding(18)

            Divider()

            if let message = store.windowPickerMessage {
                ContentUnavailableView(message, systemImage: "macwindow.badge.exclamationmark")
                    .frame(width: 520, height: 280)
            } else {
                List(store.windowCandidates) { candidate in
                    Button {
                        Task { await store.captureWindow(candidate) }
                    } label: {
                        WindowCandidateRow(
                            candidate: candidate,
                            thumbnail: store.windowThumbnails[candidate.id]
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                }
                .listStyle(.plain)
                .frame(width: 560, height: 330)
            }

            Divider()

            HStack {
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") {
                    store.isShowingWindowPicker = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(14)
        }
        .frame(width: 560)
    }

    private var footerText: String {
        let loaded = store.windowThumbnails.count
        let total = min(store.windowCandidates.count, 14)
        guard total > 0 else {
            return "\(store.windowCandidates.count) windows"
        }
        return "\(store.windowCandidates.count) windows - \(loaded)/\(total) previews"
    }
}

@MainActor
private struct WindowCandidateRow: View {
    let candidate: CaptureWindowCandidate
    let thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            WindowThumbnailView(thumbnail: thumbnail)

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(candidate.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "camera.viewfinder")
                .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
        }
        .padding(9)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHovered ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var backgroundStyle: Color {
        isHovered ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor)
    }
}

@MainActor
private struct WindowThumbnailView: View {
    let thumbnail: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.quaternary)

            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 86, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 86, height: 54)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        }
    }
}
