extends Node3D
## 한 스테이지를 플레이하는 장면.
##
## 판정은 Sim 이 하고, 이 스크립트는 입력을 넘기고 결과를 화면에 옮긴다.
## 흐름: 스테이지 지도 → 플레이 → (장면을 다시 불러) 결과가 얹힌 스테이지 지도.
## 지금 플레이할 수 있는 스테이지는 잠실 하나다.

const StageDataScript := preload("res://src/data/stage_data.gd")
const BalanceScript := preload("res://src/data/balance.gd")
const SimScript := preload("res://src/sim/sim.gd")
const BoardViewScript := preload("res://src/render/board_view.gd")
const SaveDataScript := preload("res://src/meta/save_data.gd")
const HudScript := preload("res://src/ui/hud.gd")
const StageMapScript := preload("res://src/ui/stage_map.gd")

const STAGES_PATH := "res://assets/stages/stages.json"
## 카메라가 내려다보는 각도
const ELEVATION_DEG := 58.0
const CAMERA_DISTANCE := 4200.0
## 화면 위쪽에서 HUD가 쓰는 비율
const HUD_SHARE := 0.13
## 한 프레임에 따라잡을 판정 횟수의 한도. 프레임이 끊겨도 한꺼번에 몰아서 돌지 않게 한다.
const MAX_STEPS_PER_FRAME := 8
## 끌기의 민감도. 1이면 손가락이 움직인 만큼 패들이 움직인다.
const DRAG_GAIN := 1.25
## 판이 끝난 뒤 스테이지 지도로 넘어가기까지의 시간 (초)
const END_PAUSE := 1.6
const SKY := Color("BFE6F2")
const INK := Color("14213D")
const FIRE := Color("FF7A3C")
## 순간의 효과를 알리는 말은 영어로 쓴다.
const ITEM_NAMES := {"multi": "MULTI BALL!", "wide": "WIDE PADDLE!", "fire": "FIRE BALL!", "life": "1 UP!", "bolt": "LIGHTNING!", "narrow": "OOPS! NARROW"}

## 방금 끝난 판의 결과. 장면을 다시 불러도 남아 있어 스테이지 지도에 보여 준다.
static var last_result := {}

var _stage: StageData
var _cfg: Dictionary
var _sim: Sim
var _board: BoardView
var _save: SaveData
var _camera: Camera3D
var _paddle: Node3D
var _hud: Hud
var _map: StageMapScreen
var _ball_nodes := {}
var _item_nodes := {}
var _ball_mesh: SphereMesh
var _outline_mesh: SphereMesh
var _trail_mesh: SphereMesh
var _ball_mat: StandardMaterial3D
var _outline_mat: StandardMaterial3D
var _river := 0.0
var _acc := 0.0
var _paddle_target := 0.0
var _fps_timer := 0.0
## 끌기를 시작한 화면 x와 그때의 패들 위치. 끌지 않는 동안은 NAN.
var _drag_from := NAN
var _drag_paddle := 0.0
var _shake := 0.0
var _camera_home := Vector3.ZERO
var _playing := false
var _ending := -1.0
var _stage_id := ""
var _stage_name := ""
var _city_name := ""
var _stage_list: Array = []
var _stage_index := 0
var _landmark := -1


func _ready() -> void:
	_cfg = BalanceScript.load_file()
	_pick_stage()
	var dir := "res://assets/stages/%s/" % _stage_id
	_stage = StageDataScript.load_file(dir + "map.json")
	if _stage == null or _cfg.is_empty():
		return
	var design: Dictionary = BalanceScript.load_file(dir + "design.json")
	_save = SaveDataScript.new()
	_river = float(_cfg["river_width"])
	_sim = SimScript.new(_stage, _cfg, design)
	_paddle_target = _sim.paddle_x
	for i in _stage.cells.size():
		if _stage.cells[i]["landmark"]:
			_landmark = i
	_setup_light()
	_board = BoardViewScript.new()
	if OS.has_environment("SMASHCITY_BADGE"):
		_board.badge_style = OS.get_environment("SMASHCITY_BADGE")  # 비교용: rim, plain, none
	add_child(_board)
	_board.build(_stage, _river, float(_cfg["paddle_y"]) - float(_cfg["fall_margin"]), design, _sim.cell_max_hp)
	_board.add_walls(_sim.walls, _sim.gates)
	_setup_camera()
	_setup_paddle_and_ball()
	_setup_ui()
	get_viewport().size_changed.connect(_frame_camera)
	if OS.has_environment("SMASHCITY_AUTOPLAY"):
		_start()
	if OS.has_environment("SMASHCITY_SHOT"):
		_save_screenshot.call_deferred(OS.get_environment("SMASHCITY_SHOT"))


## 이번에 할 스테이지를 고른다. 만들어진 스테이지 가운데 아직 못 깬 첫 번째이고, 다 깼으면 첫 번째다.
func _pick_stage() -> void:
	var data: Dictionary = BalanceScript.load_file(STAGES_PATH)
	var city: Dictionary = data["cities"][0]
	_city_name = String(city["name"])
	_stage_list = city["stages"]
	var done := SaveDataScript.new().cleared
	_stage_index = -1
	for i in _stage_list.size():
		if bool(_stage_list[i]["ready"]) and not done.has(String(_stage_list[i]["id"])):
			_stage_index = i
			break
	if _stage_index < 0:
		for i in _stage_list.size():
			if bool(_stage_list[i]["ready"]):
				_stage_index = i
				break
	_stage_id = String(_stage_list[_stage_index]["id"])
	_stage_name = String(_stage_list[_stage_index]["name"])


func _process(delta: float) -> void:
	if _sim == null:
		return
	if _playing:
		_acc = minf(_acc + delta, Sim.STEP * MAX_STEPS_PER_FRAME)
		while _acc >= Sim.STEP:
			_acc -= Sim.STEP
			if OS.has_environment("SMASHCITY_AUTOPLAY"):
				_paddle_target = _lowest_ball_x()
			_sim.set_paddle(_paddle_target)
			_sim.step()
	for e in _sim.take_events():
		match e["type"]:
			"hit":
				_board.show_hit(e["cell"], e["hp"], e["max_hp"])
			"destroyed":
				var at := _board.cell_center(e["cell"])
				_board.show_debris(at, _board.cell_color(e["cell"]), e["landmark"] or e["chained"])
				_board.show_popup(at, "+%d" % e["points"], Color("FFE27A") if e["chained"] else Color.WHITE)
				_board.show_destroyed(e["cell"])
				_shake = maxf(_shake, 16.0 if e["chained"] else 9.0)
				Input.vibrate_handheld(18)
			"splash":
				_board.show_splash(e["pos"], false)
			"emerge":
				_board.show_splash(e["pos"], true)
			"item_caught":
				_hud.say(ITEM_NAMES.get(e["type_of"], ""))
				Input.vibrate_handheld(30)
			"speed_up":
				_hud.say("SPEED UP!")
			"rush":
				_hud.say("RUSH!")
				_shake = maxf(_shake, 18.0)
			"fever":
				_hud.say("FEVER!")
			"finale":
				_hud.say("FINALE!")
			"bolt":
				_board.show_bolt(e["pos"])
				_shake = maxf(_shake, 20.0)
			"lost":
				_hud.say("MISS!")
				_shake = maxf(_shake, 26.0)
				Input.vibrate_handheld(120)
			"cleared":
				_hud.say("CLEAR!")
				_finish(true)
			"over":
				_hud.say("GAME OVER")
				_finish(false)
	# 화면 흔들림
	_shake = maxf(0.0, _shake - delta * 60.0)
	_camera.position = _camera_home + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake
	_sync_paddle()
	_sync_balls()
	_sync_items()
	_sync_hud(delta)
	if _ending > 0.0:
		_ending -= delta
		if _ending <= 0.0:
			get_tree().reload_current_scene()


## 판이 끝났다. 기록을 남기고 잠시 뒤 스테이지 지도로 넘어간다.
func _finish(cleared: bool) -> void:
	var now := Time.get_datetime_dict_from_system()
	var at := "%02d.%02d %02d:%02d" % [now["month"], now["day"], now["hour"], now["minute"]]
	var rank := 0
	if not OS.has_environment("SMASHCITY_AUTOPLAY"):
		rank = _save.add_result(_stage_id, _sim.score, cleared, int(_sim.elapsed), at)
	last_result = {"cleared": cleared, "score": _sim.score, "rank": rank, "stage": _stage_id}
	_ending = END_PAUSE


func _start() -> void:
	if _map != null:
		_map.queue_free()
		_map = null
	last_result = {}
	_playing = true


## 패들은 손가락이 닿은 자리로 튀지 않는다. 닿은 곳을 기준으로 끈 만큼만 움직인다.
func _unhandled_input(event: InputEvent) -> void:
	if _sim == null or not _playing:
		return
	var view_w := get_viewport().get_visible_rect().size.x
	var per_pixel := _camera.size / view_w * DRAG_GAIN
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_drag_from = event.position.x
			_drag_paddle = _sim.paddle_x
		else:
			_drag_from = NAN
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if is_nan(_drag_from):
			_drag_from = event.position.x
			_drag_paddle = _sim.paddle_x
		_paddle_target = _drag_paddle + (event.position.x - _drag_from) * per_pixel
		# 판 끝에 닿은 뒤 더 끌어도 반대로 돌아올 때 바로 반응하도록 기준을 다시 잡는다
		var half := _sim.paddle_width() / 2.0
		var clamped := clampf(_paddle_target, half, _stage.width - half)
		if clamped != _paddle_target:
			_paddle_target = clamped
			_drag_from = event.position.x
			_drag_paddle = clamped


## 자동 플레이용: 패들에 가장 먼저 닿을 공의 x.
func _lowest_ball_x() -> float:
	var best := _sim.paddle_x
	var best_y := INF
	for b in _sim.balls:
		if b.state == Sim.BallState.FLYING and b.vel.y < 0.0 and b.pos.y < best_y:
			best_y = b.pos.y
			best = b.pos.x
	return best


func _to_scene(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x - _stage.width / 2.0, height, _stage.height / 2.0 - p.y)


func _sync_paddle() -> void:
	_paddle.position.x = _sim.paddle_x - _stage.width / 2.0
	_paddle.scale.x = _sim.paddle_width() / float(_cfg["paddle_width"])


func _sync_balls() -> void:
	_ball_mat.albedo_color = FIRE if _sim.fire_left > 0.0 else (Color("FFE27A") if _sim.any_fever() else Color.WHITE)
	var seen := {}
	for b in _sim.balls:
		seen[b.id] = true
		var node: Node3D = _ball_nodes.get(b.id)
		if node == null:
			node = MeshInstance3D.new()
			node.mesh = _outline_mesh
			node.material_override = _outline_mat
			var core := MeshInstance3D.new()
			core.mesh = _ball_mesh
			core.material_override = _ball_mat
			node.add_child(core)
			node.add_child(_make_trail())
			add_child(node)
			_ball_nodes[b.id] = node
		node.position = _to_scene(b.pos, _sim.ball_radius)
		node.visible = b.state != Sim.BallState.SUNK
	for id: int in _ball_nodes.keys():
		if not seen.has(id):
			_ball_nodes[id].queue_free()
			_ball_nodes.erase(id)


## 공 뒤에 남는 꼬리.
func _make_trail() -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.mesh = _trail_mesh
	trail.local_coords = false
	trail.amount = 16
	trail.lifetime = 0.2
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	trail.scale_amount_curve = shrink
	return trail


func _sync_items() -> void:
	var seen := {}
	for it in _sim.items:
		seen[it["id"]] = true
		var node: Node3D = _item_nodes.get(it["id"])
		if node == null:
			node = BoardViewScript.make_item_node(it["type"], _sim.ball_radius * 1.5)
			add_child(node)
			_item_nodes[it["id"]] = node
		node.position = _to_scene(it["pos"], _sim.ball_radius * 2.6)
	for id: int in _item_nodes.keys():
		if not seen.has(id):
			_item_nodes[id].queue_free()
			_item_nodes.erase(id)


func _sync_hud(delta: float) -> void:
	var effects: Array = []
	if _sim.fire_left > 0.0:
		effects.append(["FIRE", _sim.fire_left, FIRE])
	if _sim.wide_left > 0.0:
		effects.append(["WIDE", _sim.wide_left, UiKit.MINT])
	if _sim.narrow_left > 0.0:
		effects.append(["NARROW", _sim.narrow_left, Color("6B5B95")])
	if _sim.rush:
		effects.append(["RUSH", 0.0, FIRE])
	if _sim.speed_tier > 0:
		effects.append(["SPEED x%d" % (_sim.speed_tier + 1), 0.0, UiKit.SKY])
	if _sim.finale:
		effects.append(["FINALE", 0.0, UiKit.CORAL])
	var goal := 0.0
	var goal_name := "LEFT"
	if _landmark >= 0:
		goal = float(_sim.cell_hp[_landmark]) / float(_sim.cell_max_hp[_landmark])
		goal_name = "TOWER"
	else:
		goal = 1.0 - float(_sim.destroyed) / maxf(1.0, _sim.breakable_count())
	_hud.show_state(_sim.score, _sim.lives, _sim.combo_multiplier(), _sim.any_fever(), goal_name, goal, effects)
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.3
		_hud.set_fps(int(Engine.get_frames_per_second()))


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = HudScript.new()
	layer.add_child(_hud)
	_hud.set_stage(_city_name, _stage_index + 1, _stage_list.size(), _stage_name)
	if OS.has_environment("SMASHCITY_AUTOPLAY"):
		return
	_map = StageMapScript.new()
	layer.add_child(_map)
	# 방금 끝난 판의 결과와 그 스테이지의 순위를 함께 보여 준다
	var result := last_result
	var cleared := _save.cleared
	var ranked := String(result.get("stage", _stage_id))
	var ranking := _save.top(ranked, 5)
	if OS.has_environment("SMASHCITY_DEMO_RESULT"):
		# 화면 확인용 가짜 결과. 기록에는 남기지 않는다.
		result = {"cleared": true, "score": 48200, "rank": 2, "stage": _stage_id}
		ranking = [{"score": 61350, "cleared": true, "at": "11.23 21:40"}, {"score": 48200, "cleared": true, "at": "11.24 17:12"},
			{"score": 30980, "cleared": false, "at": "11.24 16:55"}, {"score": 12400, "cleared": false, "at": "11.22 09:03"}]
		cleared = [_stage_id]
	var best := {}
	for st: Dictionary in _stage_list:
		best[String(st["id"])] = _save.best(String(st["id"]))
	if OS.has_environment("SMASHCITY_DEMO_RESULT"):
		best[_stage_id] = 61350
	_map.setup(_city_name, _stage_list, cleared, _stage_index, best, ranking, result)
	_map.started.connect(_start)


func _setup_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.56
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFF3DC")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = CAMERA_DISTANCE * 2.2
	sun.shadow_bias = 0.6
	sun.shadow_normal_bias = 3.0
	add_child(sun)
	sun.look_at_from_position(Vector3(-0.5, 1.0, 0.55) * 1000.0, Vector3.ZERO, Vector3.UP)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.near = 10.0
	_camera.far = CAMERA_DISTANCE * 3.0
	add_child(_camera)
	_camera.make_current()
	_frame_camera()


## 판과 강이 모두 보이게 맞춘다. 강의 아래 끝이 화면 아래에 오고, 위쪽에는 HUD 자리를 남긴다.
func _frame_camera() -> void:
	if _camera == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var e := deg_to_rad(ELEVATION_DEG)
	var board_v := (_stage.height + _river) * sin(e)
	var need_v := board_v / (1.0 - HUD_SHARE)
	_camera.size = maxf(_stage.width + 24.0, need_v * view.x / view.y)
	var visible_v := _camera.size * view.y / view.x
	var bottom_z := _stage.height / 2.0 + _river
	var target := Vector3(0.0, 0.0, bottom_z - visible_v / (2.0 * sin(e)))
	_camera.look_at_from_position(target + Vector3(0.0, sin(e), cos(e)) * CAMERA_DISTANCE, target, Vector3.UP)
	_camera_home = _camera.position


func _setup_paddle_and_ball() -> void:
	var width := float(_cfg["paddle_width"])
	var thick := float(_cfg["paddle_thickness"])
	_paddle = Node3D.new()
	_paddle.position = Vector3(0.0, 0.0, _stage.height / 2.0 - float(_cfg["paddle_y"]))
	add_child(_paddle)
	_add_box(_paddle, Vector3(width, 22.0, thick), Vector3(0, 11, 0), INK, false)
	_add_box(_paddle, Vector3(width - 14.0, 4.0, thick - 14.0), Vector3(0, 24, 0), Color.WHITE, true)
	_add_box(_paddle, Vector3(46.0, 20.0, thick - 20.0), Vector3(0, 36, 0), Color("F0645A"), false)

	var r := _sim.ball_radius
	_outline_mesh = SphereMesh.new()
	_outline_mesh.radius = r + 5.0
	_outline_mesh.height = (r + 5.0) * 2.0
	_outline_mat = _flat(INK, true)
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = r
	_ball_mesh.height = r * 2.0
	_ball_mat = _flat(Color.WHITE, true)
	_trail_mesh = SphereMesh.new()
	_trail_mesh.radius = r * 0.8
	_trail_mesh.height = r * 1.6
	_trail_mesh.radial_segments = 8
	_trail_mesh.rings = 4
	_trail_mesh.material = _ball_mat


func _add_box(parent: Node3D, size: Vector3, at: Vector3, color: Color, unshaded: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _flat(color, unshaded)
	mi.position = at
	parent.add_child(mi)


func _flat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## 화면을 PNG로 저장하고 끝낸다. 환경 변수 SMASHCITY_SHOT 에 경로를 주면 실행된다.
## SMASHCITY_SHOT_AFTER 에 초를 주면 그만큼 지난 뒤 찍는다.
func _save_screenshot(path: String) -> void:
	var wait := float(OS.get_environment("SMASHCITY_SHOT_AFTER")) if OS.has_environment("SMASHCITY_SHOT_AFTER") else 0.6
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
