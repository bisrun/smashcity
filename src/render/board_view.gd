class_name BoardView
extends Node3D
## 스테이지 데이터를 2.5D 판으로 그린다. 판정에는 관여하지 않는다.
##
## 지도 좌표 (x, y)는 장면 좌표 (x - W/2, 높이, H/2 - y)로 옮긴다.
##
## 벽돌(셀) 하나는 건물 한 채다. 블록의 윤곽이 그대로 건물의 벽이 되고, 이웃과는 틈을 두고 떨어져 있다.
## 남은 HP만큼 층이 쌓이고, 맞을 때마다 한 단 낮아진다. 그 위에 종류에 맞는 지붕을 얹는다(docs/11_art_audio.md).
## 건물이 없던 낮은 구획은 큰 나무를 심은 공원이 된다. 랜드마크만 실제 윤곽의 탑을 세운다.

## 강가 나무가 서는 높이
const SLAB_HEIGHT := 1.0
const ModelLibraryScript := preload("res://src/render/model_library.gd")
const SimScript := preload("res://src/sim/sim.gd")
const FLOOR_HEIGHT := 3.2
const LANDMARK_HEIGHT := 555.0
## 이 높이를 넘는 부분은 눌러 그린다. 높은 건물이 통로를 가리지 않게 하려는 것.
const SOFT_LIMIT := 60.0
const SOFT_RATIO := 0.45
## 이웃 블록과의 틈을 만들려고 셀 윤곽을 안으로 들이는 거리 (m)
const GAP := 5.0
## 블록 윗면 테두리의 폭 (m)
const RIM := 6.0
## 건물 몸통의 높이: 바닥 + 남은 단계 x 한 단의 높이
## 한 단을 높게 잡아, 맞을 때마다 건물이 눈에 띄게 줄어든다.
const BODY_BASE := 8.0
const BODY_FLOOR := 26.0
const PARK_HEIGHT := 12.0
const KIND_PARK := "park"
const KIND_HOUSE := "house"
const KIND_TIERED := "tiered"
const KIND_FLAT := "flat"
const KIND_LANDMARK := "landmark"
## 가져온 건물 모델을 통째로 올리는 구획. 네모에 가까운 구획만 해당한다.
const KIND_MODEL := "model"
## 이것을 켜면 네모에 가까운 구획에 가져온 건물 모델을 올린다.
## 잠실에서 해 보니 277개 중 20개만 해당해, 나머지와 섞여 따로 놀아 보였다. 그래서 꺼 두었다.
const USE_MODEL_BUILDINGS := false
## 모델 건물을 올릴 만큼 네모에 가까운지의 기준: 감싸는 네모를 채우는 비율, 가로세로 비, 넓이
const FIT_FILL := 0.84
const FIT_ASPECT := 2.6
const FIT_AREA := 2400.0
const PLINTH := 3.0
const MODEL_HEIGHTS: Array[float] = [40.0, 64.0, 90.0, 118.0]
## 창문 하나의 폭 (m), 밑동 그늘이 건물 밖으로 나오는 폭 (m)
const WINDOW_PITCH := 12.0
const SKIRT := 5.0
const BADGE_RADIUS := 15.0
## 실제 윤곽을 그대로 쓰는 건물의 최소 넓이 (㎡)
const KEEP_REAL_AREA := 1200.0
## 블록 위에 큼직한 것을 놓는 자리의 간격 (m)
## 블록 위 건물의 바닥 배율 범위. 블록에 들어가는 만큼 키운다.
const MAX_BUILDING_SCALE := 2.6
const MIN_BUILDING_SCALE := 0.45
## 높이는 이 배율까지만 키운다. 넓은 블록의 건물이 통로를 가리지 않게 하려는 것.
const MAX_HEIGHT_SCALE := 1.35
const TREE_SPACING := 34.0
const SHORE_SPACING := 40.0

const ROAD := Color("F7ECD8")
const WATER := Color("63CFE0")
## 건물 벽과 지붕의 색. 블록마다 하나씩 고른다.
const WALL_TINTS: Array[Color] = [Color("FFF4E3"), Color("FFE3E0"), Color("E3F4EA"), Color("E2EEFB"), Color("FFF3C9"), Color("EEE4F8"),
	Color("F3C9AE"), Color("EDB8A0"), Color("CFE6D8"), Color("C9DDF2"), Color("FFFFFF"), Color("F6DDB6")]
const ROOF_TINTS: Array[Color] = [Color("E8785A"), Color("F2A65A"), Color("4FB0A5"), Color("E56B8C"), Color("5E8FD6"), Color("8A78D6")]
const WINDOW := Color("8CCBF2")
## 건물마다 고르는 창의 색, 불이 켜진 창의 색
const WINDOWS: Array[Color] = [Color("8CCBF2"), Color("7FD6D8"), Color("9DB8F2"), Color("6FB3E8"), Color("A9D9F5")]
const LIT := Color("FFE9A8")
const STONE := Color("D8D2C4")
## 숲을 두른 돌 테두리의 색, 많이 맞은 숲의 풀빛, 많이 맞은 숲의 나무에 입히는 색
const CURB := Color("F5EFE2")
const AUTUMN := Color("E0B45C")
const AUTUMN_TINT := Color(1.0, 0.72, 0.42)
## 부서진 자리에 남는 터의 색. 길보다 조금 어둡다.
const TRACE_EDGE := Color("E6D4B4")
## 건물 밑동에 깔리는 그늘의 색
const SHADE := Color("D9C7A6")
## 찻길과 차선의 색, 찻길을 바닥에서 띄우는 높이(호수 위 다리에서도 보이게)
const ASPHALT := Color("D9D4DE")
const LANE := Color("FFFFFF")
const ROAD_LIFT := 0.75
const CAR_COUNT := 46
const DECK := Color("F1ECE1")
const WALL_TOP := Color("B9C1CE")
const WALL_SIDE := Color("8792A3")
## 숫자 표지의 색. 2, 3, 4, 5 이상 순서.
const BADGE_COLORS: Array[Color] = [Color("3DBE8B"), Color("F5A623"), Color("F0645A"), Color("8A78D6")]
const GRASS: Array[Color] = [Color("BFE3A8"), Color("B4DC9E"), Color("C9E9B3")]
const WALLS: Array[Color] = [Color("FFF7EC"), Color("FDEFDC"), Color("F7EEF6"), Color("EEF6F3")]
const PITCHED: Array[Color] = [Color("E8785A"), Color("F2A65A"), Color("5BB5A6"), Color("E56B8C"), Color("6F9BD8"), Color("F0C24B")]
const FLAT_LOW: Array[Color] = [Color("8FD3C8"), Color("9CC9F0"), Color("F6D06A")]
const FLAT_MID: Array[Color] = [Color("C9A8EE"), Color("F5A9B8"), Color("9FB7F5")]
const FLAT_HIGH: Array[Color] = [Color("F08BA8"), Color("B58CF0"), Color("F7A072")]
const GOLD := Color("F6C53B")
const WHITE_WALL := Color("F6F9FC")
const ROOF_WHITE := Color("FFFFFF")
const GLASS: Array[Color] = [Color("6FB3E8"), Color("58A6E0"), Color("7CC4EE"), Color("6FD0D8")]
const GLASS_DEEP := Color("3F8FD6")
const GLASS_FRAME := Color("DCEEFB")
const DOME := Color("5FC3CE")
const WARM := Color("D98F78")
const WARM_WINDOW := Color("FBE9D7")
const TRUNK := Color("9A6B4A")
## 위에서 내려다보면 지붕이 가장 많이 보인다. 흰색만 쓰면 판이 허옇게 뜨므로 옅은 색을 섞는다.
const ROOFS: Array[Color] = [Color("BFE0F2"), Color("CFE9E2"), Color("F6D9C8"), Color("E3D8F3"), Color("F7E7B9"), Color("D6ECFA")]
const GOLD_WALL := Color("FFE08A")
const LANDMARK_LOT := Color("FBE7A1")
const PINE: Array[Color] = [Color("4FA873"), Color("5DB57E"), Color("3F9A6B")]
const LEAF: Array[Color] = [Color("7CCB7A"), Color("8FD489"), Color("6BBF73")]
const BLOSSOM: Array[Color] = [Color("F7B7CF"), Color("F9C9DA"), Color("F4A3C0")]
const BANK := Color("A9DB93")
const SAND := Color("F3E2B8")
const FOAM := Color("FFFFFF")
const WATER_NEAR := Color("9BE6E8")
const WATER_MID := Color("5FC8DC")
const WATER_FAR := Color("3FA9CE")
const RIPPLE := Color("C9F4F6")
const HILLS: Array[Color] = [Color("A9D8A0"), Color("9CCFA6"), Color("8FC6AE")]
## 판 바깥으로 배경을 더 그리는 폭 (m). 화면 비율이 달라도 가장자리가 비지 않게 한다.
const OUTSIDE := 500.0

## 셀 번호로 찾는 노드. 부서진 셀은 null.
var cell_nodes: Array[Node3D] = []
## 블록 위에 올린 큼직한 것(건물, 나무 무리)의 수. build() 뒤에 읽는다.
var object_count := 0

var _w := 0.0
var _h := 0.0
var _material: StandardMaterial3D
var _outline: Array[PackedVector2Array] = []
var _lawn: Array[PackedVector2Array] = []
var _is_landmark: Array[bool] = []
var _plinths: Array[MeshInstance3D] = []
var _kind: Array[String] = []
## 셀마다 남은 HP의 비율 (1이면 멀쩡). 숲의 색을 정한다.
var _health: Array[float] = []
var _wall_tint: Array[Color] = []
var _roof_tint: Array[Color] = []
var _badges: Array[Dictionary] = []
var _font: Font
## 숫자 표지의 모양. none 은 숫자만, plain 은 색 원 위의 숫자, rim 은 흰 테가 있는 색 원 위의 숫자.
var badge_style := "none"
var _tops: Array[Node3D] = []
## 셀마다 지붕 숫자를 띄울 자리. (지도 x, 블록 윗면에서의 높이, 지도 y). 없으면 Vector3.INF.
var _label_at: Array[Vector3] = []
var _boxes: Array[Rect2] = []
var _design := {}
var _car_roads: Array[Dictionary] = []
var _cars: Array[Dictionary] = []
var _car_batches: Array[MultiMeshInstance3D] = []
## 네모에 가까운 구획에 올릴 건물 모델의 자리. 셀 번호 → {center, along, across, half_long, half_short}
var _fit := {}
## 모델 건물이 한 번 맞을 때마다 내려앉는 깊이와, 처음의 단계
var _sink: Array[float] = []
var _max_tier: Array[int] = []


## near_bank_y 는 화면 아래쪽 강가가 시작되는 y다. 공을 잃는 선과 맞춘다.
## design 은 스테이지의 수작업 기획(design.json)이다. 멀티볼 아이템이 든 자리에 열기구를 띄운다.
## hp 는 셀마다의 시작 HP다. 지붕 숫자에 쓴다. 비우면 스테이지 데이터의 HP를 쓴다.
func build(stage: StageData, river_width: float, near_bank_y: float, design: Dictionary = {}, hp: PackedInt32Array = PackedInt32Array()) -> void:
	_w = stage.width
	_h = stage.height
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 1.0
	_add_plane(Vector2(_w, _h), Vector3.ZERO, ROAD)
	_build_surroundings(river_width, near_bank_y)
	var lakes := _begin()
	for lake in stage.lakes:
		_add_prism(lakes, lake["points"], 0.0, 0.6, WATER, WATER, 0.0)
	_add_mesh(lakes, false)

	_design = design
	var boxes: Array[Rect2] = []
	for c in stage.cells:
		boxes.append(_bounds(c["points"]))
	_boxes = boxes
	_build_roads(stage)
	var real := _assign_buildings(stage, boxes)
	object_count = 0
	for ci in stage.cells.size():
		var cell := stage.cells[ci]
		var outline := _inset(cell["points"], GAP)
		var lawn := _inset(outline, RIM)
		_outline.append(outline)
		_lawn.append(lawn)
		_is_landmark.append(cell["landmark"])
		var node := Node3D.new()
		add_child(node)
		cell_nodes.append(node)
		var kind := _classify(cell, real[ci], _area(outline))
		if USE_MODEL_BUILDINGS and kind != KIND_PARK and kind != KIND_LANDMARK:
			var fit := _model_fit(outline)
			if not fit.is_empty():
				_fit[ci] = fit
				kind = KIND_MODEL
		_kind.append(kind)
		_health.append(1.0)
		var pick := _hash(ci, 5, 23)
		_wall_tint.append(GOLD_WALL if cell["landmark"] else WALL_TINTS[pick % WALL_TINTS.size()])
		_roof_tint.append(GOLD if cell["landmark"] else ROOF_TINTS[(pick >> 4) % ROOF_TINTS.size()])
		var start_hp: int = hp[ci] if ci < hp.size() else int(cell["hp"])
		var tier := _tier(start_hp, start_hp, cell["landmark"])
		_max_tier.append(tier)
		_sink.append(MODEL_HEIGHTS[clampi(int(cell["hp"]) - 1, 0, 3)] / tier)
		var plinth := MeshInstance3D.new()
		plinth.material_override = _material
		node.add_child(plinth)
		_plinths.append(plinth)
		plinth.mesh = _body_mesh(ci, tier)
		var st := _begin()
		_label_at.append(Vector3.INF)
		_furnish(st, ci, cell, lawn, real[ci], stage)
		var tops := _mesh_child(node, st, true)
		if _kind[ci] == KIND_PARK:
			tops.material_override = _material.duplicate()
		tops.position.y = _body_height(ci, tier)
		_tops.append(tops)
		_badges.append(_add_badge(ci, tops, start_hp))
	_add_props(stage)
	_build_lake_decor(stage)


## 셀이 맞았을 때. 건물이 한 단 낮아지고 숫자가 준다.
func show_hit(cell: int, hp: int, max_hp: int) -> void:
	var node := cell_nodes[cell]
	if node == null:
		return
	_set_badge(_badges[cell], hp)
	var tier := _tier(hp, max_hp, _is_landmark[cell])
	_health[cell] = float(hp) / float(max_hp)
	_plinths[cell].mesh = _body_mesh(cell, tier)
	if _kind[cell] == KIND_PARK:
		# 숲은 낮아지지 않는다. 출렁이고 잎이 흩날리며, 맞을수록 가을빛으로 물든다.
		var tint := Color.WHITE.lerp(AUTUMN_TINT, 1.0 - _health[cell])
		((_tops[cell] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = tint
		var sway := node.create_tween()
		sway.tween_property(node, "scale", Vector3(1.03, 0.88, 1.03), 0.06)
		sway.tween_property(node, "scale", Vector3(0.99, 1.06, 0.99), 0.08)
		sway.tween_property(node, "scale", Vector3.ONE, 0.08)
		return
	var tween := node.create_tween()
	# 쿵 하고 눌렸다가 한 단 낮아진 높이로 튀어 오른다
	tween.tween_property(_tops[cell], "position:y", _body_height(cell, tier), 0.12).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(node, "scale:y", 0.72, 0.06)
	tween.tween_property(node, "scale:y", 1.06, 0.08)
	tween.tween_property(node, "scale:y", 1.0, 0.08)


## 숲에 공이 튕겼을 때. 숲이 출렁이고 잎이 흩날린다. 숲은 부서지지 않는다.
func show_thud(cell: int, map_pos: Vector2) -> void:
	var node := cell_nodes[cell]
	if node == null:
		return
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(1.03, 0.9, 1.03), 0.06)
	tween.tween_property(node, "scale", Vector3(0.99, 1.05, 0.99), 0.08)
	tween.tween_property(node, "scale", Vector3.ONE, 0.08)
	show_debris(map_pos, LEAF[cell % LEAF.size()], false, 7)


## 셀이 부서졌을 때. 납작하게 꺼뜨린 뒤 없앤다.
func show_destroyed(cell: int) -> void:
	var node := cell_nodes[cell]
	if node == null:
		return
	cell_nodes[cell] = null
	_leave_trace(cell)
	var tween := node.create_tween()
	tween.tween_property(node, "scale:y", 0.02, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)


## 숫자 표지. 앞으로 몇 번 맞아야 부서지는지를 지붕 위에 큰 숫자로 보여 준다. 한 번 남은 블록에는 띄우지 않는다.
## 숫자의 크기는 블록의 크기를 따른다. badge_style 에 따라 숫자 뒤에 색 원을 받칠 수 있다.
func _add_badge(ci: int, tops: Node3D, hp: int) -> Dictionary:
	if _label_at[ci] == Vector3.INF:
		return {}
	var node := Node3D.new()
	tops.add_child(node)
	var at := _label_at[ci]
	node.position = _at(Vector2(at.x, at.z), at.y)
	# 글자의 높이 (m). 작은 블록에서도 읽히고 큰 블록에서는 더 크게.
	var tall := clampf(sqrt(_area(_outline[ci])) * 0.5, 34.0, 64.0)
	var fill_mat: StandardMaterial3D = null
	if badge_style != "none":
		var radius := tall * 0.62
		if badge_style == "rim":
			var rim_mat := StandardMaterial3D.new()
			rim_mat.albedo_color = Color.WHITE
			rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rim_mat.no_depth_test = true
			rim_mat.render_priority = 1
			var rim := MeshInstance3D.new()
			rim.mesh = _sphere(radius + 4.0)
			rim.material_override = rim_mat
			rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(rim)
		fill_mat = StandardMaterial3D.new()
		fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill_mat.no_depth_test = true
		fill_mat.render_priority = 2
		var fill := MeshInstance3D.new()
		fill.mesh = _sphere(radius)
		fill.material_override = fill_mat
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(fill)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.shaded = false
	label.font = _badge_font()
	label.font_size = 96
	label.outline_size = 0 if badge_style != "none" else 34
	label.pixel_size = tall / 96.0 * (0.8 if badge_style != "none" else 1.0)
	label.modulate = Color.WHITE
	node.add_child(label)
	var badge := {"node": node, "label": label, "fill": fill_mat}
	_set_badge(badge, hp)
	return badge


func _set_badge(badge: Dictionary, hp: int) -> void:
	if badge.is_empty():
		return
	badge["node"].visible = hp >= 2
	badge["label"].text = str(hp)
	var color := BADGE_COLORS[clampi(hp - 2, 0, BADGE_COLORS.size() - 1)]
	if badge["fill"] != null:
		badge["fill"].albedo_color = color
	else:
		# 원이 없을 때는 흰 숫자에 HP 색의 굵은 테두리를 두른다
		badge["label"].outline_modulate = color.darkened(0.25)


func _badge_font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Jua-Regular.ttf") as Font
	return _font


## 깨지지 않는 벽과 그 구멍의 문기둥을 세운다.
func add_walls(walls: Array[PackedVector2Array], gates: Array[Array]) -> void:
	if walls.is_empty():
		return
	var st := _begin()
	for w in walls:
		_add_prism(st, w, 0.0, 30.0, WALL_TOP, WALL_SIDE, 0.0)
	for g in gates:
		for post: Vector2 in g:
			_add_lathe(st, post, [Vector2(15.0, 0.0), Vector2(15.0, 46.0), Vector2(18.0, 46.0), Vector2(18.0, 52.0), Vector2(0.0, 72.0)], 10,
				[WALL_SIDE, WALL_TOP, WALL_TOP, Color("F0645A")])
	_add_mesh(st, true)


## 그 셀의 한가운데와 대표 색. 이펙트를 낼 때 쓴다.
func cell_center(cell: int) -> Vector2:
	return _center(_outline[cell])


func cell_color(cell: int) -> Color:
	return GRASS[cell % GRASS.size()] if _kind[cell] == KIND_PARK else _roof_tint[cell]


## 번개. 하늘에서 그 자리로 꺾이며 내려꽂힌다.
func show_bolt(map_pos: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foot := _at(map_pos, 6.0)
	var seed := _hash(int(map_pos.x), int(map_pos.y), 9)
	var prev := foot
	var top := 1100.0
	var steps := 7
	for k in range(1, steps + 1):
		var jag := Vector3(((seed >> (k * 3)) % 90) - 45.0, 0.0, 0.0) if k < steps else Vector3.ZERO
		var next := foot + Vector3(0, top * k / steps, 0) + jag
		var half := Vector3(lerpf(9.0, 20.0, float(k) / steps), 0, 0)
		for v: Vector3 in [prev - half, prev + half, next + half, prev - half, next + half, next - half]:
			st.add_vertex(v)
		prev = next
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("FFF7B0")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	var bolt := MeshInstance3D.new()
	bolt.mesh = st.commit()
	bolt.material_override = mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)
	var flash := _prim(self, _sphere(46.0), Color("FFFDE0"), foot + Vector3(0, 24, 0), true)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := bolt.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(flash, "scale", Vector3.ONE * 2.2, 0.2)
	tween.tween_callback(bolt.queue_free)
	tween.tween_callback(flash.queue_free)


## 바닥을 따라 퍼지는 충격파 고리.
func show_shockwave(map_pos: Vector2, reach: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 22.0
	torus.outer_radius = 30.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = _at(map_pos, 8.0)
	var grow := reach / 26.0
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(grow, 1.0, grow), 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)


## 부서지는 조각. 셀이 부서질 때 그 자리에서 튀어 오른다.
func show_debris(map_pos: Vector2, color: Color, big: bool, count: int = 0) -> void:
	var bits := CPUParticles3D.new()
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * (11.0 if big else 8.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	bit.material = mat
	bits.mesh = bit
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = count if count > 0 else (26 if big else 14)
	bits.lifetime = 0.75
	bits.direction = Vector3.UP
	bits.spread = 65.0
	bits.initial_velocity_min = 140.0
	bits.initial_velocity_max = 420.0 if big else 300.0
	bits.angular_velocity_min = -400.0
	bits.angular_velocity_max = 400.0
	bits.gravity = Vector3(0, -900, 0)
	bits.scale_amount_min = 0.4
	bits.scale_amount_max = 1.1
	add_child(bits)
	bits.position = _at(map_pos, 20.0)
	bits.emitting = true
	get_tree().create_timer(1.3).timeout.connect(bits.queue_free)


## 떠오르며 사라지는 글자. 얻은 점수 같은 것을 보여 준다.
func show_popup(map_pos: Vector2, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 4
	label.shaded = false
	label.font = _badge_font()
	label.font_size = 96
	label.outline_size = 26
	label.pixel_size = 0.36
	label.modulate = color
	label.outline_modulate = Color("14213D")
	add_child(label)
	label.position = _at(map_pos, 70.0)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", 190.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


## 떨어지는 아이템 하나의 모습. 종류마다 색과 글자가 다르다.
static func make_item_node(type: String, radius: float) -> Node3D:
	var colors := {"multi": Color("6FB8FF"), "wide": Color("7CD992"), "fire": Color("FF8A5B"), "life": Color("FF6FA3"), "bolt": Color("FFD23F"), "narrow": Color("6B5B95")}
	var marks := {"multi": "x3", "wide": "<>", "fire": "火", "life": "+1", "bolt": "⚡", "narrow": "><"}
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colors.get(type, Color.WHITE)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = mat
	node.add_child(body)
	var label := Label3D.new()
	label.text = marks.get(type, "?")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.font_size = 80
	label.outline_size = 22
	label.pixel_size = radius * 0.016
	label.outline_modulate = Color("14213D")
	node.add_child(label)
	return node


## 길에 생기를 넣는다. 큰 도로를 따라 찻길 띠와 차선을 그리고, 길가에 가로수를 심고, 작은 차를 달리게 한다.
## 모두 그림일 뿐이고 판정과는 무관하다. 공은 그 위를 그대로 지나간다.
func _build_roads(stage: StageData) -> void:
	var st := _begin()
	var trees := _begin()
	_car_roads.clear()
	for ri in stage.roads.size():
		var road := stage.roads[ri]
		var cls: String = road["road_class"]
		if cls != "trunk" and cls != "primary" and cls != "secondary":
			continue
		var pts: PackedVector2Array = road["points"]
		if pts.size() < 2:
			continue
		var half := 15.0 if cls != "secondary" else 12.0
		var total := 0.0
		var lengths := PackedFloat32Array([0.0])
		for i in pts.size() - 1:
			total += pts[i].distance_to(pts[i + 1])
			lengths.append(total)
		if total < 30.0:
			continue
		# 찻길 띠
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := (b - a).normalized()
			var out := Vector2(-dir.y, dir.x) * half
			st.set_color(ASPHALT)
			for v: Vector2 in [a - out, b - out, b + out, a - out, b + out, a + out]:
				st.add_vertex(_at(v, ROAD_LIFT))
			# 꺾이는 자리의 틈을 메운다
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				st.add_vertex(_at(b, ROAD_LIFT))
				st.add_vertex(_at(b + Vector2(cos(a0), sin(a0)) * half, ROAD_LIFT))
				st.add_vertex(_at(b + Vector2(cos(a1), sin(a1)) * half, ROAD_LIFT))
		# 가운데 점선
		var d := 12.0
		while d + 16.0 < total:
			var p0 := _along(pts, lengths, d)
			var p1 := _along(pts, lengths, d + 16.0)
			var dir := (p1 - p0).normalized()
			var out := Vector2(-dir.y, dir.x) * 1.3
			st.set_color(LANE)
			for v: Vector2 in [p0 - out, p1 - out, p1 + out, p0 - out, p1 + out, p0 + out]:
				st.add_vertex(_at(v, ROAD_LIFT + 0.12))
			d += 36.0
		# 가로수: 찻길 양옆에 드문드문
		d = 40.0 + float(_hash(ri, 1, 5) % 40)
		while d < total - 20.0:
			var p0 := _along(pts, lengths, d)
			var p1 := _along(pts, lengths, d + 4.0)
			var dir := (p1 - p0).normalized()
			var h := _hash(ri, int(d), 29)
			var at := p0 + Vector2(-dir.y, dir.x) * (half + 9.0) * (1.0 if h % 2 == 0 else -1.0)
			if at.x > 12.0 and at.x < _w - 12.0 and at.y > 12.0 and at.y < _h - 12.0 and _cell_at(stage, _boxes, at) < 0 and not _on_water(stage, at):
				_add_tree(trees, {"at": at, "round": true, "size": 0.62 + (h >> 3) % 4 * 0.05, "base": 0.0, "color": LEAF[(h >> 6) % 3]})
			d += 84.0
		# 가로등: 가로수 사이사이에
		d = 82.0 + float(_hash(ri, 3, 9) % 40)
		while d < total - 20.0:
			var p0 := _along(pts, lengths, d)
			var p1 := _along(pts, lengths, d + 4.0)
			var dir := (p1 - p0).normalized()
			var h := _hash(ri, int(d), 53)
			var at := p0 + Vector2(-dir.y, dir.x) * (half + 6.0) * (1.0 if h % 2 == 0 else -1.0)
			if at.x > 12.0 and at.x < _w - 12.0 and at.y > 12.0 and at.y < _h - 12.0 and _cell_at(stage, _boxes, at) < 0 and not _on_water(stage, at):
				_add_prop(trees, ModelLibraryScript.LIGHTS, at, 0.0, 30.0, h)
			d += 168.0
		if total > 160.0:
			_car_roads.append({"points": pts, "lengths": lengths, "total": total, "lane": half * 0.5})
	_add_mesh(st, false)
	_add_mesh(trees, true)
	_spawn_cars()


static func _on_water(stage: StageData, p: Vector2) -> bool:
	for lake in stage.lakes:
		if Geometry2D.is_point_in_polygon(p, lake["points"]):
			return true
	return false


## 꺾인 선 위에서 처음부터 d 만큼 간 자리.
static func _along(pts: PackedVector2Array, lengths: PackedFloat32Array, d: float) -> Vector2:
	var i := 0
	while i < lengths.size() - 2 and lengths[i + 1] < d:
		i += 1
	var seg := lengths[i + 1] - lengths[i]
	return pts[i].lerp(pts[i + 1], clampf((d - lengths[i]) / maxf(seg, 0.001), 0.0, 1.0))


## 부서진 자리에 터를 남긴다. 건물이 있던 윤곽이 바닥에 옅게 남아, 판이 휑해 보이지 않고 어디가 뚫렸는지도 읽힌다.
## 공은 그 위를 그대로 지나간다.
func _leave_trace(cell: int) -> void:
	var st := _begin()
	var tint := cell_color(cell)
	_add_prism(st, _outline[cell], 0.0, 0.7, TRACE_EDGE, TRACE_EDGE, 0.0)
	_add_prism(st, _lawn[cell], 0.7, 1.0, TRACE_EDGE.lerp(tint, 0.22), TRACE_EDGE, 0.0)
	var trace := _add_mesh(st, false)
	trace.scale = Vector3(1.0, 0.01, 1.0)
	var tween := trace.create_tween()
	tween.tween_interval(0.18)
	tween.tween_property(trace, "scale:y", 1.0, 0.2)


## 건물이 화면에 그려지는 높이.
static func display_height(levels: int, landmark: bool) -> float:
	var h := LANDMARK_HEIGHT if landmark else levels * FLOOR_HEIGHT
	if h > SOFT_LIMIT:
		h = SOFT_LIMIT + (h - SOFT_LIMIT) * SOFT_RATIO
	return maxf(9.0, h)


## 남은 HP를 1~4단계로 옮긴다. 보통 셀은 HP가 곧 단계이고, HP가 큰 랜드마크와 숲은 4단계로 나눈다.
static func _tier(hp: int, max_hp: int, _landmark: bool) -> int:
	if max_hp > 4:
		return clampi(ceili(hp * 4.0 / max_hp), 1, 4)
	return clampi(hp, 1, 4)


## 블록 몸통의 높이. 건물은 남은 단계만큼 층이 쌓이고, 공원은 낮은 화단이다.
func _body_height(ci: int, tier: int) -> float:
	if _kind[ci] == KIND_PARK:
		return PARK_HEIGHT
	if _kind[ci] == KIND_MODEL:
		# 모델 건물은 받침 위에 서 있다가, 맞을 때마다 땅속으로 한 단씩 내려앉는다
		return PLINTH - (_max_tier[ci] - tier) * _sink[ci]
	return BODY_BASE + tier * BODY_FLOOR


## 블록 몸통. 블록의 윤곽이 그대로 건물의 벽이 된다. 층마다 창문 띠를 두른다.
func _body_mesh(ci: int, tier: int) -> ArrayMesh:
	var st := _begin()
	if _kind[ci] == KIND_PARK:
		# 숲: 돌 테두리를 두른 화단. 테두리가 숲의 경계를 또렷하게 보여 준다. 맞을수록 풀빛이 가을빛으로 바뀐다.
		_add_skirt(st, _outline[ci])
		_add_prism(st, _outline[ci], 0.0, PARK_HEIGHT, CURB, CURB.darkened(0.18), 0.0)
		_add_prism(st, _lawn[ci], PARK_HEIGHT, PARK_HEIGHT + 1.6, GRASS[ci % GRASS.size()].lerp(AUTUMN, 1.0 - _health[ci]), CURB.darkened(0.1), 0.0)
	elif _kind[ci] == KIND_MODEL:
		# 받침은 그대로 남고 건물만 내려앉는다
		_add_skirt(st, _outline[ci])
		_add_prism(st, _outline[ci], 0.0, PLINTH, DECK, STONE, 0.0)
	else:
		var wall := _wall_tint[ci]
		_add_skirt(st, _outline[ci])
		_add_facade(st, _outline[ci], 0.0, _body_height(ci, tier), tier * 3, wall, _roof_tint[ci], wall.darkened(0.06), _hash(ci, 11, 3))
	st.generate_normals()
	return st.commit()


## 구획이 네모에 가까우면 건물 모델을 올릴 자리를 돌려준다. 아니면 빈 사전.
func _model_fit(outline: PackedVector2Array) -> Dictionary:
	if ModelLibraryScript.pick(ModelLibraryScript.BUILDINGS, 0).is_empty():
		return {}
	var rect := _bounding_rect(outline)
	if rect.is_empty() or rect["fill"] < FIT_FILL or _area(outline) < FIT_AREA:
		return {}
	if rect["half_long"] / maxf(1.0, rect["half_short"]) > FIT_ASPECT:
		return {}
	# 건물이 구획 밖으로 나가지 않을 때까지 줄여 본다
	for shrink: float in [0.9, 0.82, 0.74]:
		var corners := _rect(rect["center"], rect["along"], rect["across"], rect["half_long"] * shrink, rect["half_short"] * shrink)
		if _rect_fits(corners, outline):
			rect["half_long"] *= shrink
			rect["half_short"] *= shrink
			return rect
	return {}


## 블록의 종류를 정한다. 건물이 없던 낮은 구획은 공원, 나머지는 블록 전체가 건물 한 채다.
static func _classify(cell: Dictionary, real: Array, area: float) -> String:
	if cell["landmark"]:
		return KIND_LANDMARK
	var hp: int = cell["hp"]
	# 판정이 부서지지 않는 숲으로 치는 셀과 같은 기준이어야 한다
	if SimScript.is_park(cell):
		return KIND_PARK
	if hp >= 3:
		return KIND_FLAT
	if hp == 2 and area >= 2600.0:
		return KIND_TIERED
	return KIND_HOUSE


## 윤곽을 안으로 들인다. 들일 수 없을 만큼 좁으면 그대로 돌려준다.
static func _inset(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var ring := pts.duplicate()
	if Geometry2D.is_polygon_clockwise(ring):
		ring.reverse()
	var best := PackedVector2Array()
	var best_area := 0.0
	for candidate: PackedVector2Array in Geometry2D.offset_polygon(ring, -by):
		if candidate.size() >= 3 and not Geometry2D.is_polygon_clockwise(candidate) and _area(candidate) > best_area:
			best = candidate
			best_area = _area(candidate)
	return best if best_area > 0.0 else ring


## 건물을 그 중심이 놓인 셀에 나눠 담는다. 어느 셀에도 속하지 않는 건물(통로에 깎인 건물)은 버린다.
func _assign_buildings(stage: StageData, boxes: Array[Rect2]) -> Array[Array]:
	var out: Array[Array] = []
	out.resize(stage.cells.size())
	for i in out.size():
		out[i] = []
	for bi in stage.buildings.size():
		var b := stage.buildings[bi]
		var pts: PackedVector2Array = b["points"]
		var center := _center(pts)
		var ci := _cell_at(stage, boxes, center)
		if ci >= 0:
			out[ci].append({"points": pts, "center": center, "area": _area(pts), "levels": b["levels"], "landmark": b["landmark"], "seed": bi})
	return out


## 블록 위를 꾸민다. 높이는 블록 몸통의 윗면을 0으로 한다.
##
## 블록 자체가 건물이므로 여기서는 지붕만 얹는다. 종류마다 지붕이 다르다.
## 집은 뾰족지붕과 굴뚝, 낮은 건물은 층층이 좁아지는 기와지붕, 높은 건물은 옥상 정원과 물탱크가 있는 평지붕이다.
## 공원은 큰 나무를 심고, 랜드마크는 유리 탑을 세운다.
## 숫자 표지를 띄울 자리(지도 좌표와 높이)를 _label_at 에 남긴다.
func _furnish(st: SurfaceTool, ci: int, cell: Dictionary, lawn: PackedVector2Array, real: Array, stage: StageData) -> void:
	var outline := _outline[ci]
	var area := _area(outline)
	var roof := _roof_tint[ci]
	var wall := _wall_tint[ci]
	var h := _hash(ci, 0, 17)
	var axis := _longest_edge(cell["points"])
	var side := Vector2(-axis.y, axis.x)
	match _kind[ci]:
		KIND_LANDMARK:
			var tower := {}
			for b: Dictionary in real:
				if b["landmark"] and (tower.is_empty() or b["area"] > tower["area"]):
					tower = b
			_add_prism(st, outline, 0.0, 2.5, LANDMARK_LOT, GOLD_WALL, 0.0)
			if not tower.is_empty():
				var top := display_height(tower["levels"], true)
				_add_bands(st, tower["points"], 2.5, top, 18, GLASS_FRAME, GLASS_DEEP, GOLD, 0.36)
				_label_at[ci] = Vector3(tower["center"].x, top + 66.0, tower["center"].y)
		KIND_MODEL:
			# 네모에 가까운 구획에 건물 모델을 통째로 올린다
			var fit: Dictionary = _fit[ci]
			var tall := MODEL_HEIGHTS[clampi(int(cell["hp"]) - 1, 0, 3)]
			var names := ModelLibraryScript.TOWERS if int(cell["hp"]) >= 4 else ModelLibraryScript.BUILDINGS
			var model := ModelLibraryScript.pick_by_shape(names, fit["half_long"] / maxf(1.0, fit["half_short"]), h)
			if not model.is_empty():
				_add_model_fit(st, model, fit["center"], fit["along"], fit["across"], fit["half_long"], fit["half_short"], tall, wall, roof)
			_label_at[ci] = Vector3(fit["center"].x, tall + 16.0, fit["center"].y)
			object_count += 1
		KIND_PARK:
			var spot := _roomiest_point(lawn)
			_label_at[ci] = Vector3(spot.x, 44.0, spot.y)
			# 공원 몇 곳에는 조각상을 세운다
			var statued := h % 4 == 0 and _add_prop(st, ModelLibraryScript.STATUES, spot, 0.0, 26.0, h)
			var box := _bounds(lawn)
			var origin := box.get_center()
			var reach := int(ceil(box.size.length() / 2.0 / TREE_SPACING))
			var planted := 0
			for ix in range(-reach, reach + 1):
				for iy in range(-reach, reach + 1):
					var t := _hash(ci, ix * 31 + 7, iy)
					var at := origin + axis * (ix * TREE_SPACING) + side * (iy * TREE_SPACING) + Vector2((t >> 4) % 13 - 6.0, (t >> 8) % 13 - 6.0)
					if not _tree_fits(at, lawn) or (statued and at.distance_to(spot) < 22.0):
						continue
					var lakeside := false
					for lake in stage.lakes:
						if _closest_on_ring(lake["points"], at).distance_to(at) < 52.0:
							lakeside = true
					var round_tree := lakeside or (t >> 12) % 3 != 0
					_add_tree(st, {"at": at, "round": round_tree, "size": 1.5 + ((t >> 14) % 5) * 0.12, "base": 0.0,
						"color": (BLOSSOM if lakeside else (LEAF if round_tree else PINE))[(t >> 17) % 3]})
					planted += 1
					var extra := at + axis * 15.0 + side * 11.0
					if _tree_fits(extra, lawn):
						var kind := (t >> 20) % 4
						if kind == 0:
							_add_prop(st, ModelLibraryScript.BUSHES, extra, 0.0, 10.0, t)
						elif kind == 1:
							_add_prop(st, ModelLibraryScript.FLOWERS, extra, 0.0, 8.0, t)
						elif kind == 2:
							_add_prop(st, ModelLibraryScript.ROCKS, extra, 0.0, 8.0, t)
			if planted == 0 and Geometry2D.is_point_in_polygon(spot, lawn):
				_add_tree(st, {"at": spot, "round": true, "size": 1.2, "base": 0.0, "color": LEAF[h % 3]})
		KIND_HOUSE:
			# 처마 위에 뾰족지붕
			var peak := clampf(sqrt(area) * 0.3, 10.0, 26.0)
			_add_prism(st, outline, 0.0, 2.2, roof.lightened(0.18), roof.darkened(0.12), 0.0)
			_add_prism(st, _inset(outline, 1.5), 2.2, 2.2, roof, roof, peak)
			var spot := _roomiest_point(lawn)
			var chimney := spot + axis * minf(9.0, sqrt(area) * 0.12)
			if Geometry2D.is_point_in_polygon(chimney, lawn):
				_add_prism(st, _rect(chimney, axis, side, 2.6, 2.6), 2.2, peak * 0.75 + 6.0, wall.darkened(0.1), WARM, 0.0)
			_label_at[ci] = Vector3(spot.x, peak + 20.0, spot.y)
			object_count += 1
		KIND_TIERED:
			# 층층이 좁아지는 기와지붕
			var step := clampf(sqrt(area) * 0.11, 5.0, 12.0)
			_add_prism(st, outline, 0.0, 2.5, roof.lightened(0.2), roof.darkened(0.12), 0.0)
			var ring := outline
			var top := 2.5
			for k in 3:
				var next := _inset(ring, step)
				if next.size() < 3 or _area(next) > _area(ring) * 0.96 or _area(next) < 120.0:
					break
				_add_prism(st, next, top, top + 6.0, roof.lightened(0.07 * (k + 1)), roof.darkened(0.1), 0.0)
				ring = next
				top += 6.0
			var spot := _roomiest_point(ring)
			_label_at[ci] = Vector3(spot.x, top + 18.0, spot.y)
			object_count += 1
		_:
			# 평지붕: 색 테두리 안에 밝은 옥상, 그 위에 표지판과 옥탑, 물탱크, 화분
			_add_prism(st, outline, 0.0, 2.2, roof, roof.darkened(0.12), 0.0)
			_add_prism(st, lawn, 2.2, 3.6, DECK, DECK.darkened(0.1), 0.0)
			var spot := _roomiest_point(lawn)
			_add_lathe(st, spot, [Vector2(15.0, 3.6), Vector2(15.0, 4.6), Vector2(11.0, 4.6), Vector2(11.0, 5.0), Vector2(0.0, 5.0)], 16, [roof, roof, ROOF_WHITE, ROOF_WHITE])
			var hut := spot + axis * 30.0
			if _rect_fits(_rect(hut, axis, side, 8.0, 6.0), lawn):
				_add_prism(st, _rect(hut, axis, side, 8.0, 6.0), 3.6, 12.0, roof.lightened(0.15), wall, 0.0)
			var tank := spot - axis * 28.0 + side * 6.0
			if _tree_fits(tank, lawn):
				_add_lathe(st, tank, [Vector2(5.5, 3.6), Vector2(5.5, 12.0), Vector2(0.0, 14.5)], 8, [STONE, STONE.lightened(0.15)])
			# 옥상 소품: 파라솔, 덤불, 꽃. 가져온 모델을 쓴다.
			var decor: Array[Vector2] = [side * 26.0, side * -26.0 + axis * 8.0, side * 22.0 + axis * 24.0, side * -24.0 - axis * 18.0, axis * -44.0, axis * 46.0 + side * 10.0]
			for k in decor.size():
				var place := spot + decor[k]
				if not _tree_fits(place, lawn):
					continue
				var pick := _hash(ci, k, 41)
				if k % 3 == 0:
					if not _add_prop(st, ModelLibraryScript.PARASOLS, place, 3.6, 15.0, pick):
						_add_tree(st, {"at": place, "round": true, "size": 0.75, "base": 3.6, "color": LEAF[pick % 3]})
				elif k % 3 == 1:
					_add_prop(st, ModelLibraryScript.BUSHES, place, 3.6, 9.0, pick)
				else:
					_add_prop(st, ModelLibraryScript.FLOWERS, place, 3.6, 7.0, pick)
			_label_at[ci] = Vector3(spot.x, 24.0, spot.y)
			object_count += 1


## 다각형 안에서 가장자리로부터 가장 먼 점을 대강 찾는다.
static func _roomiest_point(poly: PackedVector2Array) -> Vector2:
	var box := _bounds(poly)
	var best := _center(poly)
	var best_d := -1.0
	for ix in 7:
		for iy in 7:
			var p := box.position + Vector2((ix + 0.5) / 7.0, (iy + 0.5) / 7.0) * box.size
			if not Geometry2D.is_point_in_polygon(p, poly):
				continue
			var d := _closest_on_ring(poly, p).distance_squared_to(p)
			if d > best_d:
				best_d = d
				best = p
	return best


static func _closest_on_ring(pts: PackedVector2Array, p: Vector2) -> Vector2:
	var best := pts[0]
	var best_d := INF
	for i in pts.size():
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


static func _rect_fits(rect: PackedVector2Array, poly: PackedVector2Array) -> bool:
	for i in rect.size():
		if not Geometry2D.is_point_in_polygon(rect[i], poly):
			return false
		if not Geometry2D.is_point_in_polygon((rect[i] + rect[(i + 1) % rect.size()]) / 2.0, poly):
			return false
	return true


func _tree_fits(at: Vector2, lawn: PackedVector2Array) -> bool:
	for off: Vector2 in [Vector2(9, 0), Vector2(-9, 0), Vector2(0, 9), Vector2(0, -9)]:
		if not Geometry2D.is_point_in_polygon(at + off, lawn):
			return false
	return true


## 큰 나무 하나와 작은 나무 둘.
func _add_clump(st: SurfaceTool, at: Vector2, h: int, size: float) -> void:
	var leaf := LEAF[(h >> 4) % 3]
	_add_tree(st, {"at": at, "round": true, "size": 1.9 * size, "base": 0.0, "color": leaf})
	_add_tree(st, {"at": at + Vector2(19, 9) * size, "round": (h >> 7) % 2 == 0, "size": 1.25 * size, "base": 0.0, "color": PINE[(h >> 9) % 3]})
	_add_tree(st, {"at": at + Vector2(-17, 12) * size, "round": true, "size": 1.15 * size, "base": 0.0, "color": LEAF[(h >> 12) % 3]})


static func _rect(at: Vector2, axis: Vector2, side: Vector2, half_w: float, half_d: float) -> PackedVector2Array:
	return PackedVector2Array([
		at - axis * half_w - side * half_d, at + axis * half_w - side * half_d,
		at + axis * half_w + side * half_d, at - axis * half_w + side * half_d,
	])


## 층마다 벽 띠와 유리 띠를 번갈아 두른 기둥. taper가 1보다 작으면 위로 갈수록 그 비율까지 좁아진다.
## grid 를 켜면 유리 띠를 세로 기둥으로 끊어 창문이 격자로 보이게 한다.
func _add_bands(st: SurfaceTool, pts: PackedVector2Array, y0: float, y1: float, floors: int, wall: Color, glass: Color, roof: Color, taper: float, grid: bool = false) -> void:
	var n := pts.size()
	if n < 3:
		return
	var center := _center(pts)
	var floor_h := (y1 - y0) / floors
	var levels := PackedFloat32Array([y0])
	for f in floors:
		levels.append(y0 + (f + 0.38) * floor_h)
		levels.append(y0 + (f + 1.0) * floor_h)
	for i in levels.size() - 1:
		var s0 := lerpf(1.0, taper, (levels[i] - y0) / (y1 - y0))
		var s1 := lerpf(1.0, taper, (levels[i + 1] - y0) / (y1 - y0))
		var is_glass := i % 2 == 1
		var color := glass if is_glass else wall
		if i == 0:
			color = wall.darkened(0.14)  # 바닥에 닿는 띠는 어둡게 해 건물이 땅에 붙어 보이게 한다
		for k in n:
			var a := center + (pts[k] - center) * s0
			var b := center + (pts[(k + 1) % n] - center) * s0
			var a_up := center + (pts[k] - center) * s1
			var b_up := center + (pts[(k + 1) % n] - center) * s1
			var length := a.distance_to(b)
			if not (grid and is_glass) or length < WINDOW_PITCH * 1.2:
				_wall_quad(st, a, b, a_up, b_up, levels[i], levels[i + 1], 0.0, 1.0, color)
				continue
			# 창 하나마다 양옆에 벽 기둥을 세운다
			var count := maxi(1, int(length / WINDOW_PITCH))
			for w in count:
				var t0 := float(w) / count
				var t1 := float(w + 1) / count
				var gap := (t1 - t0) * 0.19
				_wall_quad(st, a, b, a_up, b_up, levels[i], levels[i + 1], t0, t0 + gap, wall)
				_wall_quad(st, a, b, a_up, b_up, levels[i], levels[i + 1], t0 + gap, t1 - gap, glass)
				_wall_quad(st, a, b, a_up, b_up, levels[i], levels[i + 1], t1 - gap, t1, wall)
	st.set_color(roof)
	var top := PackedVector2Array()
	for p in pts:
		top.append(center + (p - center) * taper)
	for idx in Geometry2D.triangulate_polygon(top):
		st.add_vertex(_at(top[idx], y1))


## 건물의 벽. 건물마다 다른 생김새를 고르고, 1층은 가게처럼 꾸미고, 창문 몇 개에는 불을 켠다.
##
## 생김새는 다섯 가지다. 0 격자 창, 1 가로로 이어진 띠 창, 2 세로 기둥 사이의 통유리, 3 작은 창이 띄엄띄엄 난 주택 벽, 4 엇갈린 창.
## 층마다 벽의 밝기를 조금씩 달리해 줄무늬가 지게 하고, 맨 아래는 어둡게 해 건물이 땅에 붙어 보이게 한다.
func _add_facade(st: SurfaceTool, pts: PackedVector2Array, y0: float, y1: float, floors: int, wall: Color, accent: Color, roof: Color, seed: int) -> void:
	var n := pts.size()
	if n < 3:
		return
	var style := seed % 5
	# 창이 시작하고 끝나는 높이(층 높이에 대한 비율), 창 하나의 폭, 창 양옆 벽의 비율
	var sill: float = [0.34, 0.42, 0.1, 0.4, 0.34][style]
	var head: float = [0.9, 0.9, 0.95, 0.8, 0.9][style]
	var pitch: float = [12.0, 0.0, 9.0, 13.0, 12.0][style]
	var pier: float = [0.19, 0.0, 0.12, 0.3, 0.19][style]
	var floor_h := (y1 - y0) / floors
	var glass := WINDOWS[(seed >> 3) % WINDOWS.size()]
	for f in floors:
		var base := y0 + f * floor_h
		var shade := wall if f % 2 == 0 else wall.darkened(0.045)
		var lo := sill
		var hi := head
		var gap := pier
		var step := pitch
		var pane := glass
		if f == 0:
			# 1층: 큰 진열창과 그 위의 차양
			lo = 0.12
			hi = 0.66
			gap = 0.1
			step = 14.0
			pane = glass.darkened(0.28)
		for k in n:
			var a := pts[k]
			var b := pts[(k + 1) % n]
			var length := a.distance_to(b)
			_wall_quad(st, a, b, a, b, base, base + floor_h * lo, 0.0, 1.0, shade.darkened(0.16) if f == 0 else shade)
			if f == 0:
				_wall_quad(st, a, b, a, b, base + floor_h * hi, base + floor_h * 0.84, 0.0, 1.0, accent)
				_wall_quad(st, a, b, a, b, base + floor_h * 0.84, base + floor_h, 0.0, 1.0, shade)
			elif hi < 1.0:
				_wall_quad(st, a, b, a, b, base + floor_h * hi, base + floor_h, 0.0, 1.0, shade)
			var w0 := base + floor_h * lo
			var w1 := base + floor_h * hi
			if step <= 0.0:
				# 띠 창: 모서리만 남기고 가로로 이어진다
				var edge := minf(0.12, 3.0 / maxf(1.0, length))
				_wall_quad(st, a, b, a, b, w0, w1, 0.0, edge, shade)
				_wall_quad(st, a, b, a, b, w0, w1, edge, 1.0 - edge, pane)
				_wall_quad(st, a, b, a, b, w0, w1, 1.0 - edge, 1.0, shade)
				continue
			if length < step * 0.9:
				_wall_quad(st, a, b, a, b, w0, w1, 0.0, 1.0, shade)
				continue
			var count := maxi(1, int(length / step))
			for w in count:
				var t0 := float(w) / count
				var t1 := float(w + 1) / count
				var side := (t1 - t0) * gap
				var h := _hash(seed + f * 31, k * 17 + w, 91)
				var open := not (style == 4 and f > 0 and (w + f) % 2 == 1)
				if not open:
					_wall_quad(st, a, b, a, b, w0, w1, t0, t1, shade)
					continue
				var color := pane
				if f > 0:
					# 창 몇 개에는 불이 켜져 있고, 몇 개는 커튼이 쳐져 있다
					if h % 9 == 0:
						color = LIT
					elif h % 7 == 0:
						color = pane.darkened(0.2)
				_wall_quad(st, a, b, a, b, w0, w1, t0, t0 + side, shade)
				_wall_quad(st, a, b, a, b, w0, w1, t0 + side, t1 - side, color)
				_wall_quad(st, a, b, a, b, w0, w1, t1 - side, t1, shade)
	st.set_color(roof)
	for idx in Geometry2D.triangulate_polygon(pts):
		st.add_vertex(_at(pts[idx], y1))


## 벽의 한 변에서 t0~t1 구간만큼의 네모.
func _wall_quad(st: SurfaceTool, a: Vector2, b: Vector2, a_up: Vector2, b_up: Vector2, y0: float, y1: float, t0: float, t1: float, color: Color) -> void:
	st.set_color(color)
	var p0 := _at(a.lerp(b, t0), y0)
	var p1 := _at(a.lerp(b, t1), y0)
	var q0 := _at(a_up.lerp(b_up, t0), y1)
	var q1 := _at(a_up.lerp(b_up, t1), y1)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(q1)
	st.add_vertex(p0)
	st.add_vertex(q1)
	st.add_vertex(q0)


## 건물 밑동의 그늘. 윤곽을 조금 넓힌 어두운 띠를 바닥에 깔아 건물이 땅에 붙어 보이게 한다.
func _add_skirt(st: SurfaceTool, outline: PackedVector2Array) -> void:
	var ring := outline.duplicate()
	if Geometry2D.is_polygon_clockwise(ring):
		ring.reverse()
	for grown: PackedVector2Array in Geometry2D.offset_polygon(ring, SKIRT, Geometry2D.JOIN_ROUND):
		if grown.size() >= 3 and not Geometry2D.is_polygon_clockwise(grown):
			_add_prism(st, grown, 0.0, 0.32, SHADE, SHADE, 0.0)


## 구획을 감싸는 가장 작은 네모와, 구획이 그 네모를 얼마나 채우는지를 구한다.
## {center, along, across, half_long, half_short, fill}
static func _bounding_rect(pts: PackedVector2Array) -> Dictionary:
	var hull := Geometry2D.convex_hull(pts)
	var best := {}
	var best_area := INF
	for i in hull.size() - 1:
		var dir := (hull[i + 1] - hull[i]).normalized()
		if dir == Vector2.ZERO:
			continue
		var side := Vector2(-dir.y, dir.x)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in hull:
			var u := p.dot(dir)
			var v := p.dot(side)
			lo = Vector2(minf(lo.x, u), minf(lo.y, v))
			hi = Vector2(maxf(hi.x, u), maxf(hi.y, v))
		var size := hi - lo
		if size.x * size.y < best_area:
			best_area = size.x * size.y
			var mid := (lo + hi) / 2.0
			var long_first := size.x >= size.y
			best = {"center": dir * mid.x + side * mid.y, "along": dir if long_first else side, "across": side if long_first else dir,
				"half_long": maxf(size.x, size.y) / 2.0, "half_short": minf(size.x, size.y) / 2.0}
	if best.is_empty():
		return {}
	best["fill"] = _area(pts) / maxf(1.0, best_area)
	return best


## 가져온 건물 모델을 네모에 맞춰 올린다. 모델의 긴 쪽이 네모의 긴 쪽을 따르도록 바닥을 늘린다.
##
## 이 건물들은 벽과 지붕이 모두 어두운 청회색이라 이 판의 밝은 색과 어긋난다.
## 회색 계열인 면만 골라, 위를 보는 면은 지붕 색으로, 옆을 보는 면은 벽 색으로 물들인다. 밝기의 차이는 살려 창과 띠가 그대로 읽히게 한다.
## 차양이나 문처럼 원래 색이 있는 면은 그대로 둔다.
func _add_model_fit(st: SurfaceTool, model: Dictionary, at: Vector2, along: Vector2, across: Vector2, half_long: float, half_short: float, height: float, wall: Color, roof: Color) -> void:
	var points: PackedVector3Array = model["points"]
	var colors: PackedColorArray = model["colors"]
	var half: Vector2 = model["half"]
	var long_is_x := half.x >= half.y
	var sx := (half_long if long_is_x else half_short) / maxf(0.0001, half.x)
	var sz := (half_short if long_is_x else half_long) / maxf(0.0001, half.y)
	var ax := along if long_is_x else across
	var az := across if long_is_x else along
	# 지도 좌표의 방향을 장면 좌표로 옮긴다
	var x3 := Vector3(ax.x, 0.0, -ax.y)
	var z3 := Vector3(az.x, 0.0, -az.y)
	var origin := _at(at, 0.0)
	for t in range(0, points.size() - 2, 3):
		var up := absf((points[t + 1] - points[t]).cross(points[t + 2] - points[t]).normalized().y) > 0.7
		for k in 3:
			var c := colors[t + k]
			if c.s < 0.32:
				var shade := lerpf(0.82, 1.08, clampf((c.v - 0.35) / 0.65, 0.0, 1.0))
				var base := roof if up else wall
				c = Color(base.r * shade, base.g * shade, base.b * shade)
			st.set_color(c)
			var v := points[t + k]
			st.add_vertex(origin + x3 * (v.x * sx) + z3 * (v.z * sz) + Vector3(0.0, v.y * height, 0.0))


## 가져온 모델을 가로 크기에 맞춰 놓는다. 수련이나 카누처럼 납작한 것은 높이가 아니라 너비로 크기를 정한다.
func _add_model_wide(st: SurfaceTool, model: Dictionary, at: Vector2, base: float, width: float, seed: int) -> void:
	var half: Vector2 = model["half"]
	_add_model(st, model, at, base, width / maxf(0.0001, 2.0 * maxf(half.x, half.y)), seed)


## 호수를 꾸민다. 물가 가까이에 수련을 띄우고 물 한가운데에 카누를 몇 척 둔다. 통로가 지나는 자리는 비운다.
func _build_lake_decor(stage: StageData) -> void:
	var st := _begin()
	var lily := 0
	var canoe := 0
	for li in stage.lakes.size():
		var ring: PackedVector2Array = stage.lakes[li]["points"]
		var box := _bounds(ring)
		for i in 900:
			var h := _hash(li * 977 + i, 13, 57)
			var at := box.position + Vector2(float(h % 1000) / 1000.0, float((h >> 10) % 1000) / 1000.0) * box.size
			if not Geometry2D.is_point_in_polygon(at, ring) or _cell_at(stage, _boxes, at) >= 0:
				continue
			var on_road := false
			for c in stage.corridors:
				if Geometry2D.is_point_in_polygon(at, c):
					on_road = true
			if on_road:
				continue
			var shore := _closest_on_ring(ring, at).distance_to(at)
			if shore > 14.0 and shore < 46.0 and lily < 46:
				var model := ModelLibraryScript.pick(ModelLibraryScript.LILIES, h >> 5)
				if not model.is_empty():
					_add_model_wide(st, model, at, 0.7, 13.0 + (h >> 7) % 8, h)
					lily += 1
			elif shore > 60.0 and canoe < 5 and (h >> 3) % 9 == 0:
				var model := ModelLibraryScript.pick(ModelLibraryScript.CANOES, h)
				if not model.is_empty():
					_add_model_wide(st, model, at, 0.7, 34.0, h)
					canoe += 1
	_add_mesh(st, true)


## 차 모델을 한 번에 여러 대 그릴 수 있는 메시로 바꾼다. 길이가 length 가 되게 하고 앞뒤가 Z축을 따르게 한다.
func _car_mesh(model: Dictionary, length: float) -> ArrayMesh:
	var points: PackedVector3Array = model["points"]
	var colors: PackedColorArray = model["colors"]
	var half: Vector2 = model["half"]
	var turn := half.x > half.y  # 길이가 X축을 따르는 모델은 돌려 놓는다
	var scale := length / maxf(0.0001, 2.0 * maxf(half.x, half.y))
	var st := _begin()
	for i in points.size():
		st.set_color(colors[i])
		var v := points[i] * scale
		st.add_vertex(Vector3(-v.z, v.y, v.x) if turn else v)
	st.generate_normals()
	return st.commit()


## 차를 길 위에 흩어 놓는다. 차 모델마다 한 묶음으로 만들어 한 번에 그린다.
func _spawn_cars() -> void:
	_cars.clear()
	_car_batches.clear()
	if _car_roads.is_empty():
		return
	var meshes: Array[Mesh] = []
	for name in ModelLibraryScript.CARS:
		var model := ModelLibraryScript.get_model(name)
		if not model.is_empty():
			meshes.append(_car_mesh(model, 21.0))
	if meshes.is_empty():
		# 모델을 읽지 못하면 상자로 대신한다
		var box := BoxMesh.new()
		box.size = Vector3(9.0, 6.0, 17.0)
		meshes.append(box)
	var counts := PackedInt32Array()
	counts.resize(meshes.size())
	for i in CAR_COUNT:
		var h := _hash(i, 71, 5)
		var road: Dictionary = _car_roads[h % _car_roads.size()]
		var kind := (h >> 19) % meshes.size()
		_cars.append({"road": road, "d": float((h >> 4) % 1000) / 1000.0 * road["total"], "speed": 55.0 + (h >> 9) % 60,
			"way": 1.0 if (h >> 15) % 2 == 0 else -1.0, "kind": kind, "slot": counts[kind]})
		counts[kind] += 1
	for k in meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = counts[k]
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 1.0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		add_child(node)
		_car_batches.append(node)
	_move_cars(0.0)


func _process(delta: float) -> void:
	if not _cars.is_empty():
		_move_cars(delta)


## 차를 길을 따라 움직인다. 끝에 닿으면 반대 차선으로 돌아온다.
func _move_cars(delta: float) -> void:
	for car in _cars:
		var road: Dictionary = car["road"]
		var d: float = car["d"] + car["speed"] * car["way"] * delta
		if d > road["total"] - 6.0 or d < 6.0:
			car["way"] = -car["way"]
			d = clampf(d, 6.0, road["total"] - 6.0)
		car["d"] = d
		var p := _along(road["points"], road["lengths"], d)
		var q := _along(road["points"], road["lengths"], d + 3.0 * car["way"])
		var dir := (q - p).normalized()
		if dir == Vector2.ZERO:
			continue
		var at: Vector2 = p + Vector2(dir.y, -dir.x) * float(road["lane"])
		# 지도 좌표의 방향을 장면 좌표로 옮긴다
		var forward := Vector3(dir.x, 0.0, -dir.y)
		var basis := Basis.looking_at(forward, Vector3.UP)
		_car_batches[car["kind"]].multimesh.set_instance_transform(car["slot"], Transform3D(basis, _at(at, ROAD_LIFT + 0.4)))


## 둥근 단면을 쌓아 올린 모양. profile의 각 점은 (반지름, 높이)다. 구간마다 colors를 차례로 쓴다.
func _add_lathe(st: SurfaceTool, center: Vector2, profile: Array, sides: int, colors: Array) -> void:
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		st.set_color(colors[i % colors.size()])
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			st.add_vertex(_at(center + d0 * p0.x, p0.y))
			st.add_vertex(_at(center + d1 * p0.x, p0.y))
			st.add_vertex(_at(center + d1 * p1.x, p1.y))
			if p1.x > 0.0:
				st.add_vertex(_at(center + d0 * p0.x, p0.y))
				st.add_vertex(_at(center + d1 * p1.x, p1.y))
				st.add_vertex(_at(center + d0 * p1.x, p1.y))


func _add_box(st: SurfaceTool, at: Vector2, axis: Vector2, side: Vector2, half_w: float, half_d: float, y0: float, y1: float, top: Color, wall: Color, apex: float) -> void:
	_add_prism(st, _rect(at, axis, side, half_w, half_d), y0, y1, top, wall, apex)


## 나무 한 그루. 가져온 모델을 쓰고, 모델을 읽지 못하면 직접 만든 모양으로 대신한다.
## 잎은 t["color"] 로 물들인다.
func _add_tree(st: SurfaceTool, t: Dictionary) -> void:
	var at: Vector2 = t["at"]
	var s: float = t["size"]
	var base: float = t.get("base", SLAB_HEIGHT)
	var leaf: Color = t["color"]
	var seed := _hash(int(at.x), int(at.y), 3)
	var model := ModelLibraryScript.pick(ModelLibraryScript.ROUND_TREES if t["round"] else ModelLibraryScript.POINTED_TREES, seed)
	if not model.is_empty():
		# 가져온 나무의 잎은 민트색이라 이 판의 풀빛과 어긋난다. 잎을 이 판의 색으로 물들인다.
		_add_model(st, model, at, base, (42.0 if t["round"] else 46.0) * s, seed, leaf)
		return
	_add_lathe(st, at, [Vector2(2.3 * s, base), Vector2(2.0 * s, base + 8.0 * s)], 5, [TRUNK])
	if t["round"]:
		_add_lathe(st, at, [Vector2(0.0, base + 5.0 * s), Vector2(10.5 * s, base + 14.0 * s), Vector2(7.5 * s, base + 22.0 * s), Vector2(0.0, base + 26.0 * s)],
			7, [leaf.darkened(0.1), leaf, leaf.lightened(0.14)])
	else:
		_add_lathe(st, at, [Vector2(9.5 * s, base + 4.0 * s), Vector2(0.0, base + 22.0 * s)], 6, [leaf])
		_add_lathe(st, at, [Vector2(6.5 * s, base + 14.0 * s), Vector2(0.0, base + 30.0 * s)], 6, [leaf.lightened(0.12)])


## 가져온 모델 하나를 메시에 구워 넣는다. height 는 세웠을 때의 높이(m), seed 는 돌려 놓는 각도를 정한다.
## leaf_tint 를 주면 초록 잎 부분을 그 색으로 바꾼다.
func _add_model(st: SurfaceTool, model: Dictionary, at: Vector2, base: float, height: float, seed: int, leaf_tint: Color = Color.TRANSPARENT) -> void:
	var points: PackedVector3Array = model["points"]
	var colors: PackedColorArray = model["colors"]
	var origin := _at(at, base)
	var yaw := float(seed % 628) / 100.0
	var cy := cos(yaw)
	var sy := sin(yaw)
	for i in points.size():
		var c := colors[i]
		# 초록이나 청록인 부분이 잎이다. 줄기는 붉은 기가 더 세다.
		if leaf_tint.a > 0.0 and c.g > c.r * 1.15:
			c = leaf_tint.darkened(clampf(0.8 - c.g, 0.0, 0.22))
		st.set_color(c)
		var v := points[i] * height
		st.add_vertex(origin + Vector3(v.x * cy - v.z * sy, v.y, v.x * sy + v.z * cy))


## 가져온 모델 중 하나를 골라 놓는다. 읽을 수 있는 모델이 없으면 아무것도 하지 않고 false 를 돌려준다.
func _add_prop(st: SurfaceTool, names: Array[String], at: Vector2, base: float, height: float, seed: int) -> bool:
	var model := ModelLibraryScript.pick(names, seed)
	if model.is_empty():
		return false
	_add_model(st, model, at, base, height, seed)
	return true


## 상상으로 더한 구조물. 지도에는 없는 것들이다(docs/05_items.md 의 상상 아이템).
func _add_props(stage: StageData) -> void:
	# 대관람차: 호수 안의 섬에 세운다. 섬 블록 위에 붙여 블록과 함께 움직이게 한다.
	var island := -1
	var island_area := 0.0
	for ci in stage.cells.size():
		var pts: PackedVector2Array = stage.cells[ci]["points"]
		for lake in stage.lakes:
			var surrounded := true
			for p in pts:
				if not Geometry2D.is_point_in_polygon(p, lake["points"]):
					surrounded = false
					break
			if surrounded and _area(pts) > island_area:
				island = ci
				island_area = _area(pts)
	if island >= 0:
		var wheel := Node3D.new()
		_tops[island].add_child(wheel)
		wheel.position = _at(_center(stage.cells[island]["points"]), 0.0)
		var radius := 64.0
		var cy := radius + 22.0
		var rim := TorusMesh.new()
		rim.inner_radius = radius - 4.5
		rim.outer_radius = radius + 4.5
		_prim(wheel, rim, Color("FF6FA3"), Vector3(0, cy, 0)).rotation.x = PI / 2.0
		for i in 6:
			var spoke := BoxMesh.new()
			spoke.size = Vector3(radius * 2.0, 2.5, 2.5)
			_prim(wheel, spoke, Color.WHITE, Vector3(0, cy, 0)).rotation.z = i * PI / 6.0
		var cabins: Array[Color] = [Color("FFD24A"), Color("6FB8FF"), Color("7CD992"), Color("FF8A5B"), Color("B58CF0")]
		for i in 10:
			var a := TAU * i / 10.0
			_prim(wheel, _sphere(8.5), cabins[i % 5], Vector3(cos(a) * radius, cy + sin(a) * radius, 0))
		for sx: float in [-1.0, 1.0]:
			var leg := BoxMesh.new()
			leg.size = Vector3(5, cy + 4.0, 5)
			_prim(wheel, leg, Color.WHITE, Vector3(sx * 20.0, cy / 2.0, 0)).rotation.z = -sx * 0.24

	# 열기구: 멀티볼 아이템이 든 블록 위에 띄운다. 블록에 붙여 블록이 부서지면 함께 사라지게 한다.
	var hues: Array[Color] = [Color("FF8A5B"), Color("6FB8FF"), Color("FFD24A"), Color("B58CF0")]
	var n := 0
	for it: Dictionary in _design.get("items", []):
		if String(it["type"]) != "multi":
			continue
		var spot := Vector2(float(it["at"][0]), float(it["at"][1]))
		var ci := _cell_at(stage, _boxes, spot)
		var parent: Node3D = _tops[ci] if ci >= 0 else self
		if ci >= 0 and _label_at[ci] != Vector3.INF:
			spot = Vector2(_label_at[ci].x, _label_at[ci].z)
		var base := _at(spot, 0.0)
		_prim(parent, _sphere(30.0), hues[n % hues.size()], base + Vector3(0, 190, 0)).scale.y = 1.18
		var neck := CylinderMesh.new()
		neck.top_radius = 17.0
		neck.bottom_radius = 7.0
		neck.height = 18.0
		_prim(parent, neck, Color.WHITE, base + Vector3(0, 158, 0))
		var basket := BoxMesh.new()
		basket.size = Vector3(12, 10, 12)
		_prim(parent, basket, Color("A8744B"), base + Vector3(0, 140, 0))
		n += 1

	# 무지개 문: 큰 도로를 가로지른다
	var seg := stage.nearest_road_segment(PackedStringArray(["primary"]), Vector2(_w * 0.72, _h * 0.5))
	var gate_at: Vector2 = seg[0]
	var along: Vector2 = seg[1]
	var across := Vector2(-along.y, along.x)
	var bands: Array[Color] = [Color("FF7A8A"), Color("FFD24A"), Color("6FD3A8"), Color("6FB8FF")]
	var arch := _begin()
	for bi in bands.size():
		arch.set_color(bands[bi])
		var r_out := 68.0 - bi * 8.0
		var r_in := r_out - 8.0
		for k in 20:
			var a0 := PI * k / 20.0
			var a1 := PI * (k + 1) / 20.0
			var o0 := _at(gate_at + across * cos(a0) * r_out, sin(a0) * r_out + 2.0)
			var o1 := _at(gate_at + across * cos(a1) * r_out, sin(a1) * r_out + 2.0)
			var i0 := _at(gate_at + across * cos(a0) * r_in, sin(a0) * r_in + 2.0)
			var i1 := _at(gate_at + across * cos(a1) * r_in, sin(a1) * r_in + 2.0)
			for v: Vector3 in [o0, o1, i1, o0, i1, i0]:
				arch.add_vertex(v)
	_add_mesh(arch, true)

	# 등대: 강가
	var foot := _at(Vector2(_w * 0.1, -36.0), 0.0)
	var tower := CylinderMesh.new()
	tower.top_radius = 11.0
	tower.bottom_radius = 16.0
	tower.height = 70.0
	_prim(self, tower, Color.WHITE, foot + Vector3(0, 35, 0))
	var stripe := CylinderMesh.new()
	stripe.top_radius = 13.2
	stripe.bottom_radius = 14.6
	stripe.height = 16.0
	_prim(self, stripe, Color("F0645A"), foot + Vector3(0, 40, 0))
	var lamp := CylinderMesh.new()
	lamp.top_radius = 9.0
	lamp.bottom_radius = 9.0
	lamp.height = 12.0
	_prim(self, lamp, Color("FFF2A8"), foot + Vector3(0, 76, 0), true)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 13.0
	cap.height = 14.0
	_prim(self, cap, Color("F0645A"), foot + Vector3(0, 89, 0))

	# 랜드마크 꼭대기의 빛. 랜드마크가 선 블록 위에 붙인다.
	for ci in stage.cells.size():
		if not stage.cells[ci]["landmark"]:
			continue
		for b in stage.buildings:
			if b["landmark"]:
				_prim(_tops[ci], _sphere(17.0), Color("FFF6C2"), _at(_center(b["points"]), display_height(b["levels"], true) + 20.0), true)
				break
		break


## 물보라. 공이 물에 빠질 때와 튀어 오를 때 그 자리에 낸다. big이면 더 크게.
func show_splash(map_pos: Vector2, big: bool) -> void:
	var at := _at(map_pos, 1.5)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 16.0
	torus.outer_radius = 21.0
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1, 1, 1, 0.95)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = at
	var grow := 4.6 if big else 3.0
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(grow, 1.0, grow), 0.55).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.55)
	tween.tween_callback(ring.queue_free)

	var drops := CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 5.0 if big else 3.6
	drop.height = drop.radius * 2.0
	drop.radial_segments = 8
	drop.rings = 4
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color("E9FBFD")
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	drops.mesh = drop
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.amount = 34 if big else 18
	drops.lifetime = 0.8
	drops.direction = Vector3.UP
	drops.spread = 48.0
	drops.initial_velocity_min = 150.0 if big else 90.0
	drops.initial_velocity_max = 330.0 if big else 190.0
	drops.gravity = Vector3(0, -780, 0)
	drops.scale_amount_min = 0.5
	drops.scale_amount_max = 1.2
	add_child(drops)
	drops.position = at
	drops.emitting = true
	get_tree().create_timer(1.4).timeout.connect(drops.queue_free)


func _mesh_child(parent: Node3D, st: SurfaceTool, shadows: bool) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _longest_edge(pts: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var best_len := 0.0
	for i in pts.size():
		var e := pts[(i + 1) % pts.size()] - pts[i]
		if e.length() > best_len:
			best_len = e.length()
			best = e.normalized()
	return best


## 판을 둘러싼 풍경. 지도와 패들 사이를 강으로 잇고, 판의 옆과 위는 풀밭과 언덕으로 감싼다.
##
## 강은 지도 쪽 강가(풀밭, 모래, 물거품)에서 시작해 깊어질수록 짙어지고, 화면 아래쪽 강가에서 끝난다.
## 강가의 선은 곧지 않고 굽이친다. 판정과는 무관한 그림이다.
func _build_surroundings(river_width: float, near_bank_y: float) -> void:
	var st := _begin()
	var x0 := -OUTSIDE
	var x1 := _w + OUTSIDE
	var bottom := -river_width - OUTSIDE
	var x := x0
	while x < x1:
		var xa := x
		var xb := minf(x + 14.0, x1)
		var sa := -_far_shore(xa)
		var sb := -_far_shore(xb)
		var na := _near_shore(xa, near_bank_y)
		var nb := _near_shore(xb, near_bank_y)
		_band(st, xa, xb, 0.0, 0.0, sa, sb, 0.5, BANK, BANK)
		_band(st, xa, xb, sa, sb, sa - 9.0, sb - 9.0, 0.45, SAND, SAND)
		_band(st, xa, xb, sa - 9.0, sb - 9.0, sa - 12.5, sb - 12.5, 0.4, FOAM, FOAM)
		_band(st, xa, xb, sa - 12.5, sb - 12.5, -130.0, -130.0, 0.0, WATER_NEAR, WATER_MID)
		_band(st, xa, xb, -130.0, -130.0, na + 3.5, nb + 3.5, 0.0, WATER_MID, WATER_FAR)
		_band(st, xa, xb, na + 3.5, nb + 3.5, na, nb, 0.4, FOAM, FOAM)
		_band(st, xa, xb, na, nb, na - 9.0, nb - 9.0, 0.45, SAND, SAND)
		_band(st, xa, xb, na - 9.0, nb - 9.0, bottom, bottom, 0.5, BANK, BANK)
		x = xb
	# 판의 옆과 위를 감싸는 풀밭
	_band(st, x0, 0.0, _h + OUTSIDE, _h + OUTSIDE, 0.0, 0.0, 0.3, BANK, BANK)
	_band(st, _w, x1, _h + OUTSIDE, _h + OUTSIDE, 0.0, 0.0, 0.3, BANK, BANK)
	_band(st, 0.0, _w, _h + OUTSIDE, _h + OUTSIDE, _h, _h, 0.3, BANK, BANK)
	# 잔물결
	for i in 170:
		var h := _hash(i, 31, 7)
		var rx := x0 + float(h % 4096) / 4096.0 * (x1 - x0)
		var ry := near_bank_y + 30.0 + float((h >> 12) % 1024) / 1024.0 * (-near_bank_y - 60.0)
		if ry > -_far_shore(rx) - 24.0:
			continue
		var length := 16.0 + (h % 5) * 7.0
		_band(st, rx, rx + length, ry, ry, ry - 2.4, ry - 2.4, 0.15, RIPPLE, RIPPLE)
	_add_mesh(st, false)

	var green := _begin()
	x = x0
	while x < x1:
		var h := _hash(int(x), 5, 11)
		if h % 3 != 0:
			var depth := _far_shore(x) * (0.25 + float((h >> 3) % 50) / 100.0)
			_add_tree(green, {"at": Vector2(x + (h % 17), -depth), "round": true, "size": 0.8 + ((h >> 9) % 5) * 0.1,
				"color": (BLOSSOM if (h >> 13) % 3 == 0 else LEAF)[(h >> 16) % 3]})
		var g := _hash(int(x), 9, 3)
		_add_tree(green, {"at": Vector2(x + (g % 19), _near_shore(x, near_bank_y) - 24.0 - (g >> 5) % 50), "round": (g >> 11) % 3 == 0,
			"size": 1.3 + ((g >> 13) % 6) * 0.1, "color": PINE[(g >> 17) % 3]})
		x += 30.0
	for i in 220:
		var h := _hash(i, 77, 13)
		var at := Vector2(float(h % 4096) / 4096.0 * _w, _h + 14.0 + float((h >> 12) % 1024) / 1024.0 * (OUTSIDE - 40.0))
		_add_tree(green, {"at": at, "round": (h >> 3) % 5 == 0, "size": 1.0 + ((h >> 6) % 6) * 0.12, "color": PINE[(h >> 9) % 3]})
	_add_mesh(green, true)

	# 지도 위쪽 멀리 보이는 언덕
	for i in 7:
		var h := _hash(i, 3, 19)
		var radius := 210.0 + (h % 5) * 40.0
		var hill := _prim(self, _sphere(radius), HILLS[i % 3], _at(Vector2(_w * (i + 0.5) / 7.0 + (h % 90) - 45.0, _h + 250.0 + (h >> 4) % 160), -radius * 0.12))
		hill.scale.y = 0.42
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 지도 쪽 강가가 기준선에서 내려온 거리.
static func _far_shore(x: float) -> float:
	return 46.0 + 14.0 * sin(x / 97.0) + 9.0 * sin(x / 41.0 + 1.3) + 5.0 * sin(x / 19.0 + 0.4)


## 화면 아래쪽 강가의 y.
static func _near_shore(x: float, base_y: float) -> float:
	return base_y + 11.0 * sin(x / 53.0 + 2.0) + 6.0 * sin(x / 23.0)


## xa에서 xb까지, 위쪽 선(ya_top, yb_top)과 아래쪽 선(ya_bot, yb_bot) 사이를 채운다. 위아래 색을 달리 줄 수 있다.
func _band(st: SurfaceTool, xa: float, xb: float, ya_top: float, yb_top: float, ya_bot: float, yb_bot: float, height: float, top: Color, bot: Color) -> void:
	var a := _at(Vector2(xa, ya_top), height)
	var b := _at(Vector2(xb, yb_top), height)
	var c := _at(Vector2(xb, yb_bot), height)
	var d := _at(Vector2(xa, ya_bot), height)
	for v: Array in [[a, top], [b, top], [c, bot], [a, top], [c, bot], [d, bot]]:
		st.set_color(v[1])
		st.add_vertex(v[0])


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


func _prim(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, unshaded: bool = false) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = at
	return mi


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # 면마다 따로 음영을 준다
	return st


func _add_mesh(st: SurfaceTool, shadows: bool) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## 다각형을 y0에서 y1까지 올린 기둥을 더한다. apex가 0보다 크면 윗면 대신 뾰족지붕을 얹는다.
func _add_prism(st: SurfaceTool, pts: PackedVector2Array, y0: float, y1: float, top: Color, side: Color, apex: float) -> void:
	var n := pts.size()
	if n < 3:
		return
	st.set_color(top)
	if apex > 0.0:
		var tip := _at(_center(pts), y1 + apex)
		for i in n:
			st.add_vertex(_at(pts[i], y1))
			st.add_vertex(_at(pts[(i + 1) % n], y1))
			st.add_vertex(tip)
	else:
		for idx in Geometry2D.triangulate_polygon(pts):
			st.add_vertex(_at(pts[idx], y1))
	st.set_color(side)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		st.add_vertex(_at(a, y0))
		st.add_vertex(_at(b, y0))
		st.add_vertex(_at(b, y1))
		st.add_vertex(_at(a, y0))
		st.add_vertex(_at(b, y1))
		st.add_vertex(_at(a, y1))


func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x - _w / 2.0, y, _h / 2.0 - p.y)


func _add_plane(size: Vector2, at: Vector3, color: Color) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	_prim(self, plane, color, at).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _cell_at(stage: StageData, boxes: Array[Rect2], p: Vector2) -> int:
	for ci in stage.cells.size():
		if boxes[ci].has_point(p) and Geometry2D.is_point_in_polygon(p, stage.cells[ci]["points"]):
			return ci
	return -1


static func _hash(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0xFFFFFF


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func _center(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()


static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) / 2.0
