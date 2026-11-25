extends "res://src/ui/screens/base_screen.gd"
## 일시정지. 플레이 중 멈춤 단추나 안드로이드의 뒤로 단추로 연다.

func setup(stage: String) -> void:
	_fill(Color(0.05, 0.08, 0.16, 0.6))
	var card := Kit.panel(Color(1, 1, 1, 0.98), 44, 34)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(520, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	v.add_child(_centered("PAUSED", 72, Kit.INK))
	v.add_child(_centered(stage, 28, Kit.GREY.darkened(0.3)))
	var resume := Kit.button("RESUME", Kit.CORAL, 52)
	resume.custom_minimum_size = Vector2(0, 120)
	v.add_child(_link(resume, "resume"))
	v.add_child(_link(Kit.button("RETRY", Kit.MINT, 36), "retry"))
	v.add_child(_link(Kit.button("HOME", Kit.INK, 36), "home"))


func back() -> bool:
	go.emit("resume", "")
	return true
