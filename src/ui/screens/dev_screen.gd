extends "res://src/ui/screens/base_screen.gd"
## DEV ROOM. 개발과 테스트에 쓰는 창이다. 설정 화면의 숨긴 동작으로 연다.
##
## 지금은 모든 스테이지를 보고 바로 들어가는 기능만 있다. 예쁘게 만들지 않는다. 한눈에 읽히면 된다.
## 여기서 들어간 판은 기록에 남지 않고 진행도 열지 않는다.

## cities: stages.json 의 cities, cleared: 클리어한 스테이지 ID들, info: 스테이지 ID → {grade, base}
func setup(cities: Array, cleared: Array[String], info: Dictionary) -> void:
	_fill(Color(0.1, 0.12, 0.16, 1.0))
	var v := _column(24, 60, 40, 10)
	v.add_child(Kit.label("DEV ROOM", 48, Color.WHITE))
	v.add_child(Kit.label("스테이지를 누르면 바로 시작합니다. 기록은 남지 않습니다.", 22, Kit.GREY))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for r in cities.size():
		var city: Dictionary = cities[r]
		list.add_child(Kit.label("%d. %s (%s)" % [r + 1, city["name"], city["id"]], 30, Kit.GOLD))
		var stages: Array = city["stages"]
		for i in stages.size():
			var s: Dictionary = stages[i]
			var id := String(s["id"])
			var about: Dictionary = info.get(id, {})
			var text := "%d-%d  %s    등급 %s  %s%s" % [r + 1, i + 1, s["name"], about.get("grade", "?"),
				"도로" if about.get("base", "") == "road" else "강", "  ✔" if cleared.has(id) else ""]
			var b := Kit.button(text if bool(s["ready"]) else text + "  (지도 없음)", Color(0.2, 0.24, 0.32), 26)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not bool(s["ready"])
			list.add_child(_link(b, "dev_stage", id))
	v.add_child(_link(Kit.button("BACK", Kit.GREY.darkened(0.3), 30), "settings"))
