class_name SettingsData
extends RefCounted
## 기기에 딸린 설정. 계정을 따라 옮기지 않는다(docs/17_account_save.md).

const DEFAULT_PATH := "user://settings.json"
## sound: 소리 크기 0~1, vibrate: 진동, shake: 화면 흔들림, drag_gain: 끄는 민감도(손가락이 움직인 거리의 몇 배)
const DEFAULTS := {"sound": 0.8, "vibrate": true, "shake": true, "drag_gain": 1.25}
const DRAG_GAIN_MIN := 0.8
const DRAG_GAIN_MAX := 2.0

var path := DEFAULT_PATH
var values := {}


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	values = DEFAULTS.duplicate()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# 모르는 항목과 형이 다른 값은 버린다
	for key: String in DEFAULTS:
		if parsed.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
			values[key] = parsed[key]
	values["sound"] = clampf(float(values["sound"]), 0.0, 1.0)
	values["drag_gain"] = clampf(float(values["drag_gain"]), DRAG_GAIN_MIN, DRAG_GAIN_MAX)


func put(key: String, value: Variant) -> void:
	values[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("설정을 저장하지 못했다: %s" % path)
		return
	f.store_string(JSON.stringify(values, "  "))
