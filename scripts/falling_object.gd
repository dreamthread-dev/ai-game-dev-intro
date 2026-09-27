class_name FallingObject
extends Area2D
## 上から降ってくるもの（コインとトゲで共通）。
## 動かすのは main.gd から毎フレーム呼ばれる advance()。

enum Kind { COIN, SPIKE }

@export var kind := Kind.COIN
## 世界のスクロールに加えて、自分で落ちる速さ（px/秒）
@export var fall_speed := 150.0
## この高さより下に出たら自分を消す
@export var despawn_y := 1360.0


func advance(delta: float, scroll_dy: float) -> void:
	position.y += fall_speed * delta + scroll_dy
	if position.y > despawn_y:
		queue_free()
