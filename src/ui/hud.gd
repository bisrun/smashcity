class_name Hud
extends Control
## 플레이 중 화면 위쪽의 표시. 스테이지, 점수, 남은 공, 목표, 콤보, 켜져 있는 아이템을 보여 준다.
##
## 판정에는 관여하지 않는다. 장면이 매 프레임 show_state()로 값을 넘겨 준다.

var _score: Label
var _stage: Label
var _lives: HBoxContainer
var _goal: ProgressBar
var _goal_text: Label
var _combo: PanelContainer
var _chips: HBoxContainer
var _toast: Label
var _toast_left := 0.0
var _shown_score := 0.0
var _target_score := 0
var _last_lives := -1
var _fps: Label
var _flash: ColorRect
var _dim: ColorRect
var _cheer: Label
var _cheer_sub: Label
var _confetti: CPUParticles2D


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 화면 전체를 덮는 어둠과 번쩍임. 평소에는 보이지 않는다.
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.07, 0.16, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var bar := UiKit.panel(UiKit.PAPER, 34, 18)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = 44
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	bar.add_child(rows)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	rows.add_child(top)
	var stage_chip := UiKit.chip("", UiKit.INK, Color.WHITE, 24)
	_stage = stage_chip.get_node("Text")
	top.add_child(stage_chip)
	_score = UiKit.label("0", 58)
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_score)
	_lives = HBoxContainer.new()
	_lives.add_theme_constant_override("separation", 6)
	_lives.alignment = BoxContainer.ALIGNMENT_END
	_lives.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_lives)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 12)
	rows.add_child(mid)
	_goal_text = UiKit.label("", 22)
	mid.add_child(_goal_text)
	_goal = ProgressBar.new()
	_goal.show_percentage = false
	_goal.custom_minimum_size = Vector2(0, 18)
	_goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_goal.add_theme_stylebox_override("background", UiKit.box(Color("E3E8EF"), 12))
	_goal.add_theme_stylebox_override("fill", UiKit.box(UiKit.GOLD, 12))
	mid.add_child(_goal)
	_combo = UiKit.chip("x1.0", UiKit.GREY, Color.WHITE, 24)
	mid.add_child(_combo)

	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	rows.add_child(_chips)

	_toast = UiKit.label("", 50)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast.anchor_top = 0.3
	_toast.anchor_bottom = 1.3
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.WHITE)
	_toast.add_theme_constant_override("outline_size", 16)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	# 축하: 색종이와 큰 글자
	_confetti = CPUParticles2D.new()
	_confetti.emitting = false
	_confetti.amount = 160
	_confetti.lifetime = 3.2
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(380, 10)
	_confetti.direction = Vector2(0, 1)
	_confetti.spread = 35.0
	_confetti.gravity = Vector2(0, 520)
	_confetti.initial_velocity_min = 120.0
	_confetti.initial_velocity_max = 420.0
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.scale_amount_min = 10.0
	_confetti.scale_amount_max = 22.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray([UiKit.CORAL, UiKit.GOLD, UiKit.MINT, UiKit.SKY, Color("B58CF0"), Color("FF8FB8")])
	_confetti.color_initial_ramp = ramp
	add_child(_confetti)
	_cheer = UiKit.label("", 150)
	_cheer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cheer.anchor_top = -0.08
	_cheer.anchor_bottom = 0.92
	_cheer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cheer.add_theme_color_override("font_outline_color", Color.WHITE)
	_cheer.add_theme_constant_override("outline_size", 34)
	_cheer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cheer.visible = false
	add_child(_cheer)
	_cheer_sub = UiKit.label("", 54)
	_cheer_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cheer_sub.anchor_top = 0.02
	_cheer_sub.anchor_bottom = 1.02
	_cheer_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheer_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cheer_sub.add_theme_color_override("font_outline_color", Color.WHITE)
	_cheer_sub.add_theme_constant_override("outline_size", 20)
	_cheer_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cheer_sub.visible = false
	add_child(_cheer_sub)

	_fps = UiKit.label("", 18, Color(0.08, 0.13, 0.24, 0.55))
	_fps.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps.offset_left = -90
	_fps.offset_top = -34
	add_child(_fps)


## 어느 도시의 몇 번째 스테이지인지.
func set_stage(city: String, index: int, total: int, stage_name: String) -> void:
	_stage.text = "%s %d/%d · %s" % [city, index, total, stage_name]


func _process(delta: float) -> void:
	# 점수는 한 번에 바뀌지 않고 빠르게 세어 올라간다
	if absf(_shown_score - _target_score) > 0.5:
		_shown_score = lerpf(_shown_score, _target_score, minf(1.0, delta * 12.0))
		if absf(_shown_score - _target_score) < 6.0:
			_shown_score = _target_score
		_score.text = UiKit.number(int(round(_shown_score)))
	_toast_left -= delta
	if _toast_left <= 0.0:
		_toast.visible = false


## 판의 지금 상태를 보여 준다.
## goal 은 0~1 의 목표 진행도, effects 는 켜져 있는 것들의 [이름, 남은 초, 색] 목록이다.
func show_state(score: int, lives: int, combo: float, fever: bool, goal_name: String, goal: float, effects: Array) -> void:
	if score != _target_score:
		if score > _target_score:
			_pop(_score, 1.18)
		_target_score = score
	if lives != _last_lives:
		_last_lives = lives
		for c in _lives.get_children():
			c.queue_free()
		for i in maxi(lives, 0):
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(26, 26)
			var sb := UiKit.box(Color.WHITE, 13)
			sb.set_border_width_all(4)
			sb.border_color = UiKit.INK
			dot.add_theme_stylebox_override("panel", sb)
			_lives.add_child(dot)
	_goal_text.text = goal_name
	_goal.value = clampf(goal, 0.0, 1.0) * 100.0
	var text: Label = _combo.get_node("Text")
	text.text = "FEVER x%.1f" % combo if fever else "x%.1f" % combo
	var sb_combo: StyleBoxFlat = _combo.get_theme_stylebox("panel")
	sb_combo.bg_color = UiKit.CORAL if fever else (UiKit.GOLD if combo > 1.05 else UiKit.GREY)

	# 켜져 있는 아이템. 달라졌을 때만 다시 만든다.
	var want := effects.size()
	while _chips.get_child_count() > want:
		var last := _chips.get_child(_chips.get_child_count() - 1)
		_chips.remove_child(last)
		last.queue_free()
	while _chips.get_child_count() < want:
		_chips.add_child(UiKit.chip("", UiKit.SKY, Color.WHITE, 22))
	for i in want:
		var chip := _chips.get_child(i) as PanelContainer
		(chip.get_node("Text") as Label).text = "%s %d" % [effects[i][0], ceili(effects[i][1])] if effects[i][1] > 0.0 else String(effects[i][0])
		(chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = effects[i][2]
	_chips.visible = want > 0


func set_fps(fps: int) -> void:
	_fps.text = "%dfps" % fps


## 화면 전체가 한 번 번쩍인다.
func flash(color: Color, seconds: float) -> void:
	_flash.color = Color(color, 0.85)
	var tween := _flash.create_tween()
	tween.tween_property(_flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


## 화면을 어둡게 했다가 seconds 뒤에 되돌린다. 번개가 내리치는 동안 쓴다.
func darken(seconds: float) -> void:
	var tween := _dim.create_tween()
	tween.tween_property(_dim, "color:a", 0.42, 0.15)
	tween.tween_interval(seconds)
	tween.tween_property(_dim, "color:a", 0.0, 0.5)


## 판이 끝났음을 크게 알린다. 큰 글자가 튀어나오고, won 이면 색종이가 쏟아진다.
func celebrate(text: String, sub: String, won: bool) -> void:
	_toast.visible = false
	_toast_left = 0.0
	_cheer.text = text
	_cheer.add_theme_color_override("font_color", UiKit.MINT if won else UiKit.CORAL)
	_cheer.visible = true
	_cheer.pivot_offset = _cheer.size / 2.0
	_cheer.scale = Vector2.ONE * 0.2
	var tween := _cheer.create_tween()
	tween.tween_property(_cheer, "scale", Vector2.ONE * 1.18, 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cheer, "scale", Vector2.ONE, 0.14)
	tween.tween_property(_cheer, "scale", Vector2.ONE * 1.05, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cheer, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	_cheer_sub.text = sub
	_cheer_sub.visible = true
	_cheer_sub.modulate.a = 0.0
	var sub_tween := _cheer_sub.create_tween()
	sub_tween.tween_interval(0.4)
	sub_tween.tween_property(_cheer_sub, "modulate:a", 1.0, 0.3)
	if won:
		_confetti.position = Vector2(size.x / 2.0, -20.0)
		_confetti.emission_rect_extents = Vector2(size.x / 2.0, 10.0)
		_confetti.emitting = true
		flash(Color.WHITE, 0.5)
	else:
		_dim.create_tween().tween_property(_dim, "color:a", 0.35, 0.6)


## 화면 가운데에 잠깐 뜨는 한마디.
func say(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = 1.5
	_pop(_toast, 1.12)


func _pop(node: Control, amount: float) -> void:
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, 0.06)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16)
