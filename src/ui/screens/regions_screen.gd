extends "res://src/ui/screens/base_screen.gd"
## WORLD TOUR. 지역을 고른다. 고르면 그 지역에서 아직 못 깬 첫 스테이지의 지도로 간다.
##
## 지금은 앞 지역을 다 깨야 다음 지역이 열린다. 별로 여는 규칙(docs/09)은 별이 생긴 뒤에 바꾼다.

## cities: stages.json 의 cities, cleared: 클리어한 스테이지 ID들
func setup(cities: Array, cleared: Array[String]) -> void:
	_fill(Color(0.87, 0.96, 0.98, 0.96))
	var v := _column(40, 70, 60, 14)
	v.add_child(_centered("WORLD TOUR", 64, Kit.INK))
	v.add_child(_centered("지역을 고르세요", 26, Kit.GREY.darkened(0.3)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var open := true
	for i in cities.size():
		var city: Dictionary = cities[i]
		var total := 0
		var done := 0
		var next := ""
		var first := ""
		for s: Dictionary in city["stages"]:
			if not bool(s["ready"]):
				continue
			total += 1
			if first == "":
				first = String(s["id"])
			if cleared.has(String(s["id"])):
				done += 1
			elif next == "":
				next = String(s["id"])
		var b := Kit.button("%d  %s      %d / %d" % [i + 1, city["name"], done, total] if open else "%d  %s      LOCKED" % [i + 1, city["name"]],
			(Kit.MINT if done == total else Kit.CORAL) if open else Kit.GREY, 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 104)
		if open and first != "":
			_link(b, "stage", next if next != "" else first)
		else:
			b.disabled = true
		list.add_child(b)
		# 다 깨야 다음 지역이 열린다
		open = open and total > 0 and done == total
	v.add_child(_link(Kit.button("BACK", Kit.INK, 32), "menu"))
