import SwiftUI

struct CaptureDetailView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        HStack(spacing: 0) {
            PreviewPane(store: store)
            Divider()
            ToolInspectorView(store: store)
                .frame(width: 260)
        }
    }
}

private struct PreviewPane: View {
    @Bindable var store: CaptureStore

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let capture = store.selectedCapture {
                    AnnotationCanvasView(capture: capture, store: store)
                        .padding(18)
                } else {
                    WelcomeCaptureView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.22))

            if store.selectedCapture != nil {
                Divider()
                HStack(spacing: 10) {
                    Picker("Tool", selection: $store.activeTool) {
                        ForEach(AnnotationTool.allCases) { tool in
                            Label(tool.rawValue, systemImage: tool.symbolName)
                                .tag(tool)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)

                    Button {
                        store.copySelectedCapture()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button {
                        Task { await store.saveSelectedCapture() }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        store.copySelectedCaptureFramed()
                    } label: {
                        Label("Frame", systemImage: "photo.on.rectangle")
                    }
                    .help("Copy framed image")

                    Button {
                        store.pinSelectedCapture()
                    } label: {
                        Label("Pin", systemImage: "pin")
                    }

                    Button {
                        store.undoLastAnnotation()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }

                    Button {
                        store.deleteSelectedAnnotation()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(store.selectedAnnotationID == nil)

                    Button {
                        store.clearAnnotations()
                    } label: {
                        Label("Clear", systemImage: "eraser")
                    }

                    Spacer()
                }
                .padding(12)
            }
        }
    }
}

private struct WelcomeCaptureView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        VStack(spacing: 18) {
            TrailShotLogo(size: 74)
            VStack(spacing: 6) {
                Text("Capture, mark, and keep moving.")
                    .font(.title2.weight(.semibold))
                Text("A Salesforce-internal screenshot workflow built for speed, polish, and trust.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !store.hasScreenRecordingPermission {
                PermissionNoticeView(store: store)
                    .frame(maxWidth: 420)
            }

            HStack {
                Button {
                    Task { await store.toggleRecording() }
                } label: {
                    Label(store.isRecording ? "Stop Recording" : "Record", systemImage: store.isRecording ? "stop.circle.fill" : "record.circle")
                }
                .tint(store.isRecording ? .red : nil)

                Button {
                    Task { await store.startAreaRecording() }
                } label: {
                    Label("Record Area", systemImage: "rectangle.dashed")
                }
                .disabled(store.isRecording)

                Button {
                    Task { await store.captureTargetedWindow() }
                } label: {
                    Label("Window", systemImage: "macwindow.on.rectangle")
                }

                Button {
                    Task { await store.captureFullScreen() }
                } label: {
                    Label("Full Screen", systemImage: "macwindow")
                }

                Button {
                    Task { await store.captureArea() }
                } label: {
                    Label("Capture Area", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

private struct ToolInspectorView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tools")
                    .font(.headline)
                Text("Draw directly on the preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                ForEach(AnnotationTool.allCases) { tool in
                    ToolTileView(tool: tool, isSelected: store.activeTool == tool) {
                        store.activeTool = tool
                    }
                }
            }

            if store.activeTool == .text {
                TextField("Label", text: $store.activeText)
                    .textFieldStyle(.roundedBorder)
            }

            if store.activeTool == .move {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.selectedAnnotationID == nil ? "Select a mark to edit it." : "Drag the mark or its handles to adjust it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if store.selectedAnnotation?.tool == .text {
                        TextField("Selected text", text: selectedAnnotationText)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Button {
                            store.deleteSelectedAnnotation()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(store.selectedAnnotationID == nil)

                        Button {
                            store.undoLastAnnotation()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                    }
                    .font(.caption)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Recording")
                    .font(.subheadline.weight(.semibold))
                Button {
                    Task { await store.toggleRecording() }
                } label: {
                    Label(store.isRecording ? "Stop recording" : "Record screen", systemImage: store.isRecording ? "stop.circle.fill" : "record.circle")
                }
                .tint(store.isRecording ? .red : nil)

                Button {
                    Task { await store.startAreaRecording() }
                } label: {
                    Label("Record area", systemImage: "rectangle.dashed")
                }
                .disabled(store.isRecording)

                if let lastRecordingURL = store.lastRecordingURL {
                    Text(lastRecordingURL.lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack {
                        Button {
                            store.openLastRecording()
                        } label: {
                            Label("Open", systemImage: "play.circle")
                        }
                        Button {
                            store.revealLastRecording()
                        } label: {
                            Label("Reveal", systemImage: "folder")
                        }
                    }
                } else {
                    Text("Saved locally to Movies/TrailShot.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            Divider()

            if store.selectedCapture != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture")
                        .font(.subheadline.weight(.semibold))
                    TextField("Name", text: selectedCaptureName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button {
                            store.deleteSelectedCapture()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            store.clearCaptureHistory()
                        } label: {
                            Label("Clear history", systemImage: "trash.slash")
                        }
                        .disabled(store.captures.isEmpty)
                    }
                }
                .font(.caption)

                Divider()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Safety")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 7) {
                    Image(systemName: store.hasScreenRecordingPermission ? "checkmark.shield" : "lock.shield")
                        .foregroundStyle(store.hasScreenRecordingPermission ? Color.green : Color.secondary)
                    Text(store.hasScreenRecordingPermission ? "Screen Recording access on" : "Screen Recording access off")
                        .foregroundStyle(.secondary)
                }
                if !store.hasScreenRecordingPermission {
                    HStack {
                        Button {
                            store.requestScreenRecordingPermission()
                        } label: {
                            Label("Allow", systemImage: "checkmark.circle")
                        }

                        Button {
                            store.openScreenRecordingSettings()
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
                Button {
                    store.refreshScreenRecordingPermission()
                } label: {
                    Label("Check access", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await store.autoRedactSensitiveText() }
                } label: {
                    Label("Detect sensitive text", systemImage: "text.viewfinder")
                }
                Text("Runs locally with Vision OCR.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Output")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    DragExportChipView(title: "Drag PNG", systemImage: "hand.draw") {
                        store.dragItemProvider(framed: false)
                    }

                    DragExportChipView(title: "Drag frame", systemImage: "photo.on.rectangle") {
                        store.dragItemProvider(framed: true)
                    }
                }
                Button {
                    store.copySelectedCapture()
                } label: {
                    Label("Copy annotated image", systemImage: "doc.on.doc")
                }
                Button {
                    store.copySelectedCaptureFramed()
                } label: {
                    Label("Copy framed image", systemImage: "photo.on.rectangle")
                }
                Button {
                    Task { await store.saveSelectedCapture() }
                } label: {
                    Label("Save PNG", systemImage: "square.and.arrow.down")
                }
                Button {
                    Task { await store.saveSelectedCaptureFramed() }
                } label: {
                    Label("Save framed PNG", systemImage: "square.and.arrow.down")
                }
                Button {
                    store.pinSelectedCapture()
                } label: {
                    Label("Pin to screen", systemImage: "pin")
                }
                if !store.pinnedCaptures.isEmpty {
                    Button {
                        store.closeAllPinnedCaptures()
                    } label: {
                        Label("Close all pins", systemImage: "xmark.circle")
                    }
                }
                Button {
                    store.clearAnnotations()
                } label: {
                    Label("Clear marks", systemImage: "eraser")
                }
            }
            .font(.caption)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Next up")
                    .font(.subheadline.weight(.semibold))
                Label("Window thumbnails", systemImage: "photo.on.rectangle")
                Label("Multi-display capture", systemImage: "display.2")
                Label("Recording trim", systemImage: "timeline.selection")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
    }

    private var selectedAnnotationText: Binding<String> {
        Binding(
            get: { store.selectedAnnotation?.text ?? "" },
            set: { store.updateSelectedAnnotationText($0) }
        )
    }

    private var selectedCaptureName: Binding<String> {
        Binding(
            get: { store.selectedCapture?.name ?? "" },
            set: { store.renameSelectedCapture($0) }
        )
    }
}

private struct PermissionNoticeView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Recording access is off")
                        .font(.subheadline.weight(.semibold))
                    Text("Required for local screen and window capture.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                Button {
                    store.requestScreenRecordingPermission()
                } label: {
                    Label("Allow", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.openScreenRecordingSettings()
                } label: {
                    Label("Settings", systemImage: "gear")
                }

                Button {
                    store.refreshScreenRecordingPermission()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Check access")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        }
    }
}

private struct DragExportChipView: View {
    let title: String
    let systemImage: String
    let provider: () -> NSItemProvider
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 9)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovered = $0 }
        .onDrag(provider)
        .help("Drag to another app")
    }

    private var backgroundColor: Color {
        isHovered ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor)
    }
}

private struct ToolTileView: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.symbolName)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 28, height: 28)
                Text(tool.rawValue)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.plain)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 0.7)
        }
        .help(tool.rawValue)
    }

    private var backgroundColor: Color {
        isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        isSelected ? Color.accentColor : Color(nsColor: .separatorColor)
    }
}
