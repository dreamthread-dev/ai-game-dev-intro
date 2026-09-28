extends Node2D
## ゲーム全体の進行役。
## 状態の切り替え、スクロール、ステージ、スコア、落下物の出現、乱数の seed を管理する。

enum GameState { READY, PLAYING, STAGE_CLEAR, GAME_OVER }

const SCREEN_SIZE := Vector2(720, 1280)
const WALL_WIDTH := 60.0
const COIN_SCENE := preload("res://scenes/coin.tscn")
const SPIKE_SCENE := preload("res://scenes/spike.tscn")

## 0 以外にすると、その値を seed に使う（同じ配置を再現したいとき用）
@export var fixed_seed := 0
## 自動で下へ流れる速さ（px/秒）
@export var base_scroll_speed := 200.0
## 1ステージで登る距離（px）。この距離の先に渡り廊下があり、触れるとクリア
@export var stage_length := 6000.0
## プレイヤーがこの高さより上に来たら、その分だけ余計にスクロールする
@export var push_line_y := 450.0
## プレイヤーの開始位置の高さ
@export var player_start_y := 900.0
## ステージ開始から落下物が出始めるまでの秒数
@export var start_grace := 1.5
## ステージ1の出現間隔（秒）
@export var base_spawn_interval := 1.0
## ステージが1つ進むごとに出現間隔に掛ける倍率
@export var spawn_interval_rate := 0.9
## 出現間隔の下限（秒）
@export var min_spawn_interval := 0.35
## 落下物のうちコインになる割合
@export_range(0.0, 1.0) var coin_ratio := 0.6
## 落下物を出す位置の、壁からの余白
@export var spawn_margin := 30.0
## 町並みが下へはける速さ。登った距離に掛ける倍率（0 で動かない、1 で壁と同じ速さ）
@export_range(0.0, 1.0) var town_parallax := 0.2
## ステージクリア後、次のステージが始まるまでの秒数
@export var clear_pause := 1.0
## ゲームオーバー後、リトライを受け付けるまでの秒数（誤タップ防止）
@export var retry_delay := 0.5

var state := GameState.READY
var rng := RandomNumberGenerator.new()
var current_seed := 0
var stage := 1
var score := 0
var climbed := 0.0
var _wait := 0.0

@onready var walls = $Walls
@onready var summit: TextureRect = $Summit
@onready var town: TextureRect = $Town
@onready var _town_top := town.position.y
@onready var drops: Node2D = $Drops
@onready var player: Player = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud = $HUD
@onready var sfx = $Sfx


func _ready() -> void:
	player.setup(WALL_WIDTH, SCREEN_SIZE.x - WALL_WIDTH)
	player.hit_spike.connect(_on_player_hit_spike)
	player.got_coin.connect(_on_player_got_coin)
	player.jumped.connect(sfx.play.bind("jump"))
	player.landed.connect(sfx.play.bind("land"))
	player.peeled.connect(sfx.play.bind("peel"))
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_reset_game()


func _physics_process(delta: float) -> void:
	match state:
		GameState.READY:
			if Input.is_action_just_pressed("tap"):
				_start_stage()
		GameState.PLAYING:
			_update_play(delta)
		GameState.STAGE_CLEAR:
			_wait -= delta
			if _wait <= 0.0:
				stage += 1
				_start_stage()
		GameState.GAME_OVER:
			_wait -= delta
			if _wait <= 0.0 and Input.is_action_just_pressed("tap"):
				_reset_game()
				_start_stage()


## 1フレーム分ゲームを進める
func _update_play(delta: float) -> void:
	var scroll_dy := base_scroll_speed * delta
	player.step(delta, scroll_dy)
	if player.state == Player.State.STUCK:
		sfx.update_charge(player.stick_ratio())
	else:
		sfx.stop_charge()

	# プレイヤーが上に行きすぎたら、その分だけ世界を下へ流して画面内に留める
	if player.position.y < push_line_y:
		scroll_dy += push_line_y - player.position.y
		player.position.y = push_line_y

	walls.scroll(scroll_dy)
	for drop: FallingObject in drops.get_children():
		drop.advance(delta, scroll_dy)
	climbed += scroll_dy
	_update_summit()
	_update_town()

	if player.position.y - player.SIZE / 2.0 > SCREEN_SIZE.y:
		_game_over()
	elif _touching_summit():
		_stage_clear()


func _reset_game() -> void:
	current_seed = fixed_seed if fixed_seed != 0 else randi()
	rng.seed = current_seed
	stage = 1
	score = 0
	climbed = 0.0
	state = GameState.READY
	spawn_timer.stop()
	_clear_drops()
	_update_summit()
	_update_town()
	player.reset(player_start_y)
	hud.set_stage(stage)
	hud.set_score(score)
	hud.set_seed(current_seed)
	hud.show_message("TAP TO START")
	print("[main] reset seed=%d" % current_seed)


func _start_stage() -> void:
	state = GameState.PLAYING
	climbed = 0.0
	_clear_drops()
	_update_summit()
	_update_town()
	# 最初の出現だけ start_grace 秒待つ。以降は _on_spawn_timer_timeout で間隔を切り替える
	spawn_timer.start(start_grace)
	hud.set_stage(stage)
	hud.show_message("STAGE %d" % stage, 1.0)
	if stage == 1:
		sfx.play("start")
	print("[main] stage %d start (interval %.2fs)" % [stage, _spawn_interval()])


func _stage_clear() -> void:
	state = GameState.STAGE_CLEAR
	spawn_timer.stop()
	_wait = clear_pause
	sfx.stop_charge()
	sfx.play("stage_clear")
	hud.show_message("STAGE %d\nCLEAR!" % stage)
	print("[main] stage %d clear score=%d" % [stage, score])


func _game_over() -> void:
	state = GameState.GAME_OVER
	spawn_timer.stop()
	_wait = retry_delay
	player.stop_animation()
	sfx.stop_charge()
	sfx.play("game_over")
	hud.show_message("GAME OVER\nSCORE %d\n\nTAP TO RETRY" % score)
	print("[main] game over stage=%d score=%d" % [stage, score])


func _spawn_interval() -> float:
	return maxf(min_spawn_interval, base_spawn_interval * pow(spawn_interval_rate, stage - 1))


func _spawn_drop() -> void:
	var scene := COIN_SCENE if rng.randf() < coin_ratio else SPIKE_SCENE
	var drop: Node2D = scene.instantiate()
	var min_x := WALL_WIDTH + spawn_margin
	var max_x := SCREEN_SIZE.x - WALL_WIDTH - spawn_margin
	drop.position = Vector2(rng.randf_range(min_x, max_x), -40.0)
	drops.add_child(drop)


func _clear_drops() -> void:
	for drop in drops.get_children():
		drop.queue_free()


## 渡り廊下の位置を、残りの距離から決める。残りが 0 になると push_line_y にいるプレイヤーの頭の高さに来る。
## その先も世界と一緒に下へ流れてくるので、跳んで触れればクリアになる
func _update_summit() -> void:
	var remaining := stage_length - climbed
	summit.position.y = push_line_y - player.SIZE / 2.0 - remaining - summit.size.y


## プレイヤーの頭が渡り廊下の下の端に届いたか
func _touching_summit() -> bool:
	return player.position.y - player.SIZE / 2.0 <= summit.position.y + summit.size.y


## 町並みを、このステージで登った距離に合わせて画面の下へずらす。見えなくなったら描かない。
## ステージが始まるたびに元の位置に戻る
func _update_town() -> void:
	town.position.y = _town_top + climbed * town_parallax
	town.visible = town.position.y < SCREEN_SIZE.y


func _on_spawn_timer_timeout() -> void:
	if state != GameState.PLAYING:
		return
	var interval := _spawn_interval()
	if not is_equal_approx(spawn_timer.wait_time, interval):
		spawn_timer.start(interval)
	_spawn_drop()


func _on_player_hit_spike() -> void:
	if state == GameState.PLAYING:
		sfx.play("hit")
		_game_over()


func _on_player_got_coin(coin: Area2D) -> void:
	if state != GameState.PLAYING or coin.is_queued_for_deletion():
		return
	score += 1
	sfx.play("coin")
	hud.set_score(score)
	coin.queue_free()
