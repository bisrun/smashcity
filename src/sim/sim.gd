class_name Sim
extends RefCounted
## 한 판의 판정. 공, 패들, 셀, 아이템의 상태를 고정 간격으로 진행시킨다.
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

## 아이템의 종류. design.json 의 type 값이다.
const ITEM_MULTI := "multi"
const ITEM_WIDE := "wide"
const ITEM_FIRE := "fire"
const ITEM_LIFE := "life"
## 마무리 단계에 하늘에서 내려오는 번개. 받으면 남은 셀을 차례로 내리친다.
const ITEM_BOLT := "bolt"
## 받으면 손해인 아이템. 패들이 잠깐 좁아진다. 피해야 한다.
const ITEM_NARROW := "narrow"
## 하늘에서 떨어지는 아이템의 종류와 나올 비중
const SKY_ITEMS := {"multi": 3.0, "wide": 2.0, "fire": 2.0, "narrow": 3.0, "life": 0.5}


class Ball:
	extends RefCounted
	var id := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var state: int = BallState.WAITING
	var wait := 0.0
	## 물에서 막 튀어 오른 공인지. 그 물을 벗어날 때까지는 다시 빠지지 않는다.
	var skipping := false
	## 패들에 닿지 않고 연속으로 부순 셀의 수
	var combo := 0
	## 마지막으로 셀을 맞힌 뒤 지난 시간 (초)
	var idle := 0.0
	## 끌려가고 있는 셀. 없으면 -1
	var target := -1
	var retarget_in := 0.0
	## 호수에서 갈라져 나온 덤 공인지. 덤 공은 정해진 횟수만큼 튕기면 사라진다.
	var temporary := false
	var bounces_left := 0
	## 사라질 차례가 된 공
	var gone := false
	## 빠져 있는 호수의 번호와, 물에서 나온 뒤 다시 빠지지 않는 남은 시간
	var lake := -1
	var grace := 0.0


var stage: StageData
var cfg: Dictionary

var cell_hp := PackedInt32Array()
var cell_max_hp := PackedInt32Array()
## 부서지지 않는 셀인지. 지금은 그런 셀이 없다. 숲은 여러 번 맞아야 부서지는 보통 셀이다.
var cell_solid := PackedByteArray()
var balls: Array[Ball] = []
## 떨어지고 있는 아이템. 각 원소: {id: int, type: String, pos: Vector2}
var items: Array[Dictionary] = []
var ball_radius := 0.0
var paddle_x := 0.0
var score := 0
## 호수에 빠진 횟수
var falls := 0
var lives := 0
## 공을 다 잃어 판이 끝났는지
var over := false
var destroyed := 0
var elapsed := 0.0
var cleared := false
## 넓은 패들, 불공, 좁은 패들의 남은 시간 (초)
var wide_left := 0.0
var fire_left := 0.0
var narrow_left := 0.0
## 시간이 흘러 빨라진 단계. 0부터.
var speed_tier := 0
## 판이 길어져 몰아치는 단계에 들어갔는지. 아이템이 쏟아진다.
var rush := false
## 남은 셀이 얼마 없어 마무리 단계에 들어갔는지
var finale := false

## 첫 번째 공을 가리키는 지름길. 공이 하나뿐인 상황과 테스트에서 쓴다.
var ball_pos: Vector2:
	get:
		return balls[0].pos if not balls.is_empty() else Vector2.ZERO
	set(v):
		if not balls.is_empty():
			balls[0].pos = v
var ball_vel: Vector2:
	get:
		return balls[0].vel if not balls.is_empty() else Vector2.ZERO
	set(v):
		if not balls.is_empty():
			balls[0].vel = v
var ball_state: int:
	get:
		return balls[0].state if not balls.is_empty() else BallState.WAITING
var combo: int:
	get:
		return balls[0].combo if not balls.is_empty() else 0
	set(v):
		if not balls.is_empty():
			balls[0].combo = v

var _landmarks_left := 0
var _events: Array[Dictionary] = []
var _grid := {}
var _lake_boxes: Array[Rect2] = []
var _lake_centers := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _next_id := 1
## 셀 번호 → 그 셀에 든 아이템의 종류
var _item_in_cell := {}
## 번개가 내리칠 셀의 차례와 다음 번개까지 남은 시간
var _strikes: Array[int] = []
var _strike_wait := 0.0
## 놓친 번개가 다시 내려오기까지 남은 시간. 0 이하면 기다리는 번개가 없다.
var _bolt_retry := 0.0
var _sky := Ball.new()
## 다음 아이템이 하늘에서 떨어지기까지 남은 시간
var _drop_in := 0.0
## 깨지지 않는 벽의 조각들. 공은 튕기기만 한다. 각 원소는 얇은 사각형이다.
var walls: Array[PackedVector2Array] = []
## 벽에 난 구멍의 양 끝. 각 원소: [Vector2, Vector2]
var gates: Array[Array] = []
var _wall_grid := {}
## 셀 번호 → 맞닿은 셀들. 연쇄에 쓴다.
var _neighbors: Array[PackedInt32Array] = []
var _centers := PackedVector2Array()


## design 은 스테이지의 수작업 기획(design.json)이다. 없으면 아이템 없이 돈다.
func _init(p_stage: StageData, p_cfg: Dictionary, design: Dictionary = {}) -> void:
	stage = p_stage
	cfg = p_cfg
	ball_radius = stage.ball_diameter / 2.0
	cell_hp.resize(stage.cells.size())
	cell_max_hp.resize(stage.cells.size())
	cell_solid.resize(stage.cells.size())
	for i in stage.cells.size():
		var c := stage.cells[i]
		cell_solid[i] = 0
		var hp: int = int(cfg["landmark_hp"]) if c["landmark"] else c["hp"]
		if is_park(c):
			hp = int(cfg["forest_hp"])  # 숲은 오래 버틴다
		cell_hp[i] = hp
		cell_max_hp[i] = hp
		if c["landmark"]:
			_landmarks_left += 1
	_build_grid()
	_build_neighbors()
	for lake in stage.lakes:
		_lake_boxes.append(_bounds(lake["points"]))
		_lake_centers.append(_center(lake["points"]))
	for it: Dictionary in design.get("items", []):
		var cell := cell_at(Vector2(float(it["at"][0]), float(it["at"][1])))
		if cell >= 0 and not stage.cells[cell]["landmark"]:
			_item_in_cell[cell] = String(it["type"])
	for w: Dictionary in design.get("walls", []):
		_build_wall(w)
	lives = int(cfg["lives"])
	_rng.seed = int(cfg["seed"])
	paddle_x = stage.width / 2.0
	_drop_in = float(cfg["drop_interval_start"])
	_add_waiting_ball(float(cfg["launch_delay"]))


## 패들의 가운데 x를 정한다. 판 밖으로 나가지 않게 잘린다.
func set_paddle(x: float) -> void:
	var half := paddle_width() / 2.0
	paddle_x = clampf(x, half, stage.width - half)


## 지금의 패들 폭. 넓은 패들 아이템이 켜져 있으면 넓다.
func paddle_width() -> float:
	var factor := 1.0
	if wide_left > 0.0:
		factor = float(cfg["wide_factor"])
	elif narrow_left > 0.0:
		factor = float(cfg["narrow_factor"])
	return float(cfg["paddle_width"]) * factor


## 지난 take_events() 뒤에 일어난 일을 돌려주고 비운다.
## 종류: hit{cell,hp,max_hp}, destroyed{cell,landmark}, paddle, launch, splash{pos}, emerge{pos},
##       ball_lost{ball}, lost, over, cleared, item_spawn{id,type_of,pos}, item_caught{id,type_of}, item_gone{id},
##       fever, finale, wall{pos}, bolt{cell,pos}, speed_up{tier}, rush, ball_split{ball,pos}, ball_faded{ball,pos},
##       thud{cell,pos}
## destroyed 에는 points(얻은 점수)와 chained(연쇄로 부서졌는지)가 함께 온다.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


## 화면에 보여 줄 콤보 배율. 공이 여럿이면 가장 높은 것.
func combo_multiplier() -> float:
	var best := 0
	for b in balls:
		best = maxi(best, b.combo)
	return _multiplier(best)


## 부술 수 있는 셀의 수. 숲과 공원은 세지 않는다.
func breakable_count() -> int:
	var n := 0
	for i in cell_solid.size():
		if cell_solid[i] == 0:
			n += 1
	return n


## 숲이나 공원인 셀인지. 실제로 건물이 없던 낮은 구획이 그렇다. 화면도 같은 기준으로 그린다.
## 숲은 여러 번 맞아야 부서진다.
static func is_park(cell: Dictionary) -> bool:
	return bool(cell.get("empty", false)) and int(cell.get("hp", 1)) <= 1 and not bool(cell.get("landmark", false))


## 지금의 공 속도. 셀을 부술수록, 그리고 시간이 흐를수록 빨라진다.
func ball_speed() -> float:
	var progress := float(destroyed) / maxf(1.0, float(breakable_count()))
	return float(cfg["ball_speed"]) * (1.0 + float(cfg["speed_gain"]) * progress) * (1.0 + float(cfg["time_speed_gain"]) * speed_tier)


## 그 공이 달아올랐는지. 달아오른 공이 부순 셀은 맞닿은 셀까지 깎는다.
func is_fever(b: Ball) -> bool:
	return b.combo >= int(cfg["fever_combo"])


## 판 위에 달아오른 공이 하나라도 있는지.
func any_fever() -> bool:
	for b in balls:
		if is_fever(b):
			return true
	return false


## 셀에 든 아이템의 종류. 없으면 빈 문자열.
func item_in_cell(cell: int) -> String:
	return _item_in_cell.get(cell, "")


## 그 자리의 셀 번호. 어느 셀 안도 아니면 가장 가까운 셀.
func cell_at(p: Vector2) -> int:
	var nearest := -1
	var nearest_d := INF
	for i in stage.cells.size():
		var pts: PackedVector2Array = stage.cells[i]["points"]
		if Geometry2D.is_point_in_polygon(p, pts):
			return i
		var d := _closest_on_outline(pts, p).distance_squared_to(p)
		if d < nearest_d:
			nearest_d = d
			nearest = i
	return nearest


func step() -> void:
	if cleared or over:
		return
	elapsed += STEP
	wide_left = maxf(0.0, wide_left - STEP)
	fire_left = maxf(0.0, fire_left - STEP)
	narrow_left = maxf(0.0, narrow_left - STEP)
	_step_pressure()
	for b: Ball in balls.duplicate():
		_step_ball(b)
		if cleared:
			return
	_step_items()
	if cleared:
		return
	if _bolt_retry > 0.0:
		_bolt_retry -= STEP
		if _bolt_retry <= 0.0:
			_drop_bolt()
	if not _strikes.is_empty():
		_strike_wait -= STEP
		while _strike_wait <= 0.0 and not _strikes.is_empty() and not cleared:
			var cell: int = _strikes.pop_front()
			if cell_hp[cell] > 0:
				_events.append({"type": "bolt", "cell": cell, "pos": _centers[cell]})
				_strike(_sky, cell, cell_hp[cell], true)
				_strike_wait += float(cfg["bolt_interval"])
		if cleared:
			return
	if balls.is_empty():
		_lose_life()


## 판이 길어질수록 조여 온다. 일정 시간마다 공이 빨라지고, 하늘에서 아이템이 점점 자주 떨어진다.
## 한참 지나면 몰아치는 단계에 들어가 아이템이 쏟아진다.
func _step_pressure() -> void:
	var tier := mini(int(elapsed / float(cfg["time_speed_every"])), int(cfg["time_speed_max_tiers"]))
	if tier > speed_tier:
		speed_tier = tier
		_events.append({"type": "speed_up", "tier": tier})
	if not rush and elapsed >= float(cfg["rush_after"]):
		rush = true
		_drop_in = minf(_drop_in, 0.5)
		_events.append({"type": "rush"})
	_drop_in -= STEP
	if _drop_in <= 0.0:
		_drop_in = float(cfg["rush_drop_interval"]) if rush else lerpf(float(cfg["drop_interval_start"]), float(cfg["drop_interval_end"]),
			clampf(elapsed / float(cfg["drop_ramp_seconds"]), 0.0, 1.0))
		var total := 0.0
		for w: float in SKY_ITEMS.values():
			total += w
		var roll := _rng.randf() * total
		var type := ITEM_MULTI
		for k: String in SKY_ITEMS:
			roll -= float(SKY_ITEMS[k])
			if roll <= 0.0:
				type = k
				break
		var margin := 90.0
		var item := {"id": _next_id, "type": type, "pos": Vector2(margin + _rng.randf() * (stage.width - margin * 2.0), float(cfg["drop_height"]))}
		_next_id += 1
		items.append(item)
		_events.append({"type": "item_spawn", "id": item["id"], "type_of": type, "pos": item["pos"]})


func _step_ball(b: Ball) -> void:
	var paddle_y := float(cfg["paddle_y"])
	if b.state == BallState.WAITING:
		b.pos = _hold_position()
		b.wait -= STEP
		if b.wait <= 0.0:
			var a := deg_to_rad(float(cfg["launch_angle_deg"])) * (1.0 if lives % 2 == 1 else -1.0)
			b.vel = Vector2(sin(a), cos(a)) * ball_speed()
			b.state = BallState.FLYING
			_events.append({"type": "launch"})
		return
	if b.state == BallState.SUNK:
		b.wait -= STEP
		if b.wait <= 0.0:
			_emerge(b)
		return

	var speed := ball_speed()
	b.idle += STEP
	b.vel.y -= float(cfg["gravity"]) * STEP
	_steer(b)
	b.vel = b.vel.normalized() * speed
	var subs := maxi(1, ceili(speed * STEP / (ball_radius * 0.5)))
	var dt := STEP / subs
	for i in subs:
		b.pos += b.vel * dt
		_collide_walls(b)
		_collide_paddle(b)
		_collide_barriers(b)
		_collide_cells(b)
		if cleared:
			return
	if b.gone:
		# 덤 공이 정해진 횟수만큼 튕겼다
		balls.erase(b)
		_events.append({"type": "ball_faded", "ball": b.id, "pos": b.pos})
		return
	if b.pos.y < paddle_y - float(cfg["fall_margin"]):
		# 패들을 지나쳐 뒤로 넘어갔다
		balls.erase(b)
		_events.append({"type": "ball_lost", "ball": b.id})
		return
	var lake := _lake_at(b.pos)
	if lake < 0:
		b.skipping = false
		b.grace = maxf(0.0, b.grace - STEP)
	elif not b.skipping and b.grace <= 0.0:
		b.lake = lake
		falls += 1
		b.combo = 0
		b.state = BallState.SUNK
		b.vel = Vector2.ZERO
		b.wait = float(cfg["splash_delay"])
		_events.append({"type": "splash", "pos": b.pos})


## 오래 아무것도 못 맞힌 공, 또는 마무리 단계의 공을 가장 가까운 셀 쪽으로 조금씩 꺾는다.
## 위로 가는 공에만 건다. 내려오는 공은 건드리지 않아 패들로 받는 일은 그대로 남는다.
func _steer(b: Ball) -> void:
	if b.vel.y <= 0.0 or b.pos.y < 0.0:
		return
	if not finale and b.idle < float(cfg["homing_after"]):
		b.target = -1
		return
	b.retarget_in -= STEP
	if b.retarget_in <= 0.0 or b.target < 0 or cell_hp[b.target] <= 0:
		b.retarget_in = 0.25
		b.target = -1
		var best := INF
		for i in cell_hp.size():
			if cell_hp[i] <= 0 or cell_solid[i] == 1:
				continue
			var d := _centers[i].distance_squared_to(b.pos)
			if d < best:
				best = d
				b.target = i
	if b.target < 0:
		return
	var want := (_centers[b.target] - b.pos).angle()
	var turn := deg_to_rad(float(cfg["finale_turn_deg"] if finale else cfg["homing_turn_deg"])) * STEP
	var diff := angle_difference(b.vel.angle(), want)
	b.vel = b.vel.rotated(clampf(diff, -turn, turn))


## 가라앉았던 공이 물 밖으로 튀어 오른다. 공 하나가 빠지면 둘이 나온다.
## 둘 다 호수 가운데에서 먼 쪽, 곧 가까운 물가 쪽으로 나가므로 나오자마자 다시 빠지지 않는다.
## 덤으로 나온 공은 정해진 횟수만큼 튕기면 사라진다. 덤 공이 빠져도 둘이 나온다.
func _emerge(b: Ball) -> void:
	var away := b.pos - _lake_centers[b.lake] if b.lake >= 0 else Vector2.ZERO
	var base := away.angle() if away.length() > 1.0 else _rng.randf() * TAU
	var spread := 0.25 + _rng.randf() * 0.6
	b.vel = Vector2.from_angle(base + spread) * ball_speed()
	_keep_min_angle(b)
	b.state = BallState.FLYING
	b.skipping = true
	b.grace = float(cfg["water_grace"])
	_events.append({"type": "emerge", "pos": b.pos})
	if balls.size() >= int(cfg["max_balls"]):
		return
	var extra := Ball.new()
	extra.id = _next_id
	_next_id += 1
	extra.state = BallState.FLYING
	extra.pos = b.pos
	extra.vel = Vector2.from_angle(base - spread) * ball_speed()
	_keep_min_angle(extra)
	extra.skipping = true
	extra.grace = b.grace
	extra.temporary = true
	extra.bounces_left = int(cfg["lake_extra_bounces"])
	balls.append(extra)
	_events.append({"type": "ball_split", "ball": extra.id, "pos": b.pos})


## 공이 무언가에 튕겼다. 덤 공은 튕길 때마다 수명이 준다.
func _bounced(b: Ball) -> void:
	if not b.temporary:
		return
	b.bounces_left -= 1
	if b.bounces_left <= 0:
		b.gone = true


func _hold_position() -> Vector2:
	return Vector2(paddle_x, float(cfg["paddle_y"]) + float(cfg["paddle_thickness"]) / 2.0 + ball_radius + 2.0)


func _add_waiting_ball(seconds: float) -> Ball:
	var b := Ball.new()
	b.id = _next_id
	_next_id += 1
	b.state = BallState.WAITING
	b.wait = seconds
	b.pos = _hold_position()
	balls.append(b)
	return b


## 판 위의 공이 하나도 남지 않았다. 목숨 하나를 잃는다.
func _lose_life() -> void:
	lives -= 1
	wide_left = 0.0
	fire_left = 0.0
	narrow_left = 0.0
	_events.append({"type": "lost"})
	if lives <= 0:
		over = true
		_events.append({"type": "over"})
		return
	_add_waiting_ball(float(cfg["respawn_delay"]))


func _collide_walls(b: Ball) -> void:
	var hit := false
	if b.pos.x < ball_radius:
		b.pos.x = ball_radius
		b.vel.x = absf(b.vel.x)
		hit = true
	elif b.pos.x > stage.width - ball_radius:
		b.pos.x = stage.width - ball_radius
		b.vel.x = -absf(b.vel.x)
		hit = true
	if b.pos.y > stage.height - ball_radius:
		b.pos.y = stage.height - ball_radius
		b.vel.y = -absf(b.vel.y)
		hit = true
	if hit:
		_keep_min_angle(b)
		_bounced(b)


func _collide_paddle(b: Ball) -> void:
	if b.vel.y >= 0.0:
		return
	var half := paddle_width() / 2.0
	var thick := float(cfg["paddle_thickness"])
	var top := float(cfg["paddle_y"]) + thick / 2.0
	if b.pos.y - ball_radius > top or b.pos.y < top - thick:
		return
	var off := b.pos.x - paddle_x
	if absf(off) > half + ball_radius * 0.6:
		return
	# 맞은 자리가 가운데에서 멀수록 옆으로 눕는다
	var a := clampf(off / half, -1.0, 1.0) * deg_to_rad(float(cfg["paddle_max_angle_deg"]))
	b.vel = Vector2(sin(a), cos(a)) * ball_speed()
	b.pos.y = top + ball_radius
	b.combo = 0
	_bounced(b)
	_events.append({"type": "paddle"})


## 깨지지 않는 벽에 튕긴다. 벽은 깎이지 않는다.
func _collide_barriers(b: Ball) -> void:
	var bucket: PackedInt32Array = _wall_grid.get(_key(b.pos), PackedInt32Array())
	var best_depth := 0.0
	var best_n := Vector2.ZERO
	for idx in bucket:
		var pts := walls[idx]
		var q := _closest_on_outline(pts, b.pos)
		var d := q.distance_to(b.pos)
		if d < 0.0001:
			continue
		var depth := 0.0
		var n := Vector2.ZERO
		if Geometry2D.is_point_in_polygon(b.pos, pts):
			depth = ball_radius + d
			n = (q - b.pos) / d
		elif d < ball_radius:
			depth = ball_radius - d
			n = (b.pos - q) / d
		if depth > best_depth:
			best_depth = depth
			best_n = n
	if best_depth <= 0.0:
		return
	b.pos += best_n * best_depth
	if b.vel.dot(best_n) < 0.0:
		b.vel = b.vel.bounce(best_n)
		_keep_min_angle(b)
		_bounced(b)
	_events.append({"type": "wall", "pos": b.pos})


## 벽 하나를 세운다. around 가 가리키는 셀에서 작은 길로 이어진 셀들을 둘러싸고, gap_toward 쪽에 구멍을 낸다.
## 둘레는 그 셀들을 감싸는 볼록한 윤곽이다. 구획이 큰 도로로 둘러싸여 있으면 벽은 큰 도로의 한쪽 면을 따라 서게 된다.
func _build_wall(w: Dictionary) -> void:
	var start := cell_at(Vector2(float(w["around"][0]), float(w["around"][1])))
	if start < 0:
		return
	# radius 를 주면 그 거리 안의 셀까지만 두른다. 구획이 너무 넓을 때 쓴다.
	var reach_limit := float(w.get("radius", INF))
	var seen := {start: true}
	var queue: Array[int] = [start]
	var cloud := PackedVector2Array()
	while not queue.is_empty():
		var c: int = queue.pop_front()
		cloud.append_array(stage.cells[c]["points"])
		for n in _neighbors[c]:
			if not seen.has(n) and _centers[n].distance_to(_centers[start]) <= reach_limit:
				seen[n] = true
				queue.append(n)
	var hull := Geometry2D.convex_hull(cloud)
	if hull.size() < 4:
		return
	hull.remove_at(hull.size() - 1)  # convex_hull 은 첫 점을 끝에 한 번 더 넣는다
	if Geometry2D.is_polygon_clockwise(hull):
		hull.reverse()
	var grown := Geometry2D.offset_polygon(hull, float(w.get("offset", 10.0)), Geometry2D.JOIN_MITER)
	if grown.is_empty():
		return
	var ring: PackedVector2Array = grown[0]
	var toward := Vector2(float(w["gap_toward"][0]), float(w["gap_toward"][1])).normalized()
	var middle := _center(ring)
	# 구멍의 가운데: 벽의 둘레에서 gap_toward 쪽으로 가장 멀리 나간 변의 가운데
	var gap_at := ring[0]
	var best := -INF
	for i in ring.size():
		var mid := (ring[i] + ring[(i + 1) % ring.size()]) / 2.0
		var score_ := (mid - middle).dot(toward)
		if score_ > best:
			best = score_
			gap_at = mid
	var half_gap := float(w.get("gap_width", 170.0)) / 2.0
	var thick := float(w.get("thickness", 12.0))
	var ends: Array[Vector2] = []
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var along := (b - a).normalized()
		var out := Vector2(along.y, -along.x)
		if out.dot(a - middle) < 0.0:
			out = -out
		# 변을 구멍에 걸리지 않는 조각들로 자른다
		var length := a.distance_to(b)
		var t := (gap_at - a).dot(along)
		var near := Geometry2D.get_closest_point_to_segment(gap_at, a, b).distance_to(gap_at) < half_gap
		var pieces: Array[Vector2] = []
		if not near:
			pieces.append(Vector2(0.0, length))
		else:
			if t - half_gap > 1.0:
				pieces.append(Vector2(0.0, t - half_gap))
				ends.append(a + along * (t - half_gap))
			if t + half_gap < length - 1.0:
				pieces.append(Vector2(t + half_gap, length))
				ends.append(a + along * (t + half_gap))
		for piece in pieces:
			var p0 := a + along * piece.x
			var p1 := a + along * piece.y
			walls.append(PackedVector2Array([p0, p1, p1 + out * thick, p0 + out * thick]))
	if ends.size() >= 2:
		gates.append([ends[0], ends[1]])
	_wall_grid.clear()
	var pad := ball_radius + 8.0
	for i in walls.size():
		var box := _bounds(walls[i]).grow(pad)
		for gx in range(maxi(0, floori(box.position.x / GRID)), floori(box.end.x / GRID) + 1):
			for gy in range(maxi(0, floori(box.position.y / GRID)), floori(box.end.y / GRID) + 1):
				var k := gx + gy * 4096
				var list: PackedInt32Array = _wall_grid.get(k, PackedInt32Array())
				list.append(i)
				_wall_grid[k] = list


func _collide_cells(b: Ball) -> void:
	if b.pos.y < -ball_radius or b.pos.y > stage.height + ball_radius:
		return
	var bucket: PackedInt32Array = _grid.get(_key(b.pos), PackedInt32Array())
	var best := -1
	var best_depth := 0.0
	var best_n := Vector2.ZERO
	for idx in bucket:
		if cell_hp[idx] <= 0:
			continue
		var pts: PackedVector2Array = stage.cells[idx]["points"]
		var q := _closest_on_outline(pts, b.pos)
		var d := q.distance_to(b.pos)
		if d < 0.0001:
			continue
		var depth := 0.0
		var n := Vector2.ZERO
		if Geometry2D.is_point_in_polygon(b.pos, pts):
			depth = ball_radius + d
			n = (q - b.pos) / d
		elif d < ball_radius:
			depth = ball_radius - d
			n = (b.pos - q) / d
		if depth > best_depth:
			best_depth = depth
			best_n = n
			best = idx
	if best < 0:
		return
	# 불공은 보통 셀을 한 번에 부수고 그대로 지나간다. 랜드마크와 숲에서는 보통 공처럼 튕긴다.
	if fire_left > 0.0 and not stage.cells[best]["landmark"] and cell_solid[best] == 0 and not is_park(stage.cells[best]):
		_damage(b, best, cell_hp[best])
		return
	b.pos += best_n * best_depth
	if b.vel.dot(best_n) < 0.0:
		b.vel = b.vel.bounce(best_n)
		_keep_min_angle(b)
		_bounced(b)
	_damage(b, best, 1)


func _damage(b: Ball, idx: int, amount: int) -> void:
	if cell_solid[idx] == 1:
		# 숲은 부서지지 않는다. 공이 튕겨 나올 뿐이다.
		_events.append({"type": "thud", "cell": idx, "pos": b.pos})
		return
	b.idle = 0.0
	# 달아오른 공이 부순 셀은 맞닿은 셀을 한 번씩 깎고, 그렇게 부서진 셀도 다시 이웃을 깎는다
	var queue: Array[int] = [idx]
	var amounts := {idx: amount}
	var first := true
	while not queue.is_empty():
		var cell: int = queue.pop_front()
		if cell_hp[cell] <= 0:
			continue
		var was_fever := is_fever(b)
		if not _strike(b, cell, amounts[cell], not first):
			first = false
			continue
		first = false
		if cleared:
			return
		if not was_fever and is_fever(b):
			_events.append({"type": "fever"})
		if is_fever(b):
			for n in _neighbors[cell]:
				if cell_hp[n] > 0 and cell_solid[n] == 0 and not amounts.has(n):
					amounts[n] = 1
					queue.append(n)


## 셀 하나를 깎는다. 부서졌으면 true.
func _strike(b: Ball, idx: int, amount: int, chained: bool) -> bool:
	cell_hp[idx] = maxi(0, cell_hp[idx] - amount)
	score += int(cfg["score_hit"])
	_events.append({"type": "hit", "cell": idx, "hp": cell_hp[idx], "max_hp": cell_max_hp[idx]})
	if cell_hp[idx] > 0:
		return false
	destroyed += 1
	var points := int(round(float(cfg["score_destroy_per_hp"]) * cell_max_hp[idx] * _multiplier(b.combo)))
	score += points
	b.combo += 1
	var landmark: bool = stage.cells[idx]["landmark"]
	_events.append({"type": "destroyed", "cell": idx, "landmark": landmark, "points": points, "chained": chained})
	if _item_in_cell.has(idx):
		var item := {"id": _next_id, "type": _item_in_cell[idx], "pos": _centers[idx]}
		_next_id += 1
		_item_in_cell.erase(idx)
		items.append(item)
		_events.append({"type": "item_spawn", "id": item["id"], "type_of": item["type"], "pos": item["pos"]})
	if landmark:
		_landmarks_left -= 1
		if _landmarks_left <= 0:
			cleared = true
			_events.append({"type": "cleared"})
	if not finale and not cleared and breakable_count() - destroyed <= int(cfg["finale_cells"]):
		finale = true
		_events.append({"type": "finale"})
		_drop_bolt()
	return true


## 아이템은 곧게 패들 쪽으로 내려온다. 패들로 받으면 발동하고, 놓치면 사라진다.
func _step_items() -> void:
	var half := paddle_width() / 2.0
	var top := float(cfg["paddle_y"]) + float(cfg["paddle_thickness"]) / 2.0
	for it: Dictionary in items.duplicate():
		var pos: Vector2 = it["pos"]
		pos.y -= float(cfg["item_speed"]) * STEP
		it["pos"] = pos
		if pos.y <= top + 20.0 and pos.y >= top - float(cfg["paddle_thickness"]) - 20.0 and absf(pos.x - paddle_x) <= half + 24.0:
			items.erase(it)
			if it["type"] != ITEM_NARROW:
				score += int(cfg["score_item"])
			_events.append({"type": "item_caught", "id": it["id"], "type_of": it["type"]})
			_apply_item(it["type"])
		elif pos.y < float(cfg["paddle_y"]) - float(cfg["fall_margin"]):
			items.erase(it)
			_events.append({"type": "item_gone", "id": it["id"]})
			if it["type"] == ITEM_BOLT:
				_bolt_retry = float(cfg["bolt_retry"])  # 놓친 번개는 잠시 뒤 다시 내려온다


func _apply_item(type: String) -> void:
	match type:
		ITEM_MULTI:
			# 날고 있는 공마다 양옆으로 하나씩 더 나온다
			var spread := deg_to_rad(float(cfg["multiball_spread_deg"]))
			for b: Ball in balls.duplicate():
				if b.state != BallState.FLYING:
					continue
				for sign_: float in [-1.0, 1.0]:
					if balls.size() >= int(cfg["max_balls"]):
						return
					var extra := Ball.new()
					extra.id = _next_id
					_next_id += 1
					extra.state = BallState.FLYING
					extra.pos = b.pos
					extra.vel = b.vel.rotated(spread * sign_)
					extra.skipping = b.skipping
					_keep_min_angle(extra)
					balls.append(extra)
		ITEM_WIDE:
			wide_left = float(cfg["wide_seconds"])
			narrow_left = 0.0
		ITEM_NARROW:
			narrow_left = float(cfg["narrow_seconds"])
			wide_left = 0.0
		ITEM_FIRE:
			fire_left = float(cfg["fire_seconds"])
		ITEM_LIFE:
			lives += 1
		ITEM_BOLT:
			# 남은 셀을 위에서부터 차례로 내리친다
			_strikes.clear()
			for i in cell_hp.size():
				if cell_hp[i] > 0 and cell_solid[i] == 0:
					_strikes.append(i)
			_strikes.sort_custom(func(a: int, b: int) -> bool:
				return _centers[a].y > _centers[b].y if _centers[a].y != _centers[b].y else a < b)
			_strike_wait = 0.0


## 번개 아이템을 판 가운데에서 내려보낸다.
func _drop_bolt() -> void:
	var item := {"id": _next_id, "type": ITEM_BOLT, "pos": Vector2(stage.width / 2.0, float(cfg["bolt_drop_height"]))}
	_next_id += 1
	items.append(item)
	_events.append({"type": "item_spawn", "id": item["id"], "type_of": ITEM_BOLT, "pos": item["pos"]})


func _multiplier(combo_count: int) -> float:
	return minf(1.0 + combo_count * float(cfg["combo_step"]), float(cfg["combo_max"]))


## 공이 거의 옆으로만 가는 상태를 막는다.
func _keep_min_angle(b: Ball) -> void:
	var speed := b.vel.length()
	if speed <= 0.0:
		return
	var min_vy := speed * sin(deg_to_rad(float(cfg["min_angle_deg"])))
	if absf(b.vel.y) >= min_vy:
		return
	var sy := -1.0 if b.vel.y < 0.0 else 1.0
	var sx := -1.0 if b.vel.x < 0.0 else 1.0
	b.vel = Vector2(sx * sqrt(speed * speed - min_vy * min_vy), sy * min_vy)


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


## 서로 맞닿은 셀을 찾아 둔다. 작은 길 하나를 사이에 둔 셀끼리가 이웃이다.
func _build_neighbors() -> void:
	var reach := float(cfg["chain_radius"])
	var boxes: Array[Rect2] = []
	_centers.resize(stage.cells.size())
	_neighbors.resize(stage.cells.size())
	for i in stage.cells.size():
		boxes.append(_bounds(stage.cells[i]["points"]).grow(reach))
		_centers[i] = _center(stage.cells[i]["points"])
		_neighbors[i] = PackedInt32Array()
	for i in stage.cells.size():
		var a: PackedVector2Array = stage.cells[i]["points"]
		for j in range(i + 1, stage.cells.size()):
			if not boxes[i].intersects(boxes[j]):
				continue
			var b: PackedVector2Array = stage.cells[j]["points"]
			var near := false
			for p in a:
				if _closest_on_outline(b, p).distance_to(p) <= reach:
					near = true
					break
			if not near:
				for p in b:
					if _closest_on_outline(a, p).distance_to(p) <= reach:
						near = true
						break
			if near:
				_neighbors[i].append(j)
				_neighbors[j].append(i)


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


static func _center(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
