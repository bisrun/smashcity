extends "res://src/ui/screens/base_screen.gd"
## CREW. 내 정보(CAPTAIN), 탈것과 꾸밈(RIDES), 출발 아이템(GEAR), 기록(RECORDS)을 보고 고친다.
##
## 여기서 바뀌는 것 가운데 판정에 들어가는 것은 없다. 출발 아이템은 출발 준비에서 골라야 판에 들어간다.

const TABS := ["CAPTAIN", "RIDES", "GEAR", "RECORDS"]

var _save: SaveData
var _prog: Progression
var _cities: Array = []
var _tab := 0
var _tab_buttons: Array[Button] = []
var _body: VBoxContainer


func setup(save: SaveData, prog: Progression, cities: Array) -> void:
	_save = save
	_prog = prog
	_cities = cities
	_fill(Color(0.96, 0.97, 0.99, 0.98))
	var v := _column(36, 70, 50, 16)
	v.add_child(_centered("CREW", 64, Kit.INK))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for i in TABS.size():
		var b := Kit.button(TABS[i], Kit.SKY, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _open(i))
		_tab_buttons.append(b)
		tabs.add_child(b)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)
	v.add_child(_link(Kit.button("BACK", Kit.INK, 32), "menu"))
	_open(0)


func _open(tab: int) -> void:
	_tab = tab
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color.WHITE if i == tab else Color(0.66, 0.7, 0.76)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match tab:
		0: _captain()
		1: _rides()
		2: _gear()
		3: _records()


func _head(text: String) -> void:
	_body.add_child(Kit.label(text, 26, Kit.GREY.darkened(0.3)))


func _level() -> int:
	return _prog.level_of(int(_save.profile["xp"]))


func _captain() -> void:
	var faces: Array = _prog.data["faces"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var face := Kit.panel(Color(String(faces[int(_save.profile["face"]) % faces.size()])), 60, 0)
	face.custom_minimum_size = Vector2(120, 120)
	var initial := _centered(_save.display_name().substr(0, 1).to_upper(), 64, Color.WHITE)
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_child(initial)
	row.add_child(face)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(Kit.label(_save.display_name(), 44))
	var xp := int(_save.profile["xp"])
	side.add_child(Kit.label("LV %d    %d / %d XP" % [_level(), _prog.into_level(xp), _prog.need(_level())], 26, Kit.CORAL))
	side.add_child(Kit.label("COIN %s" % Kit.number(int(_save.profile["coins"])), 26, Kit.GOLD.darkened(0.15)))
	row.add_child(side)
	_body.add_child(row)

	_head("NAME  (10자까지)")
	var edit := LineEdit.new()
	edit.text = String(_save.profile["name"])
	edit.placeholder_text = "CAPTAIN"
	edit.max_length = SaveData.NAME_MAX
	edit.custom_minimum_size = Vector2(0, 76)
	edit.add_theme_font_size_override("font_size", 34)
	edit.add_theme_color_override("font_color", Kit.INK)
	edit.add_theme_color_override("font_placeholder_color", Kit.GREY)
	edit.add_theme_color_override("caret_color", Kit.INK)
	var field := Kit.box(Color.WHITE, 18, 14)
	field.border_color = Kit.GREY
	field.set_border_width_all(3)
	edit.add_theme_stylebox_override("normal", field)
	edit.add_theme_stylebox_override("focus", field)
	edit.text_submitted.connect(func(text: String) -> void:
		_save.set_name(text)
		_open(0))
	_body.add_child(edit)
	var ok := Kit.button("SAVE NAME", Kit.MINT, 28)
	ok.pressed.connect(func() -> void:
		_save.set_name(edit.text)
		_open(0))
	_body.add_child(ok)

	_head("FACE")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in faces.size():
		var b := Kit.button("✔" if i == int(_save.profile["face"]) else " ", Color(String(faces[i])), 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 90)
		b.pressed.connect(func() -> void:
			_save.pick("face", i)
			_open(0))
		grid.add_child(b)
	_body.add_child(grid)
	_head("ACCOUNT")
	_body.add_child(Kit.label("GUEST  ·  구글 계정 연결은 준비 중이에요", 24))


## 고르는 꾸밈 한 종류. 레벨이 모자라면 잠겨 있다.
func _choices(kind: String) -> void:
	for c: Dictionary in _prog.data[kind]:
		var id := String(c["id"])
		var open := _level() >= int(c["level"])
		var picked := String(_save.profile[kind]) == id
		var color := Color(String(c["color"])) if String(c["color"]) != "" else Kit.GREY.darkened(0.2)
		var text := "%s%s" % ["✔  " if picked else "", c["name"]] if open else "%s      LV %d" % [c["name"], c["level"]]
		var b := Kit.button(text, color if open else Kit.GREY, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not open
		b.pressed.connect(func() -> void:
			_save.pick(kind, id)
			_open(1))
		_body.add_child(b)


func _rides() -> void:
	_head("SHIP  (강에서 타는 것)")
	_body.add_child(Kit.label("OCEAN LINER  ·  다른 배는 준비 중이에요", 26))
	_head("BUS  (도로에서 타는 것)")
	_choices("bus")
	_head("BALL TRAIL  (공의 자취)")
	_choices("trail")
	_body.add_child(Kit.label("꾸밈은 모양만 바꿉니다. 레벨이 오르면 열립니다.", 22, Kit.GREY.darkened(0.2)))


func _gear() -> void:
	_body.add_child(Kit.label("COIN %s" % Kit.number(int(_save.profile["coins"])), 40, Kit.GOLD.darkened(0.15)))
	_body.add_child(Kit.label("출발 준비에서 한 판에 하나를 골라 가져갑니다. 쓴 판의 기록에는 GEAR 표시가 남습니다.", 22, Kit.GREY.darkened(0.2)))
	for g: Dictionary in _prog.data["gear"]:
		var id := String(g["id"])
		var price := int(g["price"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Kit.label("%s  ×%d" % [g["name"], _save.gear_count(id)], 32))
		words.add_child(Kit.label(String(g["about"]), 22, Kit.GREY.darkened(0.3)))
		row.add_child(words)
		var buy := Kit.button("BUY %d" % price, Kit.GOLD if int(_save.profile["coins"]) >= price else Kit.GREY, 26)
		buy.disabled = int(_save.profile["coins"]) < price
		buy.pressed.connect(func() -> void:
			_save.buy_gear(id, price)
			_open(2))
		row.add_child(buy)
		_body.add_child(row)


func _records() -> void:
	var s: Dictionary = _save.profile["stats"]
	var seconds := int(s.get("seconds", 0))
	for line: Array in [["PLAYED", "%d판" % int(s.get("games", 0))], ["CLEARED", "%d판" % int(s.get("clears", 0))],
			["SMASHED", "%s칸" % Kit.number(int(s.get("cells", 0)))], ["BEST COMBO", str(int(s.get("best_combo", 0)))],
			["PLAY TIME", "%d분 %d초" % [seconds / 60, seconds % 60]]]:
		var row := HBoxContainer.new()
		var name := Kit.label(String(line[0]), 28, Kit.GREY.darkened(0.3))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(Kit.label(String(line[1]), 34))
		_body.add_child(row)
	_head("WORLD TOUR")
	for city: Dictionary in _cities:
		var done := 0
		for st: Dictionary in city["stages"]:
			if _save.cleared.has(String(st["id"])):
				done += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name := Kit.label(String(city["name"]), 28)
		name.custom_minimum_size = Vector2(190, 0)
		row.add_child(name)
		var bar := ProgressBar.new()
		bar.max_value = city["stages"].size()
		bar.value = done
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 26)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", Kit.box(Kit.GREY.lightened(0.4), 13))
		bar.add_theme_stylebox_override("fill", Kit.box(Kit.MINT, 13))
		row.add_child(bar)
		row.add_child(Kit.label("%d/%d" % [done, city["stages"].size()], 26, Kit.GREY.darkened(0.3)))
		_body.add_child(row)
