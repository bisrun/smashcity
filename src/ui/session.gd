class_name Session
extends RefCounted
## 장면을 다시 불러도 남는 것. 지금 어느 공간에 있고 어느 스테이지를 띄울지를 담는다.
##
## 판을 바꿀 때마다 장면을 다시 부르므로, 다시 부른 뒤에 무엇을 보여 줄지를 여기에 적어 둔다.
## 판정(src/sim)은 이것을 모른다.

## 장면이 뜨면 보여 줄 공간. "" 이면 앱을 처음 켠 것이다. login, menu, regions, map, settings, dev, play
static var screen := ""
## 띄울 스테이지. "" 이면 진행에 따라 고른다(아직 못 깬 첫 스테이지).
static var stage := ""
## 개발자 창에서 들어간 판이다. 기록을 남기지 않고, 끝나면 개발자 창으로 돌아온다.
static var dev := false
