# XP-Pen ACK05 Remote for macOS

A native macOS menubar app for the [XP-Pen ACK05 Wireless Shortcut Remote](https://www.amazon.com/ACK05-Wireless-Bluetooth-Programmable-Customized/dp/B0BVW3S1QR). Map any of the 11 buttons and scroll wheel to keyboard shortcuts, media controls, volume, or shell commands — over **USB or Bluetooth**.

> **This project is not associated with XP-Pen in any way.**

<img width="1056" height="1191" alt="image" src="https://github.com/user-attachments/assets/857ffaa0-bcd3-40df-8be6-d8aff0f11d75" />


## Features

- **USB + Bluetooth** — works with the 2.4GHz USB dongle or Bluetooth Low Energy, auto-detects both
- **11 buttons + scroll wheel** — every input is mappable
- **Press, double-press, and long-press** — each button supports three gesture types
- **Keyboard shortcuts** — record any key combo (⌘⇧K, ⌃Space, etc.)
- **Media controls** — play/pause, next/previous track
- **Volume & mute** — scroll wheel as a volume knob
- **Shell commands** — run anything
- **Visual topology** — interactive diagram of the remote that highlights on press and navigates to button settings
- **Lives in the menubar** — no dock icon, launches at login

## Install

### From GitHub Releases

Download `XP-Pen-Remote-<version>.zip` from [Releases](https://github.com/Jayphen/xp-pen/releases), unzip, and drag to `/Applications`.

Since the app isn't notarized, macOS will block it on first launch. To fix this:

```bash
xattr -cr /Applications/XP-Pen\ Remote.app
```

Or right-click the app and select **Open**.

### Build from source

Requires Swift 5.9+ and macOS 14+.

```bash
git clone https://github.com/Jayphen/xp-pen.git
cd xp-pen/menubar_app
swift build -c release
./scripts/build-app.sh
open build/XP-Pen\ Remote.app
```

## macOS Permissions

Grant these in **System Settings > Privacy & Security**:

| Permission | Why |
|---|---|
| **Input Monitoring** | Reading HID reports from the remote (grant to your terminal or the app) |
| **Accessibility** | Sending keyboard shortcuts and media keys |
| **Bluetooth** | Connecting via BLE (prompted automatically) |

## Run at Login

Copy the built `.app` to `/Applications`, then add it to **System Settings > General > Login Items**.

## Configuration

Button mappings are stored in `~/.config/xp-pen/mappings.json` and persist across restarts.

## Architecture

| Component | Role |
|---|---|
| `menubar_app/` | SwiftUI menubar app with button mapper UI |
| `hid_helper/` | Standalone Swift binary — USB (IOHIDManager) + BLE (CoreBluetooth) |

The device communicates via a vendor-specific HID interface (USB) or a custom BLE service (`FFE0`, characteristic `0003`). Both transports produce identical report formats.

## Attribution

Based on [smartfastlabs/xp-pen](https://github.com/smartfastlabs/xp-pen) by Todd Sifleet.

## License

See [LICENSE](LICENSE).
