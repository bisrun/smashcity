extends Node3D
## 기술 검증용 첫 장면. 잠실 판을 2.5D로 그리고 프레임을 잰다.
##
## 아직 게임이 아니다. 공은 움직이지 않고 패들만 손가락을 따라간다.
## 판정(sim)은 들어 있지 않다(docs/14_roadmap.md 의 M0).

const StageDataScript := preload("res://src/data/stage_data.gd")
const BoardViewScript := preload("res://src/render/board_view.gd")

const STAGE_PATH := "res://assets/stages/seoul/jamsil/map.json"
## 판 아래 한강 띠의 폭 (m)
const RIVER := 330.0
## 카메라가 내려다보는 각도
const ELEVATION_DEG := 58.0
const CAMERA_DISTANCE := 3600.0
const PADDLE_WIDTH := 240.0
const PADDLE_Y := -150.0
const SKY := Color("BFE6F2")
const INK := Color("14213D")

var _stage: StageData
var _camera: Camera3D
var _paddle: MeshInstance3D
var _info: Label
var _info_timer := 0.0


func _ready() -> void:
	_stage = StageDataScript.load_file(STAGE_PATH)
	if _stage == null:
		return
	_setup_light()
	var board: BoardView = BoardViewScript.new()
	add_child(board)
	board.build(_stage, RIVER)
	_setup_camera()
	_setup_paddle_and_ball()
	_setup_hud()
	get_viewport().size_changed.connect(_frame_camera)
	if OS.has_environment("SMASHCITY_SHOT"):
		_save_screenshot.call_deferred(OS.get_environment("SMASHCITY_SHOT"))


func _process(delta: float) -> void:
	_info_timer -= delta
	if _info_timer <= 0.0 and _info != null:
		_info_timer = 0.5
		_info.text = "FPS %d   벽돌 %d   건물 %d" % [Engine.get_frames_per_second(), _stage.cells.size(), _stage.buildings.size()]


func _unhandled_input(event: InputEvent) -> void:
	var x := NAN
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		x = event.position.x
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		x = event.position.x
	elif event is InputEventMouseButton and event.pressed:
		x = event.position.x
	if is_nan(x) or _paddle == null:
		return
	var view_w := get_viewport().get_visible_rect().size.x
	var world_x := (x / view_w - 0.5) * _camera.size
	var limit := _stage.width / 2.0 - PADDLE_WIDTH / 2.0
	_paddle.position.x = clampf(world_x, -limit, limit)


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


## 판의 가로를 화면 가로에 맞추고, 한강 띠의 아래 끝이 화면 아래에 오게 한다.
func _frame_camera() -> void:
	if _camera == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var e := deg_to_rad(ELEVATION_DEG)
	_camera.size = _stage.width + 24.0
	var visible_v := _camera.size * view.y / view.x
	var board_v := (_stage.height + RIVER) * sin(e)
	var bottom_z := _stage.height / 2.0 + RIVER
	var target_z := bottom_z - visible_v / (2.0 * sin(e))
	if visible_v < board_v:
		target_z = RIVER / 2.0  # 화면이 판보다 짧으면 가운데에 둔다
	var target := Vector3(0.0, 0.0, target_z)
	_camera.look_at_from_position(target + Vector3(0.0, sin(e), cos(e)) * CAMERA_DISTANCE, target, Vector3.UP)


func _setup_paddle_and_ball() -> void:
	var hull := BoxMesh.new()
	hull.size = Vector3(PADDLE_WIDTH, 22.0, 42.0)
	_paddle = MeshInstance3D.new()
	_paddle.mesh = hull
	_paddle.material_override = _flat(INK, false)
	_paddle.position = Vector3(0.0, 11.0, _stage.height / 2.0 - PADDLE_Y)
	add_child(_paddle)
	var deck := BoxMesh.new()
	deck.size = Vector3(PADDLE_WIDTH - 14.0, 4.0, 28.0)
	var deck_mi := MeshInstance3D.new()
	deck_mi.mesh = deck
	deck_mi.material_override = _flat(Color.WHITE, true)
	deck_mi.position = Vector3(0.0, 13.0, 0.0)
	_paddle.add_child(deck_mi)

	var at := _stage.nearest_road_point(PackedStringArray(["primary"]), Vector2(_stage.width * 0.47, _stage.height * 0.2))
	var r := _stage.ball_diameter / 2.0
	var outline := SphereMesh.new()
	outline.radius = r + 5.0
	outline.height = (r + 5.0) * 2.0
	var outline_mi := MeshInstance3D.new()
	outline_mi.mesh = outline
	var outline_mat := _flat(INK, true)
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mi.material_override = outline_mat
	outline_mi.position = Vector3(at.x - _stage.width / 2.0, r, _stage.height / 2.0 - at.y)
	add_child(outline_mi)
	var ball := SphereMesh.new()
	ball.radius = r
	ball.height = r * 2.0
	var ball_mi := MeshInstance3D.new()
	ball_mi.mesh = ball
	ball_mi.material_override = _flat(Color.WHITE, true)
	outline_mi.add_child(ball_mi)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(24.0, 64.0)
	_info.add_theme_font_size_override("font_size", 30)
	_info.add_theme_color_override("font_color", INK)
	layer.add_child(_info)


func _flat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## 화면을 PNG로 저장하고 끝낸다. 환경 변수 SMASHCITY_SHOT 에 경로를 주면 실행된다.
func _save_screenshot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
