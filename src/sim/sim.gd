class_name Sim
extends RefCounted
## 한 판의 판정. 공, 패들, 셀의 상태를 고정 간격으로 진행시킨다.
##
## 장면에 의존하지 않는다. 같은 스테이지와 밸런스 값에 같은 패들 입력을 주면 늘 같은 결과가 나온다.
## 좌표는 지도 좌표다. x는 0에서 판 가로까지, y는 기준선 쪽이 0이고 화면 위쪽으로 커진다.
## 패들은 y가 음수인 강 쪽에 있다.
##
## 쓰는 법: step()을 STEP 초마다 한 번 부르고, 그 전에 set_paddle()로 패들 위치를 준다.
## 일어난 일은 take_events()로 가져간다.

const STEP := 1.0 / 120.0
const GRID := 160.0

enum BallState { WAITING, FLYING, SUNK }

var stage: StageData
var cfg: Dictionary

var cell_hp := PackedInt32Array()
var cell_max_hp := PackedInt32Array()
var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_state: int = BallState.WAITING
var ball_radius := 0.0
var paddle_x := 0.0
var score := 0
## 패들에 닿지 않고 연속으로 부순 셀의 수
var combo := 0
## 호수에 빠진 횟수
var falls := 0
var lives := 0
## 공을 다 잃어 판이 끝났는지
var over := false
var destroyed := 0
var elapsed := 0.0
var cleared := false

var _wait_left := 0.0
## 물에서 막 튀어 오른 공인지. 그 물을 벗어날 때까지는 다시 빠지지 않는다.
var _skipping := false
var _rng := RandomNumberGenerator.new()
var _landmarks_left := 0
var _events: Array[Dictionary] = []
var _grid := {}
var _cols := 1
var _lake_boxes: Array[Rect2] = []


func _init(p_stage: StageData, p_cfg: Dictionary) -> void:
	stage = p_stage
	cfg = p_cfg
	ball_radius = stage.ball_diameter / 2.0
	cell_hp.resize(stage.cells.size())
	cell_max_hp.resize(stage.cells.size())
	for i in stage.cells.size():
		var c := stage.cells[i]
		var hp: int = int(cfg["landmark_hp"]) if c["landmark"] else c["hp"]
		cell_hp[i] = hp
		cell_max_hp[i] = hp
		if c["landmark"]:
			_landmarks_left += 1
	_build_grid()
	for lake in stage.lakes:
		var box := _bounds(lake["points"])
		_lake_boxes.append(box)
	lives = int(cfg["lives"])
	_rng.seed = int(cfg["seed"])
	paddle_x = stage.width / 2.0
	_hold(float(cfg["launch_delay"]))


## 패들의 가운데 x를 정한다. 판 밖으로 나가지 않게 잘린다.
func set_paddle(x: float) -> void:
	var half := float(cfg["paddle_width"]) / 2.0
	paddle_x = clampf(x, half, stage.width - half)


## 지난 take_events() 뒤에 일어난 일을 돌려주고 비운다.
## 종류: hit{cell,hp,max_hp}, destroyed{cell,landmark}, paddle, launch, splash{pos}, emerge{pos}, lost, over, cleared
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func combo_multiplier() -> float:
	return minf(1.0 + combo * float(cfg["combo_step"]), float(cfg["combo_max"]))


func breakable_count() -> int:
	return cell_hp.size()


func step() -> void:
	if cleared or over:
		return
	elapsed += STEP
	var paddle_y := float(cfg["paddle_y"])
	if ball_state == BallState.SUNK:
		_wait_left -= STEP
		if _wait_left <= 0.0:
			_emerge()
		return
	if ball_state == BallState.WAITING:
		ball_pos = Vector2(paddle_x, paddle_y + float(cfg["paddle_thickness"]) / 2.0 + ball_radius + 2.0)
		_wait_left -= STEP
		if _wait_left <= 0.0:
			_launch()
		return

	var speed := float(cfg["ball_speed"])
	ball_vel.y -= float(cfg["gravity"]) * STEP
	ball_vel = ball_vel.normalized() * speed
	var subs := maxi(1, ceili(speed * STEP / (ball_radius * 0.5)))
	var dt := STEP / subs
	for i in subs:
		ball_pos += ball_vel * dt
		_collide_walls()
		_collide_paddle()
		_collide_cells()
		if cleared:
			return
	if ball_pos.y < paddle_y - float(cfg["fall_margin"]):
		_lose()
		return
	if _lake_at(ball_pos) < 0:
		_skipping = false
	elif not _skipping:
		_sink()


func _hold(seconds: float) -> void:
	ball_state = BallState.WAITING
	ball_vel = Vector2.ZERO
	_wait_left = seconds
	ball_pos = Vector2(paddle_x, float(cfg["paddle_y"]) + float(cfg["paddle_thickness"]) / 2.0 + ball_radius + 2.0)


func _launch() -> void:
	var a := deg_to_rad(float(cfg["launch_angle_deg"])) * (1.0 if falls % 2 == 0 else -1.0)
	ball_vel = Vector2(sin(a), cos(a)) * float(cfg["ball_speed"])
	ball_state = BallState.FLYING
	_events.append({"type": "launch"})


## 패들을 지나쳐 뒤로 넘어갔다. 공 하나를 잃는다.
func _lose() -> void:
	lives -= 1
	combo = 0
	_events.append({"type": "lost"})
	if lives <= 0:
		over = true
		ball_state = BallState.WAITING
		ball_vel = Vector2.ZERO
		_events.append({"type": "over"})
		return
	_hold(float(cfg["respawn_delay"]))


## 물에 빠졌다. 공은 잠깐 가라앉는다.
func _sink() -> void:
	falls += 1
	combo = 0
	ball_state = BallState.SUNK
	ball_vel = Vector2.ZERO
	_wait_left = float(cfg["splash_delay"])
	_events.append({"type": "splash", "pos": ball_pos})


## 가라앉았던 자리에서 아무 방향으로나 튀어 오른다. 방향은 판마다 정해진 난수열을 따른다.
func _emerge() -> void:
	ball_vel = Vector2.from_angle(_rng.randf() * TAU) * float(cfg["ball_speed"])
	_keep_min_angle()
	ball_state = BallState.FLYING
	_skipping = true
	_events.append({"type": "emerge", "pos": ball_pos})


func _collide_walls() -> void:
	var hit := false
	if ball_pos.x < ball_radius:
		ball_pos.x = ball_radius
		ball_vel.x = absf(ball_vel.x)
		hit = true
	elif ball_pos.x > stage.width - ball_radius:
		ball_pos.x = stage.width - ball_radius
		ball_vel.x = -absf(ball_vel.x)
		hit = true
	if ball_pos.y > stage.height - ball_radius:
		ball_pos.y = stage.height - ball_radius
		ball_vel.y = -absf(ball_vel.y)
		hit = true
	if hit:
		_keep_min_angle()


func _collide_paddle() -> void:
	if ball_vel.y >= 0.0:
		return
	var half := float(cfg["paddle_width"]) / 2.0
	var thick := float(cfg["paddle_thickness"])
	var top := float(cfg["paddle_y"]) + thick / 2.0
	if ball_pos.y - ball_radius > top or ball_pos.y < top - thick:
		return
	var off := ball_pos.x - paddle_x
	if absf(off) > half + ball_radius * 0.6:
		return
	# 맞은 자리가 가운데에서 멀수록 옆으로 눕는다
	var a := clampf(off / half, -1.0, 1.0) * deg_to_rad(float(cfg["paddle_max_angle_deg"]))
	ball_vel = Vector2(sin(a), cos(a)) * float(cfg["ball_speed"])
	ball_pos.y = top + ball_radius
	combo = 0
	_events.append({"type": "paddle"})


func _collide_cells() -> void:
	if ball_pos.y < -ball_radius or ball_pos.y > stage.height + ball_radius:
		return
	var bucket: PackedInt32Array = _grid.get(_key(ball_pos), PackedInt32Array())
	var best := -1
	var best_depth := 0.0
	var best_n := Vector2.ZERO
	for idx in bucket:
		if cell_hp[idx] <= 0:
			continue
		var pts: PackedVector2Array = stage.cells[idx]["points"]
		var q := _closest_on_outline(pts, ball_pos)
		var d := q.distance_to(ball_pos)
		if d < 0.0001:
			continue
		var depth := 0.0
		var n := Vector2.ZERO
		if Geometry2D.is_point_in_polygon(ball_pos, pts):
			depth = ball_radius + d
			n = (q - ball_pos) / d
		elif d < ball_radius:
			depth = ball_radius - d
			n = (ball_pos - q) / d
		if depth > best_depth:
			best_depth = depth
			best_n = n
			best = idx
	if best < 0:
		return
	ball_pos += best_n * best_depth
	if ball_vel.dot(best_n) < 0.0:
		ball_vel = ball_vel.bounce(best_n)
		_keep_min_angle()
	_damage(best)


func _damage(idx: int) -> void:
	cell_hp[idx] -= 1
	score += int(cfg["score_hit"])
	_events.append({"type": "hit", "cell": idx, "hp": cell_hp[idx], "max_hp": cell_max_hp[idx]})
	if cell_hp[idx] > 0:
		return
	destroyed += 1
	score += int(round(float(cfg["score_destroy_per_hp"]) * cell_max_hp[idx] * combo_multiplier()))
	combo += 1
	var landmark: bool = stage.cells[idx]["landmark"]
	_events.append({"type": "destroyed", "cell": idx, "landmark": landmark})
	if landmark:
		_landmarks_left -= 1
		if _landmarks_left <= 0:
			cleared = true
			_events.append({"type": "cleared"})


## 공이 거의 옆으로만 가는 상태를 막는다.
func _keep_min_angle() -> void:
	var speed := ball_vel.length()
	if speed <= 0.0:
		return
	var min_vy := speed * sin(deg_to_rad(float(cfg["min_angle_deg"])))
	if absf(ball_vel.y) >= min_vy:
		return
	var sy := -1.0 if ball_vel.y < 0.0 else 1.0
	var sx := -1.0 if ball_vel.x < 0.0 else 1.0
	ball_vel = Vector2(sx * sqrt(speed * speed - min_vy * min_vy), sy * min_vy)


## 그 자리가 몇 번째 호수의 물 위인지. 물이 아니면 -1. 물 위를 지나는 통로(다리)는 물이 아니다.
func _lake_at(p: Vector2) -> int:
	for i in stage.lakes.size():
		if not _lake_boxes[i].has_point(p):
			continue
		if not Geometry2D.is_point_in_polygon(p, stage.lakes[i]["points"]):
			continue
		for c in stage.corridors:
			if Geometry2D.is_point_in_polygon(p, c):
				return -1
		return i
	return -1


func _build_grid() -> void:
	_cols = maxi(1, ceili(stage.width / GRID))
	var pad := ball_radius + 8.0
	for i in stage.cells.size():
		var box := _bounds(stage.cells[i]["points"]).grow(pad)
		var x0 := maxi(0, floori(box.position.x / GRID))
		var x1 := floori(box.end.x / GRID)
		var y0 := maxi(0, floori(box.position.y / GRID))
		var y1 := floori(box.end.y / GRID)
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var k := gx + gy * 4096
				var list: PackedInt32Array = _grid.get(k, PackedInt32Array())
				list.append(i)
				_grid[k] = list


func _key(p: Vector2) -> int:
	return maxi(0, floori(p.x / GRID)) + maxi(0, floori(p.y / GRID)) * 4096


static func _closest_on_outline(pts: PackedVector2Array, p: Vector2) -> Vector2:
	var best := pts[0]
	var best_d := INF
	for i in pts.size():
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
