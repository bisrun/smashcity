class_name BoardView
extends Node3D
## 스테이지 데이터를 2.5D 판으로 그린다. 판정에는 관여하지 않는다.
##
## 지도 좌표 (x, y)는 장면 좌표 (x - W/2, 높이, H/2 - y)로 옮긴다.
##
## 벽돌(셀) 하나는 두툼한 받침 블록 하나다. 이웃과 틈을 두고 떨어져 있고, 두께와 옆면 색이 남은 HP를 말한다.
## 블록 위에는 작은 건물을 여럿 늘어놓지 않고 큼직한 것을 몇 개만 올린다(docs/11_art_audio.md).
## 건물은 흰 벽에 유리 띠를 두른 미니어처 모형처럼 그린다.
## 블록 위의 것들은 지도의 건물을 그대로 옮긴 것이 아니라 그 구획의 성격에 맞춰 지어낸 것이다.
## 넓은 건물과 랜드마크만 실제 윤곽을 쓴다.

## 강가 나무가 서는 높이
const SLAB_HEIGHT := 1.0
const FLOOR_HEIGHT := 3.2
const LANDMARK_HEIGHT := 555.0
## 이 높이를 넘는 부분은 눌러 그린다. 높은 건물이 통로를 가리지 않게 하려는 것.
const SOFT_LIMIT := 60.0
const SOFT_RATIO := 0.45
## 이웃 블록과의 틈을 만들려고 셀 윤곽을 안으로 들이는 거리 (m)
const GAP := 5.0
## 블록 윗면 테두리의 폭 (m)
const RIM := 6.0
## 블록 두께: 바닥 두께 + 남은 단계 x 단 높이
const BLOCK_BASE := 6.0
const BLOCK_STEP := 11.0
const LAWN_LIFT := 1.4
## 실제 윤곽을 그대로 쓰는 건물의 최소 넓이 (㎡)
const KEEP_REAL_AREA := 1200.0
## 블록 위에 큼직한 것을 놓는 자리의 간격 (m)
const SLOT_SPACING := 58.0
const SLOT_HALF := 20.0
const SHORE_SPACING := 40.0

const ROAD := Color("F7ECD8")
const WATER := Color("63CFE0")
## 남은 단계별 블록 옆면 색. 1단계(곧 부서짐)부터 4단계까지.
const TIER_SIDE: Array[Color] = [Color("F4D9A8"), Color("F2B880"), Color("E88F6E"), Color("B9789E")]
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
var _tops: Array[Node3D] = []


## near_bank_y 는 화면 아래쪽 강가가 시작되는 y다. 공을 잃는 선과 맞춘다.
func build(stage: StageData, river_width: float, near_bank_y: float) -> void:
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

	var boxes: Array[Rect2] = []
	for c in stage.cells:
		boxes.append(_bounds(c["points"]))
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
		var tier := _tier(cell["hp"], cell["hp"], cell["landmark"])
		var plinth := MeshInstance3D.new()
		plinth.material_override = _material
		node.add_child(plinth)
		_plinths.append(plinth)
		plinth.mesh = _plinth_mesh(ci, tier)
		var st := _begin()
		_furnish(st, ci, cell, lawn, real[ci], stage)
		var tops := _mesh_child(node, st, true)
		tops.position.y = _block_height(tier) + LAWN_LIFT
		_tops.append(tops)
	_add_props(stage)


## 셀이 맞았을 때. 블록이 한 단 낮아지고 옆면 색이 바뀐다.
func show_hit(cell: int, hp: int, max_hp: int) -> void:
	var node := cell_nodes[cell]
	if node == null:
		return
	var tier := _tier(hp, max_hp, _is_landmark[cell])
	_plinths[cell].mesh = _plinth_mesh(cell, tier)
	var tween := node.create_tween()
	tween.tween_property(_tops[cell], "position:y", _block_height(tier) + LAWN_LIFT, 0.14)
	tween.parallel().tween_property(node, "scale:y", 0.88, 0.05)
	tween.tween_property(node, "scale:y", 1.0, 0.12)


## 셀이 부서졌을 때. 납작하게 꺼뜨린 뒤 없앤다.
func show_destroyed(cell: int) -> void:
	var node := cell_nodes[cell]
	if node == null:
		return
	cell_nodes[cell] = null
	var tween := node.create_tween()
	tween.tween_property(node, "scale:y", 0.02, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)


## 건물이 화면에 그려지는 높이.
static func display_height(levels: int, landmark: bool) -> float:
	var h := LANDMARK_HEIGHT if landmark else levels * FLOOR_HEIGHT
	if h > SOFT_LIMIT:
		h = SOFT_LIMIT + (h - SOFT_LIMIT) * SOFT_RATIO
	return maxf(9.0, h)


## 남은 HP를 1~4단계로 옮긴다. 보통 셀은 HP가 곧 단계이고, HP가 큰 랜드마크는 4단계로 나눈다.
static func _tier(hp: int, max_hp: int, landmark: bool) -> int:
	if landmark and max_hp > 4:
		return clampi(ceili(hp * 4.0 / max_hp), 1, 4)
	return clampi(hp, 1, 4)


static func _block_height(tier: int) -> float:
	return BLOCK_BASE + tier * BLOCK_STEP


## 블록 몸통. 옆면은 단계 색, 윗면 테두리는 그보다 밝은 색, 가운데는 잔디.
func _plinth_mesh(ci: int, tier: int) -> ArrayMesh:
	var st := _begin()
	var side := TIER_SIDE[tier - 1]
	var top_y := _block_height(tier)
	_add_prism(st, _outline[ci], 0.0, top_y, side.lightened(0.35), side, 0.0)
	var lawn := LANDMARK_LOT if _is_landmark[ci] else GRASS[ci % GRASS.size()]
	_add_prism(st, _lawn[ci], top_y, top_y + LAWN_LIFT, lawn, lawn.darkened(0.12), 0.0)
	st.generate_normals()
	return st.commit()


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


## 블록 위를 꾸민다. 높이는 블록 윗면을 0으로 한다.
##
## 넓은 건물과 랜드마크는 실제 윤곽대로 세운다. 나머지 자리에는 구획의 HP에 맞는 큼직한 건물을 몇 채 놓는다.
## HP 1은 집이나 나무 무리, 2는 낮은 건물이나 돔, 3은 유리 빌딩, 4는 층층이 좁아지는 고층이다.
## 건물은 흰 벽에 층마다 유리 띠를 두른 미니어처 모형처럼 그린다.
func _furnish(st: SurfaceTool, ci: int, cell: Dictionary, lawn: PackedVector2Array, real: Array, stage: StageData) -> void:
	var kept: Array[Dictionary] = []
	var tower := {}
	for b: Dictionary in real:
		if b["landmark"]:
			kept.append(b)
			if tower.is_empty() or b["area"] > tower["area"]:
				tower = b
		elif b["area"] >= KEEP_REAL_AREA:
			var h := display_height(b["levels"], false)
			_add_bands(st, b["points"], 0.0, h, clampi(int(h / 6.5), 2, 12), WHITE_WALL, GLASS[b["seed"] % GLASS.size()], ROOFS[b["seed"] % ROOFS.size()], 1.0)
			kept.append(b)
			object_count += 1
	if not tower.is_empty():
		for b: Dictionary in real:
			if b["landmark"] and b["seed"] != tower["seed"]:
				_add_bands(st, b["points"], 0.0, 16.0, 2, WHITE_WALL, GLASS[0], ROOF_WHITE, 1.0)
		# 랜드마크: 위로 갈수록 좁아지는 유리 탑
		_add_bands(st, tower["points"], 0.0, display_height(tower["levels"], true), 18, GLASS_FRAME, GLASS_DEEP, GOLD, 0.36)
	if cell["landmark"]:
		return

	var axis := _longest_edge(cell["points"])
	var side := Vector2(-axis.y, axis.x)
	var origin := _center(lawn)
	var box := _bounds(lawn)
	var reach := int(ceil(box.size.length() / 2.0 / SLOT_SPACING))
	var slots: Array[Vector2] = []
	for ix in range(-reach, reach + 1):
		for iy in range(-reach, reach + 1):
			var at := origin + axis * (ix * SLOT_SPACING) + side * (iy * SLOT_SPACING)
			if _slot_fits(at, axis, side, lawn, kept):
				slots.append(at)
	slots.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da := a.distance_squared_to(origin)
		var db := b.distance_squared_to(origin)
		return da < db if not is_equal_approx(da, db) else (a.x < b.x if a.x != b.x else a.y < b.y))
	var small := 1.0
	if slots.is_empty() and kept.is_empty() and Geometry2D.is_point_in_polygon(origin, lawn):
		slots.append(origin)  # 좁은 구획에는 작게 하나만 놓는다
		small = 0.55
	var want := clampi(int(_area(cell["points"]) / 7000.0), 1, 3)
	var hp: int = cell["hp"]
	for si in slots.size():
		var h := _hash(ci, si, 17)
		var at := slots[si]
		if si < want:
			if hp <= 1 and real.is_empty():
				_add_clump(st, at, h, small)
			else:
				_add_house(st, at, axis, side, hp, h, small)
			object_count += 1
		elif h % 2 == 0:
			_add_tree(st, {"at": at, "round": (h >> 3) % 3 != 0, "size": 1.3 + ((h >> 6) % 5) * 0.1, "base": 0.0,
				"color": (LEAF if (h >> 3) % 3 != 0 else PINE)[(h >> 10) % 3]})
	# 호숫가에 닿은 구획에는 벚나무를 두른다
	for lake in stage.lakes:
		var ring: PackedVector2Array = lake["points"]
		var middle := _center(ring)
		var acc := 0.0
		for i in ring.size():
			var a := ring[i]
			acc += a.distance_to(ring[(i + 1) % ring.size()])
			while acc > SHORE_SPACING:
				acc -= SHORE_SPACING
				var at := a + (a - middle).normalized() * 22.0
				if Geometry2D.is_point_in_polygon(at, lawn) and _clear_of(at, 16.0, slots, want, kept):
					var h := _hash(i, int(a.x), int(a.y))
					_add_tree(st, {"at": at, "round": true, "size": 1.2 + (h % 4) * 0.1, "base": 0.0, "color": BLOSSOM[(h >> 4) % 3]})


func _slot_fits(at: Vector2, axis: Vector2, side: Vector2, lawn: PackedVector2Array, kept: Array[Dictionary]) -> bool:
	for c: Vector2 in [at + (axis + side) * SLOT_HALF, at + (axis - side) * SLOT_HALF, at - (axis + side) * SLOT_HALF, at - (axis - side) * SLOT_HALF]:
		if not Geometry2D.is_point_in_polygon(c, lawn):
			return false
		for b in kept:
			if Geometry2D.is_point_in_polygon(c, b["points"]):
				return false
	for b in kept:
		if Geometry2D.is_point_in_polygon(at, b["points"]) or at.distance_to(b["center"]) < 30.0:
			return false
	return true


func _clear_of(at: Vector2, margin: float, slots: Array[Vector2], used: int, kept: Array[Dictionary]) -> bool:
	for i in mini(used, slots.size()):
		if at.distance_to(slots[i]) < SLOT_HALF + margin:
			return false
	for b in kept:
		if Geometry2D.is_point_in_polygon(at, b["points"]):
			return false
	return true


## 구획의 HP에 맞는 건물 하나. 블록의 긴 변과 나란히 선다.
func _add_house(st: SurfaceTool, at: Vector2, axis: Vector2, side: Vector2, hp: int, h: int, size: float) -> void:
	var glass := GLASS[(h >> 5) % GLASS.size()]
	if hp <= 1:
		# 집: 파스텔 벽에 색 지붕
		_add_prism(st, _rect(at, axis, side, 17.0 * size, 13.0 * size), 0.0, 15.0 * size, PITCHED[(h >> 5) % PITCHED.size()], WALLS[(h >> 2) % WALLS.size()], 11.0 * size)
	elif hp == 2:
		if (h >> 8) % 4 == 0:
			# 돔: 낮은 원통 위에 유리 지붕
			var r := 19.0 * size
			_add_lathe(st, at, [Vector2(r, 0.0), Vector2(r, 11.0 * size), Vector2(r * 0.92, 13.0 * size), Vector2(r * 0.8, 22.0 * size), Vector2(r * 0.5, 29.0 * size), Vector2(0.0, 32.0 * size)],
				12, [WHITE_WALL, ROOF_WHITE, DOME, DOME.lightened(0.18), DOME.lightened(0.32)])
		else:
			var warm := (h >> 11) % 4 == 0
			_add_bands(st, _rect(at, axis, side, 19.0 * size, 14.0 * size), 0.0, 31.0 * size, 5, WARM if warm else WHITE_WALL, WARM_WINDOW if warm else glass, ROOFS[(h >> 14) % ROOFS.size()], 1.0)
			_add_prism(st, _rect(at - axis * 6.0 * size, axis, side, 6.0 * size, 5.0 * size), 31.0 * size, 36.0 * size, ROOF_WHITE, glass, 0.0)
	elif hp == 3:
		# 유리 빌딩
		_add_bands(st, _rect(at, axis, side, 17.0 * size, 13.0 * size), 0.0, 58.0 * size, 10, WHITE_WALL, glass, ROOFS[(h >> 14) % ROOFS.size()], 1.0)
		_add_prism(st, _rect(at, axis, side, 7.0 * size, 5.0 * size), 58.0 * size, 64.0 * size, ROOF_WHITE, glass.darkened(0.1), 0.0)
	else:
		# 고층: 세 단으로 좁아진다
		_add_bands(st, _rect(at, axis, side, 15.0 * size, 15.0 * size), 0.0, 44.0 * size, 8, GLASS_FRAME, glass, glass.lightened(0.35), 1.0)
		_add_bands(st, _rect(at, axis, side, 11.0 * size, 11.0 * size), 44.0 * size, 76.0 * size, 6, GLASS_FRAME, glass, glass.lightened(0.35), 1.0)
		_add_bands(st, _rect(at, axis, side, 7.0 * size, 7.0 * size), 76.0 * size, 98.0 * size, 4, GLASS_FRAME, glass, glass.lightened(0.35), 1.0)
		_add_prism(st, _rect(at, axis, side, 1.6 * size, 1.6 * size), 98.0 * size, 114.0 * size, ROOF_WHITE, ROOF_WHITE, 0.0)


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
func _add_bands(st: SurfaceTool, pts: PackedVector2Array, y0: float, y1: float, floors: int, wall: Color, glass: Color, roof: Color, taper: float) -> void:
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
		var color := wall if i % 2 == 0 else glass
		if i == 0:
			color = wall.darkened(0.1)  # 바닥에 닿는 띠는 살짝 어둡게
		st.set_color(color)
		for k in n:
			var a := center + (pts[k] - center) * s0
			var b := center + (pts[(k + 1) % n] - center) * s0
			var a_up := center + (pts[k] - center) * s1
			var b_up := center + (pts[(k + 1) % n] - center) * s1
			st.add_vertex(_at(a, levels[i]))
			st.add_vertex(_at(b, levels[i]))
			st.add_vertex(_at(b_up, levels[i + 1]))
			st.add_vertex(_at(a, levels[i]))
			st.add_vertex(_at(b_up, levels[i + 1]))
			st.add_vertex(_at(a_up, levels[i + 1]))
	st.set_color(roof)
	var top := PackedVector2Array()
	for p in pts:
		top.append(center + (p - center) * taper)
	for idx in Geometry2D.triangulate_polygon(top):
		st.add_vertex(_at(top[idx], y1))


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


## 나무 한 그루. 줄기 위에 잎 덩어리를 두 겹 얹는다. 둥근 나무는 도톰하게, 뾰족한 나무는 원뿔로.
func _add_tree(st: SurfaceTool, t: Dictionary) -> void:
	var at: Vector2 = t["at"]
	var s: float = t["size"]
	var base: float = t.get("base", SLAB_HEIGHT)
	var leaf: Color = t["color"]
	_add_lathe(st, at, [Vector2(2.3 * s, base), Vector2(2.0 * s, base + 8.0 * s)], 5, [TRUNK])
	if t["round"]:
		_add_lathe(st, at, [Vector2(0.0, base + 5.0 * s), Vector2(10.5 * s, base + 14.0 * s), Vector2(7.5 * s, base + 22.0 * s), Vector2(0.0, base + 26.0 * s)],
			7, [leaf.darkened(0.1), leaf, leaf.lightened(0.14)])
	else:
		_add_lathe(st, at, [Vector2(9.5 * s, base + 4.0 * s), Vector2(0.0, base + 22.0 * s)], 6, [leaf])
		_add_lathe(st, at, [Vector2(6.5 * s, base + 14.0 * s), Vector2(0.0, base + 30.0 * s)], 6, [leaf.lightened(0.12)])


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

	# 열기구
	var spots: Array[Vector2] = [Vector2(_w * 0.2, _h * 0.6), Vector2(_w * 0.8, _h * 0.27), Vector2(_w * 0.27, _h * 0.82)]
	var hues: Array[Color] = [Color("FF8A5B"), Color("6FB8FF"), Color("FFD24A")]
	for i in spots.size():
		var base := _at(spots[i], 0.0)
		_prim(self, _sphere(30.0), hues[i], base + Vector3(0, 170, 0)).scale.y = 1.18
		var neck := CylinderMesh.new()
		neck.top_radius = 17.0
		neck.bottom_radius = 7.0
		neck.height = 18.0
		_prim(self, neck, Color.WHITE, base + Vector3(0, 138, 0))
		var basket := BoxMesh.new()
		basket.size = Vector3(12, 10, 12)
		_prim(self, basket, Color("A8744B"), base + Vector3(0, 120, 0))

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
