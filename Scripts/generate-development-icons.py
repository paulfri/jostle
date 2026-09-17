#!/usr/bin/env python3
"""Generate the cool-hued Debug icon by rotating saturated colors 180° in HSV."""

from __future__ import annotations

import colorsys
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Jostle/Images.xcassets/AppIcon.appiconset"
DESTINATION = ROOT / "Jostle/Images.xcassets/AppIconDevelopment.appiconset"


def complement(pixel: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    red, green, blue, alpha = pixel
    hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
    if saturation < 0.05:
        return pixel
    red_out, green_out, blue_out = colorsys.hsv_to_rgb(
        (hue + 0.5) % 1.0,
        saturation,
        value,
    )
    return (
        round(red_out * 255),
        round(green_out * 255),
        round(blue_out * 255),
        alpha,
    )


def transform(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    cache: dict[tuple[int, int, int, int], tuple[int, int, int, int]] = {}
    transformed = []
    for pixel in image.get_flattened_data():
        transformed.append(cache.setdefault(pixel, complement(pixel)))
    image.putdata(transformed)
    image.save(destination)


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    contents = json.loads((SOURCE / "Contents.json").read_text())
    (DESTINATION / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    filenames = {
        image["filename"]
        for image in contents["images"]
        if "filename" in image
    }
    for filename in sorted(filenames):
        transform(SOURCE / filename, DESTINATION / filename)


if __name__ == "__main__":
    main()
