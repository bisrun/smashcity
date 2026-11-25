class_name UiKit
extends RefCounted
## 화면 UI가 함께 쓰는 색, 글꼴, 작은 부품.
##
## 글꼴은 Jua 다(SIL Open Font License, assets/fonts/OFL.txt). 둥글둥글한 한글 글꼴이다.

const INK := Color("14213D")
const PAPER := Color(1, 1, 1, 0.9)
const CORAL := Color("F0645A")
const GOLD := Color("F5A623")
const MINT := Color("3DBE8B")
const SKY := Color("6FB8FF")
const GREY := Color("B9C1CE")

static var _theme: Theme


## 모든 UI에 거는 테마. 글꼴만 바꾼다.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		var font := load("res://assets/fonts/Jua-Regular.ttf") as Font
		if font != null:
			_theme.default_font = font
		_theme.default_font_size = 30
	return _theme


static func font() -> Font:
	return theme().default_font


## 모서리가 둥근 판.
static func box(color: Color, radius: int, pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 색 바탕 위에 글자가 놓인 알약 모양 표지.
static func chip(text: String, bg: Color, fg: Color = Color.WHITE, size: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, 40)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, fg)
	l.name = "Text"
	p.add_child(l)
	return p


static func panel(color: Color, radius: int, pad: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, pad))
	return p


## 도톰한 단추.
static func button(text: String, color: Color, size: int = 34, fg: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fg)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := box(color.darkened(0.12) if state == "pressed" else color, 28)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		sb.border_width_bottom = 0 if state == "pressed" else 6
		sb.border_color = color.darkened(0.25)
		b.add_theme_stylebox_override(state, sb)
	return b


## 점수를 천 단위로 끊어 쓴다.
static func number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## 순위 목록 한 줄씩을 담은 상자. mark 번째 줄(1부터)을 강조한다.
static func ranking(entries: Array, mark: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if entries.is_empty():
		v.add_child(label("아직 기록이 없어요", 26, GREY))
		return v
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var mine := i + 1 == mark
		var color := CORAL if mine else INK
		var place := chip(str(i + 1), GOLD if i == 0 else (CORAL if mine else GREY), Color.WHITE, 22)
		place.custom_minimum_size = Vector2(54, 0)
		row.add_child(place)
		var score := label(number(int(e["score"])), 30, color)
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score)
		row.add_child(label("클리어" if e.get("cleared", false) else "", 22, MINT))
		row.add_child(label(String(e.get("at", "")), 20, GREY))
		v.add_child(row)
	return v
