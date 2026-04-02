***THIS REPOSITORY IS NOT ASSOCIATED WITH XP-PEN IN ANY WAY***
--------------------------------------------------------------

Summary:
--------
A Python library for the [XP Pen ACK05 Wireless Shortcut Remote](https://www.amazon.com/ACK05-Wireless-Bluetooth-Programmable-Customized/dp/B0BVW3S1QR). Maps remote key presses to async Python callbacks — use it to control Home Assistant, trigger scripts, or run arbitrary code.

Supports both **USB dongle** and **Bluetooth** on macOS.

<img width="1718" alt="image" src="https://github.com/user-attachments/assets/c1cb42a7-918b-4efb-ba70-b09ce3c78fda">

Requirements:
-------------
- macOS 12+
- Python 3.11+
- Swift 5.9+ (to build the HID helper)

Installation:
-------------

```bash
# Clone the repo
git clone https://github.com/Jayphen/xp-pen.git
cd xp-pen

# Build the Swift HID helper
cd hid_helper && swift build -c release && cd ..

# Install the Python package
pip install -e .
```

### macOS Permissions

The HID helper needs the following macOS permissions (System Settings > Privacy & Security):

- **Input Monitoring** — grant to your terminal app (Ghostty, Terminal, iTerm, etc.)
- **Accessibility** — may be required for some configurations
- **Bluetooth** — if using Bluetooth, allow when prompted

Usage:
--------------

The remote works over **USB dongle** or **Bluetooth** — the library auto-detects whichever is connected.

See [examples](examples/) for full usage.

```python
import asyncio
from xp_pen import Event, XPPenClient

async def on_event(event: Event):
    print(f"[XP Pen] EVENT: {event.method}:{event.value}")

client = XPPenClient(on_event)
asyncio.run(client.start())
```

There are 5 *methods* an event can have:

- `down`
- `up`
- `scroll`
- `double-down` (press within 0.5 seconds of the previous)
- `long-down` (held for more than 0.5 seconds)

Every event has a `value` — for buttons this is a numeric string, for scroll it's `clockwise` or `counter-clockwise`.

Architecture:
-------------

The library uses a small Swift helper binary (`hid_helper/`) that handles low-level device communication:

- **USB**: Uses `IOHIDManager` to read HID reports from the dongle
- **Bluetooth**: Uses `CoreBluetooth` to connect to the device's custom BLE service (`FFE0`) and subscribe to notifications

Both transports output the same data format. The Python library spawns the helper as a subprocess and processes its output into events.

Attribution:
------------
Based on [smartfastlabs/xp-pen](https://github.com/smartfastlabs/xp-pen) by Todd Sifleet. The original library used `pyusb` for USB-only support. This fork replaces it with a Swift helper for native macOS USB + Bluetooth support.

License:
--------
See LICENSE
