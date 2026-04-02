import Foundation
import CoreBluetooth
import IOKit.hid

// --- Shared output ---

let vendorID = 0x28BD
let productID = 0x0202

func emitReport(_ data: [UInt8]) {
    guard data.count >= 8 else { return }
    // Skip status/battery reports (0xF2 = 242)
    if data[1] == 242 { return }
    // Only process button/scroll reports (0xF0 = 240)
    guard data[1] == 240 else { return }

    let button = Int(data[2])
    let scroll = Int(data[7])
    print("\(button),\(scroll)")
    fflush(stdout)
}

// --- USB via IOHIDManager ---

var usbBuffers = [UnsafeMutablePointer<UInt8>]()

func usbReportHandler(_ context: UnsafeMutableRawPointer?, _ result: IOReturn, _ sender: UnsafeMutableRawPointer?, _ type: IOHIDReportType, _ reportID: UInt32, _ report: UnsafeMutablePointer<UInt8>, _ length: CFIndex) {
    var bytes = [UInt8]()
    for i in 0..<length { bytes.append(report[i]) }
    emitReport(bytes)
}

func setupUSBDevice(_ device: IOHIDDevice) {
    let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "?"
    fputs("usb: connected (\(transport))\n", stderr)

    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))

    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    usbBuffers.append(buf)
    IOHIDDeviceRegisterInputReportCallback(device, buf, 64, usbReportHandler, nil)
}

func startUSB() {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: NSDictionary = [
        kIOHIDVendorIDKey: vendorID,
        kIOHIDProductIDKey: productID,
    ]
    IOHIDManagerSetDeviceMatching(manager, matching)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard opened == kIOReturnSuccess else {
        fputs("usb: failed to open manager\n", stderr)
        return
    }

    if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
        for device in devices { setupUSBDevice(device) }
    }

    IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, device in
        setupUSBDevice(device)
    }, nil)

    IOHIDManagerRegisterDeviceRemovalCallback(manager, { _, _, _, _ in
        fputs("usb: disconnected\n", stderr)
    }, nil)
}

// --- BLE via CoreBluetooth ---

let serviceUUID = CBUUID(string: "FFE0")
let notifyChar = CBUUID(string: "0003")

class BLEDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var central: CBCentralManager!
    var peripheral: CBPeripheral?

    func start() {
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }

        // Check for already-connected peripherals first
        let connected = central.retrieveConnectedPeripherals(withServices: [serviceUUID])
        if let first = connected.first {
            fputs("ble: found connected peripheral: \(first.name ?? "?")\n", stderr)
            self.peripheral = first
            first.delegate = self
            central.connect(first, options: nil)
            return
        }

        // Also try HID over GATT service
        let hogp = central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "1812")])
        if let first = hogp.first {
            fputs("ble: found HOGP peripheral: \(first.name ?? "?")\n", stderr)
            self.peripheral = first
            first.delegate = self
            central.connect(first, options: nil)
            return
        }

        fputs("ble: scanning...\n", stderr)
        central.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        fputs("ble: discovered \(peripheral.name ?? "?")\n", stderr)
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        fputs("ble: connected\n", stderr)
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        fputs("ble: disconnected, reconnecting...\n", stderr)
        self.peripheral = nil
        // Restart scan after disconnect
        if central.state == .poweredOn {
            centralManagerDidUpdateState(central)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([notifyChar], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
                fputs("ble: subscribed to \(char.uuid)\n", stderr)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        emitReport([UInt8](data))
    }
}

// --- Main ---

startUSB()

let ble = BLEDelegate()
ble.start()

fputs("ready\n", stderr)
CFRunLoopRun()
