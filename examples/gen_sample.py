#!/usr/bin/env python3
"""Write examples/sample.png — a synthetic red cube on a floor (stdlib only)."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

WIDTH, HEIGHT = 640, 480


def _chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    raw = b""
    row_bytes = width * 3
    for y in range(height):
        raw += b"\x00" + rgb[y * row_bytes : (y + 1) * row_bytes]
    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(raw, 9))
    png += _chunk(b"IEND", b"")
    path.write_bytes(png)


def render() -> bytes:
    pixels = bytearray(WIDTH * HEIGHT * 3)
    horizon = int(HEIGHT * 0.55)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            i = (y * WIDTH + x) * 3
            if y < horizon:
                pixels[i : i + 3] = bytes((210, 205, 195))
            else:
                t = (y - horizon) / max(1, HEIGHT - horizon)
                g = int(90 + 50 * t)
                pixels[i : i + 3] = bytes((g, g, g + 8))

    # Red cube in the lower-center of the frame (Grounded-SAM prompt: "red cube.")
    cx, cy = WIDTH // 2, int(HEIGHT * 0.62)
    half = 70
    for y in range(cy - half, cy + half):
        for x in range(cx - half, cx + half):
            if 0 <= x < WIDTH and 0 <= y < HEIGHT:
                i = (y * WIDTH + x) * 3
                shade = 40 if x - (cx - half) < 18 or y - (cy - half) < 18 else 0
                pixels[i] = 200 - shade
                pixels[i + 1] = 40 - shade // 4
                pixels[i + 2] = 40 - shade // 4
    return bytes(pixels)


def main() -> None:
    out = Path(__file__).resolve().parent / "sample.png"
    write_png(out, WIDTH, HEIGHT, render())
    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
