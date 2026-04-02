import asyncio
import logging
import os
import sys
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, Awaitable, Callable, Optional
from uuid import UUID, uuid4

VENDOR_ID = 0x28BD
PRODUCT_ID = 0x0202

# Path to the Swift HID helper binary (relative to this file)
HID_HELPER_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "hid_helper",
    ".build",
    "release",
    "hid_helper",
)

logger = logging.getLogger("xp-pen")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)


@dataclass
class Event:
    value: str
    method: str
    uuid: UUID
    timestamp: datetime


class XPPenClient:
    def __init__(
        self,
        on_event: Callable[[Event], Awaitable[Any]],
        hid_helper_path: Optional[str] = None,
        **kwargs,
    ) -> None:
        self._on_event: Callable[[Event], Awaitable[Any]] = on_event
        self._current_event: Optional[Event] = None
        self._hid_helper_path = hid_helper_path or HID_HELPER_PATH

    async def start(self) -> None:
        while True:
            try:
                await self.run()
            except Exception as e:
                logger.info(e)

            await asyncio.sleep(5)

    async def run(self) -> None:
        if not os.path.exists(self._hid_helper_path):
            raise FileNotFoundError(
                f"HID helper not found at {self._hid_helper_path}. "
                "Build it with: cd hid_helper && swift build -c release"
            )

        process = await asyncio.create_subprocess_exec(
            self._hid_helper_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Wait for "ready" on stderr (skip setup lines)
        while True:
            stderr_line = await process.stderr.readline()
            msg = stderr_line.decode().strip()
            logger.info("hid_helper: %s", msg)
            if msg == "ready":
                break

        # Flush stale buffered messages by discarding everything
        # received in the first 0.5 seconds
        flush_until = asyncio.get_event_loop().time() + 0.5
        flushing = True

        try:
            while True:
                line = await process.stdout.readline()
                if not line:
                    break

                line = line.decode().strip()
                if not line:
                    continue

                parts = line.split(",")
                if len(parts) < 2:
                    continue

                button = int(parts[0])
                scroll = int(parts[1])

                if flushing:
                    if asyncio.get_event_loop().time() >= flush_until:
                        flushing = False
                        logger.info("DONE FLUSHING")
                    else:
                        continue

                button_value = self._map_button(button, scroll)

                self._current_event = await self._process_input(button_value)
                if self._current_event:
                    await self._on_event(self._current_event)

        finally:
            process.terminate()
            await process.wait()

    def _map_button(self, button: int, scroll: int) -> str:
        if scroll == 1:
            return "clockwise"
        elif scroll == 2:
            return "counter-clockwise"

        # Strip touch/proximity bit (bit 4) to get button number
        return str(button & 0x0F)

    async def _process_input(self, value: str) -> Optional[Event]:
        method: str = "down"
        event: Optional[Event] = None
        start_time: datetime = datetime.now(UTC)
        if value == "0" and self._current_event and self._current_event.method != "up":
            method = "up"
            value = self._current_event.value
        else:
            if "clockwise" in value:
                method = "scroll"

            elif self._current_event:
                if start_time - timedelta(seconds=0.5) < self._current_event.timestamp:
                    method = "double-down"

        event = Event(
            timestamp=start_time,
            value=value,
            method=method,
            uuid=uuid4(),
        )
        if method not in ("scroll", "up"):
            asyncio.ensure_future(self._check_for_long_press(event))

        if "clockwise" in value and method == "up":
            return

        return event

    async def _check_for_long_press(
        self,
        click: Event,
        delay: float = 0.5,
    ):
        await asyncio.sleep(delay)

        if (
            not self._current_event
            or self._current_event.method == "up"
            or click.uuid != self._current_event.uuid
        ):
            return

        self._current_event.method = "long-down"
        await self._on_event(self._current_event)
