import AppKit
import SwiftUI

@main
struct TrailShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = CaptureStore()

    var body: some Scene {
        WindowGroup("TrailShot", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 960, minHeight: 640)
                .onAppear {
                    store.startGlobalShortcuts()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Capture Area") {
                    Task { await store.captureArea() }
                }
                .keyboardShortcut("4", modifiers: [.control, .option, .shift])

                Button("Capture Full Screen") {
                    Task { await store.captureFullScreen() }
                }
                .keyboardShortcut("3", modifiers: [.control, .option, .shift])

                Button("Capture Window") {
                    Task { await store.captureTargetedWindow() }
                }
                .keyboardShortcut("5", modifiers: [.control, .option, .shift])

                Button(store.isRecording ? "Stop Recording" : "Start Recording") {
                    Task { await store.toggleRecording() }
                }
                .keyboardShortcut("r", modifiers: [.control, .option, .shift])

                Button("Record Area") {
                    Task { await store.startAreaRecording() }
                }
                .keyboardShortcut("a", modifiers: [.control, .option, .shift])
                .disabled(store.isRecording)
            }

            CommandMenu("Capture") {
                Button("Choose Window from List...") {
                    Task { await store.showWindowPicker() }
                }

                Divider()

                Button("Copy Annotated Image") {
                    store.copySelectedCapture()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(store.selectedCapture == nil)

                Button("Copy Framed Image") {
                    store.copySelectedCaptureFramed()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(store.selectedCapture == nil)

                Button("Copy Detected Text") {
                    Task { await store.copyDetectedTextFromSelectedCapture() }
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(store.selectedCapture == nil)

                Button("Save Annotated Image...") {
                    Task { await store.saveSelectedCapture() }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.selectedCapture == nil)

                Button("Save Framed Image...") {
                    Task { await store.saveSelectedCaptureFramed() }
                }
                .disabled(store.selectedCapture == nil)

                Button("Pin to Screen") {
                    store.pinSelectedCapture()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(store.selectedCapture == nil)

                Button("Close All Pins") {
                    store.closeAllPinnedCaptures()
                }
                .disabled(store.pinnedCaptures.isEmpty)

                Divider()

                Button(store.isRecording ? "Stop Recording" : "Start Recording") {
                    Task { await store.toggleRecording() }
                }
                .keyboardShortcut("r", modifiers: [.control, .option, .shift])

                Button("Record Area") {
                    Task { await store.startAreaRecording() }
                }
                .keyboardShortcut("a", modifiers: [.control, .option, .shift])
                .disabled(store.isRecording)

                Button("Open Last Recording") {
                    store.openLastRecording()
                }
                .disabled(store.lastRecordingURL == nil)

                Button("Reveal Last Recording") {
                    store.revealLastRecording()
                }
                .disabled(store.lastRecordingURL == nil)

                Divider()

                Button("Delete Capture") {
                    store.deleteSelectedCapture()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(store.selectedCapture == nil)

                Button("Clear Capture History") {
                    store.clearCaptureHistory()
                }
                .disabled(store.captures.isEmpty)

                Divider()

                Button("Move Tool") {
                    store.activeTool = .move
                }
                .keyboardShortcut("v", modifiers: [])

                Button("Delete Selected Mark") {
                    store.deleteSelectedAnnotation()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(store.selectedAnnotationID == nil)

                Button("Undo Last Mark") {
                    store.undoLastAnnotation()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(store.selectedCapture?.annotations.isEmpty ?? true)
            }
        }

        MenuBarExtra("TrailShot", systemImage: "camera.viewfinder") {
            Button("Capture Area") {
                Task { await store.captureArea() }
            }
            .keyboardShortcut("4", modifiers: [.control, .option, .shift])

            Button("Capture Full Screen") {
                Task { await store.captureFullScreen() }
            }
            .keyboardShortcut("3", modifiers: [.control, .option, .shift])

            Button("Capture Window") {
                Task { await store.captureTargetedWindow() }
            }
            .keyboardShortcut("5", modifiers: [.control, .option, .shift])

            Button("Choose Window from List...") {
                Task { await store.showWindowPicker() }
            }

            Button(store.isRecording ? "Stop Recording" : "Start Recording") {
                Task { await store.toggleRecording() }
            }
            .keyboardShortcut("r", modifiers: [.control, .option, .shift])

            Button("Record Area") {
                Task { await store.startAreaRecording() }
            }
            .keyboardShortcut("a", modifiers: [.control, .option, .shift])
            .disabled(store.isRecording)

            Divider()

            Button("Copy Latest") {
                store.copySelectedCapture()
            }
            .disabled(store.selectedCapture == nil)

            Button("Copy Latest Framed") {
                store.copySelectedCaptureFramed()
            }
            .disabled(store.selectedCapture == nil)

            Button("Copy Detected Text") {
                Task { await store.copyDetectedTextFromSelectedCapture() }
            }
            .disabled(store.selectedCapture == nil)

            Button("Save Latest...") {
                Task { await store.saveSelectedCapture() }
            }
            .disabled(store.selectedCapture == nil)

            Button("Save Latest Framed...") {
                Task { await store.saveSelectedCaptureFramed() }
            }
            .disabled(store.selectedCapture == nil)

            Button("Pin Latest") {
                store.pinSelectedCapture()
            }
            .disabled(store.selectedCapture == nil)

            Button("Close All Pins") {
                store.closeAllPinnedCaptures()
            }
            .disabled(store.pinnedCaptures.isEmpty)

            Divider()

            Button("Open Last Recording") {
                store.openLastRecording()
            }
            .disabled(store.lastRecordingURL == nil)

            Button("Reveal Last Recording") {
                store.revealLastRecording()
            }
            .disabled(store.lastRecordingURL == nil)

            Divider()

            Button("Delete Latest") {
                store.deleteSelectedCapture()
            }
            .disabled(store.selectedCapture == nil)

            Button("Clear History") {
                store.clearCaptureHistory()
            }
            .disabled(store.captures.isEmpty)

            Divider()

            SettingsLink {
                Label("Settings...", systemImage: "gear")
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
