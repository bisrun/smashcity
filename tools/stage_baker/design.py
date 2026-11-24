#!/usr/bin/env python3
"""스테이지의 design.json 초안과 stages.json 을 만든다.

design.json 은 손으로 고치는 파일이다. 이 도구는 "_auto": true 가 붙은 것만 다시 쓴다. 손으로 고친 뒤에는 그 표시를 지운다.
난이도 값은 목표 등급에서 나온다(docs/07_stage_leveling.md). 봇으로 잰 결과에 맞춰 조정한 값은 tools/difficulty/tuning.json 에 있다.

실행 (저장소 루트에서): python3 tools/stage_baker/design.py
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake import STAGES, all_stages  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
TUNING = ROOT / "tools" / "difficulty" / "tuning.json"


def target_grade(region_index, order):
    """목표 등급 1~10. 지역이 바뀌면 낮춰 시작하고, 지역 안에서는 톱니 모양으로 오른다."""
    g = 1.0 + 0.6 * region_index + 0.45 * order
    if order in (4, 7):   # 숨 돌리는 판
        g -= 0.8
    return round(max(1.0, min(10.0, g)), 1)


def balance_for(level, region_index):
    """난이도 손잡이 level(0~1)에서 스테이지 값을 만든다. 0이 가장 쉽고 1이 가장 어렵다."""
    t = max(0.0, min(1.25, level))
    sky = {"multi": 3.0, "wide": 2.0, "fire": 2.0, "life": 0.5, "narrow": round(3.0 + 3.0 * t, 1)}
    if region_index >= 1:
        sky["shield"] = 1.5
    if region_index >= 3:
        sky["wreck"] = 1.5
    return {
        "ball_speed": round(1000 + 420 * t),
        "paddle_width": round(280 - 100 * t),
        "landmark_hp": round(12 + 22 * t),
        "cell_hp_bonus": 0 if t < 0.45 else (1 if t < 0.85 else 2),
        "drop_interval_start": round(14 + 8 * t, 1),
        "drop_interval_end": round(6 + 5 * t, 1),
        "sky_items": sky,
    }


def poly_area(p):
    n = len(p) // 2
    return abs(sum(p[2 * i] * p[2 * ((i + 1) % n) + 1] - p[2 * ((i + 1) % n)] * p[2 * i + 1] for i in range(n))) / 2


def centre(p):
    n = len(p) // 2
    return [round(sum(p[0::2]) / n), round(sum(p[1::2]) / n)]


def make(stage, m, level):
    t = max(0.0, min(1.0, level))
    cells = m["cells"]
    lm = next(c for c in cells if c.get("lm"))
    lm_at = centre(lm["p"])
    items = []
    quota = {"fuel": ("fire", 3), "pharmacy": ("life", 2), "parking": ("wide", 3)}
    if stage["region_index"] >= 1:
        quota["police"] = ("shield", 2)
    if stage["region_index"] >= 3:
        quota["bank"] = ("wreck", 2)
    label = {"fuel": "주유소", "pharmacy": "약국", "parking": "주차장", "police": "경찰서", "bank": "은행"}
    used = {}
    budget = round(12 - 6 * t)
    for p in sorted(m.get("pois", []), key=lambda p: (p["y"], p["x"])):
        if p["k"] not in quota or len(items) >= budget - 2:
            continue
        kind, cap = quota[p["k"]]
        if used.get(kind, 0) >= cap:
            continue
        # 같은 종류가 한곳에 몰리지 않게 띄운다
        if any(i["type"] == kind and math.hypot(i["at"][0] - p["x"], i["at"][1] - p["y"]) < 350 for i in items):
            continue
        used[kind] = used.get(kind, 0) + 1
        items.append({"at": [p["x"], p["y"]], "type": kind, "from": (label[p["k"]] + " " + p.get("n", "")).strip()})
    # 상상 아이템: 열기구(멀티볼). 판을 네 칸으로 나눠 칸마다 하나씩 띄운다.
    open_cells = [c for c in cells if not c.get("lm") and not c.get("e") and not c.get("s")]
    balloons = 4 if t < 0.6 else 3 if t < 0.9 else 2
    spots = [(0.25, 0.25), (0.75, 0.45), (0.3, 0.65), (0.7, 0.85)][:balloons]
    for fx, fy in spots:
        if not open_cells:
            break
        c = min(open_cells, key=lambda c: math.hypot(centre(c["p"])[0] - fx * m["W"], centre(c["p"])[1] - fy * m["H"]))
        items.append({"at": centre(c["p"]), "type": "multi", "from": "열기구 (상상)"})
    if not any(i["type"] == "wide" for i in items) and open_cells:
        for fx, fy in [(0.5, 0.2), (0.5, 0.6)]:
            c = min(open_cells, key=lambda c: math.hypot(centre(c["p"])[0] - fx * m["W"], centre(c["p"])[1] - fy * m["H"]))
            items.append({"at": centre(c["p"]), "type": "wide", "from": "임시 배치 (상상)"})
    walls = []
    if t >= 0.18:
        # 목표를 두른 깨지지 않는 벽. 어려울수록 구멍이 좁고, 패들에서 먼 쪽으로 돌아간다.
        toward = [0.3, -1.0] if t < 0.45 else ([1.0, -0.2] if stage["index"] % 2 else [-1.0, -0.2]) if t < 0.75 else [0.2, 1.0]
        walls.append({"around": lm_at, "gap_toward": toward, "gap_width": round(200 - 80 * t), "offset": 10, "thickness": 12, "radius": 240,
                      "_note": "목표를 두른 깨지지 않는 벽"})
    return {
        "_comment": "스테이지의 수작업 기획. map.json 과 달리 손으로 고친다. 지금은 도구가 만든 초안이다.",
        "_auto": True,
        "theme": stage["theme"],
        # 물이 거의 없는 동네에서는 패들이 강이 아니라 큰 도로를 다닌다 (배 대신 버스)
        "base": "road" if m.get("report", {}).get("water_share", 0) < 0.01 else "river",
        "grade_target": target_grade(stage["region_index"], stage["order"]),
        "level": round(level, 3),
        "balance": balance_for(level, stage["region_index"]),
        "items": items,
        "walls": walls,
    }


def main():
    tuning = json.loads(TUNING.read_text()) if TUNING.exists() else {}
    regions = {}
    for stage in all_stages():
        folder = STAGES / stage["region"] / stage["id"]
        ready = (folder / "map.json").exists()
        regions.setdefault(stage["region"], {"id": stage["region"], "name": stage["region_name"], "stages": []})["stages"].append(
            {"id": stage["key"], "name": stage["name"], "ready": ready})
        if not ready:
            continue
        path = folder / "design.json"
        grade = target_grade(stage["region_index"], stage["order"])
        level = tuning.get(stage["key"], (grade - 1) / 9)
        if path.exists():
            old = json.loads(path.read_text())
            if not old.get("_auto"):
                # 손으로 고친 파일: 테마와 목표 등급만 채운다
                changed = False
                for k, v in (("theme", stage["theme"]), ("grade_target", grade)):
                    if old.get(k) != v:
                        old[k] = v
                        changed = True
                if stage["key"] in tuning:
                    b = balance_for(level, stage["region_index"])
                    if old.get("balance") != b or old.get("level") != round(level, 3):
                        old["balance"] = b
                        old["level"] = round(level, 3)
                        changed = True
                if changed:
                    path.write_text(json.dumps(old, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                continue
        m = json.loads((folder / "map.json").read_text())
        path.write_text(json.dumps(make(stage, m, level), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    out = {"_comment": "지역과 스테이지의 차례. ready 가 false 인 스테이지는 아직 지도를 굽지 않은 것이다. tools/stage_baker/design.py 가 만든다.",
           "cities": list(regions.values())}
    (STAGES / "stages.json").write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    done = sum(1 for r in regions.values() for s in r["stages"] if s["ready"])
    print("스테이지 %d개 가운데 %d개 준비됨" % (sum(len(r["stages"]) for r in regions.values()), done))


if __name__ == "__main__":
    main()
