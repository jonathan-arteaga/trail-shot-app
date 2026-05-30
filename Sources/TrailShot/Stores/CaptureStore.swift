import AppKit
import Observation
import UniformTypeIdentifiers

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
    var isSensitiveExportGuardEnabled: Bool
    var captureRetentionPolicy: CaptureRetentionPolicy
    var recordingRetentionPolicy: CaptureRetentionPolicy
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
    private let textRecognitionService = TextRecognitionService()
    private let recordingTrimService = RecordingTrimService()
    private let captureLibraryService: CaptureLibraryService
    private let permissionService = ScreenRecordingPermissionService()
    private let globalHotKeyService = GlobalHotKeyService()
    private let userDefaults: UserDefaults
    private let recordingsDirectory: URL
    private var exportClearedCaptureIDs: Set<CaptureItem.ID> = []

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
        isSensitiveExportGuardEnabled = userDefaults.object(forKey: PreferencesKeys.sensitiveExportGuardEnabled) as? Bool ?? true
        captureRetentionPolicy = Self.loadCaptureRetentionPolicy(from: userDefaults)
        recordingRetentionPolicy = Self.loadRecordingRetentionPolicy(from: userDefaults)
        globalShortcuts = Self.loadGlobalShortcuts(from: userDefaults)
        recordings = Self.loadRecordings(from: recordingsDirectory)
        applyRecordingRetentionPolicy(now: Date())
        lastRecordingURL = recordings.first?.url
        captures = captureLibraryService.loadCaptures()
        applyCaptureRetentionPolicy(now: Date(), shouldPersistWhenChanged: true)
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

    func setSensitiveExportGuardEnabled(_ enabled: Bool) {
        isSensitiveExportGuardEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.sensitiveExportGuardEnabled)
        if !enabled {
            exportClearedCaptureIDs.removeAll()
        }
    }

    func setAutoCopyAfterCaptureEnabled(_ enabled: Bool) {
        isAutoCopyAfterCaptureEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.autoCopyAfterCaptureEnabled)
    }

    func setQuickAccessAfterCaptureEnabled(_ enabled: Bool) {
        isQuickAccessAfterCaptureEnabled = enabled
        userDefaults.set(enabled, forKey: PreferencesKeys.quickAccessAfterCaptureEnabled)
    }

    func setCaptureRetentionPolicy(_ policy: CaptureRetentionPolicy) {
        captureRetentionPolicy = policy
        userDefaults.set(policy.rawValue, forKey: PreferencesKeys.captureRetentionPolicy)
        applyCaptureRetentionPolicy(now: Date(), shouldPersistWhenChanged: true)
    }

    func setRecordingRetentionPolicy(_ policy: CaptureRetentionPolicy) {
        recordingRetentionPolicy = policy
        userDefaults.set(policy.rawValue, forKey: PreferencesKeys.recordingRetentionPolicy)
        applyRecordingRetentionPolicy(now: Date())
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

    private static func loadCaptureRetentionPolicy(from userDefaults: UserDefaults) -> CaptureRetentionPolicy {
        guard
            let rawValue = userDefaults.string(forKey: PreferencesKeys.captureRetentionPolicy),
            let policy = CaptureRetentionPolicy(rawValue: rawValue)
        else {
            return .forever
        }

        return policy
    }

    private static func loadRecordingRetentionPolicy(from userDefaults: UserDefaults) -> CaptureRetentionPolicy {
        guard
            let rawValue = userDefaults.string(forKey: PreferencesKeys.recordingRetentionPolicy),
            let policy = CaptureRetentionPolicy(rawValue: rawValue)
        else {
            return .forever
        }

        return policy
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
        applyRecordingRetentionPolicy(now: Date())
        lastRecordingURL = recordings.first?.url
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

    func recordingDuration(of recording: RecordingItem) async -> TimeInterval {
        await recordingTrimService.duration(of: recording.url)
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

    func copySelectedCapture() async {
        guard let captureID = selectedCapture?.id else { return }
        await copyCapture(id: captureID, framed: false)
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

    func copySelectedCaptureFramed() async {
        guard let captureID = selectedCapture?.id else { return }
        await copyCapture(id: captureID, framed: true)
    }

    func copyDetectedTextFromSelectedCapture() async {
        guard let capture = selectedCapture else { return }
        status = .working("Reading text locally")

        do {
            let observations = try await textRecognitionService.recognize(in: capture.image)
            let text = TextRecognitionService.plainText(from: observations)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                showTransientStatus("No text found")
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            showTransientStatus("Copied detected text")
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func saveSelectedCapture() async {
        guard
            let captureID = selectedCapture?.id,
            await ensureCaptureIsSafeToExport(id: captureID),
            let capture = capture(id: captureID)
        else {
            return
        }
        await exportService.saveWithPanel(capture)
    }

    func saveSelectedCaptureFramed() async {
        guard
            let captureID = selectedCapture?.id,
            await ensureCaptureIsSafeToExport(id: captureID),
            let capture = capture(id: captureID)
        else {
            return
        }
        await exportService.saveFramedWithPanel(capture)
    }

    func dragItemProvider(framed: Bool) -> NSItemProvider {
        guard let captureID = selectedCapture?.id else {
            return NSItemProvider()
        }

        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            Task { @MainActor in
                guard
                    await self.ensureCaptureIsSafeToExport(id: captureID),
                    let capture = self.capture(id: captureID)
                else {
                    completion(nil, CocoaError(.userCancelled))
                    return
                }

                let image = framed ? self.exportService.framedImage(for: capture) : self.exportService.renderedImage(for: capture)
                guard let data = image.pngData() else {
                    completion(nil, CocoaError(.fileWriteUnknown))
                    return
                }

                completion(data, nil)
            }

            return Progress(totalUnitCount: 1)
        }
        return provider
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
        exportClearedCaptureIDs.remove(id)
        selectedAnnotationID = nil

        if selectedCaptureID == id || selectedCaptureID == nil {
            selectedCaptureID = captures.indices.contains(index) ? captures[index].id : captures.first?.id
        }
        persistCaptureLibrary()
    }

    func clearCaptureHistory() {
        captures.removeAll()
        exportClearedCaptureIDs.removeAll()
        selectedCaptureID = nil
        selectedAnnotationID = nil
        closeAllPinnedCaptures()
        status = .ready
        persistCaptureLibrary()
    }

    func applyCaptureRetentionPolicy(now: Date, shouldPersistWhenChanged: Bool = true) {
        let removedCaptureIDs = captures
            .filter { !captureRetentionPolicy.keeps(capture: $0, now: now) }
            .map(\.id)

        guard !removedCaptureIDs.isEmpty else { return }

        removedCaptureIDs.forEach(closePinnedCaptures)
        captures.removeAll { removedCaptureIDs.contains($0.id) }
        removedCaptureIDs.forEach { exportClearedCaptureIDs.remove($0) }
        if let selectedCaptureID, removedCaptureIDs.contains(selectedCaptureID) {
            self.selectedCaptureID = captures.first?.id
            selectedAnnotationID = nil
        }

        if shouldPersistWhenChanged {
            persistCaptureLibrary()
        }
    }

    func applyRecordingRetentionPolicy(now: Date) {
        let expiredRecordings = recordings.filter { !recordingRetentionPolicy.keeps(recording: $0, now: now) }
        guard !expiredRecordings.isEmpty else { return }

        for recording in expiredRecordings where FileManager.default.fileExists(atPath: recording.url.path) {
            try? FileManager.default.removeItem(at: recording.url)
        }

        let expiredIDs = Set(expiredRecordings.map(\.id))
        recordings.removeAll { expiredIDs.contains($0.id) }
        if let lastRecordingURL, expiredRecordings.contains(where: { $0.url == lastRecordingURL }) {
            self.lastRecordingURL = recordings.first?.url
        }
    }

    func clearAnnotations() {
        guard let index = selectedCaptureIndex else { return }
        invalidateExportSafety(for: captures[index].id)
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
            invalidateExportSafety(for: id)
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
        invalidateExportSafety(for: captures[index].id)
        self.selectedAnnotationID = nil
        persistCaptureLibrary()
    }

    func undoLastAnnotation() {
        guard let index = selectedCaptureIndex, !captures[index].annotations.isEmpty else { return }
        let removed = captures[index].annotations.removeLast()
        invalidateExportSafety(for: captures[index].id)
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
        invalidateExportSafety(for: captures[index].id)
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
        invalidateExportSafety(for: captures[captureIndex].id)
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
        invalidateExportSafety(for: captures[captureIndex].id)
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
        invalidateExportSafety(for: captures[captureIndex].id)
        persistCaptureLibrary()
    }

    private func copyCapture(id: CaptureItem.ID, framed: Bool) async {
        guard
            await ensureCaptureIsSafeToExport(id: id),
            let capture = capture(id: id)
        else {
            return
        }

        let image = framed ? exportService.framedImage(for: capture) : exportService.renderedImage(for: capture)
        exportService.copyToClipboard(image)
        showTransientStatus(framed ? "Copied framed image" : "Copied image")
    }

    private func ensureCaptureIsSafeToExport(id: CaptureItem.ID) async -> Bool {
        guard isSensitiveExportGuardEnabled else { return true }
        guard !exportClearedCaptureIDs.contains(id) else { return true }
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return false }

        status = .working("Checking screenshot locally")
        let image = captures[index].image

        do {
            let matches = try await sensitiveTextDetectionService.detect(in: image)
            guard let resolvedIndex = captures.firstIndex(where: { $0.id == id }) else {
                status = .ready
                return false
            }

            let uncoveredMatches = SensitiveExportGuard.uncoveredMatches(
                in: matches,
                annotations: captures[resolvedIndex].annotations
            )

            guard !uncoveredMatches.isEmpty else {
                exportClearedCaptureIDs.insert(id)
                status = .ready
                return true
            }

            let annotations = uncoveredMatches.map(\.redactionAnnotation)
            captures[resolvedIndex].annotations.append(contentsOf: annotations)
            selectedAnnotationID = annotations.last?.id
            activeTool = .move
            persistCaptureLibrary()
            showTransientStatus("Added \(annotations.count) redaction\(annotations.count == 1 ? "" : "s"). Review before sharing.")
            return false
        } catch {
            status = .failed("Could not check sensitive text.")
            return false
        }
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
        if isAutoRedactAfterCaptureEnabled {
            Task { [weak self] in
                await self?.autoRedactCapture(id: item.id, isAutomatic: true)
                if self?.isAutoCopyAfterCaptureEnabled == true {
                    await self?.copyCapture(id: item.id, framed: false)
                }
            }
        } else if isAutoCopyAfterCaptureEnabled {
            Task { [weak self] in
                await self?.copyCapture(id: item.id, framed: false)
            }
        }
        if isQuickAccessAfterCaptureEnabled {
            quickAccessService.show(
                captureName: item.name,
                copy: { [weak self] in Task { await self?.copySelectedCapture() } },
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

    private func capture(id: CaptureItem.ID) -> CaptureItem? {
        captures.first { $0.id == id }
    }

    private func invalidateExportSafety(for id: CaptureItem.ID) {
        exportClearedCaptureIDs.remove(id)
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
    static let sensitiveExportGuardEnabled = "sensitiveExportGuardEnabled"
    static let captureRetentionPolicy = "captureRetentionPolicy"
    static let recordingRetentionPolicy = "recordingRetentionPolicy"
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
