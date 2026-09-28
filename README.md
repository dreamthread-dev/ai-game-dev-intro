# ai-game-dev-intro

DREAM THREAD のブログ連載「AIゲーム開発入門」で制作した作例です。
ボタン1つで遊ぶ、壁を蹴って登る2Dアクションゲームです。

[ブラウザで遊ぶ](https://storage.googleapis.com/godot-html/ai-game-dev-intro/index.html)

## 動かし方

1. [Godot](https://godotengine.org/) 4.7.2 を公式サイトからダウンロードします
2. このリポジトリをクローンし、Godot で `project.godot` を開きます
3. F5 キーで実行します

## 各回の到達点

連載の各回の到達点を、タグで固定しています。タグ名は記事の URL の末尾（slug）と同じです。

| タグ | 内容 |
|---|---|
| `ai-game-dev-coding` | Claude Code でシーンとスクリプトを作成し、単色の図形で遊べる状態 |
| `ai-game-dev-assets` | 絵と効果音を加え、Web 向けに書き出してブラウザで遊べる状態 |

## 素材について

このリポジトリに含まれる絵と効果音は、AI を用いて作成したものです。人が描いた絵や、録音した音ではありません。

| 素材 | 置き場所 | 作成方法 |
|---|---|---|
| 絵 | `art/` | Google Gemini で生成した画像（`art/raw/`）を、`tools/process_art.py` で縮小し、背景を透明にしたもの |
| 効果音 | `audio/sfx/` | Claude Code が作成した GDScript（`tools/generate_sfx.gd`）で波形を計算し、書き出したもの |

- `art/raw/` には、Gemini が出力した画像をそのまま収めています。生成 AI による出力であることを示す情報（透かしやメタデータ）を残すため、手を加えていません
- 絵を加工し直す場合は、Python と Pillow・numpy が必要です（`python tools/process_art.py`）
- 効果音を作り直す場合は、プロジェクトのフォルダで `godot --headless --path . -s res://tools/generate_sfx.gd` を実行してください
- 素材を AI の学習に利用することは、ご遠慮ください

## ライセンス

MIT License です。詳細は [LICENSE](./LICENSE) をご覧ください。
