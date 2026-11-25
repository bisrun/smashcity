extends "res://src/ui/screens/base_screen.gd"
## 출발 준비. 스테이지를 누르면 아래에서 올라오는 판이다. 판을 시작하기 전에 알 것과 고를 것을 모은다.

var _gear := ""
var _gear_buttons := {}


## info: {title, grade, best, ride, top: Array(순위 기록), gear: Array({id, name, about, count})}
func setup(info: Dictionary) -> void:
	_fill(Color(0.05, 0.08, 0.16, 0.55))
	var card := Kit.panel(Color(1, 1, 1, 0.98), 44, 30)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 24
	card.offset_right = -24
	card.offset_bottom = -60
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	v.add_child(_centered(String(info["title"]), 54, Kit.INK))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	chips.add_child(Kit.chip("GRADE %s" % info["grade"], Kit.CORAL, Color.WHITE, 26))
	chips.add_child(Kit.chip("BEST %s" % Kit.number(int(info["best"])), Kit.GOLD, Color.WHITE, 26))
	chips.add_child(Kit.chip(String(info["ride"]), Kit.SKY, Color.WHITE, 26))
	v.add_child(chips)
	v.add_child(Kit.label("RANKING", 26, Kit.GREY.darkened(0.3)))
	v.add_child(Kit.ranking(info["top"], 0))

	v.add_child(Kit.label("GEAR  (한 판에 하나)", 26, Kit.GREY.darkened(0.3)))
	var owned: Array = info["gear"]
	if owned.is_empty():
		v.add_child(Kit.label("가진 출발 아이템이 없어요. CREW 의 GEAR 에서 살 수 있어요.", 22, Kit.GREY.darkened(0.2)))
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		v.add_child(grid)
		for g: Dictionary in [{"id": "", "name": "NONE", "count": -1}] + owned:
			var text := String(g["name"]) if int(g["count"]) < 0 else "%s  ×%d" % [g["name"], g["count"]]
			var b := Kit.button(text, Kit.MINT, 26)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var id := String(g["id"])
			b.pressed.connect(func() -> void:
				_gear = id
				_mark())
			_gear_buttons[id] = b
			grid.add_child(b)
		_mark()

	var start := Kit.button("START", Kit.CORAL, 64)
	start.custom_minimum_size = Vector2(0, 130)
	start.pressed.connect(func() -> void: go.emit("start", _gear))
	v.add_child(start)
	v.add_child(_link(Kit.button("CLOSE", Kit.GREY.darkened(0.25), 26), "close"))


func _mark() -> void:
	for id: String in _gear_buttons:
		_gear_buttons[id].modulate = Color.WHITE if id == _gear else Color(0.62, 0.66, 0.72)


func back() -> bool:
	go.emit("close", "")
	return true
