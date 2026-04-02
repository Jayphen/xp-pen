import AppKit
import Carbon.HIToolbox

enum ActionType: String, CaseIterable, Identifiable {
    case none = "None"
    case keyboardShortcut = "Keyboard Shortcut"
    case volumeUp = "Volume Up"
    case volumeDown = "Volume Down"
    case mute = "Mute Toggle"
    case playPause = "Play / Pause"
    case nextTrack = "Next Track"
    case prevTrack = "Previous Track"
    case shellCommand = "Shell Command"

    var id: String { rawValue }
}

struct Action {
    let type: ActionType
    let shellCommand: String?
    /// Stores keyboard shortcut as "modifiers+keycode", e.g. "cmd+shift+49"
    let keyCombo: String?

    init(type: ActionType, shellCommand: String? = nil, keyCombo: String? = nil) {
        self.type = type
        self.shellCommand = shellCommand
        self.keyCombo = keyCombo
    }

    func execute() {
        switch type {
        case .none:
            break
        case .keyboardShortcut:
            if let combo = keyCombo {
                sendKeyCombo(combo)
            }
        case .volumeUp:
            runAppleScript("set volume output volume ((output volume of (get volume settings)) + 5)")
        case .volumeDown:
            runAppleScript("set volume output volume ((output volume of (get volume settings)) - 5)")
        case .mute:
            runAppleScript("set volume output muted (not (output muted of (get volume settings)))")
        case .playPause:
            sendMediaKey(NX_KEYTYPE_PLAY)
        case .nextTrack:
            sendMediaKey(NX_KEYTYPE_NEXT)
        case .prevTrack:
            sendMediaKey(NX_KEYTYPE_PREVIOUS)
        case .shellCommand:
            if let cmd = shellCommand {
                DispatchQueue.global().async {
                    let task = Process()
                    task.launchPath = "/bin/sh"
                    task.arguments = ["-c", cmd]
                    try? task.run()
                }
            }
        }
    }

    // MARK: - Keyboard shortcut

    private func sendKeyCombo(_ combo: String) {
        let parts = combo.split(separator: "+")
        guard let keycodeStr = parts.last, let keycode = UInt16(keycodeStr) else { return }

        var flags: CGEventFlags = []
        for part in parts.dropLast() {
            switch part {
            case "cmd": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "opt": flags.insert(.maskAlternate)
            case "ctrl": flags.insert(.maskControl)
            default: break
            }
        }

        if let down = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: true),
           let up = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: false) {
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Helpers

    private func runAppleScript(_ script: String) {
        DispatchQueue.global().async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            try? task.run()
        }
    }

    private func sendMediaKey(_ key: Int32) {
        func doKey(_ down: Bool) {
            let flags: UInt64 = UInt64((key << 16) | (down ? 0x0A00 : 0x0B00))
            if let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: Int(flags), data2: -1
            ) {
                event.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        doKey(true)
        doKey(false)
    }

    // MARK: - Serialization

    static func fromMapping(_ mapping: ButtonMapping) -> Action? {
        guard let type = ActionType(rawValue: mapping.actionType) else { return nil }
        return Action(type: type, shellCommand: mapping.shellCommand, keyCombo: mapping.keyCombo)
    }
}

// MARK: - Key combo display helpers

func keyComboDisplayName(_ combo: String) -> String {
    let parts = combo.split(separator: "+")
    guard let keycodeStr = parts.last, let keycode = UInt16(keycodeStr) else { return combo }

    var symbols = ""
    for part in parts.dropLast() {
        switch part {
        case "ctrl": symbols += "⌃"
        case "opt": symbols += "⌥"
        case "shift": symbols += "⇧"
        case "cmd": symbols += "⌘"
        default: break
        }
    }

    return symbols + keyName(keycode)
}

private func keyName(_ keycode: UInt16) -> String {
    let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "Home", 116: "PgUp", 117: "⌦", 119: "End", 121: "PgDn",
    ]
    return names[keycode] ?? "Key\(keycode)"
}
