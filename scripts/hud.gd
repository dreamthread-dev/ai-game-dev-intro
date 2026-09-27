extends CanvasLayer
## 画面表示。ステージ番号・スコア・seed・中央のメッセージ。

@onready var stage_label: Label = $StageLabel
@onready var score_label: Label = $ScoreLabel
@onready var seed_label: Label = $SeedLabel
@onready var message_label: Label = $MessageLabel

var _message_time := 0.0


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message_label.visible = false


func set_stage(stage: int) -> void:
	stage_label.text = "STAGE %d" % stage


func set_score(score: int) -> void:
	score_label.text = "SCORE %d" % score


func set_seed(value: int) -> void:
	seed_label.text = "SEED %d" % value


## duration が 0 のときは、次のメッセージが来るまで出しっぱなしにする
func show_message(text: String, duration := 0.0) -> void:
	message_label.text = text
	message_label.visible = true
	_message_time = duration
