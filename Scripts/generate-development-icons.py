#!/usr/bin/env python3
"""Generate the cool-hued Debug icon by rotating saturated colors 180° in HSV."""

from __future__ import annotations

import colorsys
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Jostle/Images.xcassets/AppIcon.appiconset"
DESTINATION = ROOT / "Jostle/Images.xcassets/AppIconDevelopment.appiconset"
SOURCE_COMPOSER = ROOT / "Jostle/AppIcon.icon"
DESTINATION_COMPOSER = ROOT / "Jostle/AppIconDevelopment.icon"


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


def complement_srgb(value: str) -> str:
    prefix = "srgb:"
    if not value.startswith(prefix):
        return value
    components = [float(component) for component in value.removeprefix(prefix).split(",")]
    if len(components) != 4:
        return value
    pixel = tuple(round(component * 255) for component in components)
    transformed = complement(pixel)
    return prefix + ",".join(f"{component / 255:.5f}" for component in transformed)


def complement_document(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: complement_document(item) for key, item in value.items()}
    if isinstance(value, list):
        return [complement_document(item) for item in value]
    if isinstance(value, str):
        return complement_srgb(value)
    return value


def transform_icon_composer_source() -> None:
    if DESTINATION_COMPOSER.exists():
        shutil.rmtree(DESTINATION_COMPOSER)
    shutil.copytree(SOURCE_COMPOSER, DESTINATION_COMPOSER)
    source_document = json.loads((SOURCE_COMPOSER / "icon.json").read_text())
    (DESTINATION_COMPOSER / "icon.json").write_text(
        json.dumps(complement_document(source_document), indent=2) + "\n"
    )


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

    transform_icon_composer_source()


if __name__ == "__main__":
    main()
