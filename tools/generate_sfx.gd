extends SceneTree
## 効果音をコードで合成して .wav に書き出すツール（ゲーム本体では使わない）。
## 実行方法（プロジェクトのフォルダで）:
##   godot --headless --path . -s res://tools/generate_sfx.gd
## 出力先: res://audio/sfx/
## 音を変えたいときは、下の各関数の数値（周波数・長さ・減衰の速さ）を変えて実行し直す。

const RATE := 44100
const OUT_DIR := "res://audio/sfx/"

## ノイズを毎回同じにするため seed を固定する
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# 第3引数は音量（波形の最大値）。音ごとの聞こえ方のバランスをここでそろえる
	_save("jump", _jump(), 0.48)
	_save("land", _land(), 0.5)
	_save("coin", _coin(), 0.55)
	_save("hit", _hit(), 0.8)
	_save("game_over", _game_over(), 0.6)
	_save("stage_clear", _stage_clear(), 0.6)
	_save("peel", _peel(), 0.55)
	_save("start", _start(), 0.55)
	_save("charge_loop", _charge_loop(), 0.35, true)
	quit()


# ---- 各効果音 ----

## 1. ジャンプ：上がっていく短い音
func _jump() -> PackedFloat32Array:
	var body := _tone(0.18, 280.0, 820.0, "square", 0.004, 18.0)
	body = _mix(_lowpass(body, 3000.0), _tone(0.18, 280.0, 820.0, "sine", 0.004, 18.0), 0.5)
	return body


## 2. 壁に着く：低く短い「トン」
func _land() -> PackedFloat32Array:
	var thump := _tone(0.09, 200.0, 80.0, "sine", 0.001, 45.0)
	return _mix(thump, _lowpass(_noise(0.05, 80.0), 1200.0), 0.6)


## 3. コイン：高い2音（シ → ミ）
func _coin() -> PackedFloat32Array:
	var first := _tone(0.07, 988.0, 988.0, "square", 0.002, 10.0)
	var second := _tone(0.25, 1319.0, 1319.0, "square", 0.002, 14.0)
	return _lowpass(_concat(first, second), 5000.0)


## 4. トゲに当たる：低く重い衝撃音
func _hit() -> PackedFloat32Array:
	var thump := _tone(0.35, 140.0, 45.0, "sine", 0.002, 10.0)
	var crunch := _lowpass(_noise(0.2, 25.0), 900.0)
	return _drive(_mix(thump, crunch, 0.8), 1.8)


## 5. ゲームオーバー：下がっていく3音（ソ → ミ → ド）
func _game_over() -> PackedFloat32Array:
	var out := _note(392.0, 0.3, 6.0)
	out = _concat(out, _note(330.0, 0.3, 6.0))
	out = _concat(out, _note(262.0, 0.8, 3.5))
	return _lowpass(out, 2500.0)


## 6. ステージクリア：上がっていく分散和音（ド → ミ → ソ → 高いド）
func _stage_clear() -> PackedFloat32Array:
	var out := _note(523.0, 0.09, 8.0)
	out = _concat(out, _note(659.0, 0.09, 8.0))
	out = _concat(out, _note(784.0, 0.09, 8.0))
	var chord := _note(1047.0, 0.7, 4.0)
	chord = _mix(chord, _note(784.0, 0.7, 4.0), 0.5)
	chord = _mix(chord, _note(659.0, 0.7, 4.0), 0.4)
	return _lowpass(_concat(out, chord), 5000.0)


## 7. 剥がれる：下がっていく音に、こすれるノイズを重ねる
func _peel() -> PackedFloat32Array:
	var slide := _tone(0.4, 700.0, 160.0, "tri", 0.005, 7.0)
	var scrape := _lowpass(_noise(0.4, 8.0), 2500.0)
	# ノイズを 40Hz で細かく揺らして「ズズッ」とした感じにする
	for i in scrape.size():
		scrape[i] *= 0.6 + 0.4 * _wave("square", fmod(40.0 * i / RATE, 1.0))
	return _mix(_scale(slide, 0.6), scrape, 0.5)


## 8. ゲーム開始：「タ・タ・ターン」と上がる短いジングル（ソ → シ → レ＋ソの和音）
## ステージクリア（ド・ミ・ソ）と聞き分けられるよう、調と形を変えている
func _start() -> PackedFloat32Array:
	var out := _note(784.0, 0.08, 10.0)
	out = _concat(out, _note(988.0, 0.08, 10.0))
	var chord := _note(1175.0, 0.4, 6.0)
	chord = _mix(chord, _note(784.0, 0.4, 6.0), 0.5)
	return _lowpass(_concat(out, chord), 5000.0)


## 9. チャージ音（ループ用、ちょうど1秒）
## 使う周波数をすべて整数 Hz にすると、1秒の終わりと始まりの波形がぴったりつながり、
## ループの継ぎ目で「プツッ」と鳴らない。音の高さの変化はゲーム側で pitch_scale を変えて付ける。
func _charge_loop() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		var v := sin(TAU * 110.0 * t) * 0.5
		v += sin(TAU * 111.0 * t) * 0.3  # 110Hz とわずかにずらして、ゆっくりうねらせる
		v += _wave("tri", fmod(165.0 * t, 1.0)) * 0.15
		v += sin(TAU * 330.0 * t) * 0.1
		v *= 0.85 + 0.15 * sin(TAU * 8.0 * t)  # 8Hz の細かい揺れ（きらめき）
		out[i] = v
	return out


# ---- 部品 ----

## 周波数を f_start から f_end へ滑らかに変える音。attack 秒で立ち上がり、decay の速さで消える
func _tone(duration: float, f_start: float, f_end: float, wave: String, attack: float, decay: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var time := float(i) / RATE
		var f := f_start * pow(f_end / f_start, float(i) / n)
		phase = fmod(phase + f / RATE, 1.0)
		out[i] = _wave(wave, phase) * minf(1.0, time / attack) * exp(-time * decay)
	return out


## 音階の1音。三角波に矩形波を少し混ぜて、柔らかいけれど芯のある音にする
func _note(freq: float, duration: float, decay: float) -> PackedFloat32Array:
	var tri := _tone(duration, freq, freq, "tri", 0.005, decay)
	return _mix(tri, _tone(duration, freq, freq, "square", 0.005, decay), 0.2)


func _noise(duration: float, decay: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = _rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * decay)
	return out


## phase は 0〜1。波の形ごとに -1〜1 の値を返す
func _wave(kind: String, phase: float) -> float:
	match kind:
		"sine":
			return sin(TAU * phase)
		"tri":
			return 4.0 * absf(phase - 0.5) - 1.0
		"square":
			return 1.0 if phase < 0.5 else -1.0
	return 0.0


## a に b を gain 倍して重ねる（長さが違えば長いほうに合わせる）
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var out := a.duplicate()
	if b.size() > out.size():
		out.resize(b.size())
	for i in b.size():
		out[i] += b[i] * gain
	return out


func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	out.append_array(b)
	return out


func _scale(a: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in out.size():
		out[i] *= gain
	return out


## 高い音を削って、耳に痛くない音にする
func _lowpass(a: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := a.duplicate()
	var alpha := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in out.size():
		y += alpha * (out[i] - y)
		out[i] = y
	return out


## 軽く歪ませて迫力を出す
func _drive(a: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in out.size():
		out[i] = tanh(out[i] * amount)
	return out


## 音量をそろえて 16bit の .wav に書き出す
func _save(sound_name: String, samples: PackedFloat32Array, peak: float, loop := false) -> void:
	var n := samples.size()
	var max_abs := 0.0
	for v in samples:
		max_abs = maxf(max_abs, absf(v))
	var gain := peak / max_abs if max_abs > 0.0 else 0.0

	# ループしない音は、始まりと終わりをごく短くフェードして「プツッ」を防ぐ
	var fade_in := 0 if loop else int(0.002 * RATE)
	var fade_out := 0 if loop else int(0.005 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := samples[i] * gain
		if i < fade_in:
			v *= float(i) / fade_in
		if i >= n - fade_out:
			v *= float(n - 1 - i) / fade_out
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	var path := OUT_DIR + sound_name + ".wav"
	var err := wav.save_to_wav(path)
	print("%-12s %.2f秒  %s" % [sound_name, float(n) / RATE, "OK" if err == OK else "ERROR %d" % err])
