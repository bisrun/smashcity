"""잠실 OSM 데이터로 통로와 셀을 만들어 보고 수치를 재는 실험 스크립트.

docs/03_map_conversion.md 와 docs/stages/seoul_jamsil.md 의 수치가 여기서 나왔다.
stage_baker 의 정식 구현이 아니다. shapely 가 필요하다.

실행: python3 jamsil_probe.py <overpass 결과.json> <출력.json> [북쪽 끝 위도]
입력은 Overpass API 에서 건물, 도로, 물, 공원, 시설을 `out geom` 으로 받은 JSON 이다.
"""
import json, sys, math, collections
from shapely.geometry import Polygon, LineString, MultiPolygon, box, Point, MultiPoint
from shapely.ops import unary_union, polygonize
from shapely import make_valid, voronoi_polygons

raw = json.load(open(sys.argv[1]))["elements"]
OUT = sys.argv[2]

# --- 판 정의: OSM 줌 15(축척 막대 300m), 세로 폰 390px 기준 ---
MPP = 156543.03 * math.cos(math.radians(37.51)) / 2**15   # m/px at zoom 15
W = round(MPP * 390)            # 화면 가로 실제 거리
H = round(W * 16 / 9)
LAT_N = float(sys.argv[3]) if len(sys.argv) > 3 else 37.5212
LON_C = 127.1000
KX, KY = 111320 * math.cos(math.radians(37.51)), 110950
LON_E = LON_C + (W / 2) / KX
def P(p):   # 180도 회전: 북쪽이 화면 아래, 동쪽이 화면 왼쪽
    return ((LON_E - p["lon"]) * KX, (LAT_N - p["lat"]) * KY)
board = box(0, 0, W, H)
BALL = round(W * 0.026)         # 공 지름: 화면 가로의 2.6%

def poly_of(geom):
    pts = [P(p) for p in geom if p]
    if len(pts) < 4: return None
    g = make_valid(Polygon(pts))
    return g if not g.is_empty else None

def levels_of(t):
    try:
        if "building:levels" in t: return max(1, int(float(t["building:levels"])))
        if "height" in t: return max(1, round(float(t["height"].replace("m", "")) / 3.2))
    except ValueError: pass
    return None

buildings = []; roads = []; parks = []; lake = None; pois = []
for e in raw:
    t = e.get("tags", {})
    if "building" in t:
        if e["type"] == "way":
            cand = [poly_of(e["geometry"])]
        else:   # 멀티폴리곤: 바깥 고리 조각들을 이어 붙인다
            ls = [LineString([P(p) for p in m["geometry"] if p]) for m in e.get("members", []) if m.get("role") in ("outer", "") and m.get("geometry") and len(m["geometry"]) >= 2]
            cand = list(polygonize(unary_union(ls))) if ls else []
        for p in cand:
            if p is None: continue
            p = p.intersection(board)
            if p.area < 20: continue
            if p.geom_type != "Polygon": p = max(getattr(p, "geoms", [p]), key=lambda x: x.area)
            if p.geom_type != "Polygon": continue
            buildings.append(dict(poly=p, lv=levels_of(t), name=t.get("name", ""), kind=t["building"]))
    elif "highway" in t and e["type"] == "way":
        pts = [P(p) for p in e["geometry"] if p]
        if len(pts) >= 2:
            ln = LineString(pts).intersection(board)
            if not ln.is_empty:
                lanes = int(t["lanes"]) if t.get("lanes", "").isdigit() else None
                roads.append(dict(line=ln, cls=t["highway"], lanes=lanes, name=t.get("name", "")))
    elif t.get("leisure") == "park" and e["type"] == "way":
        p = poly_of(e["geometry"])
        if p is not None:
            p = p.intersection(board)
            if p.area > 300: parks.append(p)
    elif e["type"] == "relation" and t.get("name") == "석촌호수":
        outer = [LineString([P(p) for p in m["geometry"] if p]) for m in e["members"] if m["role"] == "outer"]
        inner = [LineString([P(p) for p in m["geometry"] if p]) for m in e["members"] if m["role"] == "inner"]
        o = unary_union(list(polygonize(outer))); i = unary_union(list(polygonize(inner)))
        lake = o.difference(i).intersection(board); islands = i.intersection(board)
    elif e["type"] == "node" and (t.get("amenity") or t.get("railway")):
        x, y = P(e)
        if 0 < x < W and 0 < y < H: pois.append(dict(x=x, y=y, kind=t.get("amenity") or "station", name=t.get("name", "")))

# 층수 추정 (태그 없는 건물): 용도와 바닥 면적으로
for b in buildings:
    if b["lv"] is None:
        a = b["poly"].area
        b["lv"] = 15 if b["kind"] == "apartments" else (4 if a < 400 else 6 if a < 1500 else 8)
        b["est"] = True

# --- 도로 실제 폭 추정 (한 way 기준, 차로 수 있으면 사용) ---
REAL = dict(trunk=16, trunk_link=8, primary=18, primary_link=8, secondary=14, tertiary=11, busway=4,
            residential=7, unclassified=7, living_street=6, service=5, pedestrian=6)
def real_w(r):
    if r["lanes"]: return r["lanes"] * 3.3 + 5
    return REAL.get(r["cls"], 0)
DRIVE = set(REAL)
ART = {"trunk", "primary", "secondary"}
MINOR = {"tertiary", "residential", "unclassified", "living_street", "service", "pedestrian"}

def area_share(g): return g.intersection(board).area / board.area
real_union = unary_union([r["line"].buffer(real_w(r) / 2) for r in roads if r["cls"] in DRIVE])
bld_union = unary_union([b["poly"] for b in buildings])

def eaten(corr):
    lost = sum(1 for b in buildings if b["poly"].intersection(corr).area > 0.5 * b["poly"].area)
    return lost
report = {}
report["board"] = dict(W=W, H=H, mpp=round(MPP, 2), ball=BALL, buildings=len(buildings),
                       with_levels=sum(1 for b in buildings if not b.get("est")))
report["real_share"] = round(area_share(real_union), 3)
# 시나리오 A: 모든 차도를 공이 지나갈 폭(공 지름 2배)으로
allwide = unary_union([r["line"].buffer(BALL) for r in roads if r["cls"] in DRIVE])
report["A_all_roads_2ball"] = dict(share=round(area_share(allwide), 3), eaten=eaten(allwide))
# 시나리오 B: 대로만 넓힘
GW = dict(trunk=2.4 * BALL, primary=2.4 * BALL, secondary=2.0 * BALL)
corr = unary_union([r["line"].buffer(GW[r["cls"]] / 2) for r in roads if r["cls"] in ART]).intersection(board)
corr = corr.buffer(-6).buffer(12).buffer(-6).simplify(2)   # 자잘한 틈 정리
report["B_arterials"] = dict(share=round(area_share(corr), 3), eaten=eaten(corr), widths={k: round(v) for k, v in GW.items()})
# 대로의 실제 폭 (양방향 합친 띠의 평균 폭 = 면적 / 중심선 길이의 절반 근사)
for cls in ("trunk", "primary", "secondary", "tertiary", "residential"):
    rs = [r for r in roads if r["cls"] == cls]
    if rs:
        u = unary_union([r["line"].buffer(real_w(r) / 2) for r in rs])
        report.setdefault("real_px", {})[cls] = dict(len_km=round(sum(r["line"].length for r in rs) / 1000, 1),
            one_way_w=round(sum(real_w(r) * r["line"].length for r in rs) / sum(r["line"].length for r in rs), 1))

# --- 셀: 대로 사이 블록을 작은 길로 쪼갠다 ---
solid = board.difference(corr)
if lake is not None: solid = solid.difference(lake.buffer(2))
cuts = unary_union([r["line"].buffer(2.0) for r in roads if r["cls"] in MINOR and r["cls"] != "service"])
pieces = []
for g in getattr(solid.difference(cuts), "geoms", [solid.difference(cuts)]):
    if g.geom_type == "Polygon" and g.area > 30: pieces.append(g)
# 큰 조각은 건물 중심으로 다시 나눈다 (아파트 단지)
BIG = 28000
split = []
for g in pieces:
    inside = [b for b in buildings if g.contains(b["poly"].representative_point())]
    if g.area > BIG and len(inside) >= 2:
        vor = voronoi_polygons(MultiPoint([b["poly"].centroid for b in inside]), extend_to=g)
        for v in vor.geoms:
            c = v.intersection(g)
            for cc in getattr(c, "geoms", [c]):
                if cc.geom_type == "Polygon" and cc.area > 30: split.append(cc)
    else: split.append(g)
# 작은 셀은 가장 길게 맞닿은 이웃에 합친다
MIN = 5200
cells = [c.buffer(2.2).buffer(-0.2) for c in split]   # 틈 메우기
changed = True
while changed:
    changed = False
    cells.sort(key=lambda c: c.area)
    for i, c in enumerate(cells):
        if c.area >= MIN: break
        best, bl = None, 0
        for j, o in enumerate(cells):
            if j == i or not c.intersects(o): continue
            l = c.intersection(o).area
            if l > bl: best, bl = j, l
        if best is not None:
            m = unary_union([c, cells[best]])
            if m.geom_type == "Polygon":
                cells[best] = m; cells.pop(i); changed = True; break
        # 이웃이 없으면 그대로 둔다
    else: break
cells = [c.buffer(-2.0).simplify(1.5) for c in cells]
cells = [max(getattr(c, "geoms", [c]), key=lambda x: x.area) for c in cells if not c.is_empty]
cells = [c for c in cells if c.geom_type == "Polygon" and c.area > 600]

# 너무 큰 구획은 쪼갠다. 긴 쪽을 가로지르는 선으로 반씩 나누기를 되풀이한다.
MAX_AREA = 15000
def split_big(c, depth=0):
    if c.area <= MAX_AREA or depth > 6: return [c]
    r = c.minimum_rotated_rectangle
    xs, ys = r.exterior.coords.xy
    e1 = (xs[1] - xs[0], ys[1] - ys[0]); e2 = (xs[2] - xs[1], ys[2] - ys[1])
    long = e1 if math.hypot(*e1) >= math.hypot(*e2) else e2
    n = math.hypot(*long)
    if n < 1: return [c]
    px, py = -long[1] / n, long[0] / n
    cx, cy = c.centroid.x, c.centroid.y
    cut = LineString([(cx - px * 3000, cy - py * 3000), (cx + px * 3000, cy + py * 3000)]).buffer(2.0)
    out = []
    for g in getattr(c.difference(cut), "geoms", [c.difference(cut)]):
        if g.geom_type == "Polygon" and g.area > 900: out += split_big(g, depth + 1)
    return out or [c]
cells = [part for c in cells for part in split_big(c)]

def hp_of(lv): return 1 if lv <= 3 else 2 if lv <= 10 else 3 if lv <= 25 else 4
cell_out = []
tower = max(buildings, key=lambda b: b["lv"])
for c in cells:
    inside = [b for b in buildings if c.contains(b["poly"].representative_point())]
    lv = max([b["lv"] for b in inside], default=1)
    cell_out.append(dict(poly=c, hp=hp_of(lv), n=len(inside), landmark=tower in inside))
areas = sorted(c["poly"].area for c in cell_out)
report["cells"] = dict(count=len(cell_out), median_area=round(areas[len(areas) // 2]), min=round(areas[0]), max=round(areas[-1]),
                       hp=dict(collections.Counter(c["hp"] for c in cell_out)), empty=sum(1 for c in cell_out if c["n"] == 0))
report["tower"] = dict(name=tower["name"], lv=tower["lv"], at=[round(v) for v in tower["poly"].centroid.coords[0]])
if lake is not None:
    report["lake"] = dict(area=round(lake.area), islands=[dict(at=[round(v) for v in g.centroid.coords[0]], area=round(g.area)) for g in getattr(islands, "geoms", [islands]) if not g.is_empty])
# 건물 분포 (기준선에서 위로 4등분)
report["bld_by_quarter"] = [sum(1 for b in buildings if q * H / 4 <= b["poly"].centroid.y < (q + 1) * H / 4) for q in range(4)]
report["bld_cover_by_quarter"] = [round(bld_union.intersection(box(0, q * H / 4, W, (q + 1) * H / 4)).area / (W * H / 4), 3) for q in range(4)]
print(json.dumps(report, ensure_ascii=False, indent=1))

def ring(p, nd=0):
    return [round(v, nd) if nd else int(round(v)) for xy in list(p.exterior.coords)[:-1] for v in xy]
def lines(g):
    gs = getattr(g, "geoms", [g])
    return [[int(round(v)) for xy in l.coords for v in xy] for l in gs if l.geom_type == "LineString"]
RW = {**REAL}
out = dict(
    W=W, H=H, ball=BALL, mpp=round(MPP, 3), report=report,
    buildings=[dict(p=ring(b["poly"].simplify(0.6), 1), lv=b["lv"], lm=1 if b["name"] == tower["name"] and b["lv"] == tower["lv"] else 0) for b in buildings],
    roads=[dict(l=l, c=r["cls"], w=round(real_w(r), 1)) for r in roads if r["cls"] in DRIVE for l in lines(r["line"])],
    cells=[dict(p=ring(c["poly"]), hp=c["hp"], lm=1 if c["landmark"] else 0, e=1 if c["n"] == 0 else 0) for c in cell_out],
    corridors=[dict(p=ring(g), h=[ring(Polygon(i)) for i in g.interiors]) for g in getattr(corr, "geoms", [corr])],
    lake=[dict(p=ring(g), h=[ring(Polygon(i)) for i in g.interiors]) for g in getattr(lake, "geoms", [lake])] if lake is not None else [],
    parks=[ring(g) for p in parks for g in getattr(p, "geoms", [p]) if g.geom_type == "Polygon"],
    pois=[dict(x=round(p["x"]), y=round(p["y"]), k=p["kind"], n=p["name"]) for p in pois if p["kind"] in ("fuel", "police", "pharmacy", "station")],
)
json.dump(out, open(OUT, "w"), ensure_ascii=False, separators=(",", ":"))
print("bytes", len(json.dumps(out, ensure_ascii=False, separators=(",", ":"))))
