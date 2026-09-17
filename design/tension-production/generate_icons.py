#!/usr/bin/env python3
"""Generate Jostle's production Tension app and menu-bar icon assets.

Requires Pillow 10 or newer. Output is deterministic and contains no external
fonts or linked resources. Run from any directory:

    python3 design/tension-production/generate_icons.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
APP_SET = ROOT / "Jostle/Images.xcassets/AppIcon.appiconset"
MENU_SET = ROOT / "Jostle/Images.xcassets/MenuIcon.imageset"

APP_FILES = {
    "icon_16x16.png": 16,
    "icon_16x16@2.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2.png": 1024,
}

APP_CONTENTS = {
    "images": [
        {"filename": "icon_16x16.png", "idiom": "mac", "size": "16x16", "scale": "1x"},
        {"filename": "icon_16x16@2.png", "idiom": "mac", "size": "16x16", "scale": "2x"},
        {"filename": "icon_32x32.png", "idiom": "mac", "size": "32x32", "scale": "1x"},
        {"filename": "icon_32x32@2.png", "idiom": "mac", "size": "32x32", "scale": "2x"},
        {"filename": "icon_128x128.png", "idiom": "mac", "size": "128x128", "scale": "1x"},
        {"filename": "icon_128x128@2.png", "idiom": "mac", "size": "128x128", "scale": "2x"},
        {"filename": "icon_256x256.png", "idiom": "mac", "size": "256x256", "scale": "1x"},
        {"filename": "icon_256x256@2.png", "idiom": "mac", "size": "256x256", "scale": "2x"},
        {"filename": "icon_512x512.png", "idiom": "mac", "size": "512x512", "scale": "1x"},
        {"filename": "icon_512x512@2.png", "idiom": "mac", "size": "512x512", "scale": "2x"},
    ],
    "info": {"author": "xcode", "version": 1},
}

MENU_CONTENTS = {
    "images": [
        {"filename": "menu_icon.png", "idiom": "mac", "scale": "1x"},
        {"filename": "menu_icon@2x.png", "idiom": "mac", "scale": "2x"},
    ],
    "info": {"author": "xcode", "version": 1},
    "properties": {"template-rendering-intent": "template"},
}

APP_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="surface" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#c85834"/>
      <stop offset="0.52" stop-color="#a43a20"/>
      <stop offset="1" stop-color="#76210f"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
      <feGaussianBlur stdDeviation="20"/>
    </filter>
    <filter id="markShadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="12" stdDeviation="10" flood-color="#3c1209" flood-opacity=".32"/>
    </filter>
  </defs>
  <rect x="68" y="82" width="888" height="888" rx="202" fill="#3c1209" opacity=".30" filter="url(#shadow)"/>
  <rect x="56" y="54" width="912" height="912" rx="208" fill="url(#surface)"/>
  <rect x="67" y="65" width="890" height="890" rx="198" fill="none" stroke="#ffe8ce" stroke-opacity=".14" stroke-width="12"/>
  <g fill="none" stroke-linecap="round" stroke-linejoin="round" filter="url(#markShadow)">
    <path d="M280 466V280H466 M558 720H720V558" stroke="#fff1dc" stroke-width="76"/>
    <path d="M340 660L660 340 M304 624L376 696 M624 304L696 376" stroke="#f5b75d" stroke-width="56"/>
  </g>
</svg>
"""

MENU_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
  <g fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M2.25 6V2.25H6 M10 13.75H13.75V10"/>
    <path d="M4.45 11.55L11.55 4.45 M3.25 10.35L5.65 12.75 M10.35 3.25L12.75 5.65"/>
  </g>
</svg>
"""


def rounded_polyline(draw: ImageDraw.ImageDraw, points, fill, width: int) -> None:
    """Draw an open polyline with genuinely round caps and joins."""
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width / 2
    for x, y in points:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)


def diagonal_gradient(size: int, start, middle, end) -> Image.Image:
    """Create a restrained upper-left to lower-right three-stop gradient."""
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1)) if size > 1 else 0
            if t < 0.52:
                u = t / 0.52
                a, b = start, middle
            else:
                u = (t - 0.52) / 0.48
                a, b = middle, end
            pixels[x, y] = tuple(round(a[i] * (1 - u) + b[i] * u) for i in range(4))
    return image


def clear_alpha_fringe(image: Image.Image, cutoff: int) -> Image.Image:
    """Remove sub-visible Lanczos ringing from otherwise transparent padding."""
    alpha = image.getchannel("A").point(lambda value: 0 if value <= cutoff else value)
    image.putalpha(alpha)
    return image


def render_app_icon(size: int) -> Image.Image:
    # Each requested raster is independently rendered at high resolution so
    # the 16 px and 32 px slots receive intentional stroke weights.
    sample = 8 if size <= 64 else 4
    s = size * sample
    k = s / 1024
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    outer = (round(56 * k), round(54 * k), round(968 * k), round(966 * k))
    radius = round(208 * k)
    silhouette = Image.new("L", (s, s), 0)
    ImageDraw.Draw(silhouette).rounded_rectangle(outer, radius=radius, fill=255)

    # Soft footprint shadow, kept inside the canvas and away from transparent
    # outer corners.
    if size >= 32:
        shadow_mask = Image.new("L", (s, s), 0)
        shadow_box = (round(68 * k), round(82 * k), round(956 * k), round(970 * k))
        ImageDraw.Draw(shadow_mask).rounded_rectangle(shadow_box, radius=round(202 * k), fill=120)
        shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(max(1, round(20 * k))))
        shadow = Image.new("RGBA", (s, s), (54, 13, 5, 0))
        shadow.putalpha(shadow_mask)
        image.alpha_composite(shadow)

    surface = diagonal_gradient(s, (200, 88, 52, 255), (164, 58, 32, 255), (118, 33, 15, 255))
    surface.putalpha(silhouette)
    image.alpha_composite(surface)

    # A nearly imperceptible inset highlight gives a native macOS material edge
    # without introducing gloss.
    if size >= 64:
        edge = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        edge_draw = ImageDraw.Draw(edge)
        edge_width = max(1, round(12 * k))
        edge_draw.rounded_rectangle(
            (round(67 * k), round(65 * k), round(957 * k), round(955 * k)),
            radius=round(198 * k),
            outline=(255, 232, 206, 36),
            width=edge_width,
        )
        edge.putalpha(ImageChops.multiply(edge.getchannel("A"), silhouette))
        image.alpha_composite(edge)

    # The mark has two visual weights: structural cream corners and the taut
    # gold gesture. Small raster slots receive optical—not geometric—weight.
    outer_width_px = max(1.45, size * 76 / 1024)
    gold_width_px = max(1.22, size * 56 / 1024)
    outer_width = round(outer_width_px * sample)
    gold_width = round(gold_width_px * sample)

    mark_shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(mark_shadow)
    y_shift = max(sample, round(10 * k))
    outer_paths = [
        [(280 * k, 466 * k + y_shift), (280 * k, 280 * k + y_shift), (466 * k, 280 * k + y_shift)],
        [(558 * k, 720 * k + y_shift), (720 * k, 720 * k + y_shift), (720 * k, 558 * k + y_shift)],
    ]
    gold_paths = [
        [(340 * k, 660 * k + y_shift), (660 * k, 340 * k + y_shift)],
        [(304 * k, 624 * k + y_shift), (376 * k, 696 * k + y_shift)],
        [(624 * k, 304 * k + y_shift), (696 * k, 376 * k + y_shift)],
    ]
    for path in outer_paths:
        rounded_polyline(shadow_draw, path, (57, 15, 7, 100), outer_width)
    for path in gold_paths:
        rounded_polyline(shadow_draw, path, (57, 15, 7, 100), gold_width)
    mark_shadow = mark_shadow.filter(ImageFilter.GaussianBlur(max(1, round(9 * k))))
    image.alpha_composite(mark_shadow)

    mark = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    mark_draw = ImageDraw.Draw(mark)
    outer_paths = [
        [(280 * k, 466 * k), (280 * k, 280 * k), (466 * k, 280 * k)],
        [(558 * k, 720 * k), (720 * k, 720 * k), (720 * k, 558 * k)],
    ]
    gold_paths = [
        [(340 * k, 660 * k), (660 * k, 340 * k)],
        [(304 * k, 624 * k), (376 * k, 696 * k)],
        [(624 * k, 304 * k), (696 * k, 376 * k)],
    ]
    for path in outer_paths:
        rounded_polyline(mark_draw, path, (255, 241, 220, 255), outer_width)
    for path in gold_paths:
        rounded_polyline(mark_draw, path, (245, 183, 93, 255), gold_width)
    mark.putalpha(ImageChops.multiply(mark.getchannel("A"), silhouette))
    image.alpha_composite(mark)

    return clear_alpha_fringe(image.resize((size, size), Image.Resampling.LANCZOS), 1)


def render_menu_icon(size: int) -> Image.Image:
    sample = 12
    s = size * sample
    point_scale = s / 16
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = round(1.5 * point_scale)
    paths = [
        [(2.25 * point_scale, 6 * point_scale), (2.25 * point_scale, 2.25 * point_scale), (6 * point_scale, 2.25 * point_scale)],
        [(10 * point_scale, 13.75 * point_scale), (13.75 * point_scale, 13.75 * point_scale), (13.75 * point_scale, 10 * point_scale)],
        [(4.45 * point_scale, 11.55 * point_scale), (11.55 * point_scale, 4.45 * point_scale)],
        [(3.25 * point_scale, 10.35 * point_scale), (5.65 * point_scale, 12.75 * point_scale)],
        [(10.35 * point_scale, 3.25 * point_scale), (12.75 * point_scale, 5.65 * point_scale)],
    ]
    for path in paths:
        rounded_polyline(draw, path, (0, 0, 0, 255), width)
    return clear_alpha_fringe(image.resize((size, size), Image.Resampling.LANCZOS), 4)


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def main() -> None:
    APP_SET.mkdir(parents=True, exist_ok=True)
    MENU_SET.mkdir(parents=True, exist_ok=True)
    HERE.mkdir(parents=True, exist_ok=True)

    (HERE / "tension-app-icon.svg").write_text(APP_SVG)
    (HERE / "tension-menu-icon.svg").write_text(MENU_SVG)

    for path in APP_SET.glob("*.png"):
        path.unlink()
    for filename, size in APP_FILES.items():
        render_app_icon(size).save(APP_SET / filename, format="PNG", optimize=True)
    write_json(APP_SET / "Contents.json", APP_CONTENTS)

    for path in MENU_SET.glob("*.png"):
        path.unlink()
    render_menu_icon(16).save(MENU_SET / "menu_icon.png", format="PNG", optimize=True)
    render_menu_icon(32).save(MENU_SET / "menu_icon@2x.png", format="PNG", optimize=True)
    write_json(MENU_SET / "Contents.json", MENU_CONTENTS)

    print(f"Generated {len(APP_FILES)} app icon slots and 2 menu icon slots.")


if __name__ == "__main__":
    main()
