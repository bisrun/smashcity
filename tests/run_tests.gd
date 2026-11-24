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
		_test_forest_lasts_several_hits, _test_protected_facility_never_breaks, _test_stage_balance_overrides_defaults, _test_shield_saves_one_ball, _test_wrecking_ball_hits_twice_as_hard, _test_paddle_sends_ball_up, _test_missed_ball_costs_a_life, _test_water_splits_ball_in_two,
		_test_extra_ball_fades_after_bounces, _test_extra_ball_splits_too, _test_sounds_are_built,
		_test_landmark_clears_stage, _test_item_drops_and_is_caught, _test_multiball, _test_wide_fire_life,
		_test_extra_balls_do_not_cost_a_life, _test_speed_grows_with_progress, _test_idle_ball_is_pulled_to_a_cell,
		_test_fever_chains_to_neighbors, _test_wall_blocks_but_gap_lets_through, _test_bolt_finishes_the_last_cells,
		_test_pressure_builds_over_time, _test_narrow_item_hurts, _test_models_load, _test_save_data_ranks_scores, _test_stage_list_is_valid, _test_sim_is_deterministic, _test_jamsil_plays,
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


## 중력과, 시간에 따라 조여 오는 장치를 끈 밸런스 값. 한 가지 규칙만 따로 볼 때 쓴다.
func _no_gravity() -> Dictionary:
	var cfg := BalanceScript.load_file()
	cfg["gravity"] = 0.0
	cfg["time_speed_every"] = 99999.0
	cfg["drop_interval_start"] = 99999.0
	cfg["drop_interval_end"] = 99999.0
	cfg["rush_after"] = 99999.0
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
	_check(first.object_count >= s.cells.size() * 0.5, "블록의 절반 이상이 건물이다 (블록 %d, 건물 %d)" % [s.cells.size(), first.object_count])
	_check(first.object_count < s.cells.size(), "나머지는 공원이거나 랜드마크다 (블록 %d, 건물 %d)" % [s.cells.size(), first.object_count])
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


func _test_forest_lasts_several_hits() -> void:
	var forest := _square(400, 1000, 200, 1)
	forest["e"] = 1
	var sim: Sim = SimScript.new(_stage({"cells": [forest, _square(100, 1700, 100, 2)]}), _no_gravity())
	var tough := int(sim.cfg["forest_hp"])
	_check(tough == 5 and sim.cell_hp[0] == tough, "건물이 없던 낮은 구획은 숲이고, 다섯 번 맞아야 부서진다")
	_check(sim.breakable_count() == 2, "숲도 부술 셀로 센다")
	for i in tough - 1:
		_place(sim, Vector2(500, 900), Vector2(0, 1))
		_run(sim, 0.3)
	_check(sim.cell_hp[0] == 1 and sim.destroyed == 0, "마지막 한 번 전까지는 서 있다 (남은 HP %d)" % sim.cell_hp[0])
	_check(sim.ball_vel.y < 0.0, "공은 숲에서 튕겨 나온다")
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.3)
	_check(sim.cell_hp[0] == 0 and sim.destroyed == 1, "마지막 한 번에 부서진다")
	var fire: Sim = SimScript.new(_stage({"cells": [forest, _square(100, 1700, 100, 2)]}), _no_gravity())
	fire.fire_left = 5.0
	_place(fire, Vector2(500, 900), Vector2(0, 1))
	_run(fire, 0.3)
	_check(fire.cell_hp[0] == tough - 1 and fire.ball_vel.y < 0.0, "불공도 숲은 한 번에 뚫지 못한다")


func _test_protected_facility_never_breaks() -> void:
	var shrine := _square(400, 1000, 200, 2)
	shrine["s"] = 1
	var sim: Sim = SimScript.new(_stage({"cells": [shrine, _square(100, 1700, 100, 2)]}), _no_gravity())
	_check(sim.cell_solid[0] == 1 and sim.breakable_count() == 1, "부수지 않는 시설은 부술 셀로 세지 않는다")
	for i in 4:
		_place(sim, Vector2(500, 900), Vector2(0, 1))
		_run(sim, 0.3)
	_check(sim.cell_hp[0] == 2 and sim.destroyed == 0, "시설은 여러 번 맞아도 그대로다")
	_check(sim.ball_vel.y < 0.0, "공은 시설에서 튕겨 나온다")
	sim.fire_left = 5.0
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.3)
	_check(sim.cell_hp[0] == 2, "불공도 시설은 부수지 못한다")


func _test_stage_balance_overrides_defaults() -> void:
	var base := _no_gravity()
	var cfg: Dictionary = BalanceScript.merged(base, {"balance": {"ball_speed": 1300, "cell_hp_bonus": 1, "landmark_hp": 20}})
	_check(int(cfg["ball_speed"]) == 1300 and int(base["ball_speed"]) != 1300, "스테이지 값이 기본 값을 덮어쓰고, 기본 값은 그대로다")
	_check(BalanceScript.merged(base, {})["ball_speed"] == base["ball_speed"], "스테이지 값이 없으면 기본 값 그대로다")
	var sim: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 2), _square(100, 1700, 100, 1, 1)]}), cfg)
	_check(sim.cell_hp[0] == 3, "건물 HP에 스테이지의 덧값이 붙는다")
	_check(sim.cell_hp[1] == 20, "목표 건물의 HP는 스테이지 값을 따른다")


func _test_shield_saves_one_ball() -> void:
	var sim: Sim = SimScript.new(_stage({"cells": [_square(100, 1700, 100, 2)]}), _no_gravity())
	sim._apply_item("shield")
	sim._apply_item("shield")
	_check(sim.shield == 1, "방어막은 한 번에 하나만 가진다")
	var lives := sim.lives
	sim.set_paddle(100.0)
	_place(sim, Vector2(800, float(sim.cfg["paddle_y"]) + 200.0), Vector2(0, -1))
	_run(sim, 0.6)
	_check(sim.shield == 0 and sim.lives == lives and sim.ball_vel.y > 0.0, "놓친 공을 방어막이 한 번 받아 올려 보낸다")
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "shield_used"), "방어막이 쓰이면 사건이 생긴다")
	_place(sim, Vector2(800, float(sim.cfg["paddle_y"]) + 200.0), Vector2(0, -1))
	_run(sim, 0.6)
	_check(sim.lives == lives - 1, "방어막이 없으면 목숨을 잃는다")


func _test_wrecking_ball_hits_twice_as_hard() -> void:
	var sim: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 4), _square(100, 1700, 100, 2)]}), _no_gravity())
	sim._apply_item("wreck")
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.3)
	_check(sim.cell_hp[0] == 2, "레킹볼은 한 번에 두 칸을 깎는다 (남은 HP %d)" % sim.cell_hp[0])
	_run(sim, float(sim.cfg["wreck_seconds"]) + 0.1)
	_check(sim.wreck_left == 0.0, "레킹볼은 시간이 지나면 끝난다")


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


func _lake_stage() -> Dictionary:
	return {
		"lake": [{"p": [200, 800, 800, 800, 800, 1200, 200, 1200], "h": []}],
		"corridors": [{"p": [450, 0, 550, 0, 550, 2000, 450, 2000], "h": []}],
	}


## 공을 호수에 빠뜨리고 튀어 오를 때까지 돌린다.
func _sink_and_emerge(sim: Sim, at: Vector2) -> void:
	sim.balls[0].grace = 0.0
	sim.balls[0].skipping = false
	sim.balls[0].pos = at
	sim.balls[0].vel = Vector2(0, 1) * sim.ball_speed()
	sim.step()
	var waited := 0
	while sim.balls[0].state == Sim.BallState.SUNK and waited < 1000:
		sim.step()
		waited += 1


func _test_water_splits_ball_in_two() -> void:
	var sim: Sim = SimScript.new(_stage(_lake_stage()), _no_gravity())
	var start := sim.lives
	_place(sim, Vector2(300, 700), Vector2(0, 1))
	sim.combo = 4
	_run(sim, 0.2)
	_check(sim.ball_state == Sim.BallState.SUNK and sim.falls == 1, "호수에 들어가면 가라앉는다")
	_check(sim.lives == start and sim.combo == 0, "공은 잃지 않지만 콤보는 끊긴다")
	var sunk_at := sim.ball_pos
	var seen := sim.take_events()
	var waited := 0
	while sim.ball_state == Sim.BallState.SUNK and waited < 1000:
		sim.step()
		waited += 1
	seen.append_array(sim.take_events())
	_check(seen.any(func(e: Dictionary) -> bool: return e["type"] == "splash") and seen.any(func(e: Dictionary) -> bool: return e["type"] == "emerge"), "빠질 때와 나올 때 사건이 생긴다")
	_check(sim.balls.size() == 2, "공 하나가 빠지면 둘이 나온다 (실제 %d)" % sim.balls.size())
	_check(not sim.balls[0].temporary and sim.balls[1].temporary, "원래 공은 그대로이고 새로 나온 공이 덤 공이다")
	_check(sim.balls[1].bounces_left == int(sim.cfg["lake_extra_bounces"]), "덤 공은 정해진 횟수만큼 튕길 수 있다")
	_check(sim.ball_pos.distance_to(sunk_at) < 60.0, "빠진 자리에서 나온다")
	var center := Vector2(500, 1000)
	var outward := true
	for b in sim.balls:
		if b.vel.dot(b.pos - center) <= 0.0:
			outward = false
	_check(outward, "두 공 모두 호수 가운데에서 먼 쪽으로 나간다")
	_check(sim.balls[0].vel.angle_to(sim.balls[1].vel) != 0.0, "두 공은 서로 다른 방향으로 간다")
	_run(sim, 0.35)
	_check(sim.falls == 1, "나온 공은 곧바로 다시 빠지지 않는다")


func _test_extra_ball_fades_after_bounces() -> void:
	var cfg := _no_gravity()
	var sim: Sim = SimScript.new(_stage(_lake_stage()), cfg)
	_place(sim, Vector2(500, 400), Vector2(0, 1))
	_sink_and_emerge(sim, Vector2(300, 900))
	var extra: Sim.Ball = sim.balls[1]
	var limit := int(cfg["lake_extra_bounces"])
	# 덤 공을 좌우 벽 사이에서 튕긴다
	extra.pos = Vector2(500, 300)
	extra.vel = Vector2(1, 0.3).normalized() * sim.ball_speed()
	extra.grace = 99.0
	var faded := false
	var most := 0
	for i in 4000:
		sim.balls[0].pos = Vector2(500, 1700)
		sim.balls[0].vel = Vector2.ZERO
		sim.balls[0].state = Sim.BallState.WAITING
		sim.balls[0].wait = 99.0
		extra.pos.y = clampf(extra.pos.y, 100.0, 600.0)
		sim.step()
		most = maxi(most, limit - extra.bounces_left)
		if not sim.balls.has(extra):
			faded = true
			break
	_check(faded and most >= limit - 1, "덤 공은 정해진 횟수만큼 튕기면 사라진다 (튕긴 횟수 %d)" % most)
	_check(sim.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "ball_faded"), "사라질 때 사건이 생긴다")
	_check(sim.balls.size() == 1 and not sim.balls[0].temporary, "원래 공은 남는다")


func _test_extra_ball_splits_too() -> void:
	var sim: Sim = SimScript.new(_stage(_lake_stage()), _no_gravity())
	_place(sim, Vector2(500, 400), Vector2(0, 1))
	_sink_and_emerge(sim, Vector2(300, 900))
	_check(sim.balls.size() == 2, "한 번 빠져 공이 둘이 됐다")
	var extra: Sim.Ball = sim.balls[1]
	sim.balls[0].state = Sim.BallState.WAITING
	sim.balls[0].wait = 99.0
	extra.grace = 0.0
	extra.skipping = false
	extra.pos = Vector2(700, 1000)
	extra.vel = Vector2(0, 1) * sim.ball_speed()
	sim.step()
	var waited := 0
	while extra.state == Sim.BallState.SUNK and waited < 1000:
		sim.step()
		waited += 1
	_check(sim.balls.size() == 3, "덤 공이 빠져도 둘이 되어 나온다 (실제 %d)" % sim.balls.size())
	_check(sim.balls[2].temporary, "거기서 나온 공도 덤 공이다")

	var bridge: Sim = SimScript.new(_stage(_lake_stage()), _no_gravity())
	_place(bridge, Vector2(500, 700), Vector2(0, 1))
	_run(bridge, 0.7)
	_check(bridge.falls == 0 and bridge.ball_pos.y > 1200.0, "호수 위를 지나는 통로로는 건넌다")


func _test_sounds_are_built() -> void:
	var sounds: Dictionary = load("res://src/audio/sfx.gd").build_all()
	var empty := 0
	for name: String in sounds:
		var wav: AudioStreamWAV = sounds[name]
		if wav.data.size() < 400:
			empty += 1
	_check(sounds.size() >= 12 and empty == 0, "효과음을 모두 만든다 (%d개)" % sounds.size())
	for needed: String in ["hit", "pop", "paddle", "splash", "item", "miss", "clear"]:
		_check(sounds.has(needed), "%s 소리가 있다" % needed)


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
	cfg["finale_cells"] = -1  # 마무리 단계의 번개가 끼어들지 않게 한다
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
	var sim: Sim = SimScript.new(_stage(), _no_gravity())
	_place(sim, Vector2(500, 600), Vector2(0, 1))
	sim._apply_item("multi")
	_check(sim.balls.size() == 3, "멀티볼을 받으면 공이 셋이 된다 (실제 %d)" % sim.balls.size())
	var dirs := {}
	for b in sim.balls:
		dirs[snappedf(b.vel.angle(), 0.01)] = true
	_check(dirs.size() == 3, "세 공은 서로 다른 방향으로 간다")
	sim._apply_item("multi")
	_check(sim.balls.size() == 9, "한 번 더 받으면 공마다 다시 갈라진다 (실제 %d)" % sim.balls.size())
	sim._apply_item("multi")
	_check(sim.balls.size() == int(sim.cfg["max_balls"]), "공의 수는 한도를 넘지 않는다 (실제 %d)" % sim.balls.size())


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
	var sim: Sim = SimScript.new(_stage(), _no_gravity())
	_place(sim, Vector2(500, 600), Vector2(0, 1))
	sim._apply_item("multi")
	var start := sim.lives
	sim.set_paddle(150)
	sim.balls[0].pos = Vector2(800, -500)
	sim.balls[0].vel = Vector2(0, -1) * sim.ball_speed()
	_run(sim, 0.3)
	_check(sim.balls.size() == 2 and sim.lives == start, "공이 남아 있으면 하나를 놓쳐도 목숨은 그대로다")


func _test_speed_grows_with_progress() -> void:
	var sim: Sim = SimScript.new(_stage({"cells": [_square(400, 1000, 200, 1), _square(100, 1700, 100, 1)]}), _no_gravity())
	var slow := sim.ball_speed()
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.2)
	_check(sim.destroyed == 1 and sim.ball_speed() > slow, "셀을 부술수록 공이 빨라진다")
	_check(is_equal_approx(sim.ball_vel.length(), sim.ball_speed()), "공은 그 속도로 난다")


func _test_idle_ball_is_pulled_to_a_cell() -> void:
	var cfg := _no_gravity()
	cfg["finale_cells"] = 0
	var sim: Sim = SimScript.new(_stage({"cells": [_square(100, 1500, 100, 1)]}), cfg)
	_place(sim, Vector2(800, 300), Vector2(0, 1))
	_run(sim, 0.5)
	_check(absf(sim.ball_vel.x) < 1.0, "방금 발사된 공은 곧게 간다")
	sim.balls[0].idle = float(cfg["homing_after"]) + 0.1
	_run(sim, 0.5)
	_check(sim.ball_vel.x < -50.0, "오래 아무것도 못 맞힌 공은 남은 셀 쪽으로 꺾인다")
	var down: Sim = SimScript.new(_stage({"cells": [_square(100, 1500, 100, 1)]}), cfg)
	_place(down, Vector2(800, 1900), Vector2(0, -1))
	down.balls[0].idle = 99.0
	_run(down, 0.5)
	_check(absf(down.ball_vel.x) < 1.0, "내려오는 공은 건드리지 않는다")


func _test_fever_chains_to_neighbors() -> void:
	var cells := [_square(400, 1000, 200, 1), _square(610, 1000, 200, 2), _square(820, 1000, 100, 1), _square(100, 1700, 100, 1)]
	var cool: Sim = SimScript.new(_stage({"cells": cells}), _no_gravity())
	_place(cool, Vector2(500, 900), Vector2(0, 1))
	_run(cool, 0.2)
	_check(cool.destroyed == 1 and cool.cell_hp[1] == 2, "보통 때는 맞은 셀만 깎인다")
	var hot: Sim = SimScript.new(_stage({"cells": cells}), _no_gravity())
	_place(hot, Vector2(500, 900), Vector2(0, 1))
	hot.combo = int(hot.cfg["fever_combo"])
	_run(hot, 0.2)
	_check(hot.cell_hp[0] == 0 and hot.cell_hp[1] == 1, "달아오른 공이 부순 셀은 맞닿은 셀을 한 번 깎는다 (이웃 HP %d)" % hot.cell_hp[1])
	_check(hot.cell_hp[3] == 1, "떨어져 있는 셀은 그대로다")
	_check(hot.take_events().any(func(e: Dictionary) -> bool: return e["type"] == "destroyed" and e["points"] > 0), "부서진 사건에 얻은 점수가 실린다")


func _test_wall_blocks_but_gap_lets_through() -> void:
	var design := {"walls": [{"around": [500, 1100], "gap_toward": [0, -1], "gap_width": 120, "offset": 20, "thickness": 12}]}
	var sim: Sim = SimScript.new(_stage({"cells": [_square(300, 1000, 400, 3)]}), _no_gravity(), design)
	_check(sim.walls.size() >= 4 and sim.gates.size() == 1, "셀이 선 구획을 벽이 두르고 구멍이 하나 난다 (벽 조각 %d)" % sim.walls.size())
	_place(sim, Vector2(350, 800), Vector2(0, 1))
	_run(sim, 0.4)
	_check(sim.cell_hp[0] == 3 and sim.ball_vel.y < 0.0, "벽에 맞은 공은 튕겨 나오고 안쪽 셀은 멀쩡하다")
	var through: Sim = SimScript.new(_stage({"cells": [_square(300, 1000, 400, 3)]}), _no_gravity(), design)
	_place(through, Vector2(500, 800), Vector2(0, 1))
	_run(through, 0.4)
	_check(through.cell_hp[0] == 2, "구멍으로 들어간 공은 안쪽 셀을 맞힌다")


func _test_bolt_finishes_the_last_cells() -> void:
	var cfg := _no_gravity()
	cfg["finale_cells"] = 3
	cfg["homing_after"] = 999.0
	cfg["finale_turn_deg"] = 0.0
	var cells := [_square(400, 1000, 200, 1), _square(100, 1700, 100, 3), _square(800, 1700, 100, 2), _square(450, 1500, 100, 4, 1)]
	var sim: Sim = SimScript.new(_stage({"cells": cells}), cfg)
	_check(not sim.finale and sim.items.is_empty(), "처음에는 번개가 없다")
	_place(sim, Vector2(500, 900), Vector2(0, 1))
	_run(sim, 0.2)
	_check(sim.finale and sim.items.size() == 1 and sim.items[0]["type"] == "bolt", "셀이 몇 개 안 남으면 번개가 내려온다")
	for i in 3000:
		if sim.items.is_empty():
			break
		sim.set_paddle(900)
		sim.step()
	_check(sim.items.is_empty() and sim.destroyed == 1, "놓친 번개는 아무 일도 일으키지 않는다")
	_run(sim, float(cfg["bolt_retry"]) + 0.1)
	_check(sim.items.size() == 1, "놓친 번개는 잠시 뒤 다시 내려온다")
	for i in 3000:
		if sim.items.is_empty():
			break
		sim.set_paddle(sim.items[0]["pos"].x)
		sim.step()
	var seen := sim.take_events()
	_check(seen.any(func(e: Dictionary) -> bool: return e["type"] == "item_caught"), "번개를 받는다")
	_run(sim, 1.0)
	seen.append_array(sim.take_events())
	_check(sim.destroyed == 4, "받으면 남은 셀을 모두 내리친다 (부순 수 %d)" % sim.destroyed)
	_check(sim.cleared, "랜드마크까지 내리쳐 판이 끝난다")
	_check(seen.filter(func(e: Dictionary) -> bool: return e["type"] == "bolt").size() == 3, "내리칠 때마다 번개 사건이 생긴다")


func _test_models_load() -> void:
	var Lib = load("res://src/render/model_library.gd")
	var loaded := 0
	var total := 0
	for group: Array in [Lib.ROUND_TREES, Lib.POINTED_TREES, Lib.BUSHES, Lib.FLOWERS, Lib.ROCKS, Lib.PARASOLS]:
		for name: String in group:
			total += 1
			var m: Dictionary = Lib.get_model(name)
			if m.is_empty():
				printerr("  읽지 못한 모델: " + name)
				continue
			loaded += 1
			var pts: PackedVector3Array = m["points"]
			var top := 0.0
			for p in pts:
				top = maxf(top, p.y)
			if pts.size() % 3 != 0 or pts.size() != m["colors"].size() or not is_equal_approx(top, 1.0):
				printerr("  모양이 이상한 모델: " + name)
				loaded -= 1
	_check(loaded == total, "가져온 모델을 모두 읽는다 (%d/%d)" % [loaded, total])


func _test_save_data_ranks_scores() -> void:
	var list: Array = []
	var Save = load("res://src/meta/save_data.gd")
	_check(Save.insert(list, {"score": 500}, 3) == 1, "첫 기록은 1위다")
	_check(Save.insert(list, {"score": 900}, 3) == 1, "더 높은 점수는 위로 간다")
	_check(Save.insert(list, {"score": 700}, 3) == 2, "가운데 점수는 가운데로 들어간다")
	_check(Save.insert(list, {"score": 700}, 3) == 3, "같은 점수면 먼저 낸 기록이 위다")
	_check(list.size() == 3 and int(list[2]["score"]) == 700, "정해진 수만큼만 남긴다")
	_check(Save.insert(list, {"score": 100}, 3) == 0, "밀려난 기록은 순위가 없다")

	var path := "user://test_save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var save: SaveData = Save.new(path)
	_check(save.best("seoul/jamsil") == 0 and save.cleared.is_empty(), "처음에는 기록이 없다")
	_check(save.add_result("seoul/jamsil", 1200, false, 80, "11.24 10:00") == 1, "기록을 남기면 순위를 돌려준다")
	_check(save.add_result("seoul/jamsil", 3400, true, 150, "11.24 10:05") == 1, "더 높은 기록이 1위가 된다")
	var again: SaveData = Save.new(path)
	_check(again.best("seoul/jamsil") == 3400 and again.top("seoul/jamsil", 5).size() == 2, "기록은 파일에 남아 다시 읽힌다")
	_check(again.cleared.has("seoul/jamsil"), "클리어한 스테이지가 남는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_stage_list_is_valid() -> void:
	var data: Dictionary = BalanceScript.load_file("res://assets/stages/stages.json")
	_check(not data.is_empty() and data["cities"].size() >= 1, "스테이지 차례 파일을 읽는다")
	var ready := 0
	for city: Dictionary in data["cities"]:
		for s: Dictionary in city["stages"]:
			if not bool(s["ready"]):
				continue
			ready += 1
			var dir := "res://assets/stages/%s/" % s["id"]
			_check(FileAccess.file_exists(dir + "map.json") and FileAccess.file_exists(dir + "design.json"), "만들어졌다고 한 스테이지는 파일이 있다 (%s)" % s["id"])
			var stage: StageData = StageDataScript.load_file(dir + "map.json")
			if stage == null:
				continue
			var goals := 0
			for c in stage.cells:
				if c["landmark"]:
					goals += 1
					_check(not c["solid"], "목표 건물은 부술 수 있다 (%s)" % s["id"])
			_check(goals == 1 and stage.cells.size() >= 40, "스테이지에 목표 건물이 하나 있고 셀이 넉넉하다 (%s)" % s["id"])
	_check(ready >= 1, "플레이할 수 있는 스테이지가 하나 이상 있다")


func _test_pressure_builds_over_time() -> void:
	var cfg := _no_gravity()
	cfg["time_speed_every"] = 10.0
	cfg["time_speed_max_tiers"] = 2
	cfg["drop_interval_start"] = 4.0
	cfg["drop_interval_end"] = 1.0
	cfg["drop_ramp_seconds"] = 20.0
	cfg["rush_after"] = 30.0
	cfg["rush_drop_interval"] = 0.5
	var sim: Sim = SimScript.new(_stage({"cells": [_square(100, 1800, 100, 4)]}), cfg)
	var slow := sim.ball_speed()
	var kinds := {}
	var drops_early := 0
	var drops_late := 0
	for i in int(45.0 / Sim.STEP):
		sim.set_paddle(sim.ball_pos.x)
		sim.step()
		for e in sim.take_events():
			kinds[e["type"]] = true
			if e["type"] == "item_spawn":
				if sim.elapsed < 10.0:
					drops_early += 1
				elif sim.elapsed >= 35.0:
					drops_late += 1
	_check(sim.speed_tier == 2 and sim.ball_speed() > slow, "시간이 흐르면 공이 빨라지고, 정해진 단계에서 멈춘다 (단계 %d)" % sim.speed_tier)
	_check(kinds.has("speed_up"), "빨라질 때 사건이 생긴다")
	_check(drops_early >= 1, "처음에도 하늘에서 아이템이 떨어진다 (처음 10초에 %d개)" % drops_early)
	_check(sim.rush and kinds.has("rush"), "한참 지나면 몰아치는 단계에 들어간다")
	_check(drops_late > drops_early * 3, "몰아치는 단계에서는 아이템이 훨씬 자주 떨어진다 (처음 10초 %d개, 끝 10초 %d개)" % [drops_early, drops_late])


func _test_narrow_item_hurts() -> void:
	var sim: Sim = SimScript.new(_stage(), _no_gravity())
	var normal := sim.paddle_width()
	var before := sim.score
	sim._apply_item("narrow")
	_check(sim.paddle_width() < normal, "좁은 패들을 받으면 패들이 좁아진다")
	sim._apply_item("wide")
	_check(sim.paddle_width() > normal, "넓은 패들을 받으면 좁아진 것이 풀리고 넓어진다")
	sim._apply_item("narrow")
	_run(sim, float(sim.cfg["narrow_seconds"]) + 0.1)
	_check(is_equal_approx(sim.paddle_width(), normal), "시간이 지나면 원래대로 돌아온다")
	_check(sim.score == before, "나쁜 아이템은 점수를 주지 않는다")


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
			if lowest > 400.0 and it["type"] != "narrow":
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
	print("  잠실 자동 플레이 %d초: 부순 벽돌 %d/%d, 호수에 빠짐 %d회, 남은 목숨 %d, %d점%s%s" % [int(sim.elapsed), sim.destroyed, sim.breakable_count(), sim.falls, sim.lives, sim.score, ", 클리어" if sim.cleared else "", ", 게임 오버" if sim.over else ""])
