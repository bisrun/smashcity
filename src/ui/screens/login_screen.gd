extends "res://src/ui/screens/base_screen.gd"
## 로그인. 처음 켠 사람에게만 뜬다.
##
## 지금은 시나리오용 화면이다. 어느 단추를 눌러도 게스트로 지나간다.
## TODO: 구글 계정(Google Play 게임 서비스) 연결. docs/17_account_save.md

func setup() -> void:
	_fill(Color(0.87, 0.96, 0.98, 0.9))
	var v := _column(70, 260, 150, 22)
	v.add_child(_centered("SMASH", 150, Kit.CORAL))
	v.add_child(_centered("CITY", 150, Kit.INK))
	v.add_child(_centered("도시를 시원하게 부수는 벽돌깨기", 30, Kit.INK))
	v.add_child(_spacer())
	v.add_child(_link(Kit.button("SIGN IN WITH GOOGLE", Kit.SKY, 34), "login_done", "guest"))
	v.add_child(_centered("구글 계정 연결은 준비 중이에요. 지금은 게스트로 시작합니다.", 22, Kit.GREY.darkened(0.3)))
	v.add_child(_link(Kit.button("PLAY AS GUEST", Kit.CORAL, 40), "login_done", "guest"))
