extends "res://src/ui/screens/base_screen.gd"
## 시작 화면. 로고를 보여 주고, 누르면 로그인(처음)이나 메인 메뉴로 간다.

var _tap: Label
var _time := 0.0


func setup() -> void:
	_fill(Color(0.87, 0.96, 0.98, 0.55))
	var v := _column(60, 300, 260, 0)
	var title := Kit.panel(Color(1, 1, 1, 0.9), 56, 36)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -30)
	words.add_child(_centered("SMASH", 150, Kit.CORAL))
	words.add_child(_centered("CITY", 150, Kit.INK))
	title.add_child(words)
	v.add_child(title)
	v.add_child(_spacer())
	_tap = _centered("TAP TO START", 54, Kit.INK)
	v.add_child(_tap)


func _process(delta: float) -> void:
	_time += delta
	if _tap != null:
		_tap.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		accept_event()
		go.emit("title_done", "")
