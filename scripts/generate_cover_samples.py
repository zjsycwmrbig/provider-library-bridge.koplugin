#!/usr/bin/env python3

from __future__ import annotations

import argparse
import math
import random
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


def source_tag(draw, text, font, corner="top-left"):
    pad_x, pad_y = 18, 10
    bbox = draw.textbbox((0, 0), text, font=font)
    width = bbox[2] - bbox[0] + pad_x * 2
    height = bbox[3] - bbox[1] + pad_y * 2
    if corner == "top-left":
        box = (MARGIN, MARGIN, MARGIN + width, MARGIN + height)
    else:
        box = (WIDTH - MARGIN - width, HEIGHT - MARGIN - height,
               WIDTH - MARGIN, HEIGHT - MARGIN)
    draw.rounded_rectangle(box, radius=8, fill="#171717")
    centered_text(draw, box, text, font, "#F7F5EF")


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
    for index in range(18):
        y = 820 + index * 18
        inset = 75 + index * 8
        draw.arc((inset, y - 90, WIDTH - inset, y + 80),
                 190, 350, fill="#AAA69B", width=2)
    for index in range(6):
        draw.arc((120 + index * 8, 420 + index * 48,
                  WIDTH - 120 - index * 8, 800 - index * 22),
                 200, 340, fill="#C8C4B9", width=2)
    draw.ellipse((WIDTH - 220, 180, WIDTH - 120, 280), outline="#6D6A63", width=3)
    draw.ellipse((WIDTH - 196, 204, WIDTH - 144, 256), outline="#6D6A63", width=2)


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
    for radius in range(70, 330, 22):
        draw.arc((center[0] - radius, center[1] - radius,
                  center[0] + radius, center[1] + radius),
                 190, 355, fill="#A6A6A6", width=2)
    for angle in range(190, 356, 12):
        rad = math.radians(angle)
        x1 = center[0] + math.cos(rad) * 75
        y1 = center[1] + math.sin(rad) * 75
        x2 = center[0] + math.cos(rad) * 420
        y2 = center[1] + math.sin(rad) * 420
        draw.line((x1, y1, x2, y2), fill="#D0D0D0", width=1)


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
        draw.line((x, 0, x, HEIGHT), fill="#DBD8CE", width=1)
    for y in range(0, HEIGHT, step):
        draw.line((0, y, WIDTH, y), fill="#DBD8CE", width=1)
    for x in range(0, WIDTH, step * 2):
        for y in range(0, HEIGHT, step * 2):
            draw.rectangle((x, y, x + step, y + step), outline="#AAA79D", width=1)
    draw.rectangle((MARGIN - 18, 160, WIDTH - MARGIN + 18, HEIGHT - 230),
                   fill="#F2F0E8", outline="#2F2F2F", width=3)


def make_cover(path, title, author, source, style, corner):
    paper_font = load_font(FONT_PATH, 28)
    title_font = load_font(FONT_PATH, 94)
    author_font = load_font(FONT_PATH, 34)
    footer_font = load_font(FONT_PATH, 24)
    tag_font = load_font(FONT_PATH, 25)

    if style == "orbit":
        image = paper_base("#101112")
        draw = ImageDraw.Draw(image)
        draw_star_orbits(draw)
        title_color = "#EFEEE8"
        secondary = "#A9A9A9"
    elif style == "sun":
        image = paper_base("#F0EEE5")
        draw = ImageDraw.Draw(image)
        draw_sun_rays(draw)
        title_color = "#202020"
        secondary = "#6D6D6D"
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
        image = paper_base("#F3F1E9")
        draw = ImageDraw.Draw(image)
        draw_lattice(draw)
        title_color = "#242322"
        secondary = "#6B6862"
    else:
        image = paper_base()
        draw = ImageDraw.Draw(image)
        draw_cloud_wave(draw)
        title_color = "#20201E"
        secondary = "#65625C"

    source_tag(draw, source, tag_font, corner)
    vertical_title(draw, title, title_font, title_color, WIDTH - 120, 205)
    if author:
        draw.text((MARGIN, HEIGHT - 145), author, font=author_font, fill=secondary)
    draw.line((MARGIN, HEIGHT - 82, WIDTH - MARGIN, HEIGHT - 82),
              fill=secondary, width=1)
    draw.text((MARGIN, HEIGHT - 66), "KOReader · 在线书库",
              font=footer_font, fill=secondary)
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
        ("01-orbit-top-left.png", "无人逝去", "[日] 白井智之", "番茄", "orbit", "top-left"),
        ("02-sun-bottom-right.png", "红星照耀中国", "[美] 埃德加·斯诺", "微信读书", "sun", "bottom-right"),
        ("03-cloud-top-left.png", "黑死馆杀人事件", "小栗虫太郎", "番茄", "cloud", "top-left"),
        ("04-mountain-bottom-right.png", "神通者", "天蚕土豆", "番茄", "mountains", "bottom-right"),
        ("05-lattice-top-left.png", "三体全集（全三册）", "刘慈欣", "微信读书", "lattice", "top-left"),
        ("06-deco-generic.png", "书名", "作者名", "在线书库", "deco", "top-left"),
    ]
    for filename, title, author, source, style, corner in samples:
        make_cover(output / filename, title, author, source, style, corner)
        print(output / filename)

    thumb_w, thumb_h = 225, 300
    gap = 24
    sheet = Image.new("RGB", (thumb_w * 3 + gap * 4, (thumb_h + 52) * 2 + gap * 3),
                      "#D8D5CC")
    sheet_draw = ImageDraw.Draw(sheet)
    label_font = load_font(FONT_PATH, 18)
    for index, (filename, title, _author, _source, _style, _corner) in enumerate(samples):
        row, col = divmod(index, 3)
        cover = Image.open(output / filename).resize(
            (thumb_w, thumb_h), Image.Resampling.LANCZOS
        )
        x = gap + col * (thumb_w + gap)
        y = gap + row * (thumb_h + 52 + gap)
        sheet.paste(cover, (x, y))
        sheet_draw.text((x, y + thumb_h + 8), f"{index + 1:02d}  {title}",
                        font=label_font, fill="#1A1A1A")
    sheet.save(output / "00-contact-sheet.png")
    print(output / "00-contact-sheet.png")


if __name__ == "__main__":
    main()
