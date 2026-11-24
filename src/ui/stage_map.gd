class_name StageMapScreen
extends Control
## 스테이지와 스테이지 사이에 뜨는 화면. 굽이진 길 위에 스테이지를 늘어놓아 얼마나 왔고 얼마나 남았는지를 보여 준다.
##
## 캐주얼 게임에서 흔히 쓰는 "레벨 길" 화면의 짜임을 따랐다. 하늘과 언덕과 풀밭을 배경으로 길이 아래에서 위로 올라가고,
## 스테이지는 도톰한 단추로 놓인다. 깬 곳은 초록 단추에 별, 이번에 할 곳은 빨간 단추에 통통 튀는 표지, 못 가는 곳은 자물쇠다.
## 한 판이 끝난 뒤에는 그 판의 결과와 순위를 함께 보여 준다.
## 화면을 누르면 started 가 난다.

signal started

const SKY_TOP := Color("9ED8F0")
const SKY_LOW := Color("DFF4FA")
const GRASS_TOP := Color("C4E9A9")
const GRASS_LOW := Color("9FD88A")
const ROAD := Color("FFF1D6")
const ROAD_EDGE := Color("E3C99B")
const LOCKED := Color("AEB8C6")
const SILVER := Color("B8C4D2")
const BRONZE := Color("D99A6C")

var _stages: Array = []
var _cleared: Array[String] = []
var _best := {}
var _current := 0
var _city := ""
var _result := {}
var _time := 0.0
var _points: PackedVector2Array = []
var _road: PackedVector2Array = []
var _radius := 50.0
var _ready_to_start := false
var _card: PanelContainer
var _play_rect := Rect2()


## stages: [{id, name, ready}], cleared: 클리어한 ID들, current: 이번에 할 스테이지의 번호(0부터),
## best: 스테이지 ID → 최고 점수, ranking: 아래에 보여 줄 순위 목록.
## result 가 있으면 방금 끝난 판의 결과다: {cleared, score, rank}.
func setup(city: String, stages: Array, cleared: Array[String], current: int, best: Dictionary, ranking: Array, result: Dictionary = {}) -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_city = city
	_stages = stages
	_cleared = cleared
	_current = current
	_best = best
	_result = result

	# 아래쪽 판: 결과와 순위
	_card = UiKit.panel(Color(1, 1, 1, 0.97), 36, 24)
	var sb: StyleBoxFlat = _card.get_theme_stylebox("panel")
	sb.shadow_color = Color(0.08, 0.13, 0.24, 0.18)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_card.offset_left = 30
	_card.offset_right = -30
	_card.offset_bottom = -196
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	_card.add_child(rows)
	if not result.is_empty():
		var won: bool = result["cleared"]
		var title := UiKit.label("CLEAR!" if won else "GAME OVER", 64, UiKit.MINT if won else UiKit.CORAL)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(title)
		var score := UiKit.label(UiKit.number(int(result["score"])), 56)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(score)
		if int(result["rank"]) > 0:
			var rank := UiKit.label("RANK #%d" % int(result["rank"]), 30, UiKit.GOLD)
			rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rows.add_child(rank)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiKit.label("RANKING", 30))
	var where := UiKit.label(String(stages[current]["name"]) if current < stages.size() else "", 24, UiKit.GREY)
	where.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(where)
	rows.add_child(head)
	# 결과가 함께 뜰 때는 판이 길어지므로 순위를 셋만 보여 준다
	rows.add_child(_ranking(ranking.slice(0, 3) if not result.is_empty() else ranking, int(result.get("rank", 0))))

	resized.connect(_layout)
	_layout.call_deferred()
	# 뜨자마자 눌려서 넘어가는 일을 막는다
	get_tree().create_timer(0.6).timeout.connect(func() -> void: _ready_to_start = true)


## 순위 목록. 1, 2, 3위는 금, 은, 동 메달이고 방금 낸 기록은 색 바탕으로 띄운다.
func _ranking(entries: Array, mark: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if entries.is_empty():
		v.add_child(UiKit.label("첫 기록을 남겨 보세요", 26, UiKit.GREY))
		return v
	var medals: Array[Color] = [UiKit.GOLD, SILVER, BRONZE]
	for i in entries.size():
		var e: Dictionary = entries[i]
		var mine := i + 1 == mark
		var line := UiKit.panel(Color("FFF0EE") if mine else Color(0, 0, 0, 0), 20, 0)
		var lsb: StyleBoxFlat = line.get_theme_stylebox("panel")
		lsb.content_margin_left = 10
		lsb.content_margin_right = 14
		lsb.content_margin_top = 4
		lsb.content_margin_bottom = 4
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		line.add_child(row)
		var medal := UiKit.chip(str(i + 1), medals[i] if i < 3 else Color("DCE2EA"), Color.WHITE if i < 3 else UiKit.INK, 24)
		medal.custom_minimum_size = Vector2(58, 0)
		(medal.get_node("Text") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(medal)
		var score := UiKit.label(UiKit.number(int(e["score"])), 34, UiKit.CORAL if mine else UiKit.INK)
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score)
		if e.get("cleared", false):
			row.add_child(UiKit.chip("CLEAR", UiKit.MINT, Color.WHITE, 18))
		var when := UiKit.label(String(e.get("at", "")), 20, UiKit.GREY)
		when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(when)
		v.add_child(line)
	return v


func _layout() -> void:
	var n := _stages.size()
	if n == 0 or size.y <= 0.0:
		return
	var top := 300.0
	var bottom := size.y - 250.0 - _card.size.y - 60.0
	bottom = maxf(bottom, top + 80.0 * n)
	var gap := (bottom - top) / maxf(1.0, n - 1.0)
	_radius = clampf(gap * 0.34, 30.0, 54.0)
	_points = PackedVector2Array()
	for i in n:
		var x := size.x * 0.5 + (-1.0 if i % 2 == 0 else 1.0) * size.x * 0.2
		_points.append(Vector2(x, bottom - gap * i))
	# 단추들을 부드럽게 잇는 길
	var curve := Curve2D.new()
	curve.add_point(_points[0] + Vector2(-60, gap * 0.9), Vector2.ZERO, Vector2(0, -gap * 0.4))
	for i in n:
		var prev := _points[maxi(i - 1, 0)]
		var next := _points[mini(i + 1, n - 1)]
		var tangent := (next - prev) * 0.25
		curve.add_point(_points[i], -tangent, tangent)
	curve.add_point(_points[n - 1] + Vector2(70, -gap * 0.9), Vector2(0, gap * 0.4), Vector2.ZERO)
	curve.bake_interval = 12.0
	_road = curve.get_baked_points()
	_play_rect = Rect2(size.x / 2.0 - 220.0, size.y - 170.0, 440.0, 104.0)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _points.is_empty():
		return
	var font := UiKit.font()
	var w := size.x
	var h := size.y
	var horizon := 250.0
	# 하늘과 풀밭
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	for hill: Array in [[0.12, 150.0, Color("A9DCA0")], [0.42, 190.0, Color("9CD3A8")], [0.74, 160.0, Color("A9DCA0")], [0.98, 200.0, Color("93CBA4")]]:
		draw_circle(Vector2(w * hill[0], horizon + hill[1] * 0.45), hill[1], hill[2])
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([GRASS_TOP, GRASS_TOP, GRASS_LOW, GRASS_LOW]))
	for cloud: Array in [[0.16, 70.0, 1.0], [0.82, 120.0, 0.8], [0.52, 40.0, 0.6]]:
		var c := Vector2(fposmod(w * cloud[0] + _time * 9.0 * cloud[2], w + 240.0) - 120.0, cloud[1])
		for puff: Vector2 in [Vector2(-34, 6), Vector2(0, -8), Vector2(34, 6), Vector2(0, 12)]:
			draw_circle(c + puff * cloud[2], 30.0 * cloud[2], Color(1, 1, 1, 0.92))

	# 길: 그림자, 가장자리, 바닥, 가운데 점선
	var shadow := PackedVector2Array()
	for p in _road:
		shadow.append(p + Vector2(0, 10))
	draw_polyline(shadow, Color(0.1, 0.25, 0.1, 0.12), 66.0, true)
	draw_polyline(_road, ROAD_EDGE, 64.0, true)
	draw_polyline(_road, ROAD, 52.0, true)
	for i in range(0, _road.size() - 2, 4):
		draw_line(_road[i], _road[i + 2], Color(1, 1, 1, 0.9), 5.0, true)

	# 길가의 나무와 작은 집
	for i in range(3, _road.size() - 3, 9):
		var p := _road[i]
		var dir := (_road[i + 1] - _road[i - 1]).normalized()
		var out := Vector2(-dir.y, dir.x) * (74.0 + (i * 37 % 30)) * (1.0 if (i / 9) % 2 == 0 else -1.0)
		var at := p + out
		if _near_button(at, 96.0) or at.y > _card.position.y - 30.0:
			continue
		if (i / 9) % 3 == 0:
			_house(at, 0.9 + (i % 5) * 0.06, [UiKit.CORAL, UiKit.SKY, UiKit.GOLD][(i / 9) % 3])
		else:
			_tree(at, 0.9 + (i % 4) * 0.1)

	# 스테이지 단추
	for i in _points.size():
		var p := _points[i]
		var st := _state(i)
		var playing := i == _current
		var r := _radius * (1.16 + 0.04 * sin(_time * 5.0) if playing else 1.0)
		var face := LOCKED if st == 0 else (UiKit.MINT if st == 2 else UiKit.CORAL)
		if playing and st != 2:
			face = UiKit.CORAL
		_button(p, r, face)
		if st == 0:
			_lock(p, r * 0.5)
		elif font != null:
			_text(font, str(i + 1), p + Vector2(0, r * 0.36), int(r * 1.05), Color.WHITE, face.darkened(0.35), 10)
		if st == 2:
			_star(p + Vector2(0, -r - 16.0), 20.0)
		# 이름표
		if font != null:
			var name := String(_stages[i]["name"])
			var on_right := p.x < w * 0.5
			var ts := 30
			var best := int(_best.get(String(_stages[i]["id"]), 0))
			var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
			if best > 0:
				tw = maxf(tw, font.get_string_size("BEST " + UiKit.number(best), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
			# 이름표는 단추의 바깥쪽에 둔다. 길과 다른 단추를 가리지 않는다.
			on_right = not on_right
			var tag := Rect2(p.x + (r + 22.0 if on_right else -r - 22.0 - tw - 36.0), p.y - 28.0, tw + 36.0, 56.0)
			tag.position.x = clampf(tag.position.x, 12.0, w - tag.size.x - 12.0)
			if best > 0:
				tag.size.y = 84.0
				tag.position.y -= 14.0
			draw_style_box(UiKit.box(Color(1, 1, 1, 0.94 if st != 0 else 0.6), 22), tag)
			draw_string(font, tag.position + Vector2(18, 38), name, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, UiKit.INK if st != 0 else LOCKED.darkened(0.2))
			if best > 0:
				draw_string(font, tag.position + Vector2(18, 70), "BEST " + UiKit.number(best), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.GOLD.darkened(0.1))
		if playing:
			_pin(p + Vector2(0, -r - 34.0 - absf(sin(_time * 3.2)) * 18.0))

	# 머리말: 도시 이름과 진행 막대
	var banner := Rect2(34.0, 52.0, w - 68.0, 150.0)
	var bsb := UiKit.box(Color(1, 1, 1, 0.95), 40)
	bsb.shadow_color = Color(0.08, 0.13, 0.24, 0.16)
	bsb.shadow_size = 16
	bsb.shadow_offset = Vector2(0, 8)
	draw_style_box(bsb, banner)
	var done := 0
	for s: Dictionary in _stages:
		if _cleared.has(String(s["id"])):
			done += 1
	if font != null:
		draw_string(font, banner.position + Vector2(34, 74), _city, HORIZONTAL_ALIGNMENT_LEFT, -1, 62, UiKit.INK)
		var count := "%d / %d" % [done, _stages.size()]
		var cw := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(font, banner.position + Vector2(banner.size.x - cw - 34.0, 68), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiKit.CORAL)
		draw_string(font, banner.position + Vector2(banner.size.x - cw - 34.0 - 96.0, 64), "STAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.GREY)
	var seg_w := (banner.size.x - 68.0 - 8.0 * (_stages.size() - 1)) / _stages.size()
	for i in _stages.size():
		var seg := Rect2(banner.position.x + 34.0 + i * (seg_w + 8.0), banner.position.y + 102.0, seg_w, 20.0)
		draw_style_box(UiKit.box(UiKit.MINT if _state(i) == 2 else (UiKit.CORAL if i == _current else Color("E3E8EF")), 10), seg)

	# 시작 단추
	var press := 4.0 + 3.0 * sin(_time * 4.0)
	draw_style_box(UiKit.box(UiKit.CORAL.darkened(0.28), 52), Rect2(_play_rect.position + Vector2(0, 12), _play_rect.size))
	var top_rect := Rect2(_play_rect.position + Vector2(0, press - 4.0), _play_rect.size)
	draw_style_box(UiKit.box(UiKit.CORAL, 52), top_rect)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.16), 40), Rect2(top_rect.position + Vector2(14, 8), Vector2(top_rect.size.x - 28.0, top_rect.size.y * 0.42)))
	if font != null:
		_text(font, "PLAY", top_rect.get_center() + Vector2(0, 22), 64, Color.WHITE, UiKit.CORAL.darkened(0.35), 12)


## 0은 아직 못 가는 곳, 1은 지금 할 곳, 2는 클리어한 곳.
func _state(i: int) -> int:
	if _cleared.has(String(_stages[i]["id"])):
		return 2
	return 1 if i == _current else 0


func _near_button(at: Vector2, within: float) -> bool:
	for p in _points:
		if p.distance_to(at) < within:
			return true
	return false


## 도톰한 둥근 단추. 아래로 그림자와 두께가 있고 위쪽에 밝은 빛이 돈다.
func _button(at: Vector2, r: float, color: Color) -> void:
	draw_set_transform(at + Vector2(0, r * 0.62), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, r * 1.12, Color(0.1, 0.2, 0.1, 0.2))
	draw_set_transform(Vector2.ZERO)
	draw_circle(at + Vector2(0, r * 0.2), r + 7.0, Color.WHITE)
	draw_circle(at + Vector2(0, r * 0.2), r, color.darkened(0.3))
	draw_circle(at, r + 7.0, Color.WHITE)
	draw_circle(at, r, color)
	draw_circle(at + Vector2(-r * 0.28, -r * 0.34), r * 0.42, Color(1, 1, 1, 0.22))


func _star(at: Vector2, r: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := 1.0 if k % 2 == 0 else 0.46
		outer.append(at + Vector2(cos(a), sin(a)) * (r + 5.0) * rr)
		inner.append(at + Vector2(cos(a), sin(a)) * r * rr)
	draw_colored_polygon(outer, Color.WHITE)
	draw_colored_polygon(inner, Color("FFC93C"))


func _lock(at: Vector2, s: float) -> void:
	draw_arc(at + Vector2(0, -s * 0.35), s * 0.5, PI, TAU, 16, Color.WHITE, s * 0.24, true)
	draw_style_box(UiKit.box(Color.WHITE, int(s * 0.25)), Rect2(at + Vector2(-s * 0.72, -s * 0.3), Vector2(s * 1.44, s * 1.1)))
	draw_circle(at + Vector2(0, s * 0.2), s * 0.16, LOCKED.darkened(0.15))


## 이번에 할 스테이지를 가리키는 표지. 공 모양 머리에 뾰족한 꼬리.
func _pin(at: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-20, -6), at + Vector2(20, -6), at + Vector2(0, 30)]), UiKit.INK)
	draw_circle(at + Vector2(0, -22), 30.0, UiKit.INK)
	draw_circle(at + Vector2(0, -22), 20.0, Color.WHITE)


func _tree(at: Vector2, s: float) -> void:
	draw_set_transform(at + Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 22.0 * s, Color(0.1, 0.25, 0.1, 0.16))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(at + Vector2(-4, -12) * s, Vector2(8, 20) * s), Color("9A6B4A"))
	draw_circle(at + Vector2(0, -30) * s, 24.0 * s, Color("5DB57E"))
	draw_circle(at + Vector2(-8, -38) * s, 12.0 * s, Color("8FD489"))


func _house(at: Vector2, s: float, roof: Color) -> void:
	draw_set_transform(at + Vector2(0, 10), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 30.0 * s, Color(0.1, 0.25, 0.1, 0.16))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(at + Vector2(-22, -26) * s, Vector2(44, 34) * s), Color("FFF4E3"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-30, -24) * s, at + Vector2(0, -54) * s, at + Vector2(30, -24) * s]), roof)
	draw_rect(Rect2(at + Vector2(-6, -8) * s, Vector2(12, 16) * s), Color("8CCBF2"))


## 가운데를 맞춘 글자. 테두리가 있다.
func _text(font: Font, text: String, baseline_center: Vector2, text_size: int, color: Color, outline: Color, outline_size: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var at := baseline_center + Vector2(-tw / 2.0, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, outline_size, outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, color)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if pressed and _ready_to_start:
		accept_event()
		started.emit()
