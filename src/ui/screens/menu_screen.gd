extends "res://src/ui/screens/base_screen.gd"
## 메인 메뉴. 모든 공간으로 가는 중심이다. 뒤에는 이어 할 스테이지의 도시가 비친다.

var _note: Label


## next: 이어 할 곳("서울 3/10 · 강남"), who: 위쪽에 쓸 이름과 레벨, coins: 가진 코인
func setup(next: String, who: String, coins: int) -> void:
	_fill(Color(1, 1, 1, 0.18))
	var v := _column(40, 70, 90, 18)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var me := Kit.button(who, Kit.INK, 26)
	top.add_child(_link(me, "crew"))
	top.add_child(Kit.chip("COIN %s" % Kit.number(coins), Kit.GOLD, Color.WHITE, 24))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(_link(Kit.button("OPTIONS", Kit.GREY.darkened(0.25), 26), "settings"))
	v.add_child(top)
	var title := Kit.panel(Color(1, 1, 1, 0.86), 44, 22)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -26)
	words.add_child(_centered("SMASH", 124, Kit.CORAL))
	words.add_child(_centered("CITY", 124, Kit.INK))
	title.add_child(words)
	v.add_child(title)
	v.add_child(_spacer())
	_note = _centered("", 26, Kit.INK)
	v.add_child(_note)
	var where := Kit.chip(next, Color(1, 1, 1, 0.9), Kit.INK, 28)
	where.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(where)
	var play := Kit.button("PLAY", Kit.CORAL, 76)
	play.custom_minimum_size = Vector2(0, 170)
	v.add_child(_link(play, "play_next"))
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	for item: Array in [["WORLD TOUR", "regions", Kit.MINT], ["CREW", "crew", Kit.SKY], ["TROPHIES", "trophies", Kit.GOLD], ["RANKING", "ranking", Kit.GOLD]]:
		var b := Kit.button(String(item[0]), item[2], 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		if String(item[1]) == "":
			# 아직 만들지 않은 공간
			b.pressed.connect(func() -> void: _note.text = "%s 는 준비 중이에요" % item[0])
		else:
			_link(b, String(item[1]))
		row.add_child(b)
	v.add_child(row)
