from PIL import Image
import os
import re

# Пути к файлам с данными
CHANNEL_R_PATH = r"C:/univer/RTL_prototype/lab2/etc/channel_R.txt"
CHANNEL_G_PATH = r"C:/univer/RTL_prototype/lab2/etc/channel_G.txt"
CHANNEL_B_PATH = r"C:/univer/RTL_prototype/lab2/etc/channel_B.txt"
OUTPUT_PATH    = r"C:/univer/RTL_prototype/lab2/sim_output/out_mask_dump.txt"

SCALE = 10  # коэффициент увеличения для наглядности


def parse_line(line: str):
    """
    Разбирает одну строку файла в список целых чисел 0..255.
    Поддерживает:
      - сплошной бинарный поток без разделителей: "01001101"
      - числа через пробел/табуляцию/запятую/точку с запятой: "15 0 15 0"
      - hex-числа: "0f 00 FF" или "0x0f 0x00 0xFF"
      - сплошной hex-поток без разделителей: "0f0f0f..."
    """
    s = line.strip()

    # 1) Hex с префиксом 0x/0X
    if re.search(r"0[xX][0-9a-fA-F]+", s):
        tokens = re.split(r"[\s,;]+", s)
        return [int(t, 16) for t in tokens if t]

    # 2) Числа, разделённые пробелами/запятыми/точками с запятой
    if re.search(r"[\s,;]", s):
        tokens = [t for t in re.split(r"[\s,;]+", s) if t]
        result = []
        for t in tokens:
            if re.fullmatch(r"[0-9]+", t):
                result.append(int(t, 10))
            elif re.fullmatch(r"[0-9a-fA-F]+", t):
                result.append(int(t, 16))
            else:
                raise ValueError(f"Непонятный токен: '{t}' в строке: {line!r}")
        return result

    # 3) Сплошной бинарный поток из 0/1
    if set(s).issubset({"0", "1"}):
        return [int(ch) for ch in s]

    # 4) Сплошной hex-поток без разделителей
    if set(s).issubset(set("0123456789abcdefABCDEF")):
        if len(s) % 2 != 0:
            raise ValueError(f"Hex-поток нечётной длины в строке: {line!r}")
        return [int(s[i:i+2], 16) for i in range(0, len(s), 2)]

    raise ValueError(f"Не удалось распознать формат строки: {line!r}")


def read_matrix(input_path: str):
    """Читает txt-дамп в матрицу чисел 0..255. Возвращает (matrix, width, height)."""
    if not os.path.exists(input_path):
        print(f"[SKIP] Файл не найден: {input_path}")
        return None

    with open(input_path, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]

    if not lines:
        print(f"[SKIP] Файл пуст: {input_path}")
        return None

    matrix = [parse_line(line) for line in lines]
    width  = len(matrix[0])
    height = len(matrix)

    for i, row in enumerate(matrix):
        if len(row) != width:
            raise ValueError(
                f"{input_path}: строка {i+1} имеет длину {len(row)}, ожидалось {width}"
            )

    for i, row in enumerate(matrix):
        for j, v in enumerate(row):
            if not (0 <= v <= 255):
                raise ValueError(
                    f"{input_path}: значение {v} в строке {i+1}, столбце {j+1} вне 0..255"
                )

    return matrix, width, height


def matrix_to_color_png(matrix, width, height, scale, color_idx, out_path):
    """
    Сохраняет матрицу как цветное PNG, где значения идут в канал color_idx:
      0 -> R, 1 -> G, 2 -> B. Остальные каналы = 0.
    """
    img = Image.new("RGB", (width, height), color=(0, 0, 0))
    pixels = img.load()
    for y, row in enumerate(matrix):
        for x, v in enumerate(row):
            if color_idx == 0:
                pixels[x, y] = (v, 0, 0)
            elif color_idx == 1:
                pixels[x, y] = (0, v, 0)
            else:
                pixels[x, y] = (0, 0, v)
    img_big = img.resize((width * scale, height * scale), Image.NEAREST)
    img_big.save(out_path)
    print(f"  -> {out_path}")


def matrix_to_binary_png(matrix, width, height, scale, out_path):
    """Сохраняет матрицу как чёрно-белое PNG: ненулевое -> белый, ноль -> чёрный."""
    img = Image.new("1", (width, height), color=0)
    pixels = img.load()
    for y, row in enumerate(matrix):
        for x, v in enumerate(row):
            pixels[x, y] = 1 if v != 0 else 0
    img_big = img.resize((width * scale, height * scale), Image.NEAREST).convert("L")
    img_big.save(out_path)
    print(f"  -> {out_path}")


def txt_to_binary_png(input_path: str, scale: int = SCALE):
    """Читает .txt-дамп маски и сохраняет увеличенный чёрно-белый *_big.png."""
    data = read_matrix(input_path)
    if data is None:
        return None
    matrix, width, height = data

    print(f"{os.path.basename(input_path)}: {width} x {height} [binary]")

    output_dir = os.path.dirname(input_path)
    base_name  = os.path.splitext(os.path.basename(input_path))[0]
    out_path = os.path.join(output_dir, f"{base_name}_big.png")

    matrix_to_binary_png(matrix, width, height, scale, out_path)
    return out_path


def channels_to_rgb_png(r_path, g_path, b_path, scale=SCALE):
    """
    Читает три канала (R, G, B) и сохраняет:
      - для каждого канала цветное *_big.png (только в своём цвете);
      - совместное RGB-изображение rgb_big.png рядом с R-файлом.
    """
    r_data = read_matrix(r_path)
    g_data = read_matrix(g_path)
    b_data = read_matrix(b_path)
    if r_data is None or g_data is None or b_data is None:
        print("[SKIP] Не все каналы найдены, RGB-изображение не строится")
        return None

    r_mat, r_w, r_h = r_data
    g_mat, g_w, g_h = g_data
    b_mat, b_w, b_h = b_data

    if (r_w, r_h) != (g_w, g_h) or (r_w, r_h) != (b_w, b_h):
        raise ValueError(
            f"Размеры каналов не совпадают: "
            f"R={r_w}x{r_h}, G={g_w}x{g_h}, B={b_w}x{b_h}"
        )

    width, height = r_w, r_h
    print(f"RGB: {width} x {height}")

    # Отдельные цветные картинки для каждого канала
    for path, mat, idx in (
        (r_path, r_mat, 0),
        (g_path, g_mat, 1),
        (b_path, b_mat, 2),
    ):
        out_dir = os.path.dirname(path)
        base = os.path.splitext(os.path.basename(path))[0]
        matrix_to_color_png(mat, width, height, scale, idx,
                            out_path=os.path.join(out_dir, f"{base}_big.png"))

    # Совместное RGB-изображение
    rgb_img = Image.new("RGB", (width, height), color=(0, 0, 0))
    pixels = rgb_img.load()
    for y in range(height):
        for x in range(width):
            pixels[x, y] = (r_mat[y][x], g_mat[y][x], b_mat[y][x])

    rgb_big = rgb_img.resize((width * scale, height * scale), Image.NEAREST)

    out_dir = os.path.dirname(r_path)
    out_path = os.path.join(out_dir, "rgb_big.png")
    rgb_big.save(out_path)
    print(f"  -> {out_path}")

    return out_path


if __name__ == "__main__":
    # Три канала -> 3 отдельных цветных + 1 общий RGB
    channels_to_rgb_png(CHANNEL_R_PATH, CHANNEL_G_PATH, CHANNEL_B_PATH, SCALE)

    # Выходная маска — только чёрный/белый
    txt_to_binary_png(OUTPUT_PATH, SCALE)