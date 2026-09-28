"""画像生成 AI で作った絵（art/raw/）を、ゲームで使える形に加工して art/ に書き出す。

実行方法（プロジェクトのフォルダで）:
    python tools/process_art.py

やること:
- マゼンタ（#FF00FF）の背景を透明にする
- プレイヤーの3ポーズを切り分ける
- 画面に出す大きさの2倍に縮小する（大きめのスマホでもぼやけないように）
- 壁の上下のつなぎ目をなじませる
必要なもの: Pillow, numpy
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "art" / "raw"
OUT = ROOT / "art"

# 画面上の大きさに掛ける倍率
SCALE = 2


def load_rgb(name: str) -> np.ndarray:
    return np.asarray(Image.open(RAW / name).convert("RGB"), dtype=np.float32)


def key_magenta(rgb: np.ndarray) -> np.ndarray:
    """マゼンタの背景を透明にして RGBA を返す。

    「赤と青のうち小さいほう − 緑」が大きいほどマゼンタに近い。
    輪郭のにじみ（マゼンタと混ざった色）は、混ざる前の色に戻してから半透明にする。
    """
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magentaness = np.minimum(r, b) - g
    # 80 以下は完全に不透明、160 以上は完全に透明、その間はなめらかにつなぐ。
    # 生成された背景は場所によって少し色がずれるので、透明にする範囲を広めにとっている
    alpha = np.clip((160.0 - magentaness) / 80.0, 0.0, 1.0)
    alpha[alpha < 0.1] = 0.0  # ほとんど透明な点は、完全に透明にする

    # 色 = 元の色 × a + マゼンタ × (1 − a) を、元の色について解く
    magenta = np.array([255.0, 0.0, 255.0])
    a = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - magenta * (1.0 - a)) / a, 0.0, 255.0)
    return np.dstack([color, alpha * 255.0])


def remove_specks(rgba: np.ndarray, min_size: int) -> np.ndarray:
    """背景に混じった小さな点（生成のゴミ）を消す。縦横とも min_size 未満のかたまりが対象"""
    opaque = rgba[..., 3] > 0
    cols = np.where(opaque.any(axis=0))[0]
    out = rgba.copy()
    for x0, x1 in runs(cols):
        rows = np.where(opaque[:, x0:x1 + 1].any(axis=1))[0]
        for y0, y1 in runs(rows):
            sub_cols = np.where(opaque[y0:y1 + 1, x0:x1 + 1].any(axis=0))[0]
            if sub_cols[-1] - sub_cols[0] + 1 < min_size and y1 - y0 + 1 < min_size:
                out[y0:y1 + 1, x0:x1 + 1, 3] = 0
    return out


def runs(indices: np.ndarray) -> list[tuple[int, int]]:
    """連続した番号のまとまりを (始め, 終わり) の組にする"""
    if len(indices) == 0:
        return []
    splits = np.where(np.diff(indices) > 1)[0]
    starts = np.concatenate([[indices[0]], indices[splits + 1]])
    ends = np.concatenate([indices[splits], [indices[-1]]])
    return list(zip(starts.tolist(), ends.tolist()))


def bbox(rgba: np.ndarray) -> tuple[int, int, int, int]:
    """不透明な部分を囲む四角 (左, 上, 右, 下)。右と下は含まない"""
    opaque = rgba[..., 3] > 8
    ys = np.where(opaque.any(axis=1))[0]
    xs = np.where(opaque.any(axis=0))[0]
    return int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1


def to_image(rgba: np.ndarray) -> Image.Image:
    return Image.fromarray(np.round(rgba).astype(np.uint8), "RGBA")


def resize(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    # 透明な部分の色がにじまないよう、色に不透明度を掛けてから縮小し、あとで戻す
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def fit_center(img: Image.Image, box: int) -> Image.Image:
    """box x box の透明な正方形の真ん中に、縦横比を保って収める"""
    scale = box / max(img.width, img.height)
    small = resize(img, (max(1, round(img.width * scale)), max(1, round(img.height * scale))))
    canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((box - small.width) // 2, (box - small.height) // 2))
    return canvas


def add_glow(img: Image.Image, color: tuple[int, int, int], pad: int) -> Image.Image:
    """絵のまわりに色の光を付ける。暗い背景でも形が見えるようにするため"""
    inner = fit_center(img, img.width - pad * 2)
    canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
    canvas.alpha_composite(inner, (pad, pad))
    spread = canvas.getchannel("A").filter(ImageFilter.MaxFilter(pad + 1 if pad % 2 == 0 else pad))
    spread = spread.filter(ImageFilter.GaussianBlur(pad / 3))
    glow = Image.new("RGBA", img.size, color + (0,))
    glow.putalpha(spread)
    glow.alpha_composite(canvas)
    return glow


def save(img: Image.Image, name: str) -> None:
    img.save(OUT / name, optimize=True)
    print(f"{name:20s} {img.width}x{img.height}（画面上 {img.width // SCALE}x{img.height // SCALE}）")


def process_player() -> None:
    """3ポーズを左から 張り付き・ジャンプ・滑り落ち として切り分け、同じ倍率で縮小する。
    絵はどれも「左の壁にいて、右を向いている」向きにそろえる。
    生成された滑り落ちの絵だけ向きが逆だったので、左右反転する。
    """
    rgba = remove_specks(key_magenta(load_rgb("player.jpg")), min_size=60)
    opaque_cols = np.where((rgba[..., 3] > 128).any(axis=0))[0]
    poses = [r for r in runs(opaque_cols) if r[1] - r[0] > 100]
    assert len(poses) == 3, f"ポーズが3つに分かれませんでした（{len(poses)}個）"

    crops = []
    for x0, x1 in poses:
        part = rgba[:, x0:x1 + 1]
        l, t, r, b = bbox(part)
        crops.append(to_image(part[t:b, l:r]))
    crops[2] = crops[2].transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    # 3枚とも同じ倍率にして、キャラの大きさがポーズごとに変わらないようにする
    box = 72 * SCALE
    scale = box / max(max(c.width, c.height) for c in crops)
    for crop, name in zip(crops, ["player_stick.png", "player_jump.png", "player_slide.png"]):
        small = resize(crop, (round(crop.width * scale), round(crop.height * scale)))
        canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
        canvas.alpha_composite(small, ((box - small.width) // 2, (box - small.height) // 2))
        save(canvas, name)
    print(f"  （画面上 {box // SCALE}x{box // SCALE} の枠の中に収めている）")


def process_sprite(src: str, dst: str, height: int | None = None, box: int | None = None,
                   glow: tuple[int, int, int] | None = None) -> None:
    rgba = remove_specks(key_magenta(load_rgb(src)), min_size=60)
    l, t, r, b = bbox(rgba)
    img = to_image(rgba[t:b, l:r])
    if height is not None:
        img = resize(img, (round(img.width * height * SCALE / img.height), height * SCALE))
    else:
        img = fit_center(img, box * SCALE)
    if glow is not None:
        img = add_glow(img, glow, pad=6)
    save(img, dst)


def process_summit() -> None:
    """幅 600 に合わせる。絵の下の端がゴールの線になる"""
    rgba = remove_specks(key_magenta(load_rgb("summit.jpg")), min_size=60)
    l, t, r, b = bbox(rgba)
    img = to_image(rgba[t:b, l:r])
    width = 600 * SCALE
    save(resize(img, (width, round(img.height * width / img.width))), "summit.png")


def process_background() -> None:
    """9:16 に切りそろえて 720x1280 の2倍にし、空（background.png）と町並み（town.png）に分ける"""
    img = Image.open(RAW / "background.jpg").convert("RGB")
    target_w = round(img.height * 9 / 16)
    if target_w <= img.width:
        left = (img.width - target_w) // 2
        img = img.crop((left, 0, left + target_w, img.height))
    else:
        target_h = round(img.width * 16 / 9)
        top = (img.height - target_h) // 2
        img = img.crop((0, top, img.width, top + target_h))
    img = img.resize((720 * SCALE, 1280 * SCALE), Image.LANCZOS)
    sky_img, town_img = split_town(np.asarray(img, dtype=np.float32))
    save(sky_img, "background.png")
    save(town_img, "town.png")


# 町並みは画面の上から 950 より下に描かれている（画面上の座標）
TOWN_TOP = 950


def split_town(rgb: np.ndarray) -> tuple[Image.Image, Image.Image]:
    """背景を、町並みのない空と、町並みだけの透明な絵に分ける。

    空は上から下へなめらかに色が変わるだけなので、町並みより上の空の行から
    「高さ → 色」の式（2次式）を求め、町並みの部分の空の色を推し量る。
    その空の色から離れた点を町並みとみなす。
    """
    h, w, _ = rgb.shape
    top = TOWN_TOP * SCALE
    # 雲と月より下、町並みより上の行だけを使う
    fit_rows = np.arange(550 * SCALE, 970 * SCALE)
    row_color = rgb[fit_rows].mean(axis=1)
    sky = np.stack([np.polyval(np.polyfit(fit_rows, row_color[:, c], 2), np.arange(h)) for c in range(3)], axis=1)
    sky = sky[:, None, :].astype(np.float32)

    # 空の色との差が 7 以下は空、13 以上は町並み、その間は半透明にする
    diff = np.abs(rgb - sky).max(axis=2)
    alpha = np.clip((diff - 7.0) / 6.0, 0.0, 1.0)
    alpha[:top] = 0.0
    alpha_img = Image.fromarray(np.round(alpha * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))
    alpha = np.asarray(alpha_img, dtype=np.float32) / 255.0

    # 輪郭の色は空と混ざっているので、key_magenta と同じ考え方で混ざる前の色に戻す
    a = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - sky * (1.0 - a)) / a, 0.0, 255.0)
    town = np.dstack([color, alpha * 255.0])[top:]

    sky_rgb = rgb.copy()
    sky_rgb[top:] = np.broadcast_to(sky[top:], sky_rgb[top:].shape)
    return Image.fromarray(np.clip(sky_rgb, 0, 255).astype(np.uint8), "RGB"), to_image(town)


def process_wall() -> None:
    """石垣から縦長に切り出し、上下がつながるようにして、夜らしく少し暗くする"""
    src = load_rgb("wall.jpg")
    h, w, _ = src.shape
    strip_w = 500  # 元の絵で、石がおよそ2個分横に並ぶ幅
    overlap = 160  # つなぎ目をなじませる高さ
    x0 = (w - strip_w) // 2
    strip = src[:, x0:x0 + strip_w]
    tile_h = h - overlap

    # 下のはみ出し部分を、上の端へ少しずつ重ねる。こうすると下の端と上の端の続きがそろう
    tile = strip[:tile_h].copy()
    t = np.linspace(0.0, 1.0, overlap)[:, None, None]
    tile[:overlap] = strip[tile_h:] * (1.0 - t) + strip[:overlap] * t

    tile *= np.array([0.78, 0.8, 0.9])  # 少し暗く、青みを足す
    img = Image.fromarray(np.clip(tile, 0, 255).astype(np.uint8), "RGB")
    width = 60 * SCALE
    height = round(tile_h * width / strip_w)
    save(img.resize((width, height), Image.LANCZOS), "wall.png")


def main() -> None:
    process_player()
    process_sprite("coin.jpg", "coin.png", height=44)
    # トゲは暗い色で夜の背景に溶けるので、赤い光で囲んで危険だと分かるようにする
    process_sprite("spike.jpg", "spike.png", box=48, glow=(255, 70, 70))
    process_summit()
    process_background()
    process_wall()


if __name__ == "__main__":
    main()
