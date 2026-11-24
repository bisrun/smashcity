class_name ModelLibrary
extends RefCounted
## 밖에서 가져온 3D 모델을 판의 메시에 구워 넣을 수 있는 꼴로 읽어 둔다.
##
## 모델은 Kenney 의 Nature Kit 과 City Kit (Commercial) 에서 가져왔다. 둘 다 CC0 다(assets/models/kenney/*/License.txt).
##
## 모델을 노드로 하나하나 세우지 않는다. 삼각형과 색을 꺼내 두었다가 블록의 메시에 함께 넣는다.
## 그래야 블록이 주저앉거나 부서질 때 함께 움직이고, 그리는 횟수도 늘지 않는다.
## 색은 재질의 색이나 색상표 그림에서 꼭짓점 색으로 옮긴다.

const DIR := "res://assets/models/kenney/"

## 잎이 둥근 나무, 뾰족한 나무, 덤불, 꽃, 바위, 파라솔
const ROUND_TREES: Array[String] = ["nature/tree_default", "nature/tree_oak", "nature/tree_fat", "nature/tree_detailed"]
const POINTED_TREES: Array[String] = ["nature/tree_cone", "nature/tree_pineRoundA", "nature/tree_pineRoundC"]
const BUSHES: Array[String] = ["nature/plant_bushLarge", "nature/plant_bush"]
const FLOWERS: Array[String] = ["nature/flower_redA", "nature/flower_yellowA", "nature/flower_purpleA"]
const ROCKS: Array[String] = ["nature/rock_largeA"]
const PARASOLS: Array[String] = ["city/detail-parasol-a", "city/detail-parasol-b"]

## 이름 → {points: PackedVector3Array, colors: PackedColorArray}. 못 읽은 모델은 빈 사전.
## points 는 삼각형 목록이다. 바닥 가운데가 원점이고 높이가 1이 되게 맞춰져 있다.
static var _cache := {}


static func get_model(name: String) -> Dictionary:
	if not _cache.has(name):
		_cache[name] = _load(DIR + name + ".glb")
	return _cache[name]


## 목록에서 seed 에 따라 하나를 고른다. 읽을 수 있는 것이 없으면 빈 사전.
static func pick(names: Array[String], seed: int) -> Dictionary:
	for i in names.size():
		var m := get_model(names[(seed + i) % names.size()])
		if not m.is_empty():
			return m
	return {}


static func _load(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		return {}
	var root := scene.instantiate()
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	_collect(root, Transform3D.IDENTITY, points, colors)
	root.free()
	if points.is_empty():
		return {}
	# 바닥 가운데를 원점으로, 높이를 1로 맞춘다
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var height := maxf(hi.y - lo.y, 0.0001)
	var shift := Vector3((lo.x + hi.x) / 2.0, lo.y, (lo.z + hi.z) / 2.0)
	for i in points.size():
		points[i] = (points[i] - shift) / height
	return {"points": points, "colors": colors}


static func _collect(node: Node, parent: Transform3D, points: PackedVector3Array, colors: PackedColorArray) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tint := Color.WHITE
			var image: Image = null
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null:
				tint = mat.albedo_color
				if mat.albedo_texture != null:
					image = mat.albedo_texture.get_image()
					if image != null and image.is_compressed():
						image.decompress()
			var count := index.size() if not index.is_empty() else verts.size()
			for k in count:
				var vi := index[k] if not index.is_empty() else k
				points.append(xf * verts[vi])
				var c := tint
				if image != null and vi < uvs.size() and not image.is_empty():
					var uv := uvs[vi]
					var px := clampi(int(fposmod(uv.x, 1.0) * image.get_width()), 0, image.get_width() - 1)
					var py := clampi(int(fposmod(uv.y, 1.0) * image.get_height()), 0, image.get_height() - 1)
					c = image.get_pixel(px, py) * tint
				colors.append(c)
	for child in node.get_children():
		_collect(child, xf, points, colors)
