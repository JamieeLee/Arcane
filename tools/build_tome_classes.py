#!/usr/bin/env python3
"""Build nine class-colored level-up books from the neutral leather-and-gold Tome.

Only the central faceted jewel and the bookmark's inset take a class color.
Colors are read from the existing SkillBar/StylesData.lua palette. The original
blue and neutral books, geometry, bronze trim and alpha remain untouched.
The existing BLP2 mirror pipeline converts all generated TGAs for both clients.
"""
from __future__ import annotations
import argparse
import io
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

CLASSES = ("warrior", "paladin", "hunter", "rogue", "priest",
           "shaman", "mage", "warlock", "druid")


def palette(root: Path) -> dict[str, tuple[int, int, int]]:
    text = (root / "SkillBar" / "StylesData.lua").read_text(encoding="utf-8")
    found = {}
    for name in CLASSES:
        section = re.search(r"\n\s*" + name + r"\s*=\s*\{(.*?)\n\s*\},", text, re.S)
        if not section:
            raise ValueError(f"No canonical class palette for {name}")
        match = re.search(
            r"\bgem\s*=\s*\{\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)\s*\}",
            section.group(1))
        if not match:
            raise ValueError(f"No class gem for {name}")
        values = tuple(float(x) for x in match.groups())
        if any(not 0 <= v <= 1 for v in values):
            raise ValueError(f"Invalid class gem for {name}")
        found[name] = tuple(round(v * 255) for v in values)
    return found


def shade(color: tuple[int, int, int], multiplier: float) -> tuple[int, int, int]:
    return tuple(min(255, max(0, round(value * multiplier))) for value in color)


def make_variant(source: Image.Image, color: tuple[int, int, int]) -> bytes:
    if source.size != (256, 256):
        raise ValueError("Book source must remain 256x256")
    result = source.copy().convert("RGBA")
    ribbon = Image.new("L", source.size, 0)
    ImageDraw.Draw(ribbon).polygon(
        [(103, 184), (120, 185), (121, 219), (111, 210), (103, 230)], fill=145)
    ribbon = ribbon.filter(ImageFilter.GaussianBlur(1.2))
    original = source.convert("RGBA")
    tinted = Image.new("RGBA", source.size)
    data = []
    for r, g, b, a in original.getdata():
        y = (0.25*r + 0.65*g + 0.10*b) / 255
        target = shade(color, 0.28 + 0.44 * y)
        data.append((round(r * 0.35 + target[0] * 0.65),
                     round(g * 0.35 + target[1] * 0.65),
                     round(b * 0.35 + target[2] * 0.65), a))
    tinted.putdata(data)
    result.paste(tinted, (0, 0), ribbon)

    # Small faceted gem atop the existing compass star. Leave its gold arms
    # visible and keep the original texture silhouette exactly unchanged.
    pen = ImageDraw.Draw(result)
    border = [(137, 87), (147, 97), (137, 108), (127, 98)]
    inner = [(137, 90), (144, 97), (137, 105), (130, 98)]
    pen.polygon(border, fill=(35, 23, 16, 255))
    pen.line(border + [border[0]], fill=(176, 121, 45, 255), width=2)
    pen.polygon(inner, fill=shade(color, 0.78) + (255,))
    pen.polygon([(137, 90), (137, 98), (130, 98)],
                fill=shade(color, 1.20) + (255,))
    pen.polygon([(137, 90), (144, 97), (137, 98)],
                fill=shade(color, 0.89) + (255,))
    pen.polygon([(137, 98), (144, 97), (137, 105)],
                fill=shade(color, 0.53) + (255,))
    pen.line([(132, 96), (136, 92), (137, 92)],
             fill=(247, 239, 214, 220), width=1)
    result.putalpha(source.getchannel("A"))
    if result.getchannel("A").tobytes() != source.getchannel("A").tobytes():
        raise ValueError("Class variant changed original alpha")
    buffer = io.BytesIO()
    result.save(buffer, format="TGA", compression="tga_rle")
    return buffer.getvalue()


def run(root: Path, check: bool) -> None:
    art = root / "Themes" / "Controller" / "Art"
    with Image.open(art / "TomeNatural.tga") as src:
        source = src.convert("RGBA")
    for name, color in palette(root).items():
        target = art / ("TomeNatural" + name.title() + ".tga")
        data = make_variant(source, color)
        if check:
            if not target.is_file() or target.read_bytes() != data:
                raise SystemExit("FAIL: missing or stale class book " + str(target))
        else:
            target.write_bytes(data)
        print(f"{'CHECK' if check else 'BUILT'} {target.relative_to(root)} color={color}")
    print("PASS: nine class-specific books from one natural source")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    run(args.root, args.check)
