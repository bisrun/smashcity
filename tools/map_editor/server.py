#!/usr/bin/env python3
"""맵 에디터. 스테이지를 눈으로 보고 design.json 을 고치는 로컬 도구다.

실행 (저장소 루트에서): python3 tools/map_editor/server.py   → 브라우저에서 http://127.0.0.1:8765

- map.json 은 보기만 한다. OSM 에서 구운 것이라 손으로 고치지 않는다(CLAUDE.md).
- 저장하면 design.json 을 쓰고 "_auto" 표시를 지운다. 그러면 design.py 가 그 파일을 다시 덮어쓰지 않는다.
- 충돌 영역은 게임의 판정 코드를 그대로 돌려 얻는다(dump.gd). 흉내 낸 것이 아니다.
- 이 컴퓨터에서만 접속할 수 있다(127.0.0.1).
"""
import json
import os
import subprocess
import sys
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent.parent.parent
HERE = Path(__file__).resolve().parent
STAGES = ROOT / "assets" / "stages"
TUNING = ROOT / "tools" / "difficulty" / "tuning.json"
REPORT = ROOT / "tools" / "difficulty" / "report.json"
PORT = int(os.environ.get("MAP_EDITOR_PORT", "8765"))

sys.path.insert(0, str(ROOT / "tools" / "stage_baker"))
sys.path.insert(0, str(ROOT / "tools" / "difficulty"))
from design import balance_for  # noqa: E402
from tune import grade_of  # noqa: E402


def read_json(path, default=None):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def world():
    """지역과 스테이지 목록. 목표 등급과 봇으로 잰 등급을 붙인다."""
    listing = read_json(STAGES / "stages.json", {"cities": []})
    report = read_json(REPORT, {})
    region_index = {c["id"]: i for i, c in enumerate(listing["cities"])}
    for city in listing["cities"]:
        for s in city["stages"]:
            d = read_json(STAGES / s["id"] / "design.json", {}) if s["ready"] else {}
            s["grade_target"] = d.get("grade_target")
            s["auto"] = bool(d.get("_auto"))
            if s["id"] in report:
                s["index"], s["grade"] = grade_of(report[s["id"]])
    return {"cities": listing["cities"], "themes": [k for k in read_json(ROOT / "assets" / "themes.json", {}) if not k.startswith("_")],
            "region_index": region_index}


def saved_at(stage_id):
    """design.json 이 디스크에 마지막으로 쓰인 시각."""
    path = STAGES / stage_id / "design.json"
    return time.strftime("%m-%d %H:%M:%S", time.localtime(path.stat().st_mtime)) if path.exists() else ""


def known(stage_id):
    return any(s["id"] == stage_id and s["ready"] for c in read_json(STAGES / "stages.json", {"cities": []})["cities"] for s in c["stages"])


def godot(script, args, timeout=600):
    out = subprocess.run(["godot", "--headless", "--path", str(ROOT), "-s", script, "--"] + args, capture_output=True, text=True, timeout=timeout)
    return out.stdout


def collision(stage_id, design):
    """편집 중인 design 으로 판정을 만들어 벽과 셀의 상태를 돌려준다."""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(design, f, ensure_ascii=False)
        path = f.name
    try:
        for line in godot("tools/map_editor/dump.gd", [stage_id, path], 60).splitlines():
            if line.startswith("DUMP "):
                return json.loads(line[5:])
    finally:
        os.unlink(path)
    raise RuntimeError("판정 코드를 돌리지 못했다")


def save(stage_id, design):
    design = dict(design)
    design.pop("_auto", None)
    design["_comment"] = "스테이지의 수작업 기획. map.json 과 달리 손으로 고친다. 맵 에디터로 고쳤다."
    path = STAGES / stage_id / "design.json"
    path.write_text(json.dumps(design, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if "level" in design:
        # 난이도 손잡이는 tuning.json 이 단일 출처다. 여기에도 적어 두어야 design.py 가 되돌리지 않는다.
        tuning = read_json(TUNING, {})
        tuning[stage_id] = design["level"]
        TUNING.write_text(json.dumps(tuning, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(time.strftime("%H:%M:%S"), "저장:", stage_id, flush=True)   # 언제 무엇을 저장했는지 남긴다
    return {"saved": str(path.relative_to(ROOT)), "saved_at": saved_at(stage_id)}


def measure(stage_id, runs):
    for line in godot("tools/difficulty/measure.gd", [str(runs), stage_id]).splitlines():
        if line.startswith("{"):
            row = json.loads(line)
            index, grade = grade_of(row)
            return {"row": row, "index": index, "grade": grade}
    raise RuntimeError("난이도를 재지 못했다")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, data, status=200, kind="application/json"):
        body = data if isinstance(data, bytes) else json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", kind + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        n = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(n).decode("utf-8")) if n else {}

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        try:
            if url.path in ("/", "/index.html"):
                return self.send((HERE / "editor.html").read_bytes(), kind="text/html")
            if url.path == "/api/world":
                return self.send(world())
            if url.path == "/api/stage":
                sid = q["id"][0]
                if not known(sid):
                    return self.send({"error": "모르는 스테이지: " + sid}, 404)
                return self.send({"map": read_json(STAGES / sid / "map.json"), "design": read_json(STAGES / sid / "design.json", {}),
                                  "report": read_json(REPORT, {}).get(sid), "saved_at": saved_at(sid)})
            if url.path == "/api/balance":
                return self.send(balance_for(float(q["level"][0]), int(q["region"][0])))
            self.send({"error": "없는 주소"}, 404)
        except Exception as e:
            self.send({"error": repr(e)}, 500)

    def do_POST(self):
        # 다른 사이트의 페이지가 이 도구를 몰래 부르지 못하게, 이 도구의 화면에서 온 요청만 받는다
        origin = self.headers.get("Origin", "")
        if origin and origin not in ("http://127.0.0.1:%d" % PORT, "http://localhost:%d" % PORT):
            return self.send({"error": "거절"}, 403)
        url = urlparse(self.path)
        q = parse_qs(url.query)
        try:
            sid = q["id"][0]
            if not known(sid):
                return self.send({"error": "모르는 스테이지: " + sid}, 404)
            if url.path == "/api/collision":
                return self.send(collision(sid, self.body()))
            if url.path == "/api/save":
                return self.send(save(sid, self.body()))
            if url.path == "/api/measure":
                return self.send(measure(sid, int(q.get("runs", ["6"])[0])))
            if url.path == "/api/play":
                subprocess.Popen(["godot", "--path", str(ROOT), "--resolution", "540x1200"], env=dict(os.environ, SMASHCITY_STAGE=sid),
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return self.send({"started": sid})
            self.send({"error": "없는 주소"}, 404)
        except Exception as e:
            self.send({"error": repr(e)}, 500)


if __name__ == "__main__":
    print("맵 에디터: http://127.0.0.1:%d  (끝내려면 Ctrl+C)" % PORT, flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
