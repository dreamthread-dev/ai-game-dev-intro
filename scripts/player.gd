class_name Player
extends Area2D
## プレイヤー。ボタン1つで「張り付き／ジャンプ／滑り落ち」を切り替える。
## 動かすのは main.gd から毎フレーム呼ばれる step()。

signal hit_spike
signal got_coin(coin: Area2D)

enum State { STUCK, SLIDING, JUMPING }

const SIZE := 48.0

## ジャンプの速さ（x: 横方向, y: 上方向）
@export var jump_speed := Vector2(1100.0, 900.0)
## ジャンプ中にかかる重力（px/秒^2）
@export var fall_gravity := 1800.0
## 剥がれたとき・押していないときに壁沿いを滑り落ちる速さ（px/秒）
@export var slide_speed := 250.0
## 1つの壁に張り付いていられる秒数
@export var stick_limit := 1.2

var state := State.STUCK
var velocity := Vector2.ZERO
## 今の壁に張り付いていた合計時間。反対の壁に着くと 0 に戻る
var stick_time := 0.0
var on_left := true
var _left_x := 0.0
var _right_x := 0.0

@onready var gauge: ColorRect = $StickGauge


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
	_update_gauge()


## 1フレーム分動かす。scroll_dy はこのフレームに世界が下へ流れた量
func step(delta: float, scroll_dy: float) -> void:
	var pressed := Input.is_action_pressed("tap")

	match state:
		State.STUCK:
			stick_time += delta
			if not pressed:
				_jump()
			elif stick_time >= stick_limit:
				state = State.SLIDING
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

	# プレイヤーは世界の中にいるので、世界と一緒に下へ流れる
	position.y += scroll_dy
	if state == State.SLIDING:
		position.y += slide_speed * delta
	_update_gauge()


func _jump() -> void:
	on_left = not on_left
	velocity = Vector2(-jump_speed.x if on_left else jump_speed.x, -jump_speed.y)
	state = State.JUMPING


func _land(target_x: float, pressed: bool) -> void:
	position.x = target_x
	velocity = Vector2.ZERO
	stick_time = 0.0
	state = State.STUCK if pressed else State.SLIDING


## 頭の上のバーで、張り付いていられる残り時間を示す
func _update_gauge() -> void:
	var ratio := 1.0 if state == State.JUMPING else clampf(1.0 - stick_time / stick_limit, 0.0, 1.0)
	gauge.size.x = SIZE * ratio


func _on_area_entered(area: Area2D) -> void:
	var drop := area as FallingObject
	if drop == null:
		return
	if drop.kind == FallingObject.Kind.SPIKE:
		hit_spike.emit()
	else:
		got_coin.emit(drop)
