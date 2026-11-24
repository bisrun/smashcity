class_name SaveData
extends RefCounted
## 기기에 남기는 기록. 스테이지별 점수 순위와 클리어한 스테이지를 담는다.
##
## 순위는 이 기기 안에서만 매긴다. 다른 사람과 겨루는 온라인 순위는 서버가 있어야 하며 아직 없다.

const DEFAULT_PATH := "user://save.json"
## 스테이지마다 남겨 두는 기록의 수
const KEEP := 20

var path := DEFAULT_PATH
## 스테이지 ID → 기록 목록. 점수가 높은 순서다. 각 기록: {score, cleared, seconds, at}
var scores := {}
## 클리어한 스테이지 ID들
var cleared: Array[String] = []


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	load_file()


func load_file() -> void:
	scores = {}
	cleared = []
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for id: String in parsed.get("scores", {}):
		scores[id] = parsed["scores"][id]
	for id: String in parsed.get("cleared", []):
		cleared.append(id)


func save_file() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("기록을 저장하지 못했다: %s" % path)
		return
	f.store_string(JSON.stringify({"scores": scores, "cleared": cleared}, "  "))


## 한 판의 결과를 남기고 그 판의 순위(1부터)를 돌려준다. 남겨 두는 수 밖으로 밀려났으면 0.
func add_result(stage_id: String, score: int, was_cleared: bool, seconds: int, at: String) -> int:
	var list: Array = scores.get(stage_id, [])
	var rank := insert(list, {"score": score, "cleared": was_cleared, "seconds": seconds, "at": at}, KEEP)
	scores[stage_id] = list
	if was_cleared and not cleared.has(stage_id):
		cleared.append(stage_id)
	save_file()
	return rank


## 그 스테이지의 위에서부터 count 개의 기록.
func top(stage_id: String, count: int) -> Array:
	var list: Array = scores.get(stage_id, [])
	return list.slice(0, count)


func best(stage_id: String) -> int:
	var list: Array = scores.get(stage_id, [])
	return int(list[0]["score"]) if not list.is_empty() else 0


## 점수가 높은 순서를 지키며 기록을 끼워 넣는다. 같은 점수면 먼저 낸 기록이 위다.
## 끼워 넣은 자리의 순위(1부터)를 돌려준다. limit 밖으로 밀려났으면 0.
static func insert(list: Array, entry: Dictionary, limit: int) -> int:
	var at := list.size()
	for i in list.size():
		if int(entry["score"]) > int(list[i]["score"]):
			at = i
			break
	list.insert(at, entry)
	while list.size() > limit:
		list.pop_back()
	return at + 1 if at < limit else 0
