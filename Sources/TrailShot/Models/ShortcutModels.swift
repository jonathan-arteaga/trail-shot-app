import Carbon.HIToolbox
import Foundation

struct GlobalShortcut: Identifiable, Equatable {
    let action: GlobalShortcutAction
    let keyCode: UInt32
    let modifiers: UInt32
    let displayValue: String

    var id: GlobalShortcutAction { action }
}

enum GlobalShortcutAction: UInt32, CaseIterable, Identifiable {
    case captureArea = 1
    case captureFullScreen
    case captureWindow
    case toggleRecording
    case recordArea

    var id: UInt32 { rawValue }

    var title: String {
        switch self {
        case .captureArea:
            "Capture Area"
        case .captureFullScreen:
            "Capture Full Screen"
        case .captureWindow:
            "Capture Window"
        case .toggleRecording:
            "Record / Stop"
        case .recordArea:
            "Record Area"
        }
    }

    var systemImage: String {
        switch self {
        case .captureArea:
            "camera.viewfinder"
        case .captureFullScreen:
            "macwindow"
        case .captureWindow:
            "macwindow.on.rectangle"
        case .toggleRecording:
            "record.circle"
        case .recordArea:
            "rectangle.dashed"
        }
    }

    var defaultShortcut: GlobalShortcut {
        let modifiers = UInt32(controlKey | optionKey | shiftKey)

        switch self {
        case .captureArea:
            return GlobalShortcut(action: self, keyCode: UInt32(kVK_ANSI_4), modifiers: modifiers, displayValue: "⌃⌥⇧4")
        case .captureFullScreen:
            return GlobalShortcut(action: self, keyCode: UInt32(kVK_ANSI_3), modifiers: modifiers, displayValue: "⌃⌥⇧3")
        case .captureWindow:
            return GlobalShortcut(action: self, keyCode: UInt32(kVK_ANSI_5), modifiers: modifiers, displayValue: "⌃⌥⇧5")
        case .toggleRecording:
            return GlobalShortcut(action: self, keyCode: UInt32(kVK_ANSI_R), modifiers: modifiers, displayValue: "⌃⌥⇧R")
        case .recordArea:
            return GlobalShortcut(action: self, keyCode: UInt32(kVK_ANSI_A), modifiers: modifiers, displayValue: "⌃⌥⇧A")
        }
    }
}

struct GlobalShortcutRegistration: Equatable {
    let shortcut: GlobalShortcut
    let status: OSStatus

    var isRegistered: Bool {
        status == noErr
    }
}
