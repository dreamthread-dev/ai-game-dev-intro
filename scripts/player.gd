class_name Player
extends Area2D
## プレイヤー。ボタン1つで「張り付き／ジャンプ／滑り落ち」を切り替える。
## スタミナ（張り付いていられる時間）を使い果たすと壁から剥がれて落ち、もう操作できない。
## 動かすのは main.gd から毎フレーム呼ばれる step()。
## 見た目の動き（伸び縮み・傾き・震え）は _process() で、状態に合わせて付ける。

signal hit_spike
signal got_coin(coin: Area2D)
## 壁から跳んだとき
signal jumped
## 反対の壁に着いたとき
signal landed
## 張り付きの時間切れで剥がれたとき。このあとは落ちていくだけになる
signal peeled

enum State { STUCK, SLIDING, JUMPING, FALLING }

const SIZE := 48.0
## 絵はどれも「左の壁にいて、右を向いている」向きで描かれている。右の壁では左右反転する
const TEX_STICK := preload("res://art/player_stick.png")
const TEX_JUMP := preload("res://art/player_jump.png")
const TEX_SLIDE := preload("res://art/player_slide.png")

## ジャンプの速さ（x: 横方向, y: 上方向）
@export var jump_speed := Vector2(1100.0, 900.0)
## ジャンプ中にかかる重力（px/秒^2）
@export var fall_gravity := 1800.0
## 着地したときにボタンを押していないと、壁沿いを滑り落ちる。その速さ（px/秒）
@export var slide_speed := 250.0
## 1つの壁に張り付いていられる秒数
@export var stick_limit := 1.2

@export_group("見た目の動き")
## 張り付き中に息をする速さと大きさ
@export var breath_speed := 4.0
@export var breath_amount := 0.04
## 跳んだとき・着いたときに伸び縮みする大きさと、元に戻る速さ
@export var squash_amount := 0.25
@export var squash_recover := 5.0
## ジャンプ中に傾ける角度（ラジアン。0.2 で約11度）
@export var jump_tilt := 0.2
## 滑り落ち中に震える幅（px）
@export var slide_shake := 1.5

var state := State.STUCK
var velocity := Vector2.ZERO
## 今の壁に張り付いていた合計時間。反対の壁に着くと 0 に戻る
var stick_time := 0.0
var on_left := true
var _left_x := 0.0
var _right_x := 0.0
var _anim_time := 0.0
## 伸び縮みの量。正でつぶれる（横に広がる）、負で縦に伸びる。0 に向かって戻っていく
var _squash := 0.0

@onready var gauge: ColorRect = $StickGauge
@onready var visual: Sprite2D = $Visual
@onready var dust: CPUParticles2D = $Dust
@onready var _base_scale := visual.scale


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## 左右の壁の内側の x 座標を受け取る
func setup(left_wall_x: float, right_wall_x: float) -> void:
	_left_x = left_wall_x + SIZE / 2.0
	_right_x = right_wall_x - SIZE / 2.0


func reset(start_y: float) -> void:
	on_left = true
	position = Vector2(_left_x, start_y)
	velocity = Vector2.ZERO
	stick_time = 0.0
	state = State.STUCK
	_squash = 0.0
	_update_gauge()
	set_process(true)


## ゲームオーバーのときに呼ぶ。見た目の動きと砂ぼこりを止める
func stop_animation() -> void:
	set_process(false)
	dust.emitting = false


## 1フレーム分動かす。scroll_dy はこのフレームに世界が下へ流れた量
func step(delta: float, scroll_dy: float) -> void:
	var pressed := Input.is_action_pressed("tap")

	match state:
		State.STUCK:
			stick_time += delta
			if not pressed:
				_jump()
			elif stick_time >= stick_limit:
				state = State.FALLING
				velocity = Vector2.ZERO
				peeled.emit()
		State.SLIDING:
			if Input.is_action_just_released("tap"):
				_jump()
			elif pressed and stick_time < stick_limit:
				state = State.STUCK
		State.JUMPING:
			velocity.y += fall_gravity * delta
			position += velocity * delta
			var target_x := _left_x if on_left else _right_x
			if (velocity.x < 0.0 and position.x <= target_x) or (velocity.x > 0.0 and position.x >= target_x):
				_land(target_x, pressed)
		State.FALLING:
			# スタミナ切れ。ボタンには反応せず、画面の下まで落ちていく
			velocity.y += fall_gravity * delta
			position.y += velocity.y * delta

	# プレイヤーは世界の中にいるので、世界と一緒に下へ流れる
	position.y += scroll_dy
	if state == State.SLIDING:
		position.y += slide_speed * delta
	_update_gauge()


func _jump() -> void:
	on_left = not on_left
	velocity = Vector2(-jump_speed.x if on_left else jump_speed.x, -jump_speed.y)
	state = State.JUMPING
	_squash = -1.0
	jumped.emit()


func _land(target_x: float, pressed: bool) -> void:
	position.x = target_x
	velocity = Vector2.ZERO
	stick_time = 0.0
	state = State.STUCK if pressed else State.SLIDING
	_squash = 1.0
	landed.emit()


## 張り付いた時間の割合。0（張り付いた直後）〜 1（時間切れ）
func stick_ratio() -> float:
	return clampf(stick_time / stick_limit, 0.0, 1.0)


func _process(delta: float) -> void:
	_anim_time += delta
	_squash = move_toward(_squash, 0.0, squash_recover * delta)
	var stretch := Vector2(1.0 + _squash * squash_amount, 1.0 - _squash * squash_amount)
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	visual.flip_h = not on_left

	match state:
		State.STUCK:
			visual.texture = TEX_STICK
			var breath := sin(_anim_time * breath_speed) * breath_amount
			stretch += Vector2(-breath, breath)
		State.JUMPING:
			visual.texture = TEX_JUMP
			visual.flip_h = velocity.x < 0.0
			visual.rotation = jump_tilt * signf(velocity.x)
		State.SLIDING:
			visual.texture = TEX_SLIDE
			visual.position.x = randf_range(-slide_shake, slide_shake)
		State.FALLING:
			visual.texture = TEX_SLIDE

	visual.scale = _base_scale * stretch
	# 砂ぼこりは壁に接している側から出す
	dust.position.x = -SIZE / 2.0 if on_left else SIZE / 2.0
	dust.emitting = state == State.SLIDING


## 頭の上のバーで、張り付いていられる残り時間（スタミナ）を示す。
## 満タンは緑、減るにつれて黄色を通って赤に変わる
func _update_gauge() -> void:
	var remaining := 1.0 if state == State.JUMPING else 1.0 - stick_ratio()
	if state == State.FALLING:
		remaining = 0.0
	gauge.size.x = SIZE * remaining
	# 色相を 緑(1/3) → 赤(0) へ動かす。RGB のまま混ぜると途中が濁った茶色になるため
	gauge.color = Color.from_hsv(remaining / 3.0, 0.85, 0.95, 0.9)


func _on_area_entered(area: Area2D) -> void:
	var drop: Area2D = area
	var kind: Variant = drop.get("kind")
	if kind == 0:
		hit_spike.emit()
	else:
		got_coin.emit(drop)
