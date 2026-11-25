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
## 누구의 기록인가. "" 이면 아직 로그인 화면을 지나지 않았다. 지금은 "guest" 뿐이다.
## TODO: 구글 계정(Google Play 게임 서비스) 연결. docs/17_account_save.md
var account := ""
## 캐릭터. name: 이름, face: 얼굴 번호, xp: 경험치, coins: 코인, bus/trail: 고른 꾸밈,
## gear: 출발 아이템 ID → 가진 수, stats: 누적 기록 {games, clears, cells, best_combo, seconds}
var profile := {}

const PROFILE_DEFAULTS := {"name": "", "face": 0, "xp": 0, "coins": 0, "bus": "blue", "trail": "none", "gear": {}, "stats": {}}
const NAME_MAX := 10


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	load_file()


func load_file() -> void:
	scores = {}
	cleared = []
	account = ""
	profile = PROFILE_DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for id: String in parsed.get("scores", {}):
		scores[id] = parsed["scores"][id]
	for id: String in parsed.get("cleared", []):
		cleared.append(id)
	account = String(parsed.get("account", ""))
	var saved: Variant = parsed.get("profile", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for key: String in PROFILE_DEFAULTS:
			if saved.has(key) and typeof(saved[key]) == typeof(PROFILE_DEFAULTS[key]):
				profile[key] = saved[key]
			elif saved.has(key) and typeof(PROFILE_DEFAULTS[key]) == TYPE_INT and typeof(saved[key]) == TYPE_FLOAT:
				profile[key] = int(saved[key])  # JSON 은 정수를 실수로 돌려준다


func save_file() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("기록을 저장하지 못했다: %s" % path)
		return
	f.store_string(JSON.stringify({"scores": scores, "cleared": cleared, "account": account, "profile": profile}, "  "))


func set_account(kind: String) -> void:
	account = kind
	save_file()


func display_name() -> String:
	return String(profile["name"]) if String(profile["name"]) != "" else "CAPTAIN"


func set_name(text: String) -> void:
	profile["name"] = text.strip_edges().substr(0, NAME_MAX)
	save_file()


func pick(key: String, value: Variant) -> void:
	profile[key] = value
	save_file()


func gear_count(id: String) -> int:
	return int(profile["gear"].get(id, 0))


## 코인으로 출발 아이템을 산다. 코인이 모자라면 false.
func buy_gear(id: String, price: int) -> bool:
	if int(profile["coins"]) < price:
		return false
	profile["coins"] = int(profile["coins"]) - price
	profile["gear"][id] = gear_count(id) + 1
	save_file()
	return true


## 출발 아이템을 하나 쓴다. 없으면 false.
func use_gear(id: String) -> bool:
	if gear_count(id) <= 0:
		return false
	profile["gear"][id] = gear_count(id) - 1
	save_file()
	return true


## 한 판에서 얻은 경험치와 코인, 누적 기록을 더한다.
func add_progress(xp: int, coins: int, was_cleared: bool, cells: int, combo: int, seconds: int) -> void:
	profile["xp"] = int(profile["xp"]) + xp
	profile["coins"] = int(profile["coins"]) + coins
	var s: Dictionary = profile["stats"]
	s["games"] = int(s.get("games", 0)) + 1
	s["clears"] = int(s.get("clears", 0)) + (1 if was_cleared else 0)
	s["cells"] = int(s.get("cells", 0)) + cells
	s["best_combo"] = maxi(int(s.get("best_combo", 0)), combo)
	s["seconds"] = int(s.get("seconds", 0)) + seconds
	save_file()


## 한 판의 결과를 남기고 그 판의 순위(1부터)를 돌려준다. 남겨 두는 수 밖으로 밀려났으면 0.
## gear 는 그 판에 쓴 출발 아이템이다. 쓴 판의 기록에는 표시가 남는다.
func add_result(stage_id: String, score: int, was_cleared: bool, seconds: int, at: String, gear: String = "") -> int:
	var list: Array = scores.get(stage_id, [])
	var entry := {"score": score, "cleared": was_cleared, "seconds": seconds, "at": at}
	if gear != "":
		entry["gear"] = gear
	var rank := insert(list, entry, KEEP)
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
