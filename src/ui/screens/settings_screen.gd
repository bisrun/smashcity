extends "res://src/ui/screens/base_screen.gd"
## OPTIONS. 게임의 기본 설정이다.
##
## 위쪽 띠에는 단추를 두지 않는다. 그 자리를 왼쪽에서 오른쪽으로 끌고 오른쪽 위를 빠르게 열 번 두드리면
## 개발자 창(DEV ROOM)이 열린다(src/ui/secret_gesture.gd).

const Gesture := preload("res://src/ui/secret_gesture.gd")
const Settings := preload("res://src/meta/settings_data.gd")

## 값이 바뀌었다. 받는 쪽이 소리 크기 같은 것을 바로 적용한다.
signal changed

var _settings: SettingsData
var _gesture: SecretGesture = Gesture.new()


func setup(settings: SettingsData, account: String, version: String) -> void:
	_settings = settings
	_fill(Color(0.96, 0.97, 0.99, 0.98))
	var v := _column(50, 110, 60, 20)
	v.add_child(_centered("OPTIONS", 72, Kit.INK))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 110)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pad)

	v.add_child(Kit.label("SOUND", 26, Kit.GREY.darkened(0.3)))
	v.add_child(_slider("sound", 0.0, 1.0, 0.05))
	v.add_child(_toggle("VIBRATION", "vibrate"))
	v.add_child(_toggle("SCREEN SHAKE", "shake"))
	v.add_child(Kit.label("DRAG SPEED", 26, Kit.GREY.darkened(0.3)))
	v.add_child(_slider("drag_gain", Settings.DRAG_GAIN_MIN, Settings.DRAG_GAIN_MAX, 0.05))

	v.add_child(Kit.label("ACCOUNT", 26, Kit.GREY.darkened(0.3)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var who := Kit.label("GUEST" if account == "guest" else account.to_upper(), 34)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	row.add_child(_link(Kit.button("LOG OUT", Kit.GREY.darkened(0.25), 26), "logout"))
	v.add_child(row)
	v.add_child(Kit.label("구글 계정 연결은 준비 중이에요", 22, Kit.GREY.darkened(0.2)))

	v.add_child(_spacer())
	v.add_child(_centered("SmashCity %s\n지도 데이터 © OpenStreetMap contributors" % version, 22, Kit.GREY.darkened(0.3)))
	v.add_child(_link(Kit.button("BACK", Kit.INK, 32), "menu"))


func _slider(key: String, low: float, high: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value = float(_settings.values[key])
	s.custom_minimum_size = Vector2(0, 64)
	s.focus_mode = Control.FOCUS_NONE
	var track := Kit.box(Kit.GREY, 10)
	track.content_margin_top = 9
	track.content_margin_bottom = 9
	s.add_theme_stylebox_override("slider", track)
	var filled := Kit.box(Kit.CORAL, 10)
	filled.content_margin_top = 9
	filled.content_margin_bottom = 9
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	s.value_changed.connect(func(value: float) -> void:
		_settings.put(key, value)
		changed.emit())
	return s


func _toggle(text: String, key: String) -> Button:
	var b := Kit.button("", Kit.MINT, 32)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var show := func() -> void:
		var on := bool(_settings.values[key])
		b.text = "%s      %s" % [text, "ON" if on else "OFF"]
		b.modulate = Color.WHITE if on else Color(0.72, 0.74, 0.78)
	b.pressed.connect(func() -> void:
		_settings.put(key, not bool(_settings.values[key]))
		show.call()
		changed.emit())
	show.call()
	return b


## 숨긴 동작을 본다. 다른 부품보다 먼저 보고, 삼키지 않는다.
func _input(event: InputEvent) -> void:
	var touch := event is InputEventScreenTouch
	# 터치 화면에서는 터치가 마우스로도 한 번 더 들어온다. 두 번 세지 않게 터치만 본다.
	var mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available()
	if not touch and not mouse:
		return
	if event.pressed:
		_gesture.press(event.position)
	elif _gesture.release(event.position, size, Time.get_ticks_msec() / 1000.0):
		go.emit("dev", "")
