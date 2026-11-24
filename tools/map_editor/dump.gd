extends SceneTree
## 맵 에디터가 쓰는 도구. 스테이지의 충돌 정보를 게임의 판정 코드에서 그대로 꺼내 JSON 으로 찍는다.
##
## 실행: godot --headless --path . -s tools/map_editor/dump.gd -- <스테이지 id> [design.json 경로]
## design 경로를 주면 저장하지 않은 편집 내용으로 계산한다.

const SimScript := preload("res://src/sim/sim.gd")
const StageDataScript := preload("res://src/data/stage_data.gd")
const BalanceScript := preload("res://src/data/balance.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	var dir := "res://assets/stages/%s/" % args[0]
	var stage: StageData = StageDataScript.load_file(dir + "map.json")
	var design_path := args[1] if args.size() > 1 else dir + "design.json"
	var design: Dictionary = BalanceScript.load_file(design_path) if FileAccess.file_exists(design_path) else {}
	if stage == null:
		quit(1)
		return
	var cfg: Dictionary = BalanceScript.merged(BalanceScript.load_file(), design)
	var sim: Sim = SimScript.new(stage, cfg, design)
	var walls: Array = []
	for w in sim.walls:
		var flat: Array = []
		for p in w:
			flat.append(snappedf(p.x, 0.1))
			flat.append(snappedf(p.y, 0.1))
		walls.append(flat)
	var gates: Array = []
	for g in sim.gates:
		gates.append([snappedf(g[0].x, 0.1), snappedf(g[0].y, 0.1), snappedf(g[1].x, 0.1), snappedf(g[1].y, 0.1)])
	var items := {}
	for i in stage.cells.size():
		var t: String = sim.item_in_cell(i)
		if t != "":
			items[str(i)] = t
	print("DUMP " + JSON.stringify({
		"walls": walls, "gates": gates,
		"hp": Array(sim.cell_max_hp), "solid": Array(sim.cell_solid),
		"breakable": sim.breakable_count(), "items": items,
		"paddle_y": float(cfg["paddle_y"]), "paddle_width": sim.paddle_width(), "paddle_thickness": float(cfg["paddle_thickness"]),
		"fall_y": float(cfg["paddle_y"]) - float(cfg["fall_margin"]), "river_width": float(cfg["river_width"]),
		"ball_radius": sim.ball_radius, "ball_speed": float(cfg["ball_speed"]), "lives": sim.lives,
	}))
	quit()
