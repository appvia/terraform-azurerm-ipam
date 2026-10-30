# /// script
# requires-python = ">=3.9"
# dependencies = ["Pillow>=10.0"]
# ///
"""Generate a banner image with the module name overlaid on the blank template.

Usage:
    uv run scripts/generate-banner.py <module-name>
    uv run scripts/generate-banner.py terraform-azurerm-just-testing

The script loads docs/blank-banner.png (the template without module text),
renders the module name in Inter Bold, and saves docs/banner.jpg.

Long module names are handled by shrinking the font until the text fits within
a fixed bounding box that avoids the mascot on the right side.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Paths relative to repo root
REPO_ROOT = Path(__file__).resolve().parent.parent
BLANK_BANNER = REPO_ROOT / "docs" / "blank-banner.png"
OUTPUT_BANNER = REPO_ROOT / "docs" / "banner.jpg"
FONT_PATH = Path(__file__).resolve().parent / "Inter-Bold.ttf"

# Text bounding box on blank-banner.png (2734x680).
# Positioned below the "TERRAFORM MODULE" header, above the badges row,
# and to the left of the mascot.
TEXT_LEFT = 65
TEXT_RIGHT = 2100
TEXT_TOP = 155
TEXT_BOTTOM = 400
TEXT_MAX_WIDTH = TEXT_RIGHT - TEXT_LEFT
TEXT_MAX_HEIGHT = TEXT_BOTTOM - TEXT_TOP

# Font sizing: start large, shrink until the text fits the bounding box.
FONT_SIZE_MAX = 130
FONT_SIZE_MIN = 30
FONT_SIZE_STEP = 2

TEXT_COLOR = (255, 255, 255)  # white


def find_fitting_font_size(text: str) -> tuple[ImageFont.FreeTypeFont, int]:
    """Return the largest font size that fits *text* within the bounding box."""
    for size in range(FONT_SIZE_MAX, FONT_SIZE_MIN - 1, -FONT_SIZE_STEP):
        font = ImageFont.truetype(str(FONT_PATH), size)
        bbox = font.getbbox(text)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        if text_width <= TEXT_MAX_WIDTH and text_height <= TEXT_MAX_HEIGHT:
            return font, size
    # Fall back to minimum size even if it overflows
    return ImageFont.truetype(str(FONT_PATH), FONT_SIZE_MIN), FONT_SIZE_MIN


def generate_banner(module_name: str, output: Path = OUTPUT_BANNER) -> None:
    """Render *module_name* onto the blank banner and save the result."""
    if not BLANK_BANNER.exists():
        sys.exit(f"Error: blank banner not found at {BLANK_BANNER}")
    if not FONT_PATH.exists():
        sys.exit(f"Error: font not found at {FONT_PATH}")

    img = Image.open(BLANK_BANNER).convert("RGBA")
    draw = ImageDraw.Draw(img)

    font, size = find_fitting_font_size(module_name)
    bbox = font.getbbox(module_name)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Position: left-aligned, vertically centred within the bounding box
    x = TEXT_LEFT
    y = TEXT_TOP + (TEXT_MAX_HEIGHT - text_height) // 2 - bbox[1]

    draw.text((x, y), module_name, font=font, fill=TEXT_COLOR)

    # Save as RGB JPEG (drop alpha channel)
    rgb = img.convert("RGB")
    rgb.save(output, "JPEG", quality=95)
    print(f"Generated {output}")
    print(f"  module name : {module_name}")
    print(f"  font size   : {size}pt")
    print(f"  text size   : {text_width}x{text_height}px")
    print(f"  image size  : {img.size[0]}x{img.size[1]}px")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a banner image with the module name.",
    )
    parser.add_argument(
        "module_name",
        help="The module name to render on the banner (e.g. terraform-azurerm-my-module)",
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=OUTPUT_BANNER,
        help=f"Output path (default: {OUTPUT_BANNER})",
    )
    args = parser.parse_args()
    generate_banner(args.module_name, args.output)


if __name__ == "__main__":
    main()
