import SwiftUI

struct MappingView: View {
    @EnvironmentObject var device: DeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Button Mapping")
                .font(.title2)
                .fontWeight(.semibold)
                .padding()

            List {
                Section("Scroll Wheel") {
                    ActionRow(device: device, buttonKey: "scroll_cw", label: "Clockwise", gesture: .press)
                    ActionRow(device: device, buttonKey: "scroll_ccw", label: "Counter-CW", gesture: .press)
                }

                Section("Buttons") {
                    ForEach(allButtons.filter({ !$0.key.hasPrefix("scroll") }), id: \.key) { btn in
                        DisclosureGroup(btn.label) {
                            ForEach(Gesture.allCases, id: \.rawValue) { gesture in
                                ActionRow(device: device, buttonKey: btn.key, label: gesture.label, gesture: gesture)
                            }
                        }
                    }
                }
            }

            .onDisappear {
                NSApp.setActivationPolicy(.accessory)
            }

            if let event = device.lastEvent, !event.isRelease {
                HStack {
                    Image(systemName: "hand.tap")
                    Text("Detected: **\(device.labelFor(key: event.key))**")
                    if !device.lastGesture.isEmpty {
                        let parts = device.lastGesture.split(separator: ":")
                        if parts.count > 1 {
                            Text("(\(String(parts.last!)))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary)
            }
        }
    }
}

struct ActionRow: View {
    let device: DeviceManager
    let buttonKey: String
    let label: String
    let gesture: Gesture

    @State private var selectedType: ActionType = .none
    @State private var shellCommand: String = ""
    @State private var keyCombo: String = ""
    @State private var isRecording = false

    private var fullKey: String { buttonKey + gesture.rawValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $selectedType) {
                    ForEach(ActionType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: selectedType) { _, newValue in
                    if newValue != .keyboardShortcut { keyCombo = "" }
                    if newValue != .shellCommand { shellCommand = "" }
                    saveMapping()
                }
            }

            if selectedType == .shellCommand {
                TextField("Command...", text: $shellCommand)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveMapping() }
            }

            if selectedType == .keyboardShortcut {
                HStack {
                    if isRecording {
                        KeyRecorderView(onRecord: { combo in
                            keyCombo = combo
                            isRecording = false
                            saveMapping()
                        })
                        .frame(width: 160, height: 24)
                        .background(.orange.opacity(0.15))
                        .cornerRadius(4)
                        .overlay(
                            Text("Press a key combo...")
                                .foregroundStyle(.orange)
                                .font(.callout)
                                .allowsHitTesting(false)
                        )
                    } else if !keyCombo.isEmpty {
                        Text(keyComboDisplayName(keyCombo))
                            .font(.system(.body, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .cornerRadius(4)
                    }

                    Button(isRecording ? "Cancel" : (keyCombo.isEmpty ? "Record" : "Change")) {
                        isRecording.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !keyCombo.isEmpty && !isRecording {
                        Button("Clear") {
                            keyCombo = ""
                            saveMapping()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            if let mapping = device.mappings[fullKey] {
                selectedType = ActionType(rawValue: mapping.actionType) ?? .none
                shellCommand = mapping.shellCommand ?? ""
                keyCombo = mapping.keyCombo ?? ""
            }
        }
    }

    private func saveMapping() {
        if selectedType == .none {
            device.mappings.removeValue(forKey: fullKey)
        } else {
            device.mappings[fullKey] = ButtonMapping(
                key: fullKey,
                label: label,
                actionType: selectedType.rawValue,
                shellCommand: selectedType == .shellCommand ? shellCommand : nil,
                keyCombo: selectedType == .keyboardShortcut ? keyCombo : nil
            )
        }
    }
}

/// Uses a global event monitor to capture key events — works even for accessory apps
struct KeyRecorderView: NSViewRepresentable {
    let onRecord: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Temporarily become a regular app so we can be key
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        context.coordinator.start(onRecord: onRecord)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
        // Stay as regular app — the user is still using the mapping window
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var globalMonitor: Any?
        var localMonitor: Any?

        func start(onRecord: @escaping (String) -> Void) {
            let handler: (NSEvent) -> Void = { event in
                // Ignore bare modifier key presses
                guard event.keyCode != 55 && event.keyCode != 56
                    && event.keyCode != 58 && event.keyCode != 59
                    && event.keyCode != 54 && event.keyCode != 60
                    && event.keyCode != 61 && event.keyCode != 62 else { return }

                var parts = [String]()
                if event.modifierFlags.contains(.control) { parts.append("ctrl") }
                if event.modifierFlags.contains(.option) { parts.append("opt") }
                if event.modifierFlags.contains(.shift) { parts.append("shift") }
                if event.modifierFlags.contains(.command) { parts.append("cmd") }
                parts.append(String(event.keyCode))
                DispatchQueue.main.async { onRecord(parts.joined(separator: "+")) }
            }

            // Global catches events even when not focused
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
            // Local catches events when focused
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handler(event)
                return nil
            }
        }

        func stop() {
            if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
            if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        }
    }
}
