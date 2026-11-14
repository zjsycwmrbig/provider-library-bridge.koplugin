#!/usr/bin/env python3

from __future__ import annotations

import argparse
import math
import random
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


WIDTH = 900
HEIGHT = 1200
MARGIN = 58


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def centered_text(draw, box, text, font, fill):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    x = box[0] + (box[2] - box[0] - (right - left)) / 2 - left
    y = box[1] + (box[3] - box[1] - (bottom - top)) / 2 - top
    draw.text((x, y), text, font=font, fill=fill)


def clean_title(title):
    """Remove Unicode punctuation and symbols while keeping words and numbers."""
    characters = []
    for character in str(title or ""):
        category = unicodedata.category(character)
        if category[0] in {"L", "N", "M"} or category == "Zs":
            characters.append(character)
        else:
            characters.append(" ")
    return " ".join("".join(characters).split()) or "无题"


def vertical_title(draw, title, font, color, x_right, top, max_per_column=8):
    chars = [char for char in title if char.strip()]
    columns = [chars[i:i + max_per_column] for i in range(0, len(chars), max_per_column)]
    line_height = font.size + 8
    for col_index, column in enumerate(reversed(columns)):
        x = x_right - col_index * (font.size + 18)
        for row_index, char in enumerate(column):
            y = top + row_index * line_height
            bbox = draw.textbbox((0, 0), char, font=font)
            draw.text((x - (bbox[2] - bbox[0]), y), char, font=font, fill=color)


def paper_base(color="#F2F0E8"):
    return Image.new("RGB", (WIDTH, HEIGHT), color)


def draw_cloud_wave(draw):
    for index in range(11):
        y = 735 + index * 31
        inset = 42 + index * 13
        draw.arc((inset, y - 125, WIDTH - inset, y + 95),
                 198, 344, fill="#AEB6B1", width=5)
    for index in range(5):
        draw.arc((88 + index * 24, 330 + index * 68,
                  WIDTH - 88 - index * 22, 815 - index * 22),
                 204, 342, fill="#D0D3CD", width=3)
    draw.arc((WIDTH - 270, 118, WIDTH - 70, 318),
             205, 338, fill="#D9D9D1", width=4)
    draw.arc((WIDTH - 242, 146, WIDTH - 98, 290),
             205, 338, fill="#8E9692", width=2)


def draw_star_orbits(draw):
    random.seed(31)
    center = (WIDTH // 2 + 60, 640)
    for radius in range(95, 540, 52):
        draw.ellipse((center[0] - radius, center[1] - radius,
                      center[0] + radius, center[1] + radius),
                     outline="#4C4C4C", width=2)
    for _ in range(90):
        x = random.randint(55, WIDTH - 55)
        y = random.randint(130, 1050)
        radius = random.choice((1, 1, 1, 2))
        draw.ellipse((x - radius, y - radius, x + radius, y + radius),
                     fill="#A9A9A9")


def draw_sun_rays(draw):
    center = (WIDTH - 210, 285)
    draw.ellipse((center[0] - 86, center[1] - 86,
                  center[0] + 86, center[1] + 86),
                 fill="#D7C89D", outline="#EFE5C5", width=3)
    for radius in range(118, 390, 24):
        draw.arc((center[0] - radius, center[1] - radius,
                  center[0] + radius, center[1] + radius),
                 160, 360, fill="#A7A89F", width=2)
    for angle in range(160, 361, 10):
        rad = math.radians(angle)
        x1 = center[0] + math.cos(rad) * 108
        y1 = center[1] + math.sin(rad) * 108
        x2 = center[0] + math.cos(rad) * 475
        y2 = center[1] + math.sin(rad) * 475
        draw.line((x1, y1, x2, y2), fill="#676C6C", width=2)


def draw_mountains(draw):
    layers = [
        (760, "#C9C7C0"),
        (835, "#99968E"),
        (910, "#65635D"),
    ]
    for base_y, color in layers:
        points = [(0, HEIGHT)]
        step = 90
        for x in range(-80, WIDTH + 160, step):
            peak = base_y - (95 if (x // step) % 2 == 0 else 45)
            points.append((x, peak))
        points.extend([(WIDTH, HEIGHT), (0, HEIGHT)])
        draw.polygon(points, fill=color)
    draw.line((MARGIN, 1020, WIDTH - MARGIN, 1020), fill="#F1F0EA", width=2)


def draw_deco_frame(draw):
    outer = (35, 35, WIDTH - 35, HEIGHT - 35)
    inner = (62, 62, WIDTH - 62, HEIGHT - 62)
    draw.rectangle(outer, outline="#202020", width=3)
    draw.rectangle(inner, outline="#202020", width=1)
    for x, y, sx, sy in (
        (35, 35, 1, 1), (WIDTH - 35, 35, -1, 1),
        (35, HEIGHT - 35, 1, -1), (WIDTH - 35, HEIGHT - 35, -1, -1),
    ):
        for i in range(4):
            draw.line((x, y + sy * i * 22,
                       x + sx * (120 - i * 12), y), fill="#202020", width=2)
            draw.line((x + sx * i * 22, y,
                       x, y + sy * (120 - i * 12)), fill="#202020", width=2)
    for i in range(13):
        y = 170 + i * 65
        draw.line((70, y, 118, y), fill="#8C8C8C", width=1)
        draw.line((WIDTH - 118, y, WIDTH - 70, y), fill="#8C8C8C", width=1)


def draw_lattice(draw):
    step = 64
    for x in range(0, WIDTH, step):
        draw.line((x, 0, x, HEIGHT), fill="#525A56", width=2)
    for y in range(0, HEIGHT, step):
        draw.line((0, y, WIDTH, y), fill="#525A56", width=2)
    for x in range(0, WIDTH, step * 2):
        for y in range(0, HEIGHT, step * 2):
            draw.rectangle((x, y, x + step, y + step), outline="#808983", width=1)
    draw.rectangle((MARGIN - 18, 152, WIDTH - MARGIN + 18, HEIGHT - 236),
                   fill="#303635", outline="#D7D8D0", width=3)
    draw.rectangle((MARGIN - 8, 162, WIDTH - MARGIN + 8, HEIGHT - 246),
                   outline="#7A827D", width=1)


def make_cover(path, title, author, style):
    title = clean_title(title)
    paper_font = load_font(FONT_PATH, 28)
    title_font = load_font(FONT_PATH, 94)
    author_font = load_font(FONT_PATH, 34)
    footer_font = load_font(FONT_PATH, 24)

    if style == "orbit":
        image = paper_base("#101112")
        draw = ImageDraw.Draw(image)
        draw_star_orbits(draw)
        title_color = "#EFEEE8"
        secondary = "#A9A9A9"
    elif style == "sun":
        image = paper_base("#3E4446")
        draw = ImageDraw.Draw(image)
        draw_sun_rays(draw)
        title_color = "#F3F0E5"
        secondary = "#D2D1C7"
    elif style == "mountains":
        image = paper_base("#EEEBE2")
        draw = ImageDraw.Draw(image)
        draw_mountains(draw)
        title_color = "#1C1C1C"
        secondary = "#F0EEE7"
    elif style == "deco":
        image = paper_base("#E9E6DD")
        draw = ImageDraw.Draw(image)
        draw_deco_frame(draw)
        title_color = "#121212"
        secondary = "#5E5B56"
    elif style == "lattice":
        image = paper_base("#222726")
        draw = ImageDraw.Draw(image)
        draw_lattice(draw)
        title_color = "#F3F1E9"
        secondary = "#CED1CA"
    else:
        image = paper_base("#505958")
        draw = ImageDraw.Draw(image)
        draw_cloud_wave(draw)
        title_color = "#F4F1E7"
        secondary = "#D3D5CE"

    vertical_title(draw, title, title_font, title_color, WIDTH - 120, 205)
    if author:
        draw.text((MARGIN, HEIGHT - 145), author, font=author_font, fill=secondary)
    draw.line((MARGIN, HEIGHT - 82, WIDTH - MARGIN, HEIGHT - 82),
              fill=secondary, width=1)
    draw.text((MARGIN, HEIGHT - 66), "KOReader · 在线书库",
              font=footer_font, fill=secondary)
    image.save(path, quality=95)


def make_shelf_tag_preview(path, samples):
    width, height = 1200, 920
    image = Image.new("RGB", (width, height), "#D8D5CC")
    draw = ImageDraw.Draw(image)
    heading_font = load_font(FONT_PATH, 32)
    title_font = load_font(FONT_PATH, 22)
    small_font = load_font(FONT_PATH, 18)
    tag_font = load_font(FONT_PATH, 17)
    list_font = load_font(FONT_PATH, 21)

    draw.text((46, 34), "书架标签预览 · 标签属于界面，不烘焙进封面",
              font=heading_font, fill="#1C1D1C")
    draw.text((46, 82), "封面网格：来源标签显示在书名下方；标准列表：显示在右侧。",
              font=small_font, fill="#4A4B48")

    cover_w, cover_h = 232, 310
    gap = 50
    start_x = 58
    top_y = 142
    for index, sample in enumerate(samples[:3]):
        x = start_x + index * (cover_w + gap)
        cover = Image.open(path.parent / sample["filename"]).resize(
            (cover_w, cover_h), Image.Resampling.LANCZOS
        )
        image.paste(cover, (x, top_y))
        clean = clean_title(sample["title"])
        draw.text((x, top_y + cover_h + 16), clean, font=title_font, fill="#171816")
        tag_text = sample["source"]
        bbox = draw.textbbox((0, 0), tag_text, font=tag_font)
        tag_w = bbox[2] - bbox[0] + 24
        tag_h = bbox[3] - bbox[1] + 14
        tag_box = (x, top_y + cover_h + 53, x + tag_w, top_y + cover_h + 53 + tag_h)
        draw.rounded_rectangle(tag_box, radius=6, fill="#2B2E2D")
        centered_text(draw, tag_box, tag_text, tag_font, "#F7F5EE")

    divider_y = 585
    draw.line((46, divider_y, width - 46, divider_y), fill="#A9A69D", width=2)
    draw.text((46, divider_y + 22), "标准文件列表", font=title_font, fill="#1B1C1A")

    rows = [
        ("无人逝去 [7277393036894538793].html", "番茄 · 12 KB"),
        ("三体全集 全三册 [695233].html", "微信读书 · 13 KB"),
        ("红星照耀中国 [3300188888].html", "微信读书 · 11 KB"),
    ]
    row_y = divider_y + 68
    for index, (filename, label) in enumerate(rows):
        y = row_y + index * 58
        if index % 2 == 0:
            draw.rounded_rectangle((44, y - 8, width - 44, y + 42),
                                   radius=7, fill="#E1DED5")
        draw.text((65, y), filename, font=list_font, fill="#1C1D1B")
        bbox = draw.textbbox((0, 0), label, font=small_font)
        draw.text((width - 74 - (bbox[2] - bbox[0]), y + 1),
                  label, font=small_font, fill="#4D514D")

    image.save(path, quality=95)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--font", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    global FONT_PATH
    FONT_PATH = Path(args.font)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    samples = [
        {"filename": "01-orbit-top-left.png", "title": "无人逝去",
         "author": "[日] 白井智之", "source": "番茄", "style": "orbit"},
        {"filename": "02-sun-bottom-right.png", "title": "红星照耀中国",
         "author": "[美] 埃德加·斯诺", "source": "微信读书", "style": "sun"},
        {"filename": "03-cloud-top-left.png", "title": "黑死馆杀人事件",
         "author": "小栗虫太郎", "source": "番茄", "style": "cloud"},
        {"filename": "04-mountain-bottom-right.png", "title": "神通者",
         "author": "天蚕土豆", "source": "番茄", "style": "mountains"},
        {"filename": "05-lattice-top-left.png", "title": "三体全集（全三册）",
         "author": "刘慈欣", "source": "微信读书", "style": "lattice"},
        {"filename": "06-deco-generic.png", "title": "《书名》",
         "author": "作者名", "source": "在线书库", "style": "deco"},
    ]
    for sample in samples:
        path = output / sample["filename"]
        make_cover(path, sample["title"], sample["author"], sample["style"])
        print(path)

    thumb_w, thumb_h = 225, 300
    gap = 24
    sheet = Image.new("RGB", (thumb_w * 3 + gap * 4, (thumb_h + 52) * 2 + gap * 3),
                      "#D8D5CC")
    sheet_draw = ImageDraw.Draw(sheet)
    label_font = load_font(FONT_PATH, 18)
    for index, sample in enumerate(samples):
        row, col = divmod(index, 3)
        cover = Image.open(output / sample["filename"]).resize(
            (thumb_w, thumb_h), Image.Resampling.LANCZOS
        )
        x = gap + col * (thumb_w + gap)
        y = gap + row * (thumb_h + 52 + gap)
        sheet.paste(cover, (x, y))
        sheet_draw.text((x, y + thumb_h + 8),
                        f"{index + 1:02d}  {clean_title(sample['title'])}",
                        font=label_font, fill="#1A1A1A")
    sheet.save(output / "00-contact-sheet.png")
    print(output / "00-contact-sheet.png")

    tag_preview = output / "00-shelf-tags-preview.png"
    make_shelf_tag_preview(tag_preview, samples)
    print(tag_preview)


if __name__ == "__main__":
    main()
