class_name BoardView
extends Node3D
## 스테이지 데이터를 2.5D 판으로 그린다. 판정에는 관여하지 않는다.
##
## 지도 좌표 (x, y)는 장면 좌표 (x - W/2, 높이, H/2 - y)로 옮긴다.
## 셀 하나가 노드 하나다. 셀의 바닥, 그 위의 건물, 나무가 한 메시에 들어 있어 함께 주저앉고 함께 사라진다.
## 색과 꾸밈은 화면 샘플의 파스텔 스타일을 옮긴 초기값이다(docs/11_art_audio.md).

const SLAB_HEIGHT := 7.0
const FLOOR_HEIGHT := 3.2
const LANDMARK_HEIGHT := 555.0
## 이 높이를 넘는 부분은 눌러 그린다. 높은 건물이 통로를 가리지 않게 하려는 것.
const SOFT_LIMIT := 60.0
const SOFT_RATIO := 0.45
## 건물이 차지한 넓이가 이 비율에 못 미치는 셀은 숲으로 채운다.
const FOREST_BELOW_COVERAGE := 0.14
const FOREST_SPACING := 21.0
const PARK_SPACING := 24.0
const SHORE_SPACING := 24.0
## HP가 바닥났을 때 셀이 눌리는 정도. 0이면 완전히 납작해진다.
const SINK_FLOOR := 0.4

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
var cell_nodes: Array[MeshInstance3D] = []
## 심은 나무의 수. build() 뒤에 읽는다.
var tree_count := 0

var _w := 0.0
var _h := 0.0
var _material: StandardMaterial3D


## near_bank_y 는 화면 아래쪽 강가가 시작되는 y다. 공이 빠진 것으로 치는 선과 맞춘다.
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
	var trees := _plan_trees(stage, boxes, real)
	tree_count = 0
	cell_nodes.clear()
	for ci in stage.cells.size():
		var cell := stage.cells[ci]
		var st := _begin()
		var top := LANDMARK_LOT if cell["landmark"] else GRASS[ci % GRASS.size()]
		_add_prism(st, cell["points"], 0.0, SLAB_HEIGHT, top, EARTH, 0.0)
		for b: Dictionary in real[ci]:
			_add_building(st, b)
		for t: Dictionary in trees[ci]:
			_add_tree(st, t)
			tree_count += 1
		cell_nodes.append(_add_mesh(st, true))
	_add_props(stage, boxes)


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


## 셀이 맞았을 때. 남은 HP만큼 주저앉힌다.
func show_hit(cell: int, hp: int, max_hp: int) -> void:
	var node := cell_nodes[cell]
	if node == null:
		return
	var target := lerpf(SINK_FLOOR, 1.0, float(hp) / float(max_hp))
	var tween := node.create_tween()
	tween.tween_property(node, "scale:y", target * 0.9, 0.05)
	tween.tween_property(node, "scale:y", target, 0.12)


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


## 셀마다 심을 나무를 정한다. 건물이 드문 셀은 숲, 공원은 둥근 나무, 호숫가는 벚나무.
func _plan_trees(stage: StageData, boxes: Array[Rect2], real: Array[Array]) -> Array[Array]:
	var out: Array[Array] = []
	out.resize(stage.cells.size())
	for i in out.size():
		out[i] = []
	for ci in stage.cells.size():
		var cell := stage.cells[ci]
		if cell["landmark"]:
			continue
		var pts: PackedVector2Array = cell["points"]
		var built := 0.0
		for b: Dictionary in real[ci]:
			built += b["area"]
		if built >= _area(pts) * FOREST_BELOW_COVERAGE:
			continue
		var origin := boxes[ci].get_center()
		var reach := int(ceil(boxes[ci].size.length() / 2.0 / FOREST_SPACING))
		for ix in range(-reach, reach + 1):
			for iy in range(-reach, reach + 1):
				var h := _hash(ci, ix, iy)
				var jitter := Vector2((h % 13) - 6.0, ((h >> 4) % 13) - 6.0)
				var at := origin + Vector2(ix, iy) * FOREST_SPACING + jitter
				if _tree_fits(at, pts, real[ci]):
					var round_tree := (h >> 9) % 7 == 0
					out[ci].append({"at": at, "round": round_tree, "size": 0.75 + ((h >> 12) % 7) * 0.1,
						"color": (LEAF if round_tree else PINE)[(h >> 16) % 3]})
	for pi in stage.parks.size():
		var park := stage.parks[pi]
		var box := _bounds(park)
		var nx := int(box.size.x / PARK_SPACING) + 1
		var ny := int(box.size.y / PARK_SPACING) + 1
		for ix in nx:
			for iy in ny:
				var h := _hash(pi + 7000, ix, iy)
				var at := box.position + Vector2(ix + 0.5, iy + 0.5) * PARK_SPACING + Vector2((h % 11) - 5.0, ((h >> 4) % 11) - 5.0)
				if not Geometry2D.is_point_in_polygon(at, park):
					continue
				var ci := _cell_at(stage, boxes, at)
				if ci >= 0 and _tree_fits(at, stage.cells[ci]["points"], real[ci]):
					out[ci].append({"at": at, "round": true, "size": 0.8 + ((h >> 8) % 5) * 0.1, "color": LEAF[(h >> 12) % 3]})
	for lake in stage.lakes:
		var ring: PackedVector2Array = lake["points"]
		var middle := _center(ring)
		var acc := 0.0
		for i in ring.size():
			var a := ring[i]
			acc += a.distance_to(ring[(i + 1) % ring.size()])
			while acc > SHORE_SPACING:
				acc -= SHORE_SPACING
				var at := a + (a - middle).normalized() * 15.0
				var ci := _cell_at(stage, boxes, at)
				if ci >= 0 and _tree_fits(at, stage.cells[ci]["points"], real[ci]):
					var h := _hash(i, int(a.x), int(a.y))
					out[ci].append({"at": at, "round": true, "size": 0.8 + (h % 5) * 0.1, "color": BLOSSOM[(h >> 4) % 3]})
	return out


func _tree_fits(at: Vector2, cell_pts: PackedVector2Array, real: Array) -> bool:
	for off: Vector2 in [Vector2(7, 0), Vector2(-7, 0), Vector2(0, 7), Vector2(0, -7)]:
		if not Geometry2D.is_point_in_polygon(at + off, cell_pts):
			return false
	for b: Dictionary in real:
		if at.distance_to(b["center"]) < 10.0 or Geometry2D.is_point_in_polygon(at, b["points"]):
			return false
	return true


func _add_building(st: SurfaceTool, b: Dictionary) -> void:
	var pts: PackedVector2Array = b["points"]
	var levels: int = b["levels"]
	var i: int = b["seed"]
	var top_y := SLAB_HEIGHT + display_height(levels, b["landmark"])
	if b["landmark"]:
		_add_prism(st, pts, SLAB_HEIGHT, top_y, GOLD, GOLD_WALL, 0.0)
		return
	var wall := WALLS[(i * 7) % WALLS.size()]
	if levels <= 4 and pts.size() <= 8 and b["area"] < 900.0:
		_add_prism(st, pts, SLAB_HEIGHT, top_y, PITCHED[(i * 13) % PITCHED.size()], wall, 7.0)
		return
	var band := FLAT_LOW if levels <= 10 else (FLAT_MID if levels <= 25 else FLAT_HIGH)
	_add_prism(st, pts, SLAB_HEIGHT, top_y, band[(i * 5) % band.size()], wall, 0.0)


## 나무 한 그루. 뾰족한 나무는 원뿔, 둥근 나무는 위아래로 맞붙인 원뿔 두 개.
func _add_tree(st: SurfaceTool, t: Dictionary) -> void:
	var at: Vector2 = t["at"]
	var s: float = t["size"]
	st.set_color(t["color"])
	var sides := 6
	var r := (10.0 if t["round"] else 9.0) * s
	var ring_y := SLAB_HEIGHT + (9.0 * s if t["round"] else 1.0)
	var top := SLAB_HEIGHT + (22.0 if t["round"] else 25.0) * s
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := _at(at + Vector2(cos(a0), sin(a0)) * r, ring_y)
		var p1 := _at(at + Vector2(cos(a1), sin(a1)) * r, ring_y)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(_at(at, top))
		if t["round"]:
			st.add_vertex(p1)
			st.add_vertex(p0)
			st.add_vertex(_at(at, SLAB_HEIGHT))


## 상상으로 더한 구조물. 지도에는 없는 것들이다(docs/05_items.md 의 상상 아이템).
func _add_props(stage: StageData, boxes: Array[Rect2]) -> void:
	# 대관람차: 호수 안의 섬에 세운다. 섬 셀에 붙여 셀과 함께 사라지게 한다.
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
		cell_nodes[island].add_child(wheel)
		wheel.position = _at(_center(stage.cells[island]["points"]), SLAB_HEIGHT)
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
		_prim(self, _sphere(27.0), hues[i], base + Vector3(0, 150, 0)).scale.y = 1.18
		var neck := CylinderMesh.new()
		neck.top_radius = 15.0
		neck.bottom_radius = 6.0
		neck.height = 16.0
		_prim(self, neck, Color.WHITE, base + Vector3(0, 121, 0))
		var basket := BoxMesh.new()
		basket.size = Vector3(11, 9, 11)
		_prim(self, basket, Color("A8744B"), base + Vector3(0, 104, 0))

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

	# 랜드마크 꼭대기의 빛. 랜드마크가 선 셀에 붙인다.
	for ci in stage.cells.size():
		if not stage.cells[ci]["landmark"]:
			continue
		for b in stage.buildings:
			if b["landmark"]:
				var top := SLAB_HEIGHT + display_height(b["levels"], true) + 20.0
				_prim(cell_nodes[ci], _sphere(17.0), Color("FFF6C2"), _at(_center(b["points"]), top), true)
				break
		break


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
