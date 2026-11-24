extends SceneTree
## 화면 없이 도는 테스트 실행기.
##
## 실행: godot --headless --path . -s tests/run_tests.gd
## 실패가 하나라도 있으면 종료 코드 1로 끝난다.
## 테스트를 더할 때는 _test_ 로 시작하는 함수를 만들고 _init 의 목록에 넣는다.

const StageDataScript := preload("res://src/data/stage_data.gd")
const BoardViewScript := preload("res://src/render/board_view.gd")

const JAMSIL := "res://assets/stages/seoul/jamsil/map.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	for t: Callable in [_test_jamsil_loads, _test_jamsil_shapes_are_valid, _test_nearest_road_point, _test_display_height]:
		t.call()
	print("%d개 확인, 실패 %d개" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("실패: " + what)


func _test_jamsil_loads() -> void:
	var s: StageData = StageDataScript.load_file(JAMSIL)
	_check(s != null, "잠실 스테이지 파일을 읽는다")
	if s == null:
		return
	_check(s.width > 1000.0 and s.height > s.width, "판은 세로로 길다")
	_check(s.ball_diameter > 0.0, "공 지름이 있다")
	_check(s.cells.size() >= 80, "벽돌이 80개 이상이다 (실제 %d)" % s.cells.size())
	_check(s.buildings.size() > s.cells.size(), "건물이 벽돌보다 많다")
	_check(s.cells.filter(func(c: Dictionary) -> bool: return c["landmark"]).size() >= 1, "랜드마크가 선 벽돌이 있다")
	_check(s.buildings.filter(func(b: Dictionary) -> bool: return b["landmark"]).size() >= 1, "랜드마크 건물이 있다")
	_check(s.lakes.size() >= 1, "호수가 있다")


func _test_jamsil_shapes_are_valid() -> void:
	var s: StageData = StageDataScript.load_file(JAMSIL)
	if s == null:
		return
	var outside := 0
	var bad_hp := 0
	var too_few := 0
	for c in s.cells:
		var pts: PackedVector2Array = c["points"]
		if pts.size() < 3:
			too_few += 1
		if c["hp"] < 1 or c["hp"] > 4:
			bad_hp += 1
		for p in pts:
			if p.x < -5.0 or p.x > s.width + 5.0 or p.y < -5.0 or p.y > s.height + 5.0:
				outside += 1
	_check(too_few == 0, "모든 벽돌은 꼭짓점이 3개 이상이다 (모자란 것 %d)" % too_few)
	_check(bad_hp == 0, "벽돌 HP는 1~4다 (벗어난 것 %d)" % bad_hp)
	_check(outside == 0, "벽돌은 판 안에 있다 (벗어난 꼭짓점 %d)" % outside)
	var untriangulated := 0
	for c in s.cells:
		if Geometry2D.triangulate_polygon(c["points"]).is_empty():
			untriangulated += 1
	_check(untriangulated == 0, "모든 벽돌의 윗면을 삼각형으로 나눌 수 있다 (못 나눈 것 %d)" % untriangulated)


func _test_nearest_road_point() -> void:
	var s: StageData = StageDataScript.from_dict({
		"W": 100, "H": 200, "ball": 4,
		"roads": [
			{"l": [0, 0, 10, 10], "c": "primary", "w": 20},
			{"l": [50, 50, 60, 60], "c": "residential", "w": 7},
		],
	})
	_check(s.nearest_road_point(PackedStringArray(["primary"]), Vector2(55, 55)) == Vector2(10, 10), "지정한 등급의 도로에서만 찾는다")
	_check(s.nearest_road_point(PackedStringArray(["trunk"]), Vector2(55, 55)) == Vector2(55, 55), "해당 등급이 없으면 목표 지점을 돌려준다")


func _test_display_height() -> void:
	_check(is_equal_approx(BoardViewScript.display_height(10, false), 32.0), "10층은 그대로 32m로 그린다")
	_check(BoardViewScript.display_height(1, false) == 9.0, "아주 낮은 건물도 9m로는 그린다")
	var tower: float = BoardViewScript.display_height(123, true)
	_check(tower > 60.0 and tower < 555.0, "랜드마크는 눌러 그린다 (실제 %.0f)" % tower)
	_check(BoardViewScript.display_height(40, false) < 40 * 3.2, "60m를 넘는 건물은 눌러 그린다")
