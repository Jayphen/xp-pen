import asyncio
import subprocess

from xp_pen import Event, XPPenClient

_volume = None


def get_volume() -> int:
    global _volume
    if _volume is None:
        result = subprocess.run(
            ["osascript", "-e", "output volume of (get volume settings)"],
            capture_output=True, text=True,
        )
        _volume = int(result.stdout.strip())
    return _volume


def set_volume(delta: int):
    global _volume
    current = get_volume()
    new = max(0, min(100, current + delta))
    if new == current:
        return
    _volume = new
    subprocess.run(["osascript", "-e", f"set volume output volume {new}"])
    print(f"Volume: {new}")


async def on_event(event: Event):
    if event.method == "scroll":
        if event.value == "clockwise":
            set_volume(5)
        elif event.value == "counter-clockwise":
            set_volume(-5)


if __name__ == "__main__":
    client = XPPenClient(on_event)
    asyncio.run(client.start())
