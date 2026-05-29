import SwiftUI

@MainActor
struct CaptureSidebarView: View {
    @Bindable var store: CaptureStore
    @State private var searchText = ""
    @State private var showFavoritesOnly = false

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

            if !store.recordings.isEmpty {
                Section {
                    ForEach(store.recordings.prefix(6)) { recording in
                        RecordingRowView(recording: recording, store: store)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack {
                        Text("Recordings")
                        Spacer()
                        Button {
                            store.refreshRecordings()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Refresh recordings")
                    }
                }
            }

            Section(showFavoritesOnly ? "Favorite Captures" : "Captures") {
                if store.captures.isEmpty {
                    ContentUnavailableView("No captures yet", systemImage: "camera.viewfinder", description: Text("Use Capture to start a TrailShot."))
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if filteredCaptures.isEmpty {
                    ContentUnavailableView(emptyFilterTitle, systemImage: emptyFilterSymbol, description: Text(emptyFilterDescription))
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredCaptures) { capture in
                        CaptureRowView(capture: capture, store: store)
                            .tag(capture.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search captures")
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                TrailShotLogo(size: 24)
                Text("TrailShot")
                    .font(.headline)
                Spacer()
                Button {
                    showFavoritesOnly.toggle()
                } label: {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .foregroundStyle(showFavoritesOnly ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(showFavoritesOnly ? "Show all captures" : "Show favorites")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var filteredCaptures: [CaptureItem] {
        store.captures.filter { capture in
            (!showFavoritesOnly || capture.isFavorite) && capture.matchesSidebarSearch(searchText)
        }
    }

    private var emptyFilterTitle: String {
        if showFavoritesOnly && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No favorite captures"
        }

        return "No matching captures"
    }

    private var emptyFilterSymbol: String {
        showFavoritesOnly ? "star" : "magnifyingglass"
    }

    private var emptyFilterDescription: String {
        if showFavoritesOnly && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Star screenshots you want to find again quickly."
        }

        return "Try a capture name, type, annotation, or size."
    }
}

@MainActor
private struct RecordingRowView: View {
    let recording: RecordingItem
    @Bindable var store: CaptureStore
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "film")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(recording.detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.openRecording(recording)
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Open recording")
            .opacity(isHovered ? 1 : 0.55)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            store.openRecording(recording)
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") {
                store.openRecording(recording)
            }

            Button("Reveal in Finder") {
                store.revealRecording(recording)
            }

            Divider()

            Button("Move to Trash", role: .destructive) {
                store.deleteRecording(recording)
            }
        }
    }

    private var backgroundColor: Color {
        isHovered ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.65)
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

            Spacer(minLength: 4)

            Button {
                store.toggleFavorite(captureID: capture.id)
            } label: {
                Image(systemName: capture.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(capture.isFavorite ? Color.accentColor : Color.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help(capture.isFavorite ? "Remove favorite" : "Favorite")
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(capture.isFavorite ? "Remove Favorite" : "Favorite") {
                store.toggleFavorite(captureID: capture.id)
            }

            Divider()

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

private extension CaptureItem {
    func matchesSidebarSearch(_ searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }

        let searchableText = [
            name,
            kind.rawValue,
            "\(Int(pixelSize.width))",
            "\(Int(pixelSize.height))",
            "\(Int(pixelSize.width)) x \(Int(pixelSize.height))"
        ]
        .joined(separator: " ")
        .lowercased()

        if searchableText.contains(query) {
            return true
        }

        return annotations.contains { annotation in
            annotation.text.lowercased().contains(query) ||
                annotation.tool.rawValue.lowercased().contains(query)
        }
    }
}
