#!/usr/bin/env python3
"""
Download Lorenz 2022 light pollution tiles and stitch into a 4K
equirectangular atlas matching the VIIRS projection (75°N to 65°S).

Tiles are 1024px Web Mercator slippy-map PNGs from:
  https://djlorenz.github.io/astronomy/image_tiles/tiles2022/tile_{z}_{x}_{y}.png

Usage:
    python3 tools/build_lorenz_atlas.py

Output:
    assets/lp_lorenz_4k.jpg  (4096×2048, JPEG quality 90)

Requirements:
    pip install Pillow
"""

import math
import urllib.request
import urllib.error
from pathlib import Path

from PIL import Image

# ── Configuration ────────────────────────────────────────────────────────────

# Lorenz tiles are 1024px with zoomOffset=-2 in Leaflet.
# Zoom 3 → 8×8 grid of 1024px tiles = 8192×8192 world (same as z=5 @ 256px).
ZOOM = 3
TILE_SIZE = 1024
N_TILES = 2 ** ZOOM  # 8

# Latitude bounds (must match VIIRS atlas)
LAT_NORTH = 75.0
LAT_SOUTH = -65.0

# Output dimensions
OUT_W = 4096
OUT_H = 2048

TILE_URL = "https://djlorenz.github.io/astronomy/image_tiles/tiles2022/tile_{z}_{x}_{y}.png"

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
TILE_CACHE = SCRIPT_DIR / "lorenz_tiles"
OUTPUT_PATH = PROJECT_DIR / "assets" / "lp_lorenz_4k.jpg"


# ── Web Mercator math ────────────────────────────────────────────────────────

def lat_to_tile_y(lat_deg: float, zoom: int) -> float:
    """Convert latitude (degrees) to fractional tile Y at given zoom."""
    lat_rad = math.radians(lat_deg)
    n = 2 ** zoom
    return (1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n


def lat_to_merc_pixel_y(lat_deg: float, zoom: int) -> float:
    """Convert latitude (degrees) to pixel Y in the full Web Mercator world."""
    return lat_to_tile_y(lat_deg, zoom) * TILE_SIZE


def lon_to_merc_pixel_x(lon_deg: float, zoom: int) -> float:
    """Convert longitude (degrees) to pixel X in the full Web Mercator world."""
    n = 2 ** zoom
    return (lon_deg + 180.0) / 360.0 * n * TILE_SIZE


# ── Tile download ────────────────────────────────────────────────────────────

def download_tile(x: int, y: int) -> Path:
    """Download a single tile, caching to disk."""
    TILE_CACHE.mkdir(parents=True, exist_ok=True)
    cached = TILE_CACHE / f"tile_{ZOOM}_{x}_{y}.png"
    if cached.exists() and cached.stat().st_size > 1000:
        return cached

    url = TILE_URL.format(z=ZOOM, x=x, y=y)
    try:
        urllib.request.urlretrieve(url, str(cached))
    except urllib.error.HTTPError as e:
        # Some tiles over ocean may 404 — create transparent placeholder
        print(f"  [WARN] {url} → {e.code}, using blank tile")
        blank = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
        blank.save(str(cached))
    return cached


# ── Main pipeline ────────────────────────────────────────────────────────────

def main():
    # Determine tile row range covering our latitude bounds
    y_top = int(math.floor(lat_to_tile_y(LAT_NORTH, ZOOM)))
    y_bot = int(math.floor(lat_to_tile_y(LAT_SOUTH, ZOOM)))
    y_top = max(0, y_top)
    y_bot = min(N_TILES - 1, y_bot)

    n_rows = y_bot - y_top + 1
    n_cols = N_TILES
    total_tiles = n_rows * n_cols
    print(f"Zoom {ZOOM}: tile rows {y_top}–{y_bot} ({n_rows} rows × {n_cols} cols = {total_tiles} tiles)")

    # 1) Download all tiles
    print("Downloading tiles...")
    downloaded = 0
    for ty in range(y_top, y_bot + 1):
        for tx in range(n_cols):
            download_tile(tx, ty)
            downloaded += 1
            print(f"  {downloaded}/{total_tiles}")

    # 2) Stitch into a single Web Mercator strip
    stitch_w = n_cols * TILE_SIZE
    stitch_h = n_rows * TILE_SIZE
    print(f"Stitching {stitch_w}×{stitch_h} Mercator strip...")
    mercator = Image.new("RGBA", (stitch_w, stitch_h), (0, 0, 0, 0))

    for ty in range(y_top, y_bot + 1):
        for tx in range(n_cols):
            tile_path = TILE_CACHE / f"tile_{ZOOM}_{tx}_{ty}.png"
            tile_img = Image.open(tile_path)
            px = tx * TILE_SIZE
            py = (ty - y_top) * TILE_SIZE
            mercator.paste(tile_img, (px, py))
            tile_img.close()

    # Pixel Y offset for the top of our stitched image in the full Mercator world
    merc_y_offset = y_top * TILE_SIZE

    # 3) Re-project to equirectangular
    print(f"Re-projecting to {OUT_W}×{OUT_H} equirectangular...")
    output = Image.new("RGB", (OUT_W, OUT_H), (0, 0, 0))
    merc_pixels = mercator.load()
    out_pixels = output.load()

    for row in range(OUT_H):
        lat = LAT_NORTH - row * (LAT_NORTH - LAT_SOUTH) / OUT_H
        merc_y_world = lat_to_merc_pixel_y(lat, ZOOM)
        merc_y_local = merc_y_world - merc_y_offset

        if merc_y_local < 0 or merc_y_local >= stitch_h:
            continue

        for col in range(OUT_W):
            lon = -180.0 + col * 360.0 / OUT_W
            merc_x = lon_to_merc_pixel_x(lon, ZOOM)
            merc_x = merc_x % stitch_w

            sx = int(merc_x) % stitch_w
            sy = int(merc_y_local)
            if sy < 0 or sy >= stitch_h:
                continue

            r, g, b, a = merc_pixels[sx, sy]
            if a > 0:
                af = a / 255.0
                out_pixels[col, row] = (
                    int(r * af),
                    int(g * af),
                    int(b * af),
                )

        if (row + 1) % 256 == 0 or row == OUT_H - 1:
            print(f"  row {row + 1}/{OUT_H}")

    mercator.close()

    # 4) Save output
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.save(str(OUTPUT_PATH), "JPEG", quality=90)
    output.close()
    print(f"Done → {OUTPUT_PATH} ({OUTPUT_PATH.stat().st_size / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
