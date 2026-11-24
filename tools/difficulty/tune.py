#!/usr/bin/env python3
"""스테이지 난이도를 봇으로 재고, 목표 등급에 맞게 난이도 손잡이를 조정한다.

기준은 docs/07_stage_leveling.md 에 있다.
  난이도 지수 = 100 × (1 − (0.25×초보 + 0.5×보통 + 0.25×고수 봇의 클리어율))
  등급 = 1 + 지수 ÷ 9  (1~10으로 자름)

실행 (저장소 루트에서):
  python3 tools/difficulty/tune.py measure [판 수]     # 재기만 한다
  python3 tools/difficulty/tune.py tune [판 수] [회]   # 목표에서 벗어난 스테이지의 손잡이를 고쳐 가며 다시 잰다
결과는 tools/difficulty/report.json 과 docs/15_difficulty_report.md 에 쓴다.
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
HERE = Path(__file__).resolve().parent
TUNING = HERE / "tuning.json"
REPORT = HERE / "report.json"
DOC = ROOT / "docs" / "15_difficulty_report.md"
WORKERS = max(2, (os.cpu_count() or 4) - 2)
TOLERANCE = 0.8


def ready_stages():
    data = json.loads((ROOT / "assets/stages/stages.json").read_text())
    return [(c["name"], s) for c in data["cities"] for s in c["stages"] if s["ready"]]


def grade_of(row):
    index = 100 * (1 - (0.25 * row["novice"]["clear"] + 0.5 * row["average"]["clear"] + 0.25 * row["expert"]["clear"]))
    return round(index, 1), round(max(1.0, min(10.0, 1 + index / 9)), 1)


def measure(ids, runs):
    chunks = [ids[i::WORKERS] for i in range(WORKERS)]

    def work(chunk):
        if not chunk:
            return []
        out = subprocess.run(["godot", "--headless", "--path", str(ROOT), "-s", "tools/difficulty/measure.gd", "--", str(runs)] + chunk,
                             capture_output=True, text=True).stdout
        return [json.loads(l) for l in out.splitlines() if l.startswith("{")]
    rows = {}
    with ThreadPoolExecutor(WORKERS) as pool:
        for part in pool.map(work, chunks):
            for r in part:
                rows[r["id"]] = r
    return rows


def design_of(key):
    return json.loads((ROOT / "assets/stages" / key / "design.json").read_text())


def write_report(rows):
    REPORT.write_text(json.dumps(rows, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    lines = ["# 15 난이도 측정 결과", "",
             "봇으로 잰 스테이지별 난이도다. `tools/difficulty/tune.py` 가 쓴 것이므로 손으로 고치지 않는다. 기준과 읽는 법은 [07 스테이지 레벨링](07_stage_leveling.md)에 있다.", "",
             "클리어율은 봇 종류마다 %d판을 돌린 값이다. 사람이 해 본 값이 아니다. 확인 전." % next(iter(rows.values()))["runs"] if rows else "", "",
             "| 지역 | 번호 | 스테이지 | 목표 등급 | 잰 등급 | 지수 | 초보 | 보통 | 고수 | 보통 봇 시간 | 손잡이 | 판정 |", "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    last = None
    n = 0
    for city, s in ready_stages():
        n = n + 1 if city == last else 1
        last = city
        r = rows.get(s["id"])
        if r is None:
            continue
        d = design_of(s["id"])
        index, grade = grade_of(r)
        target = d.get("grade_target", 0)
        verdict = "맞음" if abs(grade - target) <= TOLERANCE else ("쉬움" if grade < target else "어려움")
        if r["expert"]["clear"] < 0.5:
            verdict += ", 고수도 절반을 못 깸"
        lines.append("| %s | %d | %s | %.1f | %.1f | %.0f | %d%% | %d%% | %d%% | %d초 | %.2f | %s |" % (
            city, n, s["name"], target, grade, index, r["novice"]["clear"] * 100, r["average"]["clear"] * 100, r["expert"]["clear"] * 100,
            r["average"]["time"], d.get("level", 0), verdict))
    DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "measure"
    runs = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    rounds = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    ids = [s["id"] for _, s in ready_stages()]
    rows = json.loads(REPORT.read_text()) if REPORT.exists() else {}
    rows = {k: v for k, v in rows.items() if k in ids}
    todo = ids if mode == "measure" else [i for i in ids if i not in rows or rows[i]["runs"] != runs] or ids
    for step in range(rounds if mode == "tune" else 1):
        rows.update(measure(todo, runs))
        write_report(rows)
        if mode != "tune":
            break
        tuning = json.loads(TUNING.read_text()) if TUNING.exists() else {}
        off = []
        for key in ids:
            d = design_of(key)
            if "grade_target" not in d or key not in rows:
                continue
            _, grade = grade_of(rows[key])
            gap = d["grade_target"] - grade
            if abs(gap) > TOLERANCE:
                level = tuning.get(key, d.get("level", (d["grade_target"] - 1) / 9))
                tuning[key] = round(max(-0.3, min(1.25, level + 0.6 * gap / 9)), 3)
                off.append(key)
        print("회차 %d: 잰 스테이지 %d개, 목표에서 벗어난 것 %d개" % (step + 1, len(todo), len(off)), flush=True)
        if not off:
            break
        TUNING.write_text(json.dumps(tuning, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        subprocess.run([sys.executable, str(ROOT / "tools/stage_baker/design.py")], check=True)
        todo = off
    for key in ids:
        if key in rows:
            index, grade = grade_of(rows[key])
            print(key, "목표", design_of(key).get("grade_target"), "잰 등급", grade, "지수", index)


if __name__ == "__main__":
    main()
