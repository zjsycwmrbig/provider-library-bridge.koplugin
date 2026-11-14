#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def solve_linear(matrix, values):
    size = len(values)
    rows = [list(matrix[index]) + [values[index]] for index in range(size)]
    for column in range(size):
        pivot = max(range(column, size), key=lambda row: abs(rows[row][column]))
        rows[column], rows[pivot] = rows[pivot], rows[column]
        divisor = rows[column][column]
        if abs(divisor) < 1e-12:
            raise ValueError("Cannot solve perspective transform")
        rows[column] = [value / divisor for value in rows[column]]
        for row in range(size):
            if row == column:
                continue
            factor = rows[row][column]
            rows[row] = [
                rows[row][index] - factor * rows[column][index]
                for index in range(size + 1)
            ]
    return [rows[index][-1] for index in range(size)]


def perspective_coefficients(source_points, width, height):
    target_points = [(0, 0), (width, 0), (width, height), (0, height)]
    matrix = []
    values = []
    for (source_x, source_y), (target_x, target_y) in zip(
        source_points, target_points
    ):
        matrix.append([
            target_x, target_y, 1, 0, 0, 0,
            -target_x * source_x, -target_y * source_x,
        ])
        values.append(source_x)
        matrix.append([
            0, 0, 0, target_x, target_y, 1,
            -target_x * source_y, -target_y * source_y,
        ])
        values.append(source_y)
    return solve_linear(matrix, values)


def perspective_crop(image, points, size):
    coefficients = perspective_coefficients(points, *size)
    return image.transform(
        size,
        Image.Transform.PERSPECTIVE,
        coefficients,
        resample=Image.Resampling.BICUBIC,
    )


def resize_with_limit(image, max_width=1000, max_height=1500):
    ratio = min(max_width / image.width, max_height / image.height)
    size = (round(image.width * ratio), round(image.height * ratio))
    return image.resize(size, Image.Resampling.LANCZOS)


def make_contact_sheet(entries, output, font_path):
    width = 1200
    height = 650
    cell_width = 340
    cover_width = 260
    cover_height = 390
    gap = 50
    image = Image.new("RGB", (width, height), "#DEDBD3")
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(font_path), 24)
    small_font = ImageFont.truetype(str(font_path), 16)

    for index, entry in enumerate(entries):
        center_x = gap + cell_width // 2 + index * (cell_width + gap)
        cover = Image.open(entry["path"]).convert("RGB")
        fitted = ImageOps.contain(
            cover, (cover_width, cover_height), Image.Resampling.LANCZOS
        )
        backing = Image.new("RGB", (cover_width, cover_height), "#B7B4AC")
        backing.paste(
            fitted,
            (
                (cover_width - fitted.width) // 2,
                (cover_height - fitted.height) // 2,
            ),
        )
        image.paste(
            backing,
            (center_x - cover_width // 2, 42),
        )
        draw.text(
            (center_x, 455),
            entry["title"],
            font=title_font,
            fill="#171816",
            anchor="mt",
        )
        draw.text(
            (center_x, 500),
            entry["source"],
            font=small_font,
            fill="#4C4F4B",
            anchor="mt",
        )
        draw.text(
            (center_x, 530),
            entry["note"],
            font=small_font,
            fill="#4C4F4B",
            anchor="mt",
        )

    image.save(output, quality=95)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--font", required=True)
    args = parser.parse_args()

    assets = Path(args.assets)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    red_star = Image.open(assets / "redstar-baike.jpg").convert("RGB")
    red_star_cover = perspective_crop(
        red_star,
        [(228, 17), (1017, 15), (1024, 1169), (366, 1169)],
        (770, 1120),
    )
    red_star_cover = resize_with_limit(red_star_cover)
    red_star_path = output / "02-redstar-official.jpg"
    red_star_cover.save(red_star_path, quality=95)

    black_death = Image.open(assets / "blackdeath-douban.jpg").convert("RGB")
    black_death = resize_with_limit(black_death)
    black_death_path = output / "03-black-death-official.jpg"
    black_death.save(black_death_path, quality=95)

    three_body = Image.open(
        assets / "threebody-douban-read-original.jpg"
    ).convert("RGB")
    three_body = resize_with_limit(three_body)
    three_body_path = output / "05-three-body-official.jpg"
    three_body.save(three_body_path, quality=95)

    make_contact_sheet(
        [
            {
                "path": red_star_path,
                "title": "红星照耀中国",
                "source": "来源：人民文学出版社版本封面",
                "note": "网络封面，仅校正透视",
            },
            {
                "path": black_death_path,
                "title": "黑死馆杀人事件",
                "source": "来源：豆瓣书目封面",
                "note": "网络封面，仅等比缩放",
            },
            {
                "path": three_body_path,
                "title": "三体全集 全三册",
                "source": "来源：豆瓣阅读电子书封面",
                "note": "网络封面，仅等比缩放",
            },
        ],
        output / "00-reference-cover-sheet.png",
        Path(args.font),
    )

    for path in (
        red_star_path,
        black_death_path,
        three_body_path,
        output / "00-reference-cover-sheet.png",
    ):
        print(path)


if __name__ == "__main__":
    main()
