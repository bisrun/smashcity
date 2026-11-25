extends "res://src/ui/screens/base_screen.gd"
## TROPHIES. 부순 목표 건물을 모아 보여 준다. 스테이지 하나에 트로피 하나다.
##
## 지금은 이름표뿐이다. 건물 모형과 실제 정보(높이, 준공 연도)는 아직 없다.

func setup(cities: Array, cleared: Array[String]) -> void:
	_fill(Color(0.99, 0.97, 0.92, 0.98))
	var v := _column(36, 70, 50, 14)
	v.add_child(_centered("TROPHIES", 64, Kit.INK))
	var total := 0
	for city: Dictionary in cities:
		total += city["stages"].size()
	v.add_child(_centered("%d / %d" % [cleared.size(), total], 34, Kit.GOLD.darkened(0.1)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for city: Dictionary in cities:
		var done := 0
		for s: Dictionary in city["stages"]:
			if cleared.has(String(s["id"])):
				done += 1
		list.add_child(Kit.label("%s   %d / %d" % [city["name"], done, city["stages"].size()], 32))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for s: Dictionary in city["stages"]:
			var got := cleared.has(String(s["id"]))
			var chip := Kit.chip("★ %s" % s["name"] if got else "?", Kit.GOLD if got else Kit.GREY.lightened(0.2), Color.WHITE, 24)
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(chip)
		list.add_child(grid)
	v.add_child(_link(Kit.button("BACK", Kit.INK, 32), "menu"))
