extends Node2D
## 左右の壁。縞模様の四角を並べて下へ流し、登っているように見せる。

@export var wall_width := 60.0
@export var screen_height := 1280.0
@export var stripe_height := 80.0
@export var stripe_colors: Array[Color] = [Color(0.32, 0.34, 0.4), Color(0.24, 0.26, 0.31)]

## 縞の模様は2本で1周するので、0 〜 stripe_height * 2 の範囲で回す
var _offset := 0.0
var _stripes: Array[ColorRect] = []


func _ready() -> void:
	var count := int(ceil(screen_height / stripe_height)) + 2
	for wall in [$LeftWall, $RightWall]:
		for i in count:
			var stripe := ColorRect.new()
			stripe.size = Vector2(wall_width, stripe_height)
			stripe.color = stripe_colors[i % stripe_colors.size()]
			stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wall.add_child(stripe)
			_stripes.append(stripe)
	_layout()


## 世界が下へ dy だけ流れたときに呼ぶ
func scroll(dy: float) -> void:
	_offset = fposmod(_offset + dy, stripe_height * 2.0)
	_layout()


func _layout() -> void:
	for stripe in _stripes:
		var i := stripe.get_index()
		stripe.position.y = (i - 2) * stripe_height + _offset
