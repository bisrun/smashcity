class_name StageData
extends RefCounted
## 스테이지 파일(map.json)을 읽어 담아 두는 순수 데이터 객체.
##
## 장면 노드에 의존하지 않는다. 판정(sim)과 화면(render)이 함께 쓴다.
## 좌표는 지도 좌표다. x는 화면 오른쪽, y는 기준선에서 화면 위쪽으로 가는 거리(m).

var width: float = 0.0
var height: float = 0.0
var ball_diameter: float = 0.0

## 각 원소: {points: PackedVector2Array, hp: int, landmark: bool, empty: bool}
var cells: Array[Dictionary] = []
## 각 원소: {points: PackedVector2Array, levels: int, landmark: bool}
var buildings: Array[Dictionary] = []
## 각 원소: {points: PackedVector2Array, road_class: String, real_width: float}
var roads: Array[Dictionary] = []
## 각 원소: {points: PackedVector2Array}  (섬은 구멍으로 빠져 있지 않고 셀이 그 위를 덮는다)
var lakes: Array[Dictionary] = []
## 각 원소: {position: Vector2, kind: String, name: String}
var pois: Array[Dictionary] = []


static func load_file(path: String) -> StageData:
	if not FileAccess.file_exists(path):
		push_error("스테이지 파일이 없다: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("스테이지 파일을 읽을 수 없다: %s" % path)
		return null
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> StageData:
	var s := StageData.new()
	s.width = float(d.get("W", 0))
	s.height = float(d.get("H", 0))
	s.ball_diameter = float(d.get("ball", 0))
	for c: Dictionary in d.get("cells", []):
		s.cells.append({
			"points": _points(c["p"]),
			"hp": int(c.get("hp", 1)),
			"landmark": int(c.get("lm", 0)) == 1,
			"empty": int(c.get("e", 0)) == 1,
		})
	for b: Dictionary in d.get("buildings", []):
		s.buildings.append({
			"points": _points(b["p"]),
			"levels": int(b.get("lv", 1)),
			"landmark": int(b.get("lm", 0)) == 1,
		})
	for r: Dictionary in d.get("roads", []):
		s.roads.append({
			"points": _points(r["l"]),
			"road_class": String(r.get("c", "")),
			"real_width": float(r.get("w", 0)),
		})
	for l: Dictionary in d.get("lake", []):
		s.lakes.append({"points": _points(l["p"])})
	for p: Dictionary in d.get("pois", []):
		s.pois.append({
			"position": Vector2(float(p["x"]), float(p["y"])),
			"kind": String(p.get("k", "")),
			"name": String(p.get("n", "")),
		})
	return s


## 지정한 등급의 도로 꼭짓점 중 목표 지점에 가장 가까운 것을 돌려준다. 없으면 목표 지점 그대로.
func nearest_road_point(classes: PackedStringArray, target: Vector2) -> Vector2:
	var best := target
	var best_d := INF
	for r in roads:
		if not classes.has(r["road_class"]):
			continue
		for pt: Vector2 in r["points"]:
			var d := pt.distance_squared_to(target)
			if d < best_d:
				best_d = d
				best = pt
	return best


static func _points(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	@warning_ignore("integer_division")
	out.resize(flat.size() / 2)
	for i in out.size():
		out[i] = Vector2(float(flat[2 * i]), float(flat[2 * i + 1]))
	return out
