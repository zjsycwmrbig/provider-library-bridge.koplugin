#!/usr/bin/env python3

from __future__ import annotations

import argparse
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


WIDTH = 900
HEIGHT = 1200


def clean_title(title):
    characters = []
    for character in str(title or ""):
        category = unicodedata.category(character)
        if category[0] in {"L", "N", "M"} or category == "Zs":
            characters.append(character)
        else:
            characters.append(" ")
    return " ".join("".join(characters).split()) or "无题"


def wrap_title(title, max_chars=8):
    title = clean_title(title)
    lines = []
    for start in range(0, len(title), max_chars):
        line = title[start:start + max_chars].strip()
        if line:
            lines.append(line)
    return lines[:3]


def prepare_background(source, brightness):
    image = Image.open(source).convert("RGB")
    image = ImageOps.fit(
        image,
        (WIDTH, HEIGHT),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    image = ImageOps.grayscale(image).convert("RGB")
    image = ImageEnhance.Contrast(image).enhance(1.08)
    return ImageEnhance.Brightness(image).enhance(brightness)


def add_title_zone(image):
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = overlay.load()
    gradient_start = 420
    for y in range(gradient_start, HEIGHT):
        progress = (y - gradient_start) / (HEIGHT - gradient_start)
        alpha = round(205 * progress ** 1.65)
        for x in range(WIDTH):
            pixels[x, y] = (8, 9, 8, alpha)
    return Image.alpha_composite(image.convert("RGBA"), overlay)


def draw_centered(draw, box, text, font, fill):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    x = box[0] + (box[2] - box[0] - (right - left)) / 2 - left
    y = box[1] + (box[3] - box[1] - (bottom - top)) / 2 - top
    draw.text((x, y), text, font=font, fill=fill)


def render_cover(background, title, author, font_path, output):
    image = add_title_zone(background)
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(font_path), 82)
    author_font = ImageFont.truetype(str(font_path), 34)
    rule_font = ImageFont.truetype(str(font_path), 19)

    lines = wrap_title(title)
    line_height = 102
    block_top = 810 - (len(lines) - 1) * line_height // 2
    for index, line in enumerate(lines):
        top = block_top + index * line_height
        draw_centered(
            draw,
            (70, top, WIDTH - 70, top + line_height),
            line,
            title_font,
            "#F5F2E9",
        )

    draw.line((180, 1052, WIDTH - 180, 1052), fill="#D2D3CD", width=2)
    draw_centered(
        draw,
        (100, 1066, WIDTH - 100, 1112),
        author,
        author_font,
        "#EAE8E0",
    )
    draw_centered(
        draw,
        (100, 1130, WIDTH - 100, 1162),
        "KOREADER  ONLINE LIBRARY",
        rule_font,
        "#B9BBB5",
    )
    image.convert("RGB").save(output, quality=94)


def make_contact_sheet(entries, font_path, output):
    width = 1200
    height = 610
    cell_width = 340
    cover_width = 250
    cover_height = 334
    gap = 50
    image = Image.new("RGB", (width, height), "#DEDBD3")
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(font_path), 23)
    small_font = ImageFont.truetype(str(font_path), 16)

    for index, entry in enumerate(entries):
        center_x = gap + cell_width // 2 + index * (cell_width + gap)
        cover = Image.open(entry["output"]).resize(
            (cover_width, cover_height), Image.Resampling.LANCZOS
        )
        image.paste(cover, (center_x - cover_width // 2, 34))
        draw.text(
            (center_x, 395),
            entry["label"],
            font=title_font,
            fill="#171816",
            anchor="mt",
        )
        draw.text(
            (center_x, 438),
            entry["source"],
            font=small_font,
            fill="#4C4F4B",
            anchor="mt",
        )
        draw.text(
            (center_x, 466),
            "Wikimedia Commons · CC0",
            font=small_font,
            fill="#4C4F4B",
            anchor="mt",
        )

    image.save(output, quality=95)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--background-output", required=True)
    parser.add_argument("--font", required=True)
    args = parser.parse_args()

    assets = Path(args.assets)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    background_output = Path(args.background_output)
    background_output.mkdir(parents=True, exist_ok=True)
    font_path = Path(args.font)

    entries = [
        {
            "source": assets / "sun-blinds.jpg",
            "output": output / "02-generic-light.jpg",
            "label": "光影",
            "credit": "Tomwsulcer",
            "brightness": 0.92,
            "background": "light.jpg",
        },
        {
            "source": assets / "cloud-sky.jpg",
            "output": output / "03-generic-cloud.jpg",
            "label": "云层",
            "credit": "Liyan Alsaideh14",
            "brightness": 0.88,
            "background": "cloud.jpg",
        },
        {
            "source": assets / "lattice-octagon.jpg",
            "output": output / "05-generic-lattice.jpg",
            "label": "窗格",
            "credit": "Z3lvs",
            "brightness": 0.88,
            "background": "lattice.jpg",
        },
    ]

    for entry in entries:
        background = prepare_background(entry["source"], entry["brightness"])
        background.save(
            background_output / entry["background"],
            quality=92,
        )
        render_cover(
            background,
            title="书名",
            author="作者",
            font_path=font_path,
            output=entry["output"],
        )

    contact_entries = [
        {
            "output": entry["output"],
            "label": entry["label"],
            "source": f"摄影：{entry['credit']}",
        }
        for entry in entries
    ]
    contact_sheet = output / "00-generic-cover-sheet.png"
    make_contact_sheet(contact_entries, font_path, contact_sheet)

    for entry in entries:
        print(entry["output"])
    print(contact_sheet)


if __name__ == "__main__":
    main()
