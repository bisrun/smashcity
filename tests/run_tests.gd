extends SceneTree
## 화면 없이 도는 테스트 실행기.
##
## 실행: godot --headless --path . -s tests/run_tests.gd
## 실패가 하나라도 있으면 종료 코드 1로 끝난다.
## 테스트를 더할 때는 _test_ 로 시작하는 함수를 만들고 _init 의 목록에 넣는다.

const StageDataScript := preload("res://src/data/stage_data.gd")
const BalanceScript := preload("res://src/data/balance.gd")
const SimScript := preload("res://src/sim/sim.gd")
const BoardViewScript := preload("res://src/render/board_view.gd")

const JAMSIL := "res://assets/stages/seoul/jamsil/map.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	for t: Callable in [
		_test_jamsil_loads, _test_jamsil_shapes_are_valid, _test_nearest_road_point, _test_display_height,
		_test_board_view_builds, _test_ball_launches_and_bounces_off_walls, _test_ball_breaks_a_cell,
		_test_paddle_sends_ball_up, _test_missed_ball_costs_a_life, _test_water_tosses_ball_out,
		_test_landmark_clears_stage, _test_item_drops_and_is_caught, _test_multiball, _test_wide_fire_life,
		_test_extra_balls_do_not_cost_a_life, _test_sim_is_deterministic, _test_jamsil_plays,
	]:
		t.call()
	print("%d개 확인, 실패 %d개" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("실패: " + what)


## 가로 1000, 세로 2000의 빈 판. 공 지름 40.
func _stage(extra: Dictionary = {}) -> StageData:
	var d := {"W": 1000, "H": 2000, "ball": 40}
	d.merge(extra)
	return StageDataScript.from_dict(d)


func _square(x: float, y: float, size: float, hp: int, landmark: int = 0) -> Dictionary:
	return {"p": [x, y, x + size, y, x + size, y + size, x, y + size], "hp": hp, "lm": landmark}


func _run(sim: Sim, seconds: float) -> void:
	for i in int(seconds / Sim.STEP):
		sim.step()


## 발사를 기다린 뒤 공을 원하는 자리와 방향에 놓는다.
func _place(sim: Sim, pos: Vector2, dir: Vector2) -> void:
	_run(sim, float(sim.cfg["launch_delay"]) + 0.05)
	sim.take_events()
	sim.ball_pos = pos
	sim.ball_vel = dir.normalized() * float(sim.cfg["ball_speed"])


func _no_gravity() -> Dictionary:
	var cfg := BalanceScript.load_file()
	cfg["gravity"] = 0.0
	return cfg


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
	_check(s.lakes.size() >= 1, "호수가 있다")
	_check(s.corridors.size() >= 1, "통로 면이 있다")
	_check(not BalanceScript.load_file().is_empty(), "밸런스 값 파일을 읽는다")


func _test_jamsil_shapes_are_valid() -> void:
	var s: StageData = StageDataScript.load_file(JAMSIL)
	if s == null:
		return
	var outside := 0
	var bad_hp := 0
	var untriangulated := 0
	for c in s.cells:
		var pts: PackedVector2Array = c["points"]
		if c["hp"] < 1 or c["hp"] > 4:
			bad_hp += 1
		if Geometry2D.triangulate_polygon(pts).is_empty():
			untriangulated += 1
		for p in pts:
			if p.x < -5.0 or p.x > s.width + 5.0 or p.y < -5.0 or p.y > s.height + 5.0:
				outside += 1
	_check(bad_hp == 0, "벽돌 HP는 1~4다 (벗어난 것 %d)" % bad_hp)
	_check(outside == 0, "벽돌은 판 안에 있다 (벗어난 꼭짓점 %d)" % outside)
	_check(untriangulated == 0, "모든 벽돌의 윗면을 삼각형으로 나눌 수 있다 (못 나눈 것 %d)" % untriangulated)


func _test_nearest_road_point() -> void:
	var s := _stage({"roads": [
		{"l": [0, 0, 10, 10], "c": "primary", "w": 20},
		{"l": [50, 50, 60, 60], "c": "residential", "w": 7},
	]})
	_check(s.nearest_road_point(PackedStringArray(["primary"]), Vector2(55, 55)) == Vector2(10, 10), "지정한 등급의 도로에서만 찾는다")
	_check(s.nearest_road_point(PackedStringArray(["trunk"]), Vector2(55, 55)) == Vector2(55, 55), "해당 등급이 없으면 목표 지점을 돌려준다")


func _test_display_height() -> void:
	_check(is_equal_approx(BoardViewScript.display_height(10, false), 32.0), "10층은 그대로 32m로 그린다")
	_check(BoardViewScript.display_height(1, false) == 9.0, "아주 낮은 건물도 9m로는 그린다")
	var tower: float = BoardViewScript.display_height(123, true)
	_check(tower > 60.0 and tower < 555.0, "랜드마크는 눌러 그린다 (실제 %.0f)" % tower)


func _test_board_view_builds() -> void:
	var s: StageData = StageDataScript.load_file(JAMSIL)
	if s == null:
		return
	var first: BoardView = BoardViewScript.new()
	first.build(s, 760.0, -690.0)
	var second: BoardView = BoardViewScript.new()
	second.build(s, 760.0, -690.0)
	_check(first.cell_nodes.size() == s.cells.size(), "셀마다 블록이 하나씩 있다")
	_check(first.object_count >= s.cells.size() * 0.8, "블록 대부분에 건물이 올라간다 (블록 %d, 건물 %d)" % [s.cells.size(), first.object_count])
	_check(first.object_count <= s.cells.size() * 1.3, "블록 하나에 건물은 하나꼴이다 (블록 %d, 건물 %d)" % [s.cells.size(), first.object_count])
	_check(first.object_count == second.object_count, "같은 스테이지는 늘 같게 꾸며진다")
	first.free()
	second.free()


func _test_ball_launches_and_bounces_off_walls() -> void:
	var sim: Sim = SimScript.new(_stage(), _no_gravity())
	_check(sim.ball_state == Sim.BallState.WAITING, "처음에는 공이 패들 위에서 기다린다")
	_run(sim, float(sim.cfg["launch_delay"]) + 0.05)
	_check(sim.ball_state == Sim.BallState.FLYING and sim.ball_vel.y > 0.0, "잠시 뒤 위로 발사된다")
	_place(sim, Vector2(900, 500), Vector2(1, 0.5))
	_run(sim, 0.5)
	_check(sim.ball_vel.x < 0.0 and sim.ball_pos.x <= 1000.0 - sim.ball_radius + 0.01, "오른쪽 벽에서 튕긴다")
	_place(sim, Vector2(500, 1900), Vector2(0.2, 1))
	_run(sim, 0.5)
	_check(sim.ball_vel.y < 0.0, "위쪽 벽에서 튕긴다")
	_check(is_equal_approx(sim.ball_vel.length(), float(sim.cfg["ball_speed"])), "속도는 일정하다")


func _test_ball_breaks_a_cell() -> void:
	var sim: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 2)]}), _no_gravity())
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.3)
	_check(sim.cell_hp[0] == 1, "맞으면 HP가 1 준다 (실제 %d)" % sim.cell_hp[0])
	_check(sim.ball_vel.y < 0.0, "맞은 뒤 되튄다")
	var kinds := sim.take_events().map(func(e: Dictionary) -> String: return e["type"])
	_check(kinds.has("hit") and not kinds.has("destroyed"), "맞았다는 사건만 생긴다")
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.3)
	_check(sim.cell_hp[0] == 0 and sim.destroyed == 1, "HP가 0이 되면 부서진다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "destroyed"), "부서졌다는 사건이 생긴다")
	_check(sim.score == 10 + 10 + 200, "점수는 타격 10점씩과 파괴 100 x HP (실제 %d)" % sim.score)
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.4)
	_check(sim.ball_pos.y > 1100.0, "부서진 자리는 공이 지나간다")


func _test_paddle_sends_ball_up() -> void:
	var sim: Sim = SimScript.new(_stage(), _no_gravity())
	sim.set_paddle(500)
	_place(sim, Vector2(500, -400), Vector2(0, -1))
	sim.combo = 3
	_run(sim, 0.4)
	_check(sim.ball_vel.y > 0.0 and absf(sim.ball_vel.x) < 1.0, "패들 가운데에 맞으면 곧게 올라간다")
	_check(sim.combo == 0, "패들에 닿으면 콤보가 끊긴다")
	_place(sim, Vector2(600, -400), Vector2(0, -1))
	_run(sim, 0.4)
	_check(sim.ball_vel.y > 0.0 and sim.ball_vel.x > 100.0, "패들 오른쪽에 맞으면 오른쪽으로 눕는다")


func _test_missed_ball_costs_a_life() -> void:
	var sim: Sim = SimScript.new(_stage(), _no_gravity())
	var start := sim.lives
	_check(start == int(sim.cfg["lives"]) and start >= 1, "밸런스 값만큼의 공으로 시작한다")
	sim.set_paddle(200)
	_place(sim, Vector2(800, -400), Vector2(0, -1))
	_run(sim, 0.6)
	_check(sim.lives == start - 1 and sim.ball_state == Sim.BallState.WAITING, "패들 뒤로 넘어가면 공 하나를 잃는다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "lost"), "잃었다는 사건이 생긴다")
	_run(sim, float(sim.cfg["respawn_delay"]) + 0.05)
	_check(sim.ball_state == Sim.BallState.FLYING and sim.ball_vel.y > 0.0, "공이 남아 있으면 패들에서 다시 발사된다")
	for i in start - 1:
		sim.set_paddle(200)
		_place(sim, Vector2(800, -400), Vector2(0, -1))
		_run(sim, 0.6)
		_run(sim, float(sim.cfg["respawn_delay"]) + 0.05)
	_check(sim.lives == 0 and sim.over, "공을 다 잃으면 판이 끝난다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "over"), "끝났다는 사건이 생긴다")
	var before := sim.elapsed
	_run(sim, 0.5)
	_check(sim.elapsed == before, "끝난 뒤에는 판정이 멈춘다")


func _test_water_tosses_ball_out() -> void:
	var extra := {
		"lake": [{"p": [200, 800, 800, 800, 800, 1200, 200, 1200], "h": []}],
		"corridors": [{"p": [450, 0, 550, 0, 550, 2000, 450, 2000], "h": []}],
	}
	var sim: Sim = SimScript.new(_stage(extra), _no_gravity())
	var start := sim.lives
	_place(sim, Vector2(300, 700), Vector2(0, 1))
	sim.combo = 4
	_run(sim, 0.2)
	_check(sim.ball_state == Sim.BallState.SUNK and sim.falls == 1, "호수에 들어가면 가라앉는다")
	_check(sim.lives == start and sim.combo == 0, "공은 잃지 않지만 콤보는 끊긴다")
	var sunk_at := sim.ball_pos
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "splash"), "빠졌다는 사건이 생긴다")
	var waited := 0
	while sim.ball_state == Sim.BallState.SUNK and waited < 1000:
		sim.step()
		waited += 1
	_check(sim.ball_state == Sim.BallState.FLYING and waited * Sim.STEP <= float(sim.cfg["splash_delay"]) + 0.02, "잠깐 뒤 튀어 오른다")
	_check(sim.ball_pos.distance_to(sunk_at) < 60.0, "빠진 자리에서 나온다")
	_check(is_equal_approx(sim.ball_vel.length(), float(sim.cfg["ball_speed"])), "튀어 오른 공의 속도는 그대로다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "emerge"), "튀어 올랐다는 사건이 생긴다")
	_run(sim, 0.25)
	_check(sim.falls == 1, "그 물을 벗어나기 전에는 다시 빠지지 않는다")

	var dirs := {}
	for i in 6:
		var s2: Sim = SimScript.new(_stage(extra), _no_gravity())
		for k in i + 1:
			_place(s2, Vector2(300, 700), Vector2(0, 1))
			_run(s2, 0.2)
			_run(s2, float(s2.cfg["splash_delay"]) + 0.01)
			s2.balls[0].skipping = false
		dirs[snappedf(s2.ball_vel.angle(), 0.01)] = true
	_check(dirs.size() >= 4, "튀어 오르는 방향은 그때그때 다르다 (서로 다른 방향 %d가지)" % dirs.size())

	var bridge: Sim = SimScript.new(_stage(extra), _no_gravity())
	_place(bridge, Vector2(500, 700), Vector2(0, 1))
	_run(bridge, 0.7)
	_check(bridge.falls == 0 and bridge.ball_pos.y > 1200.0, "호수 위를 지나는 통로로는 건넌다")


func _test_landmark_clears_stage() -> void:
	var cfg := _no_gravity()
	cfg["landmark_hp"] = 1
	var sim: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 4, 1), _square(100, 1500, 100, 1)]}), cfg)
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.3)
	_check(sim.cleared, "랜드마크가 부서지면 클리어다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "cleared"), "클리어 사건이 생긴다")
	var before := sim.elapsed
	_run(sim, 0.5)
	_check(sim.elapsed == before, "클리어 뒤에는 판정이 멈춘다")


## 아이템 하나가 든 셀 하나짜리 판.
func _item_stage(type: String) -> Sim:
	var cfg := _no_gravity()
	var sim: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 1)]}), cfg, {"items": [{"at": [500, 1100], "type": type}]})
	return sim


## 셀을 부숴 아이템을 떨어뜨리고, 패들을 그 아래에 두어 받는다.
func _catch_item(sim: Sim) -> void:
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.2)
	sim.set_paddle(500)
	for i in 2000:
		if sim.items.is_empty():
			break
		sim.set_paddle(500)
		sim.step()


func _test_item_drops_and_is_caught() -> void:
	var sim := _item_stage("wide")
	_check(sim.item_in_cell(0) == "wide", "기획 파일의 자리에 있는 셀에 아이템이 들어간다")
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.2)
	_check(sim.items.size() == 1 and sim.items[0]["type"] == "wide", "셀이 부서지면 아이템이 나온다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "item_spawn"), "아이템이 나왔다는 사건이 생긴다")
	var y0: float = sim.items[0]["pos"].y
	_run(sim, 0.5)
	_check(sim.items[0]["pos"].y < y0, "아이템은 패들 쪽으로 내려온다")
	var before := sim.score
	_catch_item(sim)
	_check(sim.items.is_empty() and sim.wide_left > 0.0, "패들로 받으면 발동한다")
	_check(sim.score >= before + int(sim.cfg["score_item"]), "받으면 점수를 얻는다")

	var missed := _item_stage("wide")
	_place(missed, Vector2(500, 900), Vector2(0, 1))
	_run(missed, 0.2)
	for i in 2000:
		if missed.items.is_empty():
			break
		missed.set_paddle(900)
		missed.step()
	_check(missed.items.is_empty() and missed.wide_left == 0.0, "놓친 아이템은 사라지고 발동하지 않는다")


func _test_multiball() -> void:
	var sim := _item_stage("multi")
	_catch_item(sim)
	var flying := sim.balls.filter(func(b: Sim.Ball) -> bool: return b.state == Sim.BallState.FLYING).size()
	_check(flying == 3, "멀티볼을 받으면 공이 셋이 된다 (실제 %d)" % flying)
	var dirs := {}
	for b in sim.balls:
		dirs[snappedf(b.vel.angle(), 0.01)] = true
	_check(dirs.size() == 3, "세 공은 서로 다른 방향으로 간다")
	var many := _item_stage("multi")
	many.cfg["max_balls"] = 2
	_catch_item(many)
	_check(many.balls.size() <= 2, "공의 수는 한도를 넘지 않는다")


func _test_wide_fire_life() -> void:
	var wide := _item_stage("wide")
	var normal := wide.paddle_width()
	_catch_item(wide)
	_check(wide.paddle_width() > normal, "넓은 패들을 받으면 패들이 넓어진다")
	_run(wide, float(wide.cfg["wide_seconds"]) + 0.1)
	_check(is_equal_approx(wide.paddle_width(), normal), "시간이 지나면 원래대로 돌아온다")

	var life := _item_stage("life")
	var start := life.lives
	_catch_item(life)
	_check(life.lives == start + 1, "공 +1을 받으면 남은 공이 하나 는다")

	var cfg := _no_gravity()
	var fire: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 3), _square(400, 1300, 200, 4)]}), cfg)
	fire.fire_left = 5.0
	_place(fire, Vector2(500, 900), Vector2(0, 1))
	_run(fire, 0.7)
	_check(fire.destroyed == 2, "불공은 HP와 상관없이 셀을 부수며 지나간다 (부순 수 %d)" % fire.destroyed)
	_check(fire.ball_vel.y > 0.0 or fire.ball_pos.y > 1500.0, "불공은 셀에 튕기지 않는다")
	var boss_cfg := _no_gravity()
	var boss: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 4, 1)]}), boss_cfg)
	boss.fire_left = 5.0
	_place(boss, Vector2(500, 900), Vector2(0, 1))
	_run(boss, 0.3)
	_check(boss.cell_hp[0] == int(boss.cfg["landmark_hp"]) - 1 and boss.ball_vel.y < 0.0, "랜드마크는 불공으로도 한 번에 못 부수고 튕긴다")


func _test_extra_balls_do_not_cost_a_life() -> void:
	var sim := _item_stage("multi")
	_catch_item(sim)
	var start := sim.lives
	var count := sim.balls.size()
	sim.set_paddle(100)
	sim.balls[0].pos = Vector2(800, -500)
	sim.balls[0].vel = Vector2(0, -1) * float(sim.cfg["ball_speed"])
	_run(sim, 0.4)
	_check(sim.balls.size() == count - 1 and sim.lives == start, "공이 남아 있으면 하나를 놓쳐도 목숨은 그대로다")


func _play(seconds: float) -> Sim:
	var dir := JAMSIL.get_base_dir()
	var sim: Sim = SimScript.new(StageDataScript.load_file(JAMSIL), BalanceScript.load_file(), BalanceScript.load_file(dir + "/design.json"))
	for i in int(seconds / Sim.STEP):
		var target := sim.paddle_x
		var lowest := INF
		for b in sim.balls:
			if b.state == Sim.BallState.FLYING and b.vel.y < 0.0 and b.pos.y < lowest:
				lowest = b.pos.y
				target = b.pos.x
		for it in sim.items:
			if lowest > 400.0:
				target = it["pos"].x
		sim.set_paddle(target + sin(i * 0.013) * 90.0)
		sim.step()
	return sim


func _test_sim_is_deterministic() -> void:
	var a := _play(20.0)
	var b := _play(20.0)
	_check(a.ball_pos == b.ball_pos and a.score == b.score and a.destroyed == b.destroyed and a.balls.size() == b.balls.size(), "같은 입력이면 같은 결과가 나온다")


## 공을 늘 받아 내는 패들로 잠실을 2분 돌려 본다. 판이 굴러가는지 보는 것이지 밸런스를 보는 것이 아니다.
func _test_jamsil_plays() -> void:
	var sim := _play(120.0)
	var sane := true
	for ball in sim.balls:
		var p := ball.pos
		if is_nan(p.x) or is_nan(p.y) or p.x < 0.0 or p.x > sim.stage.width or p.y > sim.stage.height:
			sane = false
	_check(sane, "공이 판 밖으로 나가거나 위치가 깨지지 않는다")
	_check(sim.destroyed >= 10, "2분 동안 벽돌이 10개 이상 부서진다 (실제 %d)" % sim.destroyed)
	print("  잠실 2분: 부순 벽돌 %d/%d, 호수에 빠짐 %d회, 남은 목숨 %d, %d점%s%s" % [sim.destroyed, sim.breakable_count(), sim.falls, sim.lives, sim.score, ", 클리어" if sim.cleared else "", ", 게임 오버" if sim.over else ""])
