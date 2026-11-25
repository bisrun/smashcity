extends Control
## 공간 하나를 그리는 화면들의 바탕. 화면은 스스로 다른 공간을 열지 않고 go 로 알리기만 한다.

const Kit := preload("res://src/ui/ui_kit.gd")

## to: 가려는 곳이나 일어난 일, arg: 딸린 값(스테이지 ID 등)
signal go(to: String, arg: String)


## 화면을 가득 채우고 바탕색을 깐다. 바탕색의 알파가 낮으면 뒤의 도시가 비친다.
func _fill(bg: Color) -> void:
	theme = Kit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = bg
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 바탕이 누름을 삼키면 화면 자신이 받지 못한다(시작 화면의 TAP TO START). 화면이 직접 받아 뒤의 것을 가린다.
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


## 가장자리를 띄운 세로 줄.
func _column(side: int, top: int, bottom: int, gap: int) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v


func _centered(text: String, size: int, color: Color) -> Label:
	var l := Kit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _link(b: Button, to: String, arg: String = "") -> Button:
	b.pressed.connect(func() -> void: go.emit(to, arg))
	return b
