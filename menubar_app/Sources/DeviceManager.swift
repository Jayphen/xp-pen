import Foundation
import CoreBluetooth
import IOKit.hid
import Combine

struct ButtonEvent: Equatable {
    let signature: [UInt8]
    let timestamp: Date

    var isRelease: Bool { signature.allSatisfy { $0 == 0 } }
    var isScroll: Bool { signature[5] != 0 }

    var key: String {
        if signature[5] == 1 { return "scroll_cw" }
        if signature[5] == 2 { return "scroll_ccw" }
        if isRelease { return "release" }
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    static func == (lhs: ButtonEvent, rhs: ButtonEvent) -> Bool {
        lhs.signature == rhs.signature
    }
}

struct ButtonMapping: Codable {
    let key: String
    var label: String
    var actionType: String
    var shellCommand: String?
    var keyCombo: String?
}

struct ButtonDef {
    let key: String
    let label: String
}

let allButtons: [ButtonDef] = [
    ButtonDef(key: "000400000000", label: "Scroll Button"),
    ButtonDef(key: "010000000000", label: "Top-Left"),
    ButtonDef(key: "020000000000", label: "Top-Middle"),
    ButtonDef(key: "040000000000", label: "Top-Right"),
    ButtonDef(key: "400000000000", label: "Right"),
    ButtonDef(key: "080000000000", label: "Middle-Left"),
    ButtonDef(key: "100000000000", label: "Middle-Center"),
    ButtonDef(key: "200000000000", label: "Middle-Right"),
    ButtonDef(key: "800000000000", label: "Bottom-Left"),
    ButtonDef(key: "000100000000", label: "Bottom-Center"),
    ButtonDef(key: "000200000000", label: "Bottom-Right"),
    ButtonDef(key: "scroll_cw",    label: "Scroll Clockwise"),
    ButtonDef(key: "scroll_ccw",   label: "Scroll Counter-CW"),
]

/// Suffix added to button key for each gesture type
enum Gesture: String, CaseIterable {
    case press = ""
    case doublePress = ":double"
    case longPress = ":long"

    var label: String {
        switch self {
        case .press: return "Press"
        case .doublePress: return "Double Press"
        case .longPress: return "Long Press"
        }
    }
}

class DeviceManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var transport = ""
    private var usbConnected = false
    private var bleConnected = false

    private func updateConnectionStatus() {
        DispatchQueue.main.async {
            self.isConnected = self.usbConnected || self.bleConnected
            if self.bleConnected && self.usbConnected {
                self.transport = "USB + Bluetooth"
            } else if self.bleConnected {
                self.transport = "Bluetooth"
            } else if self.usbConnected {
                self.transport = "USB"
            } else {
                self.transport = ""
            }
        }
    }
    @Published var lastEvent: ButtonEvent?
    @Published var activeKey: String = ""
    @Published var lastGesture: String = ""
    private var activeKeyTimer: DispatchWorkItem?
    @Published var mappings: [String: ButtonMapping] = [:] {
        didSet { saveMappings() }
    }

    // Gesture detection state
    private var currentButtonKey: String?
    private var buttonDownTime: Date?
    private var lastPressKey: String?
    private var lastPressTime: Date?
    private var longPressTimer: DispatchWorkItem?
    private var doublePressTimer: DispatchWorkItem?

    private var central: CBCentralManager?
    private var blePeripheral: CBPeripheral?
    private var usbBuffers = [UnsafeMutablePointer<UInt8>]()
    private let vendorID = 0x28BD
    private let productID = 0x0202
    private let serviceUUID = CBUUID(string: "FFE0")
    private let charUUID = CBUUID(string: "0003")
    private var flushUntil: Date = .distantFuture

    override init() {
        super.init()
        loadMappings()
        startUSB()
        central = CBCentralManager(delegate: self, queue: nil)
        flushUntil = Date().addingTimeInterval(0.5)
    }

    // MARK: - Event handling

    func handleReport(_ data: [UInt8]) {
        guard data.count >= 8, data[1] == 240 else { return }
        if Date() < flushUntil { return }

        let sig = Array(data[2..<8])
        let event = ButtonEvent(signature: sig, timestamp: Date())

        DispatchQueue.main.async {
            self.lastEvent = event

            if !event.isRelease {
                // Set active key and keep it visible
                self.activeKeyTimer?.cancel()
                self.activeKey = event.key
            } else {
                // Clear active key after a short delay so highlight is visible
                let timer = DispatchWorkItem { self.activeKey = "" }
                self.activeKeyTimer = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: timer)
            }
        }

        // Scroll events fire immediately, no gesture detection
        if event.isScroll {
            fireAction(event.key)
            return
        }

        if event.isRelease {
            handleRelease()
        } else {
            handleDown(event)
        }
    }

    private func handleDown(_ event: ButtonEvent) {
        let key = event.key
        currentButtonKey = key
        buttonDownTime = Date()

        // Cancel any pending long press from a previous button
        longPressTimer?.cancel()

        // Schedule long press detection (0.5s)
        let timer = DispatchWorkItem { [weak self] in
            guard let self = self, self.currentButtonKey == key else { return }
            self.doublePressTimer?.cancel()
            self.doublePressTimer = nil
            self.lastPressKey = nil
            self.fireAction(key + Gesture.longPress.rawValue)
        }
        longPressTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: timer)
    }

    private func handleRelease() {
        longPressTimer?.cancel()
        longPressTimer = nil

        guard let key = currentButtonKey,
              let downTime = buttonDownTime else {
            currentButtonKey = nil
            return
        }

        let held = Date().timeIntervalSince(downTime)
        currentButtonKey = nil
        buttonDownTime = nil

        // If held long enough, long press already fired
        if held >= 0.5 { return }

        // Check for double press
        if let lastKey = lastPressKey,
           let lastTime = lastPressTime,
           lastKey == key,
           Date().timeIntervalSince(lastTime) < 0.4 {
            // Double press
            doublePressTimer?.cancel()
            doublePressTimer = nil
            lastPressKey = nil
            lastPressTime = nil
            fireAction(key + Gesture.doublePress.rawValue)
            return
        }

        // Record this press and wait briefly for a possible double press
        lastPressKey = key
        lastPressTime = Date()

        doublePressTimer?.cancel()
        let timer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lastPressKey = nil
            self.lastPressTime = nil
            self.fireAction(key + Gesture.press.rawValue)
        }
        doublePressTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: timer)
    }

    private func fireAction(_ fullKey: String) {
        DispatchQueue.main.async {
            self.lastGesture = fullKey
        }
        if let mapping = mappings[fullKey],
           let action = Action.fromMapping(mapping) {
            action.execute()
        }
    }

    func labelFor(key: String) -> String {
        allButtons.first { $0.key == key }?.label ?? key
    }

    // MARK: - Persistence

    private let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("xp-pen")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mappings.json")
    }()

    private func saveMappings() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(mappings) {
            try? data.write(to: configURL)
        }
    }

    private func loadMappings() {
        guard let data = try? Data(contentsOf: configURL),
              let loaded = try? JSONDecoder().decode([String: ButtonMapping].self, from: data)
        else { return }
        mappings = loaded
    }

    // MARK: - USB

    private func startUSB() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: NSDictionary = [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDProductIDKey: productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            for device in devices { setupUSBDevice(device) }
        }

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            Unmanaged<DeviceManager>.fromOpaque(ctx!).takeUnretainedValue().setupUSBDevice(device)
        }, ctx)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, _ in
            let mgr = Unmanaged<DeviceManager>.fromOpaque(ctx!).takeUnretainedValue()
            mgr.usbConnected = false; mgr.updateConnectionStatus()
        }, ctx)
    }

    private func setupUSBDevice(_ device: IOHIDDevice) {
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))

        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        usbBuffers.append(buf)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buf, 64, { ctx, _, _, _, _, report, length in
            let mgr = Unmanaged<DeviceManager>.fromOpaque(ctx!).takeUnretainedValue()
            var bytes = [UInt8]()
            for i in 0..<length { bytes.append(report[i]) }
            mgr.handleReport(bytes)
        }, ctx)

        self.usbConnected = true
        updateConnectionStatus()
    }

    // MARK: - BLE

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [serviceUUID])
        if let first = connected.first {
            blePeripheral = first; first.delegate = self; central.connect(first); return
        }
        let hogp = central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "1812")])
        if let first = hogp.first {
            blePeripheral = first; first.delegate = self; central.connect(first); return
        }
        central.scanForPeripherals(withServices: [serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        blePeripheral = peripheral; peripheral.delegate = self; central.stopScan(); central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
        self.bleConnected = true
        updateConnectionStatus()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        blePeripheral = nil
        self.bleConnected = false
        updateConnectionStatus()
        if central.state == .poweredOn { centralManagerDidUpdateState(central) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] { peripheral.discoverCharacteristics([charUUID], for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            if char.properties.contains(.notify) { peripheral.setNotifyValue(true, for: char) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        handleReport([UInt8](data))
    }
}
