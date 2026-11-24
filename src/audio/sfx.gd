class_name Sfx
extends Node
## 효과음. 녹음한 파일을 쓰지 않고, 시작할 때 짧은 소리를 계산해서 만든다.
##
## 장난감 같은 귀여운 소리를 낸다. 둥근 음색의 짧은 음을 미끄러지게 하거나 두세 개 이어 붙인 것이 전부다.
## 건물을 연달아 부술수록 음이 한 계단씩 올라간다.

const RATE := 22050
const VOICES := 12
## 같은 소리가 겹쳐 시끄러워지지 않게, 이 시간 안에는 같은 소리를 다시 내지 않는다 (초)
const MIN_GAP := 0.045
## 콤보에 따라 올라가는 음계. 다섯 음 음계라 어떻게 이어져도 어울린다.
const SCALE: Array[float] = [1.0, 1.122, 1.26, 1.498, 1.682, 2.0, 2.245, 2.52, 2.997, 3.364]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _time := 0.0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams = build_all()


func _process(delta: float) -> void:
	_time += delta


## name 의 소리를 낸다. step 을 주면 음계에서 그만큼 올린 음으로 낸다.
func play(sound: String, step: int = 0, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	if _time - float(_last.get(sound, -1.0)) < MIN_GAP:
		return
	_last[sound] = _time
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = SCALE[clampi(step, 0, SCALE.size() - 1)]
	p.volume_db = volume_db
	p.play()


## 모든 효과음을 만들어 돌려준다. 이름 → AudioStreamWAV.
static func build_all() -> Dictionary:
	var out := {}
	# 건물이 맞음: 짧고 통통한 소리
	out["hit"] = _wav(_tone(520.0, 400.0, 0.07, 0.5))
	# 건물이 부서짐: 뽁 하고 올라가는 소리
	out["pop"] = _wav(_mix([_tone(440.0, 880.0, 0.11, 0.6), _noise(0.05, 0.18)]))
	# 패들에 맞음: 낮고 둥근 소리
	out["paddle"] = _wav(_tone(240.0, 330.0, 0.09, 0.6))
	# 벽에 맞음: 가벼운 톡
	out["wall"] = _wav(_tone(700.0, 620.0, 0.04, 0.35))
	# 물에 빠짐: 퐁당
	out["splash"] = _wav(_mix([_tone(520.0, 150.0, 0.22, 0.5), _noise(0.16, 0.22)]))
	# 물에서 나옴: 뿅
	out["emerge"] = _wav(_tone(260.0, 780.0, 0.16, 0.55))
	# 좋은 아이템: 딩동
	out["item"] = _wav(_chain([_tone(784.0, 784.0, 0.08, 0.5), _tone(1175.0, 1175.0, 0.14, 0.5)]))
	# 나쁜 아이템: 뚜웅
	out["bad"] = _wav(_chain([_tone(330.0, 300.0, 0.1, 0.5), _tone(220.0, 160.0, 0.2, 0.5)]))
	# 공을 다 놓침: 내려가는 세 음
	out["miss"] = _wav(_chain([_tone(523.0, 523.0, 0.11, 0.5), _tone(392.0, 392.0, 0.11, 0.5), _tone(262.0, 220.0, 0.26, 0.5)]))
	# 클리어: 올라가는 네 음
	out["clear"] = _wav(_chain([_tone(523.0, 523.0, 0.1, 0.5), _tone(659.0, 659.0, 0.1, 0.5), _tone(784.0, 784.0, 0.1, 0.5), _tone(1047.0, 1047.0, 0.34, 0.55)]))
	# 게임 오버: 느리게 내려가는 소리
	out["over"] = _wav(_chain([_tone(392.0, 392.0, 0.18, 0.5), _tone(330.0, 330.0, 0.18, 0.5), _tone(262.0, 196.0, 0.5, 0.5)]))
	# 피버, 빨라짐, 러시: 휘익 올라가는 소리
	out["fever"] = _wav(_chain([_tone(523.0, 1047.0, 0.16, 0.5), _tone(1047.0, 1568.0, 0.2, 0.5)]))
	out["speed"] = _wav(_chain([_tone(660.0, 660.0, 0.06, 0.45), _tone(880.0, 880.0, 0.06, 0.45), _tone(1100.0, 1100.0, 0.1, 0.45)]))
	# 번개: 찌직
	out["bolt"] = _wav(_mix([_noise(0.14, 0.5), _tone(1800.0, 200.0, 0.14, 0.4)]))
	# 덤 공이 사라짐: 작게 스르륵
	out["fade"] = _wav(_tone(900.0, 500.0, 0.09, 0.25))
	# 단추를 누름
	out["tap"] = _wav(_tone(600.0, 900.0, 0.06, 0.45))
	return out


## 높이가 from 에서 to 로 미끄러지는 둥근 음. 처음에 톡 치고 서서히 줄어든다.
static func _tone(from: float, to: float, seconds: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(from, to, t)
		phase += TAU * freq / RATE
		# 사인에 배음을 조금 섞어 장난감 실로폰 같은 소리를 낸다
		var wave := sin(phase) * 0.8 + sin(phase * 2.0) * 0.15 + sin(phase * 3.0) * 0.05
		var attack := minf(1.0, float(i) / (0.004 * RATE))
		var decay := pow(1.0 - t, 1.6)
		out[i] = wave * attack * decay * volume
	return out


## 짧은 잡음. 물 튀는 소리나 부서지는 소리에 섞는다. 늘 같은 소리가 나도록 정해진 난수를 쓴다.
static func _noise(seconds: float, volume: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var smooth := 0.0
	for i in n:
		var t := float(i) / n
		smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.35)
		out[i] = smooth * pow(1.0 - t, 2.0) * volume
	return out


## 소리들을 겹친다.
static func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


## 소리들을 차례로 잇는다.
static func _chain(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
