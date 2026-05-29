import AppKit
import Observation

@MainActor
@Observable
final class CaptureStore {
    var captures: [CaptureItem] = []
    var selectedCaptureID: CaptureItem.ID?
    var status: CaptureStatus = .ready
    var activeTool: AnnotationTool = .arrow
    var activeText = "Note"
    var selectedAnnotationID: CaptureAnnotation.ID?
    var pinnedCaptures: [PinnedCapture] = []
    var isShowingWindowPicker = false
    var windowCandidates: [CaptureWindowCandidate] = []
    var windowThumbnails: [CGWindowID: NSImage] = [:]
    var windowPickerMessage: String?
    var hasScreenRecordingPermission: Bool
    var isRecording = false
    var recordingStartedAt: Date?
    var lastRecordingURL: URL?
    var recordings: [RecordingItem]
    var areGlobalShortcutsEnabled: Bool
    var isAutoCopyAfterCaptureEnabled: Bool
    var isQuickAccessAfterCaptureEnabled: Bool
    var isAutoRedactAfterCaptureEnabled: Bool
    var globalShortcuts: [GlobalShortcut]
    var globalShortcutRegistrations: [GlobalShortcutRegistration] = []
    var shortcutEditingMessage: String?

    private let captureService = ScreenCaptureService()
    private let recordingService: ScreenRecordingService
    private let selectionService = AreaSelectionService()
    private let hoverWindowSelectionService = HoverWindowSelectionService()
    private let exportService = ImageExportService()
    private let quickAccessService = QuickAccessService()
    private let pinWindowService = PinWindowService()
    private let sensitiveTextDetectionService = SensitiveTextDetectionService()
    private let recordingTrimService = RecordingTrimService()
    private let captureLibraryService: CaptureLibraryService
    private let permissionService = ScreenRecordingPermissionService()
    private let globalHotKeyService = GlobalHotKeyService()
    private let userDefaults: UserDefaults
    private let recordingsDirectory: URL

    init(
        userDefaults: UserDefaults = .standard,
        recordingsDirectory: URL = ScreenRecordingService.defaultRecordingsDirectory,
        captureLibraryDirectory: URL = CaptureLibraryService.defaultLibraryDirectory
    ) {
        self.userDefaults = userDefaults
        self.recordingsDirectory = recordingsDirectory
        recordingService = ScreenRecordingService(outputDirectory: recordingsDirectory)
        captureLibraryService = CaptureLibraryService(directory: captureLibraryDirectory)
        hasScreenRecordingPermission = permissionService.hasPermission()
        areGlobalShortcutsEnabled = userDefaults.object(forKey: PreferencesKeys.globalShortcutsEnabled) as? Bool ?? true
        isAutoCopyAfterCaptureEnabled = userDefaults.object(forKey: PreferencesKeys.autoCopyAfterCaptureEnabled) as? Bool ?? true
        isQuickAccessAfterCaptureEnabled = userDefaults.object(forKey: PreferencesKeys.quickAccessAfterCaptureEnabled) as? Bool ?? true
        isAutoRedactAfterCaptureEnabled = userDefaults.object(forKey: PreferencesKeys.autoRedactAfterCaptureEnabled) as? Bool ?? false
        globalShortcuts = Self.loadGlobalShortcuts(from: userDefaults)
        recordings = Self.loadRecordings(from: recordingsDirectory)
        lastRecordingURL = recordings.first?.url
        captures = captureLibraryService.loadCaptures()
        selectedCaptureID = captures.first?.id
    }

    var selectedCapture: CaptureItem? {
        guard let selectedCaptureID else { return captures.first }
        return captures.first { $0.id == selectedCaptureID }
    }

    var selectedAnnotation: CaptureAnnotation? {
        guard
            let selectedCapture,
            let selectedAnnotationID
        else {
            return nil
        }

        return selectedCapture.annotations.first { $0.id == selectedAnnotationID }
    }

    var defaultGlobalShortcuts: [GlobalShortcut] {
        GlobalShortcutAction.allCases.map(\.defaultShortcut)
    }

    func shortcut(for action: GlobalShortcutAction) -> GlobalShortcut {
        globalShortcuts.first { $0.action == action } ?? action.defaultShortcut
    }

    var globalShortcutSummary: String {
        guard areGlobalShortcutsEnabled else {
            return "Global shortcuts are off"
        }

        guard !globalShortcutRegistrations.isEmpty else {
            return "Global shortcuts are starting"
        }

        let failedCount = globalShortcutRegistrations.filter { !$0.isRegistered }.count
        if failedCount == 0 {
            return "Global shortcuts are ready"
        }

        return "\(failedCount) shortcut\(failedCount == 1 ? "" : "s") unavailable"
    }

    func startGlobalShortcuts() {
        configureGlobalShortcuts()
    }

    func setGlobalShortcutsEnabled(_ enabled: Bool) {
        areGlobalShortcutsEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.globalShortcutsEnabled)
        configureGlobalShortcuts()
    }

    func setAutoRedactAfterCaptureEnabled(_ enabled: Bool) {
        isAutoRedactAfterCaptureEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.autoRedactAfterCaptureEnabled)
    }

    func setAutoCopyAfterCaptureEnabled(_ enabled: Bool) {
        isAutoCopyAfterCaptureEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.autoCopyAfterCaptureEnabled)
    }

    func setQuickAccessAfterCaptureEnabled(_ enabled: Bool) {
        isQuickAccessAfterCaptureEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.quickAccessAfterCaptureEnabled)
    }

    private func configureGlobalShortcuts() {
        guard areGlobalShortcutsEnabled else {
            globalHotKeyService.unregisterAll()
            globalShortcutRegistrations = []
            return
        }

        globalShortcutRegistrations = globalHotKeyService.register(shortcuts: globalShortcuts) { [weak self] action in
            Task { @MainActor in
                await self?.performGlobalShortcut(action)
            }
        }
    }

    func updateGlobalShortcut(_ shortcut: GlobalShortcut) {
        guard shortcut.isUsableGlobalShortcut else {
            shortcutEditingMessage = "Use Command, Control, or Option with a key."
            return
        }

        guard !hasShortcutConflict(shortcut) else {
            shortcutEditingMessage = "\(shortcut.displayValue) is already assigned."
            return
        }

        replaceGlobalShortcut(shortcut)
        shortcutEditingMessage = "\(shortcut.action.title) set to \(shortcut.displayValue)."
    }

    func resetGlobalShortcut(action: GlobalShortcutAction) {
        replaceGlobalShortcut(action.defaultShortcut)
        shortcutEditingMessage = "\(action.title) reset."
    }

    func resetAllGlobalShortcuts() {
        globalShortcuts = defaultGlobalShortcuts
        persistGlobalShortcuts()
        configureGlobalShortcuts()
        shortcutEditingMessage = "Shortcuts reset to defaults."
    }

    private func replaceGlobalShortcut(_ shortcut: GlobalShortcut) {
        if let index = globalShortcuts.firstIndex(where: { $0.action == shortcut.action }) {
            globalShortcuts[index] = shortcut
        } else {
            globalShortcuts.append(shortcut)
            globalShortcuts.sort { $0.action.rawValue < $1.action.rawValue }
        }

        persistGlobalShortcuts()
        configureGlobalShortcuts()
    }

    private func hasShortcutConflict(_ shortcut: GlobalShortcut) -> Bool {
        globalShortcuts.contains {
            $0.action != shortcut.action &&
                $0.keyCode == shortcut.keyCode &&
                $0.modifiers == shortcut.modifiers
        }
    }

    private func persistGlobalShortcuts() {
        guard let data = try? JSONEncoder().encode(globalShortcuts) else { return }
        userDefaults.set(data, forKey: PreferencesKeys.globalShortcuts)
    }

    private static func loadGlobalShortcuts(from userDefaults: UserDefaults) -> [GlobalShortcut] {
        guard
            let data = userDefaults.data(forKey: PreferencesKeys.globalShortcuts),
            let decoded = try? JSONDecoder().decode([GlobalShortcut].self, from: data)
        else {
            return GlobalShortcutAction.allCases.map(\.defaultShortcut)
        }

        return GlobalShortcutAction.allCases.map { action in
            decoded.first { $0.action == action && $0.isUsableGlobalShortcut } ?? action.defaultShortcut
        }
    }

    private func performGlobalShortcut(_ action: GlobalShortcutAction) async {
        switch action {
        case .captureArea:
            await captureArea()
        case .captureFullScreen:
            await captureFullScreen()
        case .captureWindow:
            await captureTargetedWindow()
        case .toggleRecording:
            await toggleRecording()
        case .recordArea:
            await startAreaRecording()
        }
    }

    func captureArea() async {
        guard ensureScreenRecordingPermission() else { return }
        status = .selectingArea

        do {
            guard let rect = await selectionService.selectArea() else {
                status = .ready
                return
            }

            status = .working("Capturing selection")
            let image = try await captureService.captureMainDisplay(rect: rect)
            insertCapture(image: image, kind: .area)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func captureFullScreen() async {
        guard ensureScreenRecordingPermission() else { return }
        status = .working("Capturing full screen")

        do {
            let image = try await captureService.captureMainDisplay()
            insertCapture(image: image, kind: .fullScreen)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func captureFrontmostWindow() async {
        guard ensureScreenRecordingPermission() else { return }
        status = .working("Capturing window")

        do {
            let image = try await captureService.captureFrontmostWindow()
            insertCapture(image: image, kind: .window)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func captureTargetedWindow() async {
        guard ensureScreenRecordingPermission() else { return }
        status = .working("Choose a window")

        do {
            let candidates = try await captureService.availableWindows()
            guard !candidates.isEmpty else {
                status = .failed("No capturable windows found.")
                return
            }

            guard let candidate = await hoverWindowSelectionService.selectWindow(from: candidates) else {
                status = .ready
                return
            }

            status = .working("Capturing \(candidate.appName)")
            let image = try await captureService.captureWindow(id: candidate.id)
            insertCapture(image: image, kind: .window)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func showWindowPicker() async {
        guard ensureScreenRecordingPermission() else { return }
        status = .working("Finding windows")

        do {
            windowCandidates = try await captureService.availableWindows()
            windowThumbnails = [:]
            windowPickerMessage = windowCandidates.isEmpty ? "No capturable windows found." : nil
            isShowingWindowPicker = true
            status = .ready
            await loadWindowThumbnails(for: Array(windowCandidates.prefix(14)))
        } catch {
            windowCandidates = []
            windowThumbnails = [:]
            windowPickerMessage = error.localizedDescription
            isShowingWindowPicker = true
            status = .failed(error.localizedDescription)
        }
    }

    func captureWindow(_ candidate: CaptureWindowCandidate) async {
        guard ensureScreenRecordingPermission() else { return }
        isShowingWindowPicker = false
        status = .working("Capturing \(candidate.appName)")

        do {
            let image = try await captureService.captureWindow(id: candidate.id)
            insertCapture(image: image, kind: .window)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func startRecording() async {
        guard ensureScreenRecordingPermission(), !isRecording else { return }
        status = .working("Starting recording")

        do {
            lastRecordingURL = try await recordingService.startMainDisplayRecording()
            recordingStartedAt = Date()
            isRecording = true
            status = .working("Recording screen")
        } catch {
            isRecording = false
            recordingStartedAt = nil
            status = .failed(error.localizedDescription)
        }
    }

    func startAreaRecording() async {
        guard ensureScreenRecordingPermission(), !isRecording else { return }
        status = .selectingArea

        guard let rect = await selectionService.selectArea() else {
            status = .ready
            return
        }

        status = .working("Starting area recording")

        do {
            lastRecordingURL = try await recordingService.startAreaRecording(rect: rect)
            recordingStartedAt = Date()
            isRecording = true
            status = .working("Recording area")
        } catch {
            isRecording = false
            recordingStartedAt = nil
            status = .failed(error.localizedDescription)
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        status = .working("Finishing recording")

        do {
            let url = try await recordingService.stopRecording()
            rememberRecording(url)
            isRecording = false
            recordingStartedAt = nil
            status = .working("Recording saved")
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.8))
                self?.status = .ready
            }
        } catch {
            isRecording = false
            recordingStartedAt = nil
            status = .failed(error.localizedDescription)
        }
    }

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func revealLastRecording() {
        guard let lastRecordingURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
    }

    func openLastRecording() {
        guard let lastRecordingURL else { return }
        NSWorkspace.shared.open(lastRecordingURL)
    }

    func refreshRecordings() {
        recordings = Self.loadRecordings(from: recordingsDirectory)
        lastRecordingURL = recordings.first?.url ?? lastRecordingURL
    }

    func openRecording(_ recording: RecordingItem) {
        NSWorkspace.shared.open(recording.url)
    }

    func revealRecording(_ recording: RecordingItem) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.url])
    }

    func deleteRecording(_ recording: RecordingItem) {
        do {
            if FileManager.default.fileExists(atPath: recording.url.path) {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: recording.url, resultingItemURL: &trashedURL)
            }
            recordings.removeAll { $0.id == recording.id }
            if lastRecordingURL == recording.url {
                lastRecordingURL = recordings.first?.url
            }
            status = .working("Recording moved to Trash")
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.4))
                self?.status = .ready
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func recordingDuration(of recording: RecordingItem) -> TimeInterval {
        recordingTrimService.duration(of: recording.url)
    }

    func trimRecording(_ recording: RecordingItem, start: TimeInterval, end: TimeInterval) async {
        status = .working("Trimming recording")

        do {
            let url = try await recordingTrimService.trim(url: recording.url, start: start, end: end)
            rememberRecording(url)
            status = .working("Trimmed recording saved")
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.6))
                self?.status = .ready
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func loadWindowThumbnails(for candidates: [CaptureWindowCandidate]) async {
        for candidate in candidates {
            guard windowCandidates.contains(where: { $0.id == candidate.id }) else { continue }

            if let thumbnail = try? await captureService.captureWindowThumbnail(id: candidate.id) {
                windowThumbnails[candidate.id] = thumbnail
            }
        }
    }

    func copySelectedCapture() {
        guard let capture = selectedCapture else { return }
        exportService.copyToClipboard(exportService.renderedImage(for: capture))
    }

    func refreshScreenRecordingPermission() {
        hasScreenRecordingPermission = permissionService.hasPermission()
        if hasScreenRecordingPermission, case .failed(let message) = status, message == screenRecordingPermissionMessage {
            status = .ready
        }
    }

    func requestScreenRecordingPermission() {
        hasScreenRecordingPermission = permissionService.requestPermission()
        if hasScreenRecordingPermission {
            status = .ready
        } else {
            status = .failed(screenRecordingPermissionMessage)
        }
    }

    func openScreenRecordingSettings() {
        permissionService.openSystemSettings()
        status = .failed(screenRecordingPermissionMessage)
    }

    func copySelectedCaptureFramed() {
        guard let capture = selectedCapture else { return }
        exportService.copyToClipboard(exportService.framedImage(for: capture))
    }

    func saveSelectedCapture() async {
        guard let capture = selectedCapture else { return }
        await exportService.saveWithPanel(capture)
    }

    func saveSelectedCaptureFramed() async {
        guard let capture = selectedCapture else { return }
        await exportService.saveFramedWithPanel(capture)
    }

    func dragItemProvider(framed: Bool) -> NSItemProvider {
        guard let capture = selectedCapture else {
            return NSItemProvider()
        }

        do {
            let variant: ImageExportService.ExportVariant = framed ? .framed : .annotated
            let url = try exportService.temporaryPNGURL(for: capture, variant: variant)
            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
        } catch {
            NSSound.beep()
            return NSItemProvider()
        }
    }

    func renameSelectedCapture(_ name: String) {
        guard let selectedCaptureID else { return }
        renameCapture(id: selectedCaptureID, name: name)
    }

    func renameCapture(id: CaptureItem.ID, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let index = captures.firstIndex(where: { $0.id == id }) else {
            return
        }

        captures[index].name = trimmedName
        persistCaptureLibrary()
    }

    func toggleFavorite(captureID: CaptureItem.ID) {
        guard let index = captures.firstIndex(where: { $0.id == captureID }) else { return }
        captures[index].isFavorite.toggle()
        persistCaptureLibrary()
    }

    func deleteSelectedCapture() {
        guard let capture = selectedCapture else { return }
        deleteCapture(id: capture.id)
    }

    func deleteCapture(id: CaptureItem.ID) {
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return }
        closePinnedCaptures(for: id)
        captures.remove(at: index)
        selectedAnnotationID = nil

        if selectedCaptureID == id || selectedCaptureID == nil {
            selectedCaptureID = captures.indices.contains(index) ? captures[index].id : captures.first?.id
        }
        persistCaptureLibrary()
    }

    func clearCaptureHistory() {
        captures.removeAll()
        selectedCaptureID = nil
        selectedAnnotationID = nil
        closeAllPinnedCaptures()
        status = .ready
        persistCaptureLibrary()
    }

    func clearAnnotations() {
        guard let index = selectedCaptureIndex else { return }
        captures[index].annotations.removeAll()
        selectedAnnotationID = nil
        persistCaptureLibrary()
    }

    func autoRedactSensitiveText() async {
        guard let captureID = selectedCapture?.id else { return }
        await autoRedactCapture(id: captureID, isAutomatic: false)
    }

    private func autoRedactCapture(id: CaptureItem.ID, isAutomatic: Bool) async {
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return }
        status = .working(isAutomatic ? "Scanning new capture locally" : "Scanning locally")
        let image = captures[index].image

        do {
            let matches = try await sensitiveTextDetectionService.detect(in: image)
            guard let resolvedIndex = captures.firstIndex(where: { $0.id == id }) else {
                status = .ready
                return
            }

            guard !matches.isEmpty else {
                if isAutomatic {
                    status = .ready
                } else {
                    showTransientStatus("No sensitive text found")
                }
                return
            }

            let annotations = matches.map(\.redactionAnnotation)
            captures[resolvedIndex].annotations.append(contentsOf: annotations)

            if !isAutomatic || selectedCaptureID == id {
                selectedAnnotationID = annotations.last?.id
                activeTool = .move
            }

            persistCaptureLibrary()
            showTransientStatus("\(isAutomatic ? "Auto-added" : "Added") \(annotations.count) redaction\(annotations.count == 1 ? "" : "s")")
        } catch {
            if !isAutomatic || selectedCaptureID == id {
                status = .failed(error.localizedDescription)
            } else {
                status = .ready
            }
        }
    }

    func deleteSelectedAnnotation() {
        guard
            let index = selectedCaptureIndex,
            let selectedAnnotationID,
            let annotationIndex = captures[index].annotations.firstIndex(where: { $0.id == selectedAnnotationID })
        else {
            return
        }

        captures[index].annotations.remove(at: annotationIndex)
        self.selectedAnnotationID = nil
        persistCaptureLibrary()
    }

    func undoLastAnnotation() {
        guard let index = selectedCaptureIndex, !captures[index].annotations.isEmpty else { return }
        let removed = captures[index].annotations.removeLast()
        if selectedAnnotationID == removed.id {
            selectedAnnotationID = nil
        }
        persistCaptureLibrary()
    }

    func pinSelectedCapture() {
        guard let capture = selectedCapture else { return }
        let renderedImage = exportService.renderedImage(for: capture)
        let pinnedCapture = PinnedCapture(
            captureID: capture.id,
            title: capture.name,
            createdAt: Date(),
            pixelSize: renderedImage.pixelSize
        )

        pinnedCaptures.insert(pinnedCapture, at: 0)
        pinWindowService.pin(id: pinnedCapture.id, image: renderedImage, title: pinnedCapture.title) { [weak self] id in
            Task { @MainActor in
                self?.forgetPinnedCapture(id: id)
            }
        }
    }

    func focusPinnedCapture(_ pinnedCapture: PinnedCapture) {
        if let captureID = pinnedCapture.captureID {
            selectedCaptureID = captureID
        }
        pinWindowService.focus(id: pinnedCapture.id)
    }

    func unpinCapture(id: PinnedCapture.ID) {
        forgetPinnedCapture(id: id)
        pinWindowService.close(id: id)
    }

    func closeAllPinnedCaptures() {
        pinnedCaptures.removeAll()
        pinWindowService.closeAll()
    }

    func addAnnotation(tool: AnnotationTool, start: CGPoint, end: CGPoint) {
        guard let index = selectedCaptureIndex, tool != .move else { return }

        let normalizedStart = start.clampedToUnitSquare
        let normalizedEnd = end.clampedToUnitSquare
        let stepNumber = nextStepNumber(for: captures[index])
        let annotation = CaptureAnnotation(
            tool: tool,
            start: normalizedStart,
            end: normalizedEnd,
            text: activeText.isEmpty ? "Note" : activeText,
            stepNumber: stepNumber
        )
        captures[index].annotations.append(annotation)
        selectedAnnotationID = annotation.id
        persistCaptureLibrary()
    }

    func selectAnnotation(id: CaptureAnnotation.ID?) {
        selectedAnnotationID = id
        if id != nil {
            activeTool = .move
        }
    }

    func moveAnnotation(id: CaptureAnnotation.ID, by delta: CGPoint) {
        guard
            let captureIndex = selectedCaptureIndex,
            let annotationIndex = captures[captureIndex].annotations.firstIndex(where: { $0.id == id })
        else {
            return
        }

        var annotation = captures[captureIndex].annotations[annotationIndex]
        annotation.start = annotation.start.offsetBy(delta).clampedToUnitSquare
        annotation.end = annotation.end.offsetBy(delta).clampedToUnitSquare
        captures[captureIndex].annotations[annotationIndex] = annotation
        persistCaptureLibrary()
    }

    func resizeAnnotation(id: CaptureAnnotation.ID, handle: AnnotationResizeHandle, to point: CGPoint) {
        guard
            let captureIndex = selectedCaptureIndex,
            let annotationIndex = captures[captureIndex].annotations.firstIndex(where: { $0.id == id })
        else {
            return
        }

        var annotation = captures[captureIndex].annotations[annotationIndex]
        let point = point.clampedToUnitSquare

        switch annotation.tool {
        case .arrow:
            if handle == .start {
                annotation.start = point
            } else {
                annotation.end = point
            }
        case .rectangle, .redact:
            let minX = min(annotation.start.x, annotation.end.x)
            let maxX = max(annotation.start.x, annotation.end.x)
            let minY = min(annotation.start.y, annotation.end.y)
            let maxY = max(annotation.start.y, annotation.end.y)

            switch handle {
            case .topLeft:
                annotation.start = CGPoint(x: min(point.x, maxX - 0.01), y: min(point.y, maxY - 0.01))
                annotation.end = CGPoint(x: maxX, y: maxY)
            case .topRight:
                annotation.start = CGPoint(x: minX, y: min(point.y, maxY - 0.01))
                annotation.end = CGPoint(x: max(point.x, minX + 0.01), y: maxY)
            case .bottomLeft:
                annotation.start = CGPoint(x: min(point.x, maxX - 0.01), y: minY)
                annotation.end = CGPoint(x: maxX, y: max(point.y, minY + 0.01))
            case .bottomRight, .end:
                annotation.start = CGPoint(x: minX, y: minY)
                annotation.end = CGPoint(x: max(point.x, minX + 0.01), y: max(point.y, minY + 0.01))
            case .start:
                annotation.start = point
            }
        case .text, .step, .move:
            annotation.start = point
            annotation.end = point
        }

        captures[captureIndex].annotations[annotationIndex] = annotation
        persistCaptureLibrary()
    }

    func updateSelectedAnnotationText(_ text: String) {
        guard
            let captureIndex = selectedCaptureIndex,
            let selectedAnnotationID,
            let annotationIndex = captures[captureIndex].annotations.firstIndex(where: { $0.id == selectedAnnotationID }),
            captures[captureIndex].annotations[annotationIndex].tool == .text
        else {
            return
        }

        captures[captureIndex].annotations[annotationIndex].text = text
        persistCaptureLibrary()
    }

    private func insertCapture(image: NSImage, kind: CaptureKind) {
        let createdAt = Date()
        let item = CaptureItem(
            kind: kind,
            createdAt: createdAt,
            image: image,
            pixelSize: image.pixelSize,
            name: "\(kind.rawValue) \(createdAt.formatted(date: .omitted, time: .shortened))"
        )

        captures.insert(item, at: 0)
        selectedCaptureID = item.id
        selectedAnnotationID = nil
        persistCaptureLibrary()
        if isAutoCopyAfterCaptureEnabled {
            exportService.copyToClipboard(image)
        }
        if isAutoRedactAfterCaptureEnabled {
            Task { [weak self] in
                await self?.autoRedactCapture(id: item.id, isAutomatic: true)
            }
        }
        if isQuickAccessAfterCaptureEnabled {
            quickAccessService.show(
                captureName: item.name,
                copy: { [weak self] in self?.copySelectedCapture() },
                save: { [weak self] in Task { await self?.saveSelectedCapture() } },
                pin: { [weak self] in self?.pinSelectedCapture() },
                annotate: {
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
        }
    }

    private func rememberRecording(_ url: URL) {
        guard let recording = Self.recordingItem(for: url) else {
            lastRecordingURL = url
            return
        }

        recordings.removeAll { $0.id == recording.id }
        recordings.insert(recording, at: 0)
        lastRecordingURL = url
    }

    private func persistCaptureLibrary() {
        do {
            try captureLibraryService.saveCaptures(captures)
        } catch {
            status = .failed("Could not save capture history.")
        }
    }

    private func showTransientStatus(_ message: String) {
        status = .working(message)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            self?.status = .ready
        }
    }

    private static func loadRecordings(from directory: URL) -> [RecordingItem] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "mov" }
            .compactMap(recordingItem(for:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func recordingItem(for url: URL) -> RecordingItem? {
        guard
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
            values.isRegularFile ?? true
        else {
            return nil
        }

        return RecordingItem(
            url: url,
            createdAt: values.creationDate ?? values.contentModificationDate ?? Date(),
            fileSize: Int64(values.fileSize ?? 0)
        )
    }

    private var selectedCaptureIndex: Int? {
        guard let selectedCaptureID else {
            return captures.isEmpty ? nil : 0
        }
        return captures.firstIndex { $0.id == selectedCaptureID }
    }

    private func nextStepNumber(for capture: CaptureItem) -> Int {
        let maxStep = capture.annotations
            .filter { $0.tool == .step }
            .map(\.stepNumber)
            .max() ?? 0
        return maxStep + 1
    }

    private func ensureScreenRecordingPermission() -> Bool {
        hasScreenRecordingPermission = permissionService.hasPermission()
        guard hasScreenRecordingPermission else {
            status = .failed(screenRecordingPermissionMessage)
            return false
        }
        return true
    }

    private func forgetPinnedCapture(id: PinnedCapture.ID) {
        pinnedCaptures.removeAll { $0.id == id }
    }

    private func closePinnedCaptures(for captureID: CaptureItem.ID) {
        let pinnedIDs = pinnedCaptures
            .filter { $0.captureID == captureID }
            .map(\.id)

        pinnedIDs.forEach { id in
            forgetPinnedCapture(id: id)
            pinWindowService.close(id: id)
        }
    }
}

private let screenRecordingPermissionMessage = "Screen Recording permission required."

private enum PreferencesKeys {
    static let globalShortcutsEnabled = "globalShortcutsEnabled"
    static let autoCopyAfterCaptureEnabled = "autoCopyAfterCaptureEnabled"
    static let quickAccessAfterCaptureEnabled = "quickAccessAfterCaptureEnabled"
    static let autoRedactAfterCaptureEnabled = "autoRedactAfterCaptureEnabled"
    static let globalShortcuts = "globalShortcuts"
}

private extension CGPoint {
    var clampedToUnitSquare: CGPoint {
        CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    func offsetBy(_ delta: CGPoint) -> CGPoint {
        CGPoint(x: x + delta.x, y: y + delta.y)
    }
}
