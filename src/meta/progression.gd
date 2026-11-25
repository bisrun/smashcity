class_name Progression
extends RefCounted
## 판 밖의 성장 규칙. 경험치와 레벨, 코인, 출발 아이템과 꾸밈의 목록을 assets/progression.json 에서 읽는다.
##
## 레벨과 꾸밈은 판정 값을 바꾸지 않는다. 판정에 들어가는 것은 출발 아이템 하나뿐이다.

const PATH := "res://assets/progression.json"

var data := {}


func _init(path: String = PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
	else:
		push_error("성장 파일을 읽을 수 없다: %s" % path)


## 레벨 n 에서 n+1 로 가는 데 드는 경험치는 level_step × n 이다. 갈수록 조금씩 멀어진다.
func level_of(xp: int) -> int:
	var level := 1
	var left := xp
	while left >= need(level):
		left -= need(level)
		level += 1
	return level


func need(level: int) -> int:
	return int(data["level_step"]) * level


## 지금 레벨 안에서 쌓은 경험치.
func into_level(xp: int) -> int:
	var left := xp
	var level := 1
	while left >= need(level):
		left -= need(level)
		level += 1
	return left


## 한 판이 주는 것. {xp, coins}
func reward(cleared: bool, first_clear: bool, cells: int) -> Dictionary:
	var x: Dictionary = data["xp"]
	var c: Dictionary = data["coins"]
	return {
		"xp": int(x["play"]) + int(x["per_cell"]) * cells + (int(x["clear"]) if cleared else 0),
		"coins": int(c["play"]) + (int(c["clear"]) if cleared else 0) + (int(c["first_clear"]) if first_clear else 0),
	}


func gear(id: String) -> Dictionary:
	for g: Dictionary in data["gear"]:
		if g["id"] == id:
			return g
	return {}


## kind: "bus" 또는 "trail". 없는 id 면 첫 번째(기본)를 돌려준다.
func cosmetic(kind: String, id: String) -> Dictionary:
	for c: Dictionary in data[kind]:
		if c["id"] == id:
			return c
	return data[kind][0]
