extends SceneTree
## 스테이지의 난이도를 봇으로 잰다. 화면 없이 돈다.
##
## 실행: godot --headless --path . -s tools/difficulty/measure.gd -- [판 수] [스테이지 id ...]
##   스테이지를 적지 않으면 stages.json 의 ready 스테이지를 모두 잰다. 결과는 한 줄에 스테이지 하나씩 JSON 으로 찍는다.
##
## 봇은 사람처럼 모자라게 만든 세 가지다(docs/07_stage_leveling.md). 공이 떨어질 자리를 내다보고 패들을 옮기지만,
## 보고 나서 움직이기까지 시간이 걸리고(react), 겨냥이 빗나가고(aim), 패들을 옮기는 빠르기에 한계가 있다(speed).

const SimScript := preload("res://src/sim/sim.gd")
const StageDataScript := preload("res://src/data/stage_data.gd")
const BalanceScript := preload("res://src/data/balance.gd")

const BOTS := {
	"novice": {"react": 0.30, "aim": 80.0, "speed": 1000.0},
	"average": {"react": 0.18, "aim": 45.0, "speed": 1600.0},
	"expert": {"react": 0.08, "aim": 15.0, "speed": 2600.0},
}
## 이 시간 안에 못 끝내면 실패로 친다 (초)
const TIME_LIMIT := 420.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 8
	var ids: Array[String] = []
	for a in args:
		if a.is_valid_int():
			runs = int(a)
		else:
			ids.append(a)
	if ids.is_empty():
		var data: Dictionary = BalanceScript.load_file("res://assets/stages/stages.json")
		for city: Dictionary in data["cities"]:
			for s: Dictionary in city["stages"]:
				if bool(s["ready"]):
					ids.append(String(s["id"]))
	var base: Dictionary = BalanceScript.load_file()
	for id in ids:
		var dir := "res://assets/stages/%s/" % id
		var stage: StageData = StageDataScript.load_file(dir + "map.json")
		if stage == null:
			continue
		var design: Dictionary = BalanceScript.load_file(dir + "design.json") if FileAccess.file_exists(dir + "design.json") else {}
		var row := {"id": id, "runs": runs}
		for bot: String in BOTS:
			row[bot] = _measure(stage, base, design, BOTS[bot], runs)
		print(JSON.stringify(row))
	quit()


func _measure(stage: StageData, base: Dictionary, design: Dictionary, bot: Dictionary, runs: int) -> Dictionary:
	var clears := 0
	var time_sum := 0.0
	var lost_sum := 0
	var broken_sum := 0.0
	for r in runs:
		var cfg: Dictionary = BalanceScript.merged(base, design)
		cfg["seed"] = 1000 + r * 7919
		var sim: Sim = SimScript.new(stage, cfg, design)
		var start_lives := sim.lives
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + r * 104729
		var target := sim.paddle_x
		var seen_in := 0.0
		var x := sim.paddle_x
		while not sim.cleared and not sim.over and sim.elapsed < TIME_LIMIT:
			seen_in -= Sim.STEP
			if seen_in <= 0.0:
				seen_in = float(bot["react"])
				target = _aim(sim, cfg) + rng.randfn(0.0, float(bot["aim"]))
			x = move_toward(x, target, float(bot["speed"]) * Sim.STEP)
			sim.set_paddle(x)
			sim.step()
			sim.take_events()
		if sim.cleared:
			clears += 1
			time_sum += sim.elapsed
		lost_sum += maxi(0, start_lives - sim.lives)
		broken_sum += float(sim.destroyed) / maxf(1.0, float(sim.breakable_count()))
	return {
		"clear": snappedf(float(clears) / runs, 0.01),
		"time": snappedf(time_sum / maxf(1.0, clears), 1.0),
		"lost": snappedf(float(lost_sum) / runs, 0.01),
		"broken": snappedf(broken_sum / runs, 0.01),
	}


## 봇이 가려는 자리. 내려오는 공 가운데 패들에 가장 먼저 닿을 공이 떨어질 곳이다. 도중에 건물에 튕기는 것은 내다보지 못한다.
func _aim(sim: Sim, cfg: Dictionary) -> float:
	var paddle_y := float(cfg["paddle_y"])
	var best_t := INF
	var best_x := sim.paddle_x
	for b in sim.balls:
		if b.state != Sim.BallState.FLYING:
			continue
		if b.vel.y >= 0.0:
			if best_t == INF:
				best_x = b.pos.x
			continue
		var t := (b.pos.y - paddle_y) / -b.vel.y
		if t < best_t:
			best_t = t
			var land := b.pos.x + b.vel.x * t
			# 옆 벽에 튕기는 것은 내다본다
			var w := sim.stage.width
			land = fposmod(land, w * 2.0)
			best_x = land if land <= w else w * 2.0 - land
	# 공이 멀리 있으면 좋은 아이템을 받으러 간다
	if best_t > 1.2:
		for it: Dictionary in sim.items:
			if it["type"] != "narrow" and it["pos"].y < 500.0:
				return it["pos"].x
	return best_x
