class_name SecretGesture
extends RefCounted
## 설정 화면에 숨긴 동작. 위쪽 띠를 왼쪽에서 오른쪽으로 끈 다음 오른쪽 위를 빠르게 열 번 두드리면 열린다.
##
## 화면을 모르는 순수한 계산이다. 누른 자리와 뗀 자리, 시각을 받아 열렸는지만 알려 준다.

## 화면 높이에서 위쪽 띠가 차지하는 몫
const TOP := 0.18
## 끌기는 이 몫보다 왼쪽에서 시작해 RIGHT 보다 오른쪽에서 끝나야 한다
const LEFT := 0.35
const RIGHT := 0.65
## 두드리는 자리는 이 몫보다 오른쪽이다
const TAP_ZONE := 0.6
const TAPS := 10
## 두드림 사이가 이보다 길면 처음부터 다시 센다 (초)
const TAP_GAP := 0.6
## 끌고 나서 첫 두드림까지 기다려 주는 시간 (초)
const ARM_SECONDS := 5.0
## 이보다 많이 움직였으면 두드림이 아니다 (화면 폭의 몫)
const TAP_MOVE := 0.06

var _down := Vector2.ZERO
var _armed_until := -1.0
var _taps := 0
var _last_tap := -1.0


func press(at: Vector2) -> void:
	_down = at


## 손을 뗐다. 숨긴 동작이 다 끝났으면 true.
func release(at: Vector2, size: Vector2, now: float) -> bool:
	var band := size.y * TOP
	var dragged := _down.y <= band and at.y <= band * 1.6 and _down.x <= size.x * LEFT and at.x >= size.x * RIGHT
	if dragged:
		_armed_until = now + ARM_SECONDS
		_taps = 0
		return false
	var tapped := _down.distance_to(at) <= size.x * TAP_MOVE and at.y <= band and at.x >= size.x * TAP_ZONE
	if not tapped or now > _armed_until:
		_armed_until = -1.0
		_taps = 0
		return false
	_taps += 1
	_last_tap = now
	_armed_until = now + TAP_GAP
	if _taps >= TAPS:
		_armed_until = -1.0
		_taps = 0
		return true
	return false


## 지금까지 센 두드림 수. 개발 중 확인용이다.
func taps() -> int:
	return _taps
