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

| 回 | タグ | 内容 | 制作の記録 |
|---|---|---|---|
| 第2回 | （コードなし） | 何を作るかを AI と決めた回です | [企画](sessions/ai-game-dev-planning.md) |
| 第3回 | `ai-game-dev-coding` | Claude Code でシーンとスクリプトを作成し、単色の図形で遊べる状態 | [実装](sessions/ai-game-dev-coding.md) |
| 第4回 | `ai-game-dev-sound` | 完成版（効果音は `audio/sfx/` と `tools/generate_sfx.gd`） | [効果音](sessions/ai-game-dev-sound.md) |
| 第5回 | `ai-game-dev-art` | 完成版（絵は `art/`、加工は `tools/process_art.py`） | [絵](sessions/ai-game-dev-art.md) |
| 第6回 | `ai-game-dev-publish` | 完成版（Web 向けの書き出し設定は `export_presets.cfg`） | [書き出して公開](sessions/ai-game-dev-publish.md) |

- 第4〜6回のタグは、どれも同じコミット（完成版）を指しています。効果音・絵・Web 向けの書き出しは1回の作業でまとめて加えたため、途中の回の時点だけのコードはありません
- `ai-game-dev-assets` は、第4〜6回を1回にまとめていたときのタグ名です。同じコミットを指しています

## 制作の記録

`sessions/` には、連載の各回で AI とやり取りした内容を、回ごとに1ファイルで収めています。

- Claude Code のセッションログから、ユーザーの入力と AI が画面に表示した文章を、全文そのまま取り出したものです
- AI がファイルを読み書きしたり、コマンドを実行したりした操作は、1行ずつの要約にしています。実行結果は含みません
- AI の内部の思考は含みません。英語で表示された文章は英語のままです
- 個人のフォルダーのパスは `~` に置き換えています
- 第5回の記録には、画像を生成したときの Gemini とのやり取り（共有リンクから取り出したもの）も含みます
- Godot がこのフォルダを読み込まないよう、空の `.gdignore` を置いています

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
