#!/usr/bin/env python3
"""Auto-slice a transparent sprite sheet into individual PNG icons.

Usage:
  python extract_icons.py icon_sheet.png icons/

No background removal — only crops tight bounding boxes around each sprite.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image
import numpy as np

# Row-major order for the Pyre icon sheet (10 icons × 8 rows).
ICON_NAMES: list[str] = [
    "flame",
    "flame_plus",
    "chat",
    "chat_empty",
    "chats",
    "send_outline",
    "send",
    "arrow_left",
    "arrow_right",
    "search",
    "camera",
    "gallery",
    "video",
    "video_flame",
    "mic",
    "mic_muted",
    "phone",
    "video_compact",
    "profile",
    "users",
    "profile_add",
    "users_add",
    "profile_heart",
    "profile_circle",
    "profile_flame",
    "settings",
    "bell",
    "bell_dot",
    "bell_muted",
    "mail",
    "mail_flame",
    "mail_plus",
    "mail_dot",
    "attach",
    "smile",
    "sticker",
    "gif_flame",
    "location",
    "calendar",
    "clock",
    "reply",
    "reply_all",
    "forward",
    "refresh",
    "shuffle",
    "trash",
    "trash_flame",
    "bookmark",
    "bookmark_flame",
    "pin",
    "more",
    "menu",
    "grid",
    "sliders",
    "lock",
    "unlock",
    "eye",
    "eye_off",
    "moon",
    "sun",
    "heart",
    "heart_filled",
    "heart_broken",
    "heart_flame",
    "star",
    "star_filled",
    "thumbs_up",
    "thumbs_down",
    "check",
    "check_double",
    "wifi",
    "wifi_off",
    "signal",
    "battery",
    "battery_low",
    "battery_charging",
    "flame_filled",
    "flame_sparkle",
    "chat_heart",
    "share",
]

ALPHA_THRESHOLD = 16
MIN_SPRITE_PIXELS = 400
PADDING = 4


def _find_sprites(alpha) -> list[tuple[int, int, int, int, int]]:
    height, width = alpha.shape
    mask = alpha > ALPHA_THRESHOLD
    visited = [[False] * width for _ in range(height)]
    sprites: list[tuple[int, int, int, int, int]] = []

    for y in range(height):
        for x in range(width):
            if not mask[y, x] or visited[y][x]:
                continue

            stack = [(x, y)]
            visited[y][x] = True
            min_x = max_x = x
            min_y = max_y = y
            pixels = 0

            while stack:
                cx, cy = stack.pop()
                pixels += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and mask[ny, nx]
                        and not visited[ny][nx]
                    ):
                        visited[ny][nx] = True
                        stack.append((nx, ny))

            if pixels >= MIN_SPRITE_PIXELS:
                sprites.append((min_x, min_y, max_x, max_y, pixels))

    return sprites


def _sort_sprites(sprites: list[tuple[int, int, int, int, int]], rows: int = 8) -> list[tuple[int, int, int, int, int]]:
    if not sprites:
        return sprites

    max_y = max(box[3] for box in sprites)
    row_height = max_y / rows

    def key(box: tuple[int, int, int, int, int]) -> tuple[int, int]:
        min_x, min_y, max_x, max_y, _ = box
        center_y = (min_y + max_y) / 2
        row = int(round(center_y / row_height))
        return (row, min_x)

    return sorted(sprites, key=key)


def extract(sheet_path: Path, out_dir: Path) -> list[dict]:
    image = Image.open(sheet_path).convert("RGBA")
    width, height = image.size
    alpha = np.array(image.getchannel("A"))

    sprites = _sort_sprites(_find_sprites(alpha))
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest: list[dict] = []
    for index, (min_x, min_y, max_x, max_y, pixels) in enumerate(sprites):
        name = ICON_NAMES[index] if index < len(ICON_NAMES) else f"icon_{index:03d}"
        left = max(0, min_x - PADDING)
        top = max(0, min_y - PADDING)
        right = min(width, max_x + PADDING + 1)
        bottom = min(height, max_y + PADDING + 1)

        crop = image.crop((left, top, right, bottom))
        out_path = out_dir / f"{name}.png"
        crop.save(out_path, "PNG")

        manifest.append(
            {
                "name": name,
                "file": out_path.name,
                "index": index,
                "bbox": [min_x, min_y, max_x, max_y],
                "pixels": pixels,
            }
        )

    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python extract_icons.py <icon_sheet.png> <output_dir/>", file=sys.stderr)
        return 1

    sheet_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])

    if not sheet_path.is_file():
        print(f"Missing sheet: {sheet_path}", file=sys.stderr)
        return 1

    manifest = extract(sheet_path, out_dir)
    print(f"Wrote {len(manifest)} icons to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
