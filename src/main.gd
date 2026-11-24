extends Node3D
## 잠실 한 판을 플레이하는 장면.
##
## 판정은 Sim 이 하고, 이 스크립트는 입력을 넘기고 결과를 화면에 옮긴다.
## 아이템, 터짐, 결과 화면은 아직 없다(docs/14_roadmap.md).

const StageDataScript := preload("res://src/data/stage_data.gd")
const BalanceScript := preload("res://src/data/balance.gd")
const SimScript := preload("res://src/sim/sim.gd")
const BoardViewScript := preload("res://src/render/board_view.gd")

const STAGE_PATH := "res://assets/stages/seoul/jamsil/map.json"
## 카메라가 내려다보는 각도
const ELEVATION_DEG := 58.0
const CAMERA_DISTANCE := 4200.0
## 화면 위쪽에서 HUD가 쓰는 비율
const HUD_SHARE := 0.1
## 한 프레임에 따라잡을 판정 횟수의 한도. 프레임이 끊겨도 한꺼번에 몰아서 돌지 않게 한다.
const MAX_STEPS_PER_FRAME := 8
const SKY := Color("BFE6F2")
const INK := Color("14213D")

var _stage: StageData
var _cfg: Dictionary
var _sim: Sim
var _board: BoardView
var _camera: Camera3D
var _paddle: MeshInstance3D
var _ball: MeshInstance3D
var _info: Label
var _banner: Label
var _river := 0.0
var _acc := 0.0
var _paddle_target := 0.0
var _info_timer := 0.0


func _ready() -> void:
	_stage = StageDataScript.load_file(STAGE_PATH)
	_cfg = BalanceScript.load_file()
	if _stage == null or _cfg.is_empty():
		return
	_river = float(_cfg["river_width"])
	_sim = SimScript.new(_stage, _cfg)
	_paddle_target = _sim.paddle_x
	_setup_light()
	_board = BoardViewScript.new()
	add_child(_board)
	_board.build(_stage, _river, float(_cfg["paddle_y"]) - float(_cfg["fall_margin"]))
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
			_paddle_target = _sim.ball_pos.x
		_sim.set_paddle(_paddle_target)
		_sim.step()
	for e in _sim.take_events():
		match e["type"]:
			"hit":
				_board.show_hit(e["cell"], e["hp"], e["max_hp"])
			"destroyed":
				_board.show_destroyed(e["cell"])
			"cleared":
				_banner.text = "클리어\n%d점  빠짐 %d회  %d초\n화면을 누르면 다시 시작" % [_sim.score, _sim.falls, int(_sim.elapsed)]
				_banner.visible = true
	_paddle.position.x = _sim.paddle_x - _stage.width / 2.0
	_ball.position = Vector3(_sim.ball_pos.x - _stage.width / 2.0, _sim.ball_radius, _stage.height / 2.0 - _sim.ball_pos.y)
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.2
		_info.text = "%d점   x%.1f   빠짐 %d\n부순 벽돌 %d/%d   %dfps" % [_sim.score, _sim.combo_multiplier(), _sim.falls,
			_sim.destroyed, _sim.breakable_count(), Engine.get_frames_per_second()]


func _unhandled_input(event: InputEvent) -> void:
	var x := NAN
	var pressed := false
	if event is InputEventScreenTouch:
		x = event.position.x
		pressed = event.pressed
	elif event is InputEventScreenDrag:
		x = event.position.x
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		x = event.position.x
	elif event is InputEventMouseButton and event.pressed:
		x = event.position.x
		pressed = true
	if is_nan(x) or _sim == null:
		return
	if _sim.cleared and pressed:
		get_tree().reload_current_scene()
		return
	var view_w := get_viewport().get_visible_rect().size.x
	_paddle_target = (x / view_w - 0.5) * _camera.size + _stage.width / 2.0


func _setup_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
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


func _setup_paddle_and_ball() -> void:
	var width := float(_cfg["paddle_width"])
	var thick := float(_cfg["paddle_thickness"])
	var hull := BoxMesh.new()
	hull.size = Vector3(width, 22.0, thick)
	_paddle = MeshInstance3D.new()
	_paddle.mesh = hull
	_paddle.material_override = _flat(INK, false)
	_paddle.position = Vector3(0.0, 11.0, _stage.height / 2.0 - float(_cfg["paddle_y"]))
	add_child(_paddle)
	var deck := BoxMesh.new()
	deck.size = Vector3(width - 14.0, 4.0, thick - 14.0)
	var deck_mi := MeshInstance3D.new()
	deck_mi.mesh = deck
	deck_mi.material_override = _flat(Color.WHITE, true)
	deck_mi.position = Vector3(0.0, 13.0, 0.0)
	_paddle.add_child(deck_mi)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(46.0, 20.0, thick - 20.0)
	var cabin_mi := MeshInstance3D.new()
	cabin_mi.mesh = cabin
	cabin_mi.material_override = _flat(Color("F0645A"), false)
	cabin_mi.position = Vector3(0.0, 25.0, 0.0)
	_paddle.add_child(cabin_mi)

	var r := _sim.ball_radius
	var outline := SphereMesh.new()
	outline.radius = r + 5.0
	outline.height = (r + 5.0) * 2.0
	_ball = MeshInstance3D.new()
	_ball.mesh = outline
	var outline_mat := _flat(INK, true)
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_ball.material_override = outline_mat
	add_child(_ball)
	var core := SphereMesh.new()
	core.radius = r
	core.height = r * 2.0
	var core_mi := MeshInstance3D.new()
	core_mi.mesh = core
	core_mi.material_override = _flat(Color.WHITE, true)
	_ball.add_child(core_mi)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(24.0, 56.0)
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_color", INK)
	layer.add_child(_info)
	_banner = Label.new()
	_banner.visible = false
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 52)
	_banner.add_theme_color_override("font_color", INK)
	_banner.add_theme_color_override("font_outline_color", Color.WHITE)
	_banner.add_theme_constant_override("outline_size", 14)
	layer.add_child(_banner)


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
