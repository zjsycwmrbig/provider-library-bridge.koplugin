#!/usr/bin/env python3

from __future__ import annotations

import argparse
import subprocess
import unicodedata
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont


WIDTH = 900
HEIGHT = 1200
FONT_STACK = "'LXGW WenKai','Kaiti SC','STKaiti','KaiTi',serif"


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
    cleaned = clean_title(title)
    lines = [
        cleaned[start:start + max_chars].strip()
        for start in range(0, len(cleaned), max_chars)
    ]
    return [line for line in lines if line][:2] or ["无题"]


def title_markup(title, x, top, line_height, font_size, fill):
    lines = wrap_title(title)
    elements = []
    for index, line in enumerate(lines):
        y = top + index * line_height
        elements.append(
            f'<text x="{x}" y="{y}" text-anchor="middle" '
            f'font-family="{FONT_STACK}" font-size="{font_size}" '
            f'font-weight="600" fill="{fill}">{escape(line)}</text>'
        )
    return "\n  ".join(elements)


def common_footer(author, ink, muted):
    return f"""
  <line x1="138" y1="1042" x2="762" y2="1042" stroke="{muted}" stroke-width="2"/>
  <text x="450" y="1090" text-anchor="middle" font-family="{FONT_STACK}"
        font-size="34" fill="{ink}">{escape(author)}</text>
  <text x="450" y="1144" text-anchor="middle" font-family="{FONT_STACK}"
        font-size="17" letter-spacing="4" fill="{muted}">KOREADER · ONLINE LIBRARY</text>
"""


def eclipse_svg(title, author):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}"
     viewBox="0 0 {WIDTH} {HEIGHT}">
  <title>{escape(title)}</title>
  <rect width="{WIDTH}" height="{HEIGHT}" fill="#1d201f"/>
  <g fill="none" stroke="#b9b8b0">
    <circle cx="704" cy="274" r="166" fill="#d0cab8" stroke="none"/>
    <circle cx="704" cy="274" r="196" stroke-width="3" opacity=".9"/>
    <circle cx="704" cy="274" r="244" stroke-width="2" opacity=".46"/>
    <circle cx="704" cy="274" r="306" stroke-width="2" opacity=".28"/>
    <circle cx="704" cy="274" r="382" stroke-width="1.5" opacity=".17"/>
  </g>
  <g stroke="#dddbd2" stroke-width="2" opacity=".38">
    <path d="M704 82V26"/>
    <path d="M850 170l58-34"/>
    <path d="M889 274h65"/>
    <path d="M847 382l57 34"/>
    <path d="M315 274H56"/>
    <path d="M412 179L355 119"/>
    <path d="M423 372l-50 58"/>
  </g>
  <path d="M56 690H844" stroke="#d9d6cb" stroke-width="3" opacity=".8"/>
  <text x="58" y="66" font-family="{FONT_STACK}" font-size="17"
        letter-spacing="4" fill="#c3c3bc">ONLINE LIBRARY</text>
  {title_markup(title, 450, 774, 104, 84, "#f5f2e8")}
  {common_footer(author, "#eceae1", "#b7b8b1")}
</svg>
"""


def current_svg(title, author):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}"
     viewBox="0 0 {WIDTH} {HEIGHT}">
  <title>{escape(title)}</title>
  <rect width="{WIDTH}" height="{HEIGHT}" fill="#3d4441"/>
  <g fill="none" stroke-linecap="round">
    <path d="M-110 300C80 120 280 420 474 252S800 40 1030 262"
          stroke="#bfc3bc" stroke-width="24" opacity=".12"/>
    <path d="M-80 360C124 170 322 478 540 292S845 108 1040 336"
          stroke="#e1e1da" stroke-width="3" opacity=".46"/>
    <path d="M-70 446C150 240 366 555 588 370S870 212 1028 434"
          stroke="#d6d8d1" stroke-width="2" opacity=".30"/>
    <path d="M-80 970C160 758 332 1074 572 878S878 742 1030 948"
          stroke="#0f1211" stroke-width="70" opacity=".20"/>
    <path d="M-80 1016C174 828 342 1130 602 944S900 820 1028 1010"
          stroke="#f0eee5" stroke-width="2" opacity=".25"/>
  </g>
  <path d="M690 150V1010" stroke="#121514" stroke-width="1.5" opacity=".34"/>
  <path d="M716 150V1010" stroke="#d8dad3" stroke-width="1.5" opacity=".16"/>
  <text x="58" y="66" font-family="{FONT_STACK}" font-size="17"
        letter-spacing="4" fill="#d3d5ce">ONLINE LIBRARY</text>
  {title_markup(title, 450, 786, 104, 84, "#f5f2e9")}
  {common_footer(author, "#eeece4", "#c2c5be")}
</svg>
"""


def lattice_svg(title, author):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}"
     viewBox="0 0 {WIDTH} {HEIGHT}">
  <title>{escape(title)}</title>
  <defs>
    <pattern id="grid" width="64" height="64" patternUnits="userSpaceOnUse">
      <path d="M64 0H0V64" fill="none" stroke="#626a65" stroke-width="2"/>
    </pattern>
  </defs>
  <rect width="{WIDTH}" height="{HEIGHT}" fill="#202423"/>
  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#grid)" opacity=".48"/>
  <rect x="62" y="112" width="776" height="742" rx="3"
        fill="#2f3533" stroke="#e1ded3" stroke-width="4"/>
  <rect x="80" y="130" width="740" height="706" rx="2"
        fill="none" stroke="#949b95" stroke-width="1.5"/>
  <path d="M154 130V836M746 130V836" stroke="#757d77" stroke-width="2"/>
  <path d="M80 736H820" stroke="#e1ded3" stroke-width="2.5" opacity=".8"/>
  <g fill="#0e1110" opacity=".36">
    <path d="M112 160h102v102H112z"/>
    <path d="M686 590h102v214H686z"/>
  </g>
  <g stroke="#ece9df" stroke-width="3" opacity=".75">
    <path d="M128 214h72"/>
    <path d="M128 226h44"/>
    <path d="M702 744h70"/>
    <path d="M702 756h70"/>
  </g>
  <text x="58" y="66" font-family="{FONT_STACK}" font-size="17"
        letter-spacing="4" fill="#cfd1ca">ONLINE LIBRARY</text>
  {title_markup(title, 450, 786, 104, 84, "#f5f2e9")}
  {common_footer(author, "#eeece4", "#bcc0ba")}
</svg>
"""


STYLES = {
    "eclipse": eclipse_svg,
    "current": current_svg,
    "lattice": lattice_svg,
}


def render_preview(svg_path, output_dir):
    rendered = output_dir / f"{svg_path.stem}.png"
    subprocess.run(
        [
            "sips",
            "-s",
            "format",
            "png",
            str(svg_path),
            "--out",
            str(rendered),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if not rendered.exists():
        raise FileNotFoundError(f"sips did not render {svg_path}")
    image = Image.open(rendered).convert("RGB")
    image.resize((450, 600), Image.Resampling.LANCZOS).save(
        output_dir / f"{svg_path.stem}.jpg", quality=94
    )
    return output_dir / f"{svg_path.stem}.jpg"


def make_contact_sheet(samples, font_path, output):
    width = 1200
    height = 780
    cell_width = 340
    cover_width = 270
    cover_height = 360
    gap = 48
    image = Image.new("RGB", (width, height), "#dcd9d1")
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(font_path), 24)
    small_font = ImageFont.truetype(str(font_path), 16)

    for index, sample in enumerate(samples):
        center_x = gap + cell_width // 2 + index * (cell_width + gap)
        cover = Image.open(sample["preview"]).resize(
            (cover_width, cover_height), Image.Resampling.LANCZOS
        )
        image.paste(cover, (center_x - cover_width // 2, 38))
        draw.text(
            (center_x, 432),
            sample["label"],
            font=title_font,
            fill="#171816",
            anchor="mt",
        )
        draw.text(
            (center_x, 474),
            sample["description"],
            font=small_font,
            fill="#4c4f4b",
            anchor="mt",
        )
        draw.text(
            (center_x, 502),
            "纯 SVG · 无位图素材",
            font=small_font,
            fill="#4c4f4b",
            anchor="mt",
        )

    image.save(output, quality=95)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-dir", required=True)
    parser.add_argument("--preview-dir", required=True)
    parser.add_argument("--font", required=True)
    args = parser.parse_args()

    asset_dir = Path(args.asset_dir)
    preview_dir = Path(args.preview_dir)
    asset_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)

    samples = [
        {
            "style": "eclipse",
            "title": "长夜将尽",
            "author": "林舟",
            "filename": "02-eclipse.svg",
            "label": "暗日",
            "description": "低密度几何，远看最稳",
        },
        {
            "style": "current",
            "title": "远山来信",
            "author": "沈原",
            "filename": "03-current.svg",
            "label": "流线",
            "description": "中灰底，弱纹理不抢字",
        },
        {
            "style": "lattice",
            "title": "纸上的银河",
            "author": "周野",
            "filename": "05-lattice.svg",
            "label": "墨格",
            "description": "深底细格，缩略图轮廓清晰",
        },
    ]

    for sample in samples:
        svg_path = asset_dir / sample["filename"]
        svg_path.write_text(
            STYLES[sample["style"]](sample["title"], sample["author"]),
            encoding="utf-8",
        )
        sample["preview"] = render_preview(svg_path, preview_dir)

    contact_sheet = preview_dir / "00-svg-cover-sheet.png"
    make_contact_sheet(samples, Path(args.font), contact_sheet)
    for sample in samples:
        print(sample["preview"])
    print(contact_sheet)


if __name__ == "__main__":
    main()
