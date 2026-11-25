extends "res://src/ui/screens/base_screen.gd"
## DEV ROOM. 개발과 테스트에 쓰는 창이다. 설정 화면의 숨긴 동작으로 연다.
##
## 예쁘게 만들지 않는다. 한눈에 읽히면 된다. 기능이 늘어도 한 화면이 넘치지 않게 단계로 나눈다.
##   DEV ROOM → STAGE JUMP → 지역 → 스테이지
## 여기서 들어간 판은 기록에 남지 않고 진행도 열지 않는다.

const BUTTON := Color(0.2, 0.24, 0.32)

var _cities: Array = []
var _cleared: Array[String] = []
var _info := {}
## 지금 보고 있는 단계. [] 는 처음, ["stages"] 는 지역 목록, ["stages", 지역 번호] 는 스테이지 목록
var _path: Array = []
var _title: Label
var _hint: Label
var _list: VBoxContainer


## cities: stages.json 의 cities, cleared: 클리어한 스테이지 ID들, info: 스테이지 ID → {grade, base}
func setup(cities: Array, cleared: Array[String], info: Dictionary) -> void:
	_cities = cities
	_cleared = cleared
	_info = info
	_fill(Color(0.1, 0.12, 0.16, 1.0))
	var v := _column(24, 60, 40, 10)
	_title = Kit.label("", 44, Color.WHITE)
	v.add_child(_title)
	_hint = Kit.label("", 22, Kit.GREY)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var back_button := Kit.button("BACK", Kit.GREY.darkened(0.3), 30)
	back_button.pressed.connect(func() -> void: back())
	v.add_child(back_button)
	_open([])


func _row(text: String, action: Callable, enabled: bool = true) -> void:
	var b := Kit.button(text, BUTTON, 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 84)
	b.disabled = not enabled
	b.pressed.connect(action)
	_list.add_child(b)


func _open(path: Array) -> void:
	_path = path
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if path.is_empty():
		_title.text = "DEV ROOM"
		_hint.text = "개발과 테스트용 창입니다."
		_row("STAGE JUMP      스테이지 바로가기  ▶", func() -> void: _open(["stages"]))
	elif path.size() == 1:
		_title.text = "STAGE JUMP"
		_hint.text = "지역을 고르세요."
		for r in _cities.size():
			var city: Dictionary = _cities[r]
			var done := 0
			for s: Dictionary in city["stages"]:
				if _cleared.has(String(s["id"])):
					done += 1
			_row("%d. %s (%s)      깬 판 %d/%d  ▶" % [r + 1, city["name"], city["id"], done, city["stages"].size()],
				func() -> void: _open(["stages", r]))
	else:
		var r: int = path[1]
		var city: Dictionary = _cities[r]
		_title.text = "%d. %s" % [r + 1, city["name"]]
		_hint.text = "스테이지를 누르면 바로 시작합니다. 기록은 남지 않습니다."
		var stages: Array = city["stages"]
		for i in stages.size():
			var s: Dictionary = stages[i]
			var id := String(s["id"])
			var about: Dictionary = _info.get(id, {})
			var text := "%d-%d  %s      등급 %s  %s%s" % [r + 1, i + 1, s["name"], about.get("grade", "?"),
				"도로" if about.get("base", "") == "road" else "강", "  ✔" if _cleared.has(id) else ""]
			_row(text if bool(s["ready"]) else text + "  (지도 없음)", func() -> void: go.emit("dev_stage", id), bool(s["ready"]))


## 한 단계 위로 간다. 처음 단계에서는 설정으로 나간다.
func back() -> bool:
	if _path.is_empty():
		go.emit("settings", "")
	else:
		_open(_path.slice(0, _path.size() - 1))
	return true
