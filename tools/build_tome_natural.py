#!/usr/bin/env python3
"""Build the unified DEV book skin without altering Controller's original Tome.

Keep all source ornament and silhouette pixels. Replace the blue/cyan hue in
leather, gems, ribbon, and engravings with natural brown and honeyed amber.
A deterministic TGA can then be mirrored to browser-compatible BLP2 by
build_browser_blp.py in the normal artwork pipeline.
"""
from __future__ import annotations

import argparse
import colorsys
import io
from pathlib import Path
from PIL import Image


def make_tome(source: Path) -> bytes:
    with Image.open(source) as input_image:
        original = input_image.convert("RGBA")
    if original.size != (256, 256):
        raise ValueError("Tome art changed size: expected the original 256x256")
    data = []
    recolored = 0
    for r, g, b, a in original.getdata():
        if a:
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            # Gold trim and neutral parchment remain untouched. Only the
            # blue/cyan paint changes, preserving the original shadows,
            # engravings, alpha contour and every non-blue pixel.
            if .47 < h < .77 and s > .11 and b > r * 1.09:
                hue = .076 if v < .65 else .102
                saturation = .68 if v < .65 else .75
                value = min(1.0, v * 1.035 + .015)
                x, y, z = colorsys.hsv_to_rgb(hue, saturation, value)
                r, g, b = (int(255 * c + .5) for c in (x, y, z))
                recolored += 1
        data.append((r, g, b, a))

    if recolored < 1000:
        raise ValueError(f"Expected blue leather pixels not found; only {recolored} recolored")
    converted = Image.new("RGBA", original.size)
    converted.putdata(data)
    if converted.getchannel("A").tobytes() != original.getchannel("A").tobytes():
        raise ValueError("Changed Tome silhouette or transparency")
    buffer = io.BytesIO()
    converted.save(buffer, format="TGA", compression="tga_rle")
    return buffer.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    art = Path(__file__).resolve().parents[1] / "Themes" / "Controller" / "Art"
    source, dest = art / "Tome.tga", art / "TomeNatural.tga"
    result = make_tome(source)
    if args.check:
        if not dest.is_file() or dest.read_bytes() != result:
            raise SystemExit("FAIL: TomeNatural.tga missing or not generated from the original")
        print("PASS: natural leather and gold tome is deterministic")
    else:
        dest.write_bytes(result)
        print(f"Built {dest.name} from existing Tome.tga; original untouched")


if __name__ == "__main__":
    main()
