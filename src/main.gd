extends Node3D
## 잠실 한 판을 플레이하는 장면.
##
## 판정은 Sim 이 하고, 이 스크립트는 입력을 넘기고 결과를 화면에 옮긴다.
## 터짐, 워프, 결과 화면은 아직 없다(docs/14_roadmap.md).

const StageDataScript := preload("res://src/data/stage_data.gd")
const BalanceScript := preload("res://src/data/balance.gd")
const SimScript := preload("res://src/sim/sim.gd")
const BoardViewScript := preload("res://src/render/board_view.gd")

const STAGE_DIR := "res://assets/stages/seoul/jamsil/"
## 카메라가 내려다보는 각도
const ELEVATION_DEG := 58.0
const CAMERA_DISTANCE := 4200.0
## 화면 위쪽에서 HUD가 쓰는 비율
const HUD_SHARE := 0.1
## 한 프레임에 따라잡을 판정 횟수의 한도. 프레임이 끊겨도 한꺼번에 몰아서 돌지 않게 한다.
const MAX_STEPS_PER_FRAME := 8
const SKY := Color("BFE6F2")
const INK := Color("14213D")
const FIRE := Color("FF7A3C")
## 끌기의 민감도. 1이면 손가락이 움직인 만큼 패들이 움직인다.
const DRAG_GAIN := 1.25
const ITEM_NAMES := {"multi": "멀티볼", "wide": "넓은 패들", "fire": "불공", "life": "공 +1"}

var _stage: StageData
var _cfg: Dictionary
var _sim: Sim
var _board: BoardView
var _camera: Camera3D
var _paddle: Node3D
var _ball_nodes := {}
var _item_nodes := {}
var _ball_mesh: SphereMesh
var _outline_mesh: SphereMesh
var _ball_mat: StandardMaterial3D
var _outline_mat: StandardMaterial3D
var _info: Label
var _banner: Label
var _toast: Label
var _toast_left := 0.0
var _river := 0.0
var _acc := 0.0
var _paddle_target := 0.0
var _info_timer := 0.0
## 끌기를 시작한 화면 x와 그때의 패들 위치. 끌지 않는 동안은 NAN.
var _drag_from := NAN
var _drag_paddle := 0.0
var _shake := 0.0
var _camera_home := Vector3.ZERO
var _trail_mesh: SphereMesh


func _ready() -> void:
	_stage = StageDataScript.load_file(STAGE_DIR + "map.json")
	_cfg = BalanceScript.load_file()
	if _stage == null or _cfg.is_empty():
		return
	var design: Dictionary = BalanceScript.load_file(STAGE_DIR + "design.json")
	_river = float(_cfg["river_width"])
	_sim = SimScript.new(_stage, _cfg, design)
	_paddle_target = _sim.paddle_x
	_setup_light()
	_board = BoardViewScript.new()
	add_child(_board)
	_board.build(_stage, _river, float(_cfg["paddle_y"]) - float(_cfg["fall_margin"]), design, _sim.cell_max_hp)
	_board.add_walls(_sim.walls, _sim.gates)
	_setup_camera()
	_setup_paddle_and_ball()
	_setup_hud()
	get_viewport().size_changed.connect(_frame_camera)
	if OS.has_environment("SMASHCITY_SHOT"):
		_save_screenshot.call_deferred(OS.get_environment("SMASHCITY_SHOT"))


func _process(delta: float) -> void:
	if _sim == null:
		return
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
				_say(ITEM_NAMES.get(e["type_of"], ""))
				Input.vibrate_handheld(30)
			"fever":
				_say("피버! 연쇄 폭발")
			"finale":
				_say("마무리! 공이 건물을 쫓아간다")
			"lost":
				_shake = maxf(_shake, 26.0)
				Input.vibrate_handheld(120)
			"cleared":
				_banner.text = "클리어\n%d점  남은 공 %d  %d초\n화면을 누르면 다시 시작" % [_sim.score, _sim.lives, int(_sim.elapsed)]
				_banner.visible = true
			"over":
				_banner.text = "게임 오버\n%d점  부순 벽돌 %d\n화면을 누르면 다시 시작" % [_sim.score, _sim.destroyed]
				_banner.visible = true
	# 화면 흔들림
	_shake = maxf(0.0, _shake - delta * 60.0)
	_camera.position = _camera_home + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake
	_sync_paddle()
	_sync_balls()
	_sync_items()
	_toast_left -= delta
	if _toast_left <= 0.0:
		_toast.visible = false
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.2
		var effects := ""
		if _sim.fire_left > 0.0:
			effects += "   불공 %d초" % ceili(_sim.fire_left)
		if _sim.wide_left > 0.0:
			effects += "   넓은 패들 %d초" % ceili(_sim.wide_left)
		_info.text = "%d점   x%.1f   남은 공 %d%s\n부순 벽돌 %d/%d   %dfps" % [_sim.score, _sim.combo_multiplier(), _sim.lives, effects,
			_sim.destroyed, _sim.breakable_count(), Engine.get_frames_per_second()]


## 패들은 손가락이 닿은 자리로 튀지 않는다. 닿은 곳을 기준으로 끈 만큼만 움직인다.
func _unhandled_input(event: InputEvent) -> void:
	if _sim == null:
		return
	var view_w := get_viewport().get_visible_rect().size.x
	var per_pixel := _camera.size / view_w * DRAG_GAIN
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			if _sim.cleared or _sim.over:
				get_tree().reload_current_scene()
				return
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


func _say(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = 1.4


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


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(24.0, 56.0)
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_color", INK)
	layer.add_child(_info)
	_banner = _centered_label(52, 0.0)
	_banner.visible = false
	layer.add_child(_banner)
	_toast = _centered_label(44, 0.28)
	_toast.visible = false
	layer.add_child(_toast)


## 화면 가운데에 놓이는 글자. shift 는 화면 높이에 대한 비율로, 양수면 아래로 내린다.
func _centered_label(font_size: int, shift: float) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.anchor_top = shift
	label.anchor_bottom = 1.0 + shift
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 14)
	return label


func _flat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## 화면을 PNG로 저장하고 끝낸다. 환경 변수 SMASHCITY_SHOT 에 경로를 주면 실행된다.
## SMASHCITY_SHOT_AFTER 에 초를 주면 그만큼 플레이한 뒤 찍는다.
func _save_screenshot(path: String) -> void:
	var wait := float(OS.get_environment("SMASHCITY_SHOT_AFTER")) if OS.has_environment("SMASHCITY_SHOT_AFTER") else 0.2
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
