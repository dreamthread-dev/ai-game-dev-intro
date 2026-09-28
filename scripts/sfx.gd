extends Node
## 効果音の再生役。play("coin") のように名前を指定して鳴らす。
## 短い音は複数のプレイヤーを順番に使うので、重なっても前の音が途切れない。
## チャージ音だけは専用の Charge で鳴らし、張り付いている間に高さを下げていく。

const SOUND_DIR := "res://audio/sfx/"
const ONE_SHOT_NAMES := ["jump", "land", "coin", "hit", "game_over", "stage_clear", "peel", "start"]

## 全体の音量（dB）。0 がそのまま、-6 で半分くらいの大きさ
@export_range(-40.0, 6.0) var volume_db := 0.0
## 短い音を同時に鳴らせる数
@export var one_shot_count := 8
## 張り付いた直後のチャージ音の高さ（倍率）。時間切れに向かって 1.0 まで下がる
@export var charge_pitch_high := 1.8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

@onready var charge: AudioStreamPlayer = $Charge


func _ready() -> void:
	for sound_name in ONE_SHOT_NAMES:
		_streams[sound_name] = load(SOUND_DIR + sound_name + ".wav")
	for i in one_shot_count:
		var player := AudioStreamPlayer.new()
		player.name = "OneShot%d" % (i + 1)
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)
	charge.stream = load(SOUND_DIR + "charge_loop.wav")
	charge.volume_db = volume_db


func play(sound_name: String) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound_name]
	player.play()


## 張り付いている間、毎フレーム呼ぶ。ratio は 0（張り付いた直後）〜 1（時間切れ）
func update_charge(ratio: float) -> void:
	charge.pitch_scale = lerpf(charge_pitch_high, 1.0, clampf(ratio, 0.0, 1.0))
	if not charge.playing:
		charge.play()


func stop_charge() -> void:
	if charge.playing:
		charge.stop()
