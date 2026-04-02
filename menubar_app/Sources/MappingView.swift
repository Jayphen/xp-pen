import SwiftUI

struct MappingView: View {
    @EnvironmentObject var device: DeviceManager
    @State private var showAll = false
    @State private var expandedKey: String? = nil

    private var visibleButtons: [ButtonDef] {
        let buttons = allButtons.filter { !$0.key.hasPrefix("scroll") && $0.key != "000400000000" }
        return showAll ? buttons : Array(buttons.prefix(4))
    }

    private func openButton(_ key: String, proxy: ScrollViewProxy) {
        if !showAll { showAll = true }
        let scrollKey = (key == "scroll_cw" || key == "scroll_ccw") ? "scroll_wheel" : key
        expandedKey = scrollKey
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(scrollKey, anchor: .top)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.xpPrimary)

                Text("Precision Mapper")
                    .font(XPFont.titleMd())
                    .foregroundColor(.xpOnSurface)
                    .tracking(-0.02 * 17)

                Spacer()

                if device.isConnected {
                    HStack(spacing: 4) {
                        Circle().fill(Color.xpPrimary).frame(width: 6, height: 6)
                        Text(device.transport)
                            .font(XPFont.labelSm())
                            .foregroundColor(.xpOnSurfaceVariant)
                    }
                }
            }
            .padding(.horizontal, XPSpacing.s6)
            .padding(.top, XPSpacing.s5)
            .padding(.bottom, XPSpacing.s2)

            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIVE DEVICE")
                    .font(XPFont.labelMd())
                    .tracking(0.8)
                    .foregroundColor(.xpOnSurfaceVariant)
                Text("XP-Pen ACK05")
                    .font(XPFont.headlineLg())
                    .foregroundColor(.xpOnSurface)
                    .tracking(-0.02 * 22)
            }
            .padding(.horizontal, XPSpacing.s6)
            .padding(.bottom, XPSpacing.s5)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: XPSpacing.s3) {
                        ButtonCard(
                            device: device,
                            button: ButtonDef(key: "scroll_wheel", label: "Scroll Wheel"),
                            isScrollWheel: true,
                            isExpanded: expandedKey == "scroll_wheel",
                            onToggle: { expandedKey = expandedKey == "scroll_wheel" ? nil : "scroll_wheel" }
                        )
                        .id("scroll_wheel")

                        ButtonCard(
                            device: device,
                            button: ButtonDef(key: "000400000000", label: "Scroll Button"),
                            isExpanded: expandedKey == "000400000000",
                            onToggle: { expandedKey = expandedKey == "000400000000" ? nil : "000400000000" }
                        )
                        .id("000400000000")

                        ForEach(visibleButtons, id: \.key) { btn in
                            ButtonCard(
                                device: device,
                                button: btn,
                                isExpanded: expandedKey == btn.key,
                                onToggle: { expandedKey = expandedKey == btn.key ? nil : btn.key }
                            )
                            .id(btn.key)
                        }

                        if !showAll {
                            Button {
                                showAll = true
                            } label: {
                                Text("SHOW ALL \(allButtons.filter { !$0.key.hasPrefix("scroll") }.count) INPUTS")
                                    .font(XPFont.labelMd())
                                    .tracking(0.8)
                                    .foregroundColor(.xpPrimary)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, XPSpacing.s3)
                        }

                        TopologyView(expandedKey: expandedKey) { key in
                            openButton(key, proxy: proxy)
                        }
                        .padding(.top, XPSpacing.s2)
                    }
                    .padding(.horizontal, XPSpacing.s4)
                    .padding(.bottom, XPSpacing.s6)
                }
            }

            // Detection footer
            if !device.activeKey.isEmpty {
                HStack(spacing: XPSpacing.s2) {
                    RoundedRectangle(cornerRadius: XPRadius.sm)
                        .fill(Color.xpSurfaceContainerHigh)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "hand.tap")
                                .font(.system(size: 13))
                                .foregroundColor(.xpOnSurfaceVariant)
                        )

                    Text(device.labelFor(key: device.activeKey))
                        .font(XPFont.bodyMd())
                        .fontWeight(.medium)
                        .foregroundColor(.xpOnSurface)

                    Spacer()
                }
                .padding(.horizontal, XPSpacing.s6)
                .padding(.vertical, XPSpacing.s3)
                .background(Color.xpSurfaceContainerLow)
            }
        }
        .background(Color.xpSurface)
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Button Card

struct ButtonCard: View {
    let device: DeviceManager
    let button: ButtonDef
    var isScrollWheel: Bool = false
    let isExpanded: Bool
    let onToggle: () -> Void

    private var mappedStatus: String {
        if isScrollWheel {
            let has = ["scroll_cw", "scroll_ccw"].contains { device.mappings[$0] != nil }
                || Gesture.allCases.contains { device.mappings["000400000000" + $0.rawValue] != nil }
            return has ? "MAPPED" : "UNMAPPED"
        }
        return Gesture.allCases.contains(where: { device.mappings[button.key + $0.rawValue] != nil }) ? "MAPPED" : "UNMAPPED"
    }

    private var isActive: Bool {
        if isScrollWheel {
            return device.activeKey == "000400000000" || device.activeKey == "scroll_cw" || device.activeKey == "scroll_ccw"
        }
        return device.activeKey == button.key
    }

    private var iconName: String {
        if isScrollWheel { return "arrow.trianglehead.2.clockwise" }
        let l = button.label.lowercased()
        if l.contains("top") && l.contains("left") { return "arrow.up.left" }
        if l.contains("top") && l.contains("middle") { return "arrow.up" }
        if l.contains("top") && l.contains("right") { return "arrow.up.right" }
        if l == "right" { return "arrow.right" }
        if l.contains("middle") { return "circle.grid.cross" }
        if l.contains("bottom") && l.contains("left") { return "arrow.down.left" }
        if l.contains("bottom") && l.contains("center") { return "arrow.down" }
        if l.contains("bottom") && l.contains("right") { return "arrow.down.right" }
        return "square"
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: XPSpacing.s3) {
                    RoundedRectangle(cornerRadius: XPRadius.md)
                        .fill(isActive || isExpanded ? Color.xpPrimary.opacity(0.12) : Color.xpSurfaceContainerHigh)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 14))
                                .foregroundColor(isActive || isExpanded ? .xpPrimary : .xpOnSurfaceVariant)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(button.label)
                            .font(XPFont.bodyMd())
                            .fontWeight(.medium)
                            .foregroundColor(.xpOnSurface)

                        Text(mappedStatus)
                            .font(XPFont.labelSm())
                            .tracking(0.5)
                            .foregroundColor(mappedStatus == "MAPPED" ? .xpPrimary : .xpOnSurfaceVariant)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.xpOnSurfaceVariant)
                }
                .padding(.horizontal, XPSpacing.s4)
                .padding(.vertical, XPSpacing.s3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            if isExpanded {
                VStack(spacing: XPSpacing.s4) {
                    if isScrollWheel {
                        GestureSection(device: device, buttonKey: "scroll_cw", title: "CLOCKWISE", gesture: .press)
                        GestureSection(device: device, buttonKey: "scroll_ccw", title: "COUNTER-CLOCKWISE", gesture: .press)
                    } else {
                        ForEach(Gesture.allCases, id: \.rawValue) { gesture in
                            GestureSection(device: device, buttonKey: button.key, title: gesture.label.uppercased(), gesture: gesture)
                        }
                    }
                }
                .padding(.horizontal, XPSpacing.s4)
                .padding(.bottom, XPSpacing.s4)
            }
        }
        .background(isExpanded ? Color.xpSurfaceContainerLowest : Color.xpSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: XPRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: XPRadius.xl)
                .stroke(isExpanded ? Color.xpPrimary.opacity(0.3) : Color.xpOutlineVariant.opacity(0.15), lineWidth: isExpanded ? 1.5 : 1)
        )
    }
}

// MARK: - Gesture Section

struct GestureSection: View {
    let device: DeviceManager
    let buttonKey: String
    let title: String
    let gesture: Gesture

    @State private var selectedType: ActionType = .none
    @State private var shellCommand: String = ""
    @State private var keyCombo: String = ""
    @State private var isRecording = false

    private var fullKey: String { buttonKey + gesture.rawValue }

    var body: some View {
        VStack(alignment: .leading, spacing: XPSpacing.s2) {
            HStack {
                Text(title)
                    .font(XPFont.labelMd())
                    .tracking(0.5)
                    .foregroundColor(.xpOnSurfaceVariant)
                Spacer()
            }

            if selectedType == .none {
                Button {
                    selectedType = .volumeUp
                    saveMapping()
                } label: {
                    HStack {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("Unmapped").font(XPFont.bodySm())
                    }
                    .foregroundColor(.xpOnSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, XPSpacing.s3)
                    .background(Color.xpSurfaceContainerHigh.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: XPRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: XPRadius.lg)
                            .stroke(Color.xpOutlineVariant.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: XPSpacing.s2) {
                    Picker("", selection: $selectedType) {
                        ForEach(ActionType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                    .tint(.xpOnSurface)
                    .padding(.horizontal, XPSpacing.s2)
                    .padding(.vertical, XPSpacing.s1)
                    .background(Color.xpSurfaceContainerHigh.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: XPRadius.md))
                    .onChange(of: selectedType) { _, newValue in
                        if newValue != .keyboardShortcut { keyCombo = "" }
                        if newValue != .shellCommand { shellCommand = "" }
                        saveMapping()
                    }

                    if selectedType == .shellCommand {
                        TextField("Command...", text: $shellCommand)
                            .font(XPFont.bodySm())
                            .textFieldStyle(.plain)
                            .padding(.horizontal, XPSpacing.s3)
                            .padding(.vertical, XPSpacing.s2)
                            .background(Color.xpSurfaceContainerHigh.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: XPRadius.md))
                            .onSubmit { saveMapping() }
                    }

                    if selectedType == .keyboardShortcut {
                        HStack(spacing: XPSpacing.s2) {
                            if isRecording {
                                KeyRecorderView(onRecord: { combo in
                                    keyCombo = combo
                                    isRecording = false
                                    saveMapping()
                                })
                                .frame(width: 120, height: 28)
                                .background(Color.xpPrimary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: XPRadius.md))
                                .overlay(
                                    Text("Press keys...")
                                        .font(XPFont.bodySm())
                                        .foregroundColor(.xpPrimary)
                                        .allowsHitTesting(false)
                                )
                            } else if !keyCombo.isEmpty {
                                Text(keyComboDisplayName(keyCombo))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.xpOnSurface)
                                    .padding(.horizontal, XPSpacing.s2)
                                    .padding(.vertical, 4)
                                    .background(Color.xpSurfaceContainerHigh)
                                    .clipShape(RoundedRectangle(cornerRadius: XPRadius.md))
                            }

                            Button(isRecording ? "Cancel" : (keyCombo.isEmpty ? "Record" : "Change")) {
                                isRecording.toggle()
                            }
                            .buttonStyle(XPSecondaryButtonStyle())

                            if !keyCombo.isEmpty && !isRecording {
                                Button("Clear") { keyCombo = ""; saveMapping() }
                                    .buttonStyle(XPTertiaryButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .padding(XPSpacing.s3)
        .background(Color.xpSurfaceContainerLow.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: XPRadius.lg))
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
                key: fullKey, label: title, actionType: selectedType.rawValue,
                shellCommand: selectedType == .shellCommand ? shellCommand : nil,
                keyCombo: selectedType == .keyboardShortcut ? keyCombo : nil
            )
        }
    }
}

// MARK: - Key Recorder

struct KeyRecorderView: NSViewRepresentable {
    let onRecord: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        context.coordinator.start(onRecord: onRecord)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.stop() }
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var globalMonitor: Any?
        var localMonitor: Any?

        func start(onRecord: @escaping (String) -> Void) {
            let handler: (NSEvent) -> Void = { event in
                guard ![55, 56, 58, 59, 54, 60, 61, 62].contains(event.keyCode) else { return }
                var parts = [String]()
                if event.modifierFlags.contains(.control) { parts.append("ctrl") }
                if event.modifierFlags.contains(.option) { parts.append("opt") }
                if event.modifierFlags.contains(.shift) { parts.append("shift") }
                if event.modifierFlags.contains(.command) { parts.append("cmd") }
                parts.append(String(event.keyCode))
                DispatchQueue.main.async { onRecord(parts.joined(separator: "+")) }
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in handler(event); return nil }
        }

        func stop() {
            if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
            if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        }
    }
}
