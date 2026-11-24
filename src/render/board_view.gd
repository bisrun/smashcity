class_name BoardView
extends Node3D
## 스테이지 데이터를 2.5D 판으로 그린다. 판정에는 관여하지 않는다.
##
## 지도 좌표 (x, y)는 장면 좌표 (x - W/2, 높이, H/2 - y)로 옮긴다.
## 색은 화면 샘플의 파스텔 스타일을 옮긴 초기값이다(docs/11_art_audio.md).

const SLAB_HEIGHT := 7.0
const FLOOR_HEIGHT := 3.2
const LANDMARK_HEIGHT := 555.0
## 이 높이를 넘는 부분은 눌러 그린다. 높은 건물이 통로를 가리지 않게 하려는 것.
const SOFT_LIMIT := 60.0
const SOFT_RATIO := 0.45

const ROAD := Color("F7ECD8")
const WATER := Color("63CFE0")
const EARTH := Color("D9A679")
const GRASS: Array[Color] = [Color("BFE3A8"), Color("B4DC9E"), Color("C9E9B3")]
const WALLS: Array[Color] = [Color("FFF7EC"), Color("FDEFDC"), Color("F7EEF6"), Color("EEF6F3")]
const PITCHED: Array[Color] = [Color("E8785A"), Color("F2A65A"), Color("5BB5A6"), Color("E56B8C"), Color("6F9BD8"), Color("F0C24B")]
const FLAT_LOW: Array[Color] = [Color("8FD3C8"), Color("9CC9F0"), Color("F6D06A")]
const FLAT_MID: Array[Color] = [Color("C9A8EE"), Color("F5A9B8"), Color("9FB7F5")]
const FLAT_HIGH: Array[Color] = [Color("F08BA8"), Color("B58CF0"), Color("F7A072")]
const GOLD := Color("F6C53B")
const GOLD_WALL := Color("FFE08A")
const LANDMARK_LOT := Color("FBE7A1")

## 건물이 차지한 넓이가 이 비율에 못 미치는 벽돌은 상상의 집으로 채운다.
const FILL_BELOW_COVERAGE := 0.14
## 채워 넣는 집 사이의 간격 (m)
const FILL_SPACING := 26.0

var _w := 0.0
var _h := 0.0

## 상상으로 채워 넣은 집의 수. build() 뒤에 읽는다.
var filler_count := 0


func build(stage: StageData, river_width: float) -> void:
	_w = stage.width
	_h = stage.height
	_add_plane(Vector2(_w, _h), Vector3.ZERO, ROAD)
	_add_plane(Vector2(_w, river_width), Vector3(0, -0.5, _h / 2.0 + river_width / 2.0), WATER)
	add_child(_mesh_instance(_build_lakes(stage), false))
	add_child(_mesh_instance(_build_cells(stage), true))
	add_child(_mesh_instance(_build_buildings(stage), true))
	add_child(_mesh_instance(_build_filler(stage), true))


## 건물이 화면에 그려지는 높이.
static func display_height(levels: int, landmark: bool) -> float:
	var h := LANDMARK_HEIGHT if landmark else levels * FLOOR_HEIGHT
	if h > SOFT_LIMIT:
		h = SOFT_LIMIT + (h - SOFT_LIMIT) * SOFT_RATIO
	return maxf(9.0, h)


func _build_lakes(stage: StageData) -> ArrayMesh:
	var st := _begin()
	for lake in stage.lakes:
		_add_prism(st, lake["points"], 0.0, 0.6, WATER, WATER, 0.0)
	st.generate_normals()
	return st.commit()


func _build_cells(stage: StageData) -> ArrayMesh:
	var st := _begin()
	for i in stage.cells.size():
		var c := stage.cells[i]
		var top := LANDMARK_LOT if c["landmark"] else GRASS[i % GRASS.size()]
		_add_prism(st, c["points"], 0.0, SLAB_HEIGHT, top, EARTH, 0.0)
	st.generate_normals()
	return st.commit()


func _build_buildings(stage: StageData) -> ArrayMesh:
	var st := _begin()
	for i in stage.buildings.size():
		var b := stage.buildings[i]
		var pts: PackedVector2Array = b["points"]
		var levels: int = b["levels"]
		var top_y := SLAB_HEIGHT + display_height(levels, b["landmark"])
		if b["landmark"]:
			_add_prism(st, pts, SLAB_HEIGHT, top_y, GOLD, GOLD_WALL, 0.0)
			continue
		var wall := WALLS[(i * 7) % WALLS.size()]
		if levels <= 4 and pts.size() <= 8 and _area(pts) < 900.0:
			_add_prism(st, pts, SLAB_HEIGHT, top_y, PITCHED[(i * 13) % PITCHED.size()], wall, 7.0)
			continue
		var band := FLAT_LOW if levels <= 10 else (FLAT_MID if levels <= 25 else FLAT_HIGH)
		_add_prism(st, pts, SLAB_HEIGHT, top_y, band[(i * 5) % band.size()], wall, 0.0)
	st.generate_normals()
	return st.commit()


## 건물이 드문 벽돌을 상상의 집으로 채운다. 실제 지도에는 없는 건물이다.
##
## 집은 벽돌의 가장 긴 변과 나란히 줄지어 선다. 같은 스테이지에서는 늘 같은 자리에 같은 집이 선다.
func _build_filler(stage: StageData) -> ArrayMesh:
	var st := _begin()
	filler_count = 0
	var boxes: Array[Rect2] = []
	for c in stage.cells:
		boxes.append(_bounds(c["points"]))
	var inside: Array[Array] = []
	inside.resize(stage.cells.size())
	for i in inside.size():
		inside[i] = []
	for b in stage.buildings:
		var pts: PackedVector2Array = b["points"]
		var center := _center(pts)
		for ci in stage.cells.size():
			if boxes[ci].has_point(center) and Geometry2D.is_point_in_polygon(center, stage.cells[ci]["points"]):
				inside[ci].append({"points": pts, "center": center, "area": _area(pts)})
				break
	for ci in stage.cells.size():
		var cell := stage.cells[ci]
		if cell["landmark"]:
			continue
		var cell_pts: PackedVector2Array = cell["points"]
		var built := 0.0
		for b: Dictionary in inside[ci]:
			built += b["area"]
		if built >= _area(cell_pts) * FILL_BELOW_COVERAGE:
			continue
		var axis := _longest_edge(cell_pts)
		var side := Vector2(-axis.y, axis.x)
		var origin := boxes[ci].get_center()
		var reach := int(ceil(boxes[ci].size.length() / 2.0 / FILL_SPACING))
		for ix in range(-reach, reach + 1):
			for iy in range(-reach, reach + 1):
				var h := _hash(ci, ix, iy)
				var at := origin + axis * (ix * FILL_SPACING) + side * (iy * FILL_SPACING)
				var half_w := 5.5 + (h % 5) * 0.6
				var half_d := 4.5 + ((h >> 3) % 4) * 0.5
				var corners := PackedVector2Array([
					at - axis * half_w - side * half_d, at + axis * half_w - side * half_d,
					at + axis * half_w + side * half_d, at - axis * half_w + side * half_d,
				])
				if not _fits(corners, at, cell_pts, inside[ci]):
					continue
				var top_y := SLAB_HEIGHT + 9.0 + ((h >> 5) % 3) * 2.0
				_add_prism(st, corners, SLAB_HEIGHT, top_y, PITCHED[(h >> 7) % PITCHED.size()], WALLS[(h >> 10) % WALLS.size()], 6.0)
				filler_count += 1
	st.generate_normals()
	return st.commit()


## 집이 벽돌 안에 온전히 들어가고 실제 건물과 겹치지 않는지.
func _fits(corners: PackedVector2Array, at: Vector2, cell_pts: PackedVector2Array, real: Array) -> bool:
	for c in corners:
		if not Geometry2D.is_point_in_polygon(c, cell_pts):
			return false
	for b: Dictionary in real:
		if at.distance_to(b["center"]) < 18.0 or Geometry2D.is_point_in_polygon(at, b["points"]):
			return false
		for c in corners:
			if Geometry2D.is_point_in_polygon(c, b["points"]):
				return false
	return true


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


static func _longest_edge(pts: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var best_len := 0.0
	for i in pts.size():
		var e := pts[(i + 1) % pts.size()] - pts[i]
		if e.length() > best_len:
			best_len = e.length()
			best = e.normalized()
	return best


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # 면마다 따로 음영을 준다
	return st


## 다각형을 y0에서 y1까지 올린 기둥을 더한다. apex가 0보다 크면 윗면 대신 뾰족지붕을 얹는다.
func _add_prism(st: SurfaceTool, pts: PackedVector2Array, y0: float, y1: float, top: Color, side: Color, apex: float) -> void:
	var n := pts.size()
	if n < 3:
		return
	st.set_color(top)
	if apex > 0.0:
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= n
		var tip := _at(c, y1 + apex)
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


func _mesh_instance(mesh: ArrayMesh, shadows: bool) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _add_plane(size: Vector2, at: Vector3, color: Color) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) / 2.0
