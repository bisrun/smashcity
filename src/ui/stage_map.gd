class_name StageMapScreen
extends Control
## 스테이지와 스테이지 사이에 뜨는 화면. 길 위에 스테이지를 늘어놓아 얼마나 왔고 얼마나 남았는지를 보여 준다.
##
## 길은 아래에서 위로 올라간다. 클리어한 곳은 초록, 지금 할 곳은 빨강, 아직 못 가는 곳은 회색이다.
## 한 판이 끝난 뒤에는 그 판의 결과와 순위도 함께 보여 준다.
## 화면을 누르면 started 가 난다.

signal started

const NODE_RADIUS := 46.0

var _stages: Array = []
var _cleared: Array[String] = []
var _current := 0
var _pulse := 0.0
var _points: PackedVector2Array = []
var _labels: Array[Label] = []
var _ready_to_start := false


## stages: [{id, name, ready}], cleared: 클리어한 ID들, current: 이번에 할 스테이지의 번호(0부터).
## result 가 있으면 방금 끝난 판의 결과다: {cleared, score, rank}.
func setup(city: String, stages: Array, cleared: Array[String], current: int, ranking: Array, result: Dictionary = {}) -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stages = stages
	_cleared = cleared
	_current = current

	var back := ColorRect.new()
	back.color = Color("EAF6FB", 0.95)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	move_child(back, 0)
	back.show_behind_parent = true

	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = 70
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var left := 0
	for s: Dictionary in stages:
		if not cleared.has(String(s["id"])):
			left += 1
	var title := UiKit.label(city, 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var sub := UiKit.label("스테이지 %d개 중 %d개 남음" % [stages.size(), left], 30, UiKit.CORAL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(sub)

	for i in stages.size():
		var l := UiKit.label(String(stages[i]["name"]), 30)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_labels.append(l)

	# 아래쪽 판: 결과와 순위
	var card := UiKit.panel(Color(1, 1, 1, 0.96), 34, 22)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 26
	card.offset_right = -26
	card.offset_bottom = -110
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	card.add_child(rows)
	var name := String(stages[current]["name"]) if current < stages.size() else ""
	if not result.is_empty():
		var word := "클리어!" if result["cleared"] else "게임 오버"
		rows.add_child(UiKit.label(word, 54, UiKit.MINT if result["cleared"] else UiKit.CORAL))
		var line := "%s점" % UiKit.number(int(result["score"]))
		if int(result["rank"]) > 0:
			line += "   이 기기에서 %d위" % int(result["rank"])
		rows.add_child(UiKit.label(line, 34))
	rows.add_child(UiKit.label("%s 순위" % name, 26, UiKit.GREY))
	rows.add_child(UiKit.ranking(ranking, int(result.get("rank", 0))))

	var hint := UiKit.label("화면을 누르면 %s 시작" % name, 32)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -92
	hint.offset_bottom = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	resized.connect(_layout)
	_layout.call_deferred()
	# 뜨자마자 눌려서 넘어가는 일을 막는다
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _ready_to_start = true)


func _layout() -> void:
	var n := _stages.size()
	if n == 0:
		return
	var top := 250.0
	var bottom := size.y * 0.5
	_points = PackedVector2Array()
	for i in n:
		var t := float(i) / maxf(1.0, n - 1.0)
		var x := size.x * (0.3 if i % 2 == 0 else 0.7)
		_points.append(Vector2(x, lerpf(bottom, top, t)))
	for i in n:
		var l := _labels[i]
		var w := l.get_minimum_size().x
		l.position = _points[i] + (Vector2(NODE_RADIUS + 16.0, -20.0) if i % 2 == 0 else Vector2(-NODE_RADIUS - 16.0 - w, -20.0))
		l.add_theme_color_override("font_color", UiKit.INK if _state(i) != 0 else UiKit.GREY)
	queue_redraw()


## 0은 아직 못 가는 곳, 1은 지금 할 곳, 2는 클리어한 곳.
func _state(i: int) -> int:
	if _cleared.has(String(_stages[i]["id"])):
		return 2
	return 1 if i == _current else 0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if _points.is_empty():
		return
	for i in _points.size() - 1:
		var done := _state(i) == 2
		draw_dashed_line(_points[i], _points[i + 1], UiKit.MINT if done else UiKit.GREY, 10.0, 22.0)
	var font := UiKit.font()
	for i in _points.size():
		var p := _points[i]
		var st := _state(i)
		var color := UiKit.GREY if st == 0 else (UiKit.CORAL if st == 1 else UiKit.MINT)
		if st == 1:
			var grow := 10.0 + 8.0 * sin(_pulse * 4.0)
			draw_circle(p, NODE_RADIUS + grow, Color(color, 0.25))
		draw_circle(p, NODE_RADIUS + 6.0, Color.WHITE)
		draw_circle(p, NODE_RADIUS, color)
		var mark := "✓" if st == 2 else str(i + 1)
		if font != null:
			var w := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
			draw_string(font, p + Vector2(-w / 2.0, 15.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if pressed and _ready_to_start:
		accept_event()
		started.emit()
