"""
Преобразует изображение в 3 текстовых файла N x N,
где каждый файл содержит значения яркости канала R, G или B
для каждого пикселя (0-255).

Использование:
    python img_to_rgb.py input.jpg 64
    python img_to_rgb.py input.jpg 64 output_prefix
"""

import sys
from pathlib import Path

from PIL import Image


def image_to_rgb_files(input_path: str, size: int, prefix: str = "channel") -> None:
    img = Image.open(input_path)

    # Приводим к RGB и масштабируем до N x N
    img = img.convert("RGB").resize((size, size), Image.LANCZOS)

    r_vals, g_vals, b_vals = [], [], []
    pixels = img.load()
    for y in range(size):
        r_row, g_row, b_row = [], [], []
        for x in range(size):
            r, g, b = pixels[x, y]
            r_row.append(str(r))
            g_row.append(str(g))
            b_row.append(str(b))
        r_vals.append(" ".join(r_row))
        g_vals.append(" ".join(g_row))
        b_vals.append(" ".join(b_row))

    for name, data in (("R", r_vals), ("G", g_vals), ("B", b_vals)):
        out_path = f"{prefix}_{name}.txt"
        Path(out_path).write_text("\n".join(data), encoding="utf-8")
        print(f"Сохранено: {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Использование: python img_to_rgb.py <входная_картинка> <N> [префикс]")
        sys.exit(1)

    input_file = sys.argv[1]
    n = int(sys.argv[2])
    pref = sys.argv[3] if len(sys.argv) > 3 else "channel"

    image_to_rgb_files(input_file, n, pref)