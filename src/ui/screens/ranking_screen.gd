extends "res://src/ui/screens/base_screen.gd"
## RANKING. 스테이지별 점수 순위를 지역을 넘겨 가며 본다. 이 기기 안의 순위다.

var _cities: Array = []
var _save: SaveData
var _region := 0
var _title: Label
var _list: VBoxContainer


func setup(cities: Array, save: SaveData, region: int) -> void:
	_cities = cities
	_save = save
	_fill(Color(0.96, 0.97, 0.99, 0.98))
	var v := _column(36, 70, 50, 14)
	v.add_child(_centered("RANKING", 64, Kit.INK))
	v.add_child(_centered("이 기기의 기록입니다", 22, Kit.GREY.darkened(0.3)))
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	var prev := Kit.button("◀", Kit.SKY, 34)
	prev.pressed.connect(func() -> void: _open(_region - 1))
	nav.add_child(prev)
	_title = _centered("", 40, Kit.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_title)
	var next := Kit.button("▶", Kit.SKY, 34)
	next.pressed.connect(func() -> void: _open(_region + 1))
	nav.add_child(next)
	v.add_child(nav)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	v.add_child(_link(Kit.button("BACK", Kit.INK, 32), "menu"))
	_open(region)


func _open(region: int) -> void:
	_region = posmod(region, _cities.size())
	var city: Dictionary = _cities[_region]
	var sum := 0
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var stages: Array = city["stages"]
	for i in stages.size():
		var id := String(stages[i]["id"])
		sum += _save.best(id)
		var card := Kit.panel(Color.WHITE, 24, 16)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		card.add_child(rows)
		rows.add_child(Kit.label("%d  %s" % [i + 1, stages[i]["name"]], 30))
		rows.add_child(Kit.ranking(_save.top(id, 3), 0))
		_list.add_child(card)
	_title.text = "%d. %s   %s" % [_region + 1, city["name"], Kit.number(sum)]
