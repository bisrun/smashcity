"""잠실 OSM 데이터로 통로와 네모 벽돌을 만들고 수치를 재는 실험 스크립트.

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

# --- 셀: 큰 도로 사이의 블록을 네모로 차곡차곡 채운다 ---
# 블록의 긴 쪽에 맞춰 줄을 나누고, 줄마다 들어가는 만큼 네모를 놓는다. 네모 사이에는 골목만큼 틈을 둔다.
# 블록의 굽은 가장자리에 남는 자투리는 벽돌이 아닌 빈 땅으로 둔다.
from shapely import affinity
ROW_H, BRICK_W, ALLEY, MIN_W, MIN_H = 88.0, 118.0, 9.0, 54.0, 40.0
solid = board.difference(corr)
if lake is not None: solid = solid.difference(lake.buffer(2))
blocks = [g for g in getattr(solid, "geoms", [solid]) if g.geom_type == "Polygon" and g.area > 400]

def spans(poly, y):
    """가로선 y 가 다각형 안을 지나는 x 구간들."""
    hit = poly.intersection(LineString([(poly.bounds[0] - 5, y), (poly.bounds[2] + 5, y)]))
    out = []
    for g in getattr(hit, "geoms", [hit]):
        if g.geom_type == "LineString" and not g.is_empty:
            xs = [c[0] for c in g.coords]; out.append((min(xs), max(xs)))
    return sorted(out)

def overlap(a, b):
    out = []
    for x0, x1 in a:
        for u0, u1 in b:
            lo, hi = max(x0, u0), min(x1, u1)
            if hi - lo > 1: out.append((lo, hi))
    return out

def pack(block):
    mrr = block.minimum_rotated_rectangle
    xs, ys = mrr.exterior.coords.xy
    e1 = (xs[1] - xs[0], ys[1] - ys[0]); e2 = (xs[2] - xs[1], ys[2] - ys[1])
    long = e1 if math.hypot(*e1) >= math.hypot(*e2) else e2
    ang = math.degrees(math.atan2(long[1], long[0]))
    c = block.centroid
    inner = affinity.rotate(block, -ang, origin=c).buffer(-ALLEY * 0.55)
    out = []
    for part in getattr(inner, "geoms", [inner]):
        if part.is_empty or part.geom_type != "Polygon": continue
        minx, miny, maxx, maxy = part.bounds
        if maxy - miny < MIN_H: continue
        rows = max(1, round((maxy - miny) / ROW_H)); rh = (maxy - miny) / rows
        for r in range(rows):
            y0 = miny + r * rh + ALLEY / 2; y1 = miny + (r + 1) * rh - ALLEY / 2
            if y1 - y0 < MIN_H * 0.7: continue
            free = spans(part, y0 + 0.5)
            for y in (y0 + (y1 - y0) * 0.25, (y0 + y1) / 2, y0 + (y1 - y0) * 0.75, y1 - 0.5):
                free = overlap(free, spans(part, y))
            for x0, x1 in free:
                if x1 - x0 < MIN_W: continue
                n = max(1, round((x1 - x0) / BRICK_W)); w = (x1 - x0) / n
                for k in range(n):
                    rect = box(x0 + k * w + ALLEY / 2, y0, x0 + (k + 1) * w - ALLEY / 2, y1)
                    if part.buffer(1.5).contains(rect):
                        out.append(affinity.rotate(rect, ang, origin=c))
    return out

cells = []
for blk in blocks:
    cells += pack(blk)

def hp_of(lv): return 1 if lv <= 3 else 2 if lv <= 10 else 3 if lv <= 25 else 4
cell_out = []
tower = max(buildings, key=lambda b: b["lv"])
for c in cells:
    reach = c.buffer(ALLEY)
    inside = [b for b in buildings if reach.contains(b["poly"].representative_point())]
    lv = max([b["lv"] for b in inside], default=1)
    cell_out.append(dict(poly=c, hp=hp_of(lv), n=len(inside), landmark=False))
# 랜드마크는 타워에 가장 가까운 네모 하나다
tp = tower["poly"].representative_point()
min(cell_out, key=lambda c: c["poly"].distance(tp))["landmark"] = True
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
    blocks=[ring(g.simplify(1.5)) for g in blocks],
    lake=[dict(p=ring(g), h=[ring(Polygon(i)) for i in g.interiors]) for g in getattr(lake, "geoms", [lake])] if lake is not None else [],
    parks=[ring(g) for p in parks for g in getattr(p, "geoms", [p]) if g.geom_type == "Polygon"],
    pois=[dict(x=round(p["x"]), y=round(p["y"]), k=p["kind"], n=p["name"]) for p in pois if p["kind"] in ("fuel", "police", "pharmacy", "station")],
)
json.dump(out, open(OUT, "w"), ensure_ascii=False, separators=(",", ":"))
print("bytes", len(json.dumps(out, ensure_ascii=False, separators=(",", ":"))))
