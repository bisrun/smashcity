class_name Balance
extends RefCounted
## 밸런스 값 파일(assets/balance.json)을 읽는다.
##
## 속도, 폭, 점수 같은 숫자는 코드에 쓰지 않고 이 파일에 둔다.

const DEFAULT_PATH := "res://assets/balance.json"


static func load_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("밸런스 파일이 없다: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("밸런스 파일을 읽을 수 없다: %s" % path)
		return {}
	return parsed
