#!/usr/bin/env python3
"""Build pixel-exact BLP2 texture mirrors for every Arcane TGA asset.

Azeroth Survivors' browser/mac clients can skip addon TGAs. Its desktop
client and Arcane's existing art already use BLP2 raw BGRA (encoding 3,
8-bit alpha); mirroring that exact format preserves all RGBA pixels and
keeps TGA files available as fallback without changing Lua paths.

This script runs after any source TGA art generators and before ZIP packaging.
"""
from __future__ import annotations

import argparse
import io
import struct
from pathlib import Path

from PIL import Image

MAGIC = b"BLP2"
PIXEL_OFFSET = 4 + 4 + 4 + 4 + 4 + 16*4 + 16*4 + 256*4  # 1172
HEADER = struct.Struct("<4sI4BII")


def blp_bytes(source: bytes, name: str) -> tuple[bytes, int, int]:
    with Image.open(io.BytesIO(source)) as image:
        width, height = image.size
        if width <= 0 or height <= 0 or width & (width - 1) or height & (height - 1):
            raise ValueError(f"{name}: BLP texture dimensions must be powers of two, got {width}x{height}")
        rgba = image.convert("RGBA")
        bgra = rgba.tobytes("raw", "BGRA")
        # BLP2: image compression = 1, encoding = 3 (raw BGRA), alpha = 8-bit,
        # alpha type = 8 (matching Arcane's already-shipped uncompressed BLPs),
        # no mipmaps. Palette block is unused in this format but reserved.
        header = HEADER.pack(MAGIC, 1, 3, 8, 8, 0, width, height)
        offsets = struct.pack("<16I", PIXEL_OFFSET, *([0] * 15))
        sizes = struct.pack("<16I", len(bgra), *([0] * 15))
        result = header + offsets + sizes + bytes(256 * 4) + bgra
        assert len(result) == PIXEL_OFFSET + 4 * width * height
        # Validate every component including orientation and all alpha bytes.
        assert result[PIXEL_OFFSET:] == rgba.tobytes("raw", "BGRA")
        return result, width, height


def run(root: Path, verify_only: bool) -> int:
    roots = (root / "Art", root / "Themes")
    tgas = sorted(path for parent in roots if parent.is_dir()
                  for path in parent.rglob("*.tga") if path.is_file())
    if not tgas:
        raise SystemExit("FAIL: no TGA artwork found to convert")
    total_bytes = 0
    for tga in tgas:
        blp, width, height = blp_bytes(tga.read_bytes(), tga.relative_to(root).as_posix())
        out = tga.with_suffix(".blp")
        if verify_only:
            if not out.is_file() or out.read_bytes() != blp:
                raise SystemExit(f"FAIL: BLP missing or stale: {out.relative_to(root)}")
        else:
            if not out.exists() or out.read_bytes() != blp:
                out.write_bytes(blp)
        total_bytes += len(blp)
        print(f"{'CHECK' if verify_only else 'BLP2'} {tga.relative_to(root)} -> {out.relative_to(root)} ({width}x{height})")
    print(f"PASS: {len(tgas)} pixel-identical BLP2 mirrors ({total_bytes:,} uncompressed bytes), all TGA originals retained")
    return len(tgas)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--check', action='store_true', help='verify BLPs exactly match their TGA sources')
    args = parser.parse_args()
    run(args.root, args.check)
