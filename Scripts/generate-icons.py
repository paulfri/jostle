#!/usr/bin/env python3
"""Generate Jostle's Calm frame app and menu-bar icon assets."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Jostle/Images.xcassets"
APP_ICON = ASSETS / "AppIcon.appiconset"
MENU_ICON = ASSETS / "MenuIcon.imageset"
ICON_COMPOSER_ICON = ROOT / "Jostle/AppIcon.icon"

TOP = (181, 59, 32, 255)
BOTTOM = (146, 36, 15, 255)
BORDER = (205, 81, 50, 190)
CREAM = (255, 237, 204, 255)
BLACK = (0, 0, 0, 255)

CALM_FRAME_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <g fill="none" stroke="#ffffff" stroke-width="53" stroke-linecap="round" stroke-linejoin="round">
    <path d="M292 438V292H438"/>
    <path d="M586 292H732V438"/>
    <path d="M732 586V732H586"/>
    <path d="M438 732H292V586"/>
  </g>
</svg>
"""


def rounded_line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    width: int,
    fill: tuple[int, int, int, int],
) -> None:
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width / 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)
    for x, y in points[1:-1]:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)


def draw_frame(
    image: Image.Image,
    bounds: tuple[float, float, float, float],
    color: tuple[int, int, int, int],
    line_width: float,
) -> None:
    draw = ImageDraw.Draw(image)
    left, top, right, bottom = bounds
    arm = (right - left) * 0.34
    width = max(1, round(line_width))
    rounded_line(draw, [(left, top + arm), (left, top), (left + arm, top)], width, color)
    rounded_line(draw, [(right - arm, top), (right, top), (right, top + arm)], width, color)
    rounded_line(draw, [(right, bottom - arm), (right, bottom), (right - arm, bottom)], width, color)
    rounded_line(draw, [(left + arm, bottom), (left, bottom), (left, bottom - arm)], width, color)


def vertical_gradient(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    for y in range(size):
        progress = y / max(1, size - 1)
        color = tuple(round(TOP[i] * (1 - progress) + BOTTOM[i] * progress) for i in range(4))
        for x in range(size):
            pixels[x, y] = color
    return image


def render_app_icon(size: int) -> Image.Image:
    scale = 4
    canvas_size = size * scale
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))

    margin = canvas_size * 0.045
    icon_bounds = (margin, margin, canvas_size - margin, canvas_size - margin)
    radius = canvas_size * 0.205

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_offset = canvas_size * 0.018
    shadow_draw.rounded_rectangle(
        (
            icon_bounds[0],
            icon_bounds[1] + shadow_offset,
            icon_bounds[2],
            icon_bounds[3] + shadow_offset,
        ),
        radius=radius,
        fill=(45, 14, 8, 165),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(canvas_size * 0.025))
    canvas.alpha_composite(shadow)

    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(icon_bounds, radius=radius, fill=255)
    gradient = vertical_gradient(canvas_size)
    canvas.alpha_composite(Image.composite(gradient, Image.new("RGBA", canvas.size), mask))

    draw = ImageDraw.Draw(canvas)
    border_inset = canvas_size * 0.018
    draw.rounded_rectangle(
        (
            icon_bounds[0] + border_inset,
            icon_bounds[1] + border_inset,
            icon_bounds[2] - border_inset,
            icon_bounds[3] - border_inset,
        ),
        radius=radius - border_inset,
        outline=BORDER,
        width=max(1, round(canvas_size * 0.012)),
    )

    frame_left = canvas_size * 0.285
    frame_top = canvas_size * 0.285
    frame_right = canvas_size * 0.715
    frame_bottom = canvas_size * 0.715
    draw_frame(
        canvas,
        (frame_left, frame_top, frame_right, frame_bottom),
        CREAM,
        canvas_size * 0.052,
    )

    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def render_menu_icon(size: int) -> Image.Image:
    scale = 8
    canvas_size = size * scale
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    inset = canvas_size * 0.19
    draw_frame(
        canvas,
        (inset, inset, canvas_size - inset, canvas_size - inset),
        BLACK,
        canvas_size * 0.095,
    )
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def app_icon_sizes() -> dict[str, int]:
    contents = json.loads((APP_ICON / "Contents.json").read_text())
    result: dict[str, int] = {}
    for item in contents["images"]:
        filename = item.get("filename")
        if not filename:
            continue
        points = int(item["size"].split("x", 1)[0])
        scale = int(item["scale"].removesuffix("x"))
        result[filename] = points * scale
    return result


def srgb(color: tuple[int, int, int, int]) -> str:
    return "srgb:" + ",".join(f"{component / 255:.5f}" for component in color)


def write_icon_composer_source() -> None:
    assets = ICON_COMPOSER_ICON / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    document = {
        "fill-specializations": [
            {"value": {"linear-gradient": [srgb(TOP), srgb(BOTTOM)]}},
        ],
        "groups": [
            {
                "blur-material": None,
                "layers": [
                    {
                        "glass": True,
                        "image-name": "CalmFrame.svg",
                        "name": "Calm Frame",
                        "fill-specializations": [
                            {"value": {"solid": srgb(CREAM)}},
                        ],
                    },
                ],
                "name": "Calm Frame",
                "shadow": {"kind": "neutral", "opacity": 0.08},
                "specular": True,
                "translucency": {"enabled": False, "value": 0.05},
            },
        ],
        "supported-platforms": {"squares": ["macOS"]},
    }
    (ICON_COMPOSER_ICON / "icon.json").write_text(
        json.dumps(document, indent=2) + "\n"
    )
    (assets / "CalmFrame.svg").write_text(CALM_FRAME_SVG)


def main() -> None:
    for filename, size in sorted(app_icon_sizes().items()):
        render_app_icon(size).save(APP_ICON / filename)

    write_icon_composer_source()
    render_menu_icon(16).save(MENU_ICON / "menu_icon.png")
    render_menu_icon(32).save(MENU_ICON / "menu_icon@2x.png")


if __name__ == "__main__":
    main()
