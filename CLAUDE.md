# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Python library + Swift helper for the XP-Pen ACK05 Wireless Shortcut Remote. Captures button presses via USB dongle or Bluetooth on macOS and dispatches them as async Python events.

## Development Commands

```bash
# Build the Swift HID helper (required before running)
cd hid_helper && swift build -c release && cd ..

# Install Python package in editable mode
pip install -e .

# Run the basic example
python examples/basic.py
```

No automated tests — validated through manual testing with the physical device.

## Architecture

### Swift HID Helper (`hid_helper/Sources/main.swift`)

A standalone macOS binary that handles device communication over two transports simultaneously:

- **USB**: `IOHIDManager` reads raw HID reports from the USB dongle (vendor-specific interface, usagePage=65290)
- **Bluetooth**: `CoreBluetooth` connects to the device's custom BLE service `FFE0`, subscribes to characteristic `0003` for notifications

Both transports produce the same raw report format: `[2, 240, button, 0, 0, 0, 0, scroll, 0, 0]`. The helper extracts `button` and `scroll` values and writes `button,scroll` lines to stdout. Status messages go to stderr.

Reports with byte[1]=242 (0xF2) are battery/status reports and are filtered out.

### Python Library (`xp_pen/__init__.py`)

`XPPenClient` spawns the Swift helper as a subprocess and reads its stdout:

1. **Startup**: Waits for "ready" on stderr, then flushes stale buffered messages
2. **Button mapping**: `_map_button()` converts raw values — scroll byte 1/2 becomes clockwise/counter-clockwise, button byte has bit 4 stripped (touch/proximity flag)
3. **Event processing**: Same logic as original — detects down/up/double-down/long-down/scroll from the stream of mapped values
4. **Reconnection**: If the helper dies, waits 5 seconds and restarts

The helper binary path defaults to `hid_helper/.build/release/hid_helper` relative to the package root. Can be overridden via `hid_helper_path` parameter.

### Event Model

- `value`: Button identifier (string) or scroll direction (`clockwise`/`counter-clockwise`)
- `method`: `down`, `up`, `scroll`, `double-down` (within 0.5s), `long-down` (held >0.5s)

### macOS Permissions

The helper requires **Input Monitoring** permission granted to the terminal app. Bluetooth also requires the standard Bluetooth permission prompt.

## Key Constraints

- **macOS only** — the Swift helper uses IOKit and CoreBluetooth (Apple frameworks)
- **No pyusb dependency** — the Swift helper replaces the previous pyusb-based USB approach
- **VendorID/ProductID**: Hardcoded to `0x28BD:0x0202` (XP-Pen ACK05)
- **BLE Service**: Custom service UUID `FFE0`, notify characteristic `0003`
