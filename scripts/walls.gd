extends Node2D
## 左右の壁。石垣の絵を縦に並べて下へ流し、登っているように見せる。
## 絵1枚分だけずれたら元の位置に戻すので、どこまで登っても途切れない。

@export var screen_height := 1280.0

## 絵1枚の、画面上での高さ
var _tile_height := 0.0
var _offset := 0.0

@onready var walls: Array[TextureRect] = [$LeftWall, $RightWall]


func _ready() -> void:
	var wall := walls[0]
	_tile_height = wall.texture.get_height() * wall.scale.y
	# 画面の高さより絵1枚分長くしておき、ずらしても下に隙間ができないようにする
	for w in walls:
		w.size.y = (screen_height + _tile_height) / w.scale.y
	_layout()


## 世界が下へ dy だけ流れたときに呼ぶ
func scroll(dy: float) -> void:
	_offset = fposmod(_offset + dy, _tile_height)
	_layout()


func _layout() -> void:
	for w in walls:
		w.position.y = _offset - _tile_height
