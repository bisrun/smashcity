#!/usr/bin/env python3
"""스테이지 굽기. world.json 에 적힌 자리의 OSM 데이터를 받아 map.json 을 만든다.

docs/03_map_conversion.md 와 docs/13_data_pipeline.md 의 규칙을 따른다. shapely 가 필요하다.

실행 (저장소 루트에서):
  python3 tools/stage_baker/bake.py all            # 아직 굽지 않은 스테이지를 모두 굽는다
  python3 tools/stage_baker/bake.py paris/eiffel   # 하나만 다시 굽는다
  python3 tools/stage_baker/bake.py all --force    # 모두 다시 굽는다

OSM 원본은 tools/stage_baker/.cache/ 에 받아 두고 커밋하지 않는다. 결과는 assets/stages/<지역>/<스테이지>/map.json 이다.
map.json 은 OSM 에서 나온 것이므로 손으로 고치지 않는다(ODbL). 손으로 정하는 것은 design.json 에 둔다.
"""
import collections
import json
import math
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from shapely import make_valid, voronoi_polygons
from shapely.geometry import LineString, MultiPoint, Point, Polygon, box
from shapely.ops import polygonize, unary_union

ROOT = Path(__file__).resolve().parent.parent.parent
HERE = Path(__file__).resolve().parent
CACHE = HERE / ".cache"
STAGES = ROOT / "assets" / "stages"

# 판 크기. 서울의 위도에서 OSM 줌 15(축척 막대 300m)를 세로 폰에 댄 크기이고, 모든 도시에 같은 크기를 쓴다.
# 공의 빠르기와 패들 폭이 이 크기에 맞춰져 있어서, 도시마다 판 크기가 다르면 난이도를 견줄 수 없다.
W, H = 1478, 2628
BALL = 38
BOARD = box(0, 0, W, H)

ENDPOINTS = ["https://overpass.openstreetmap.fr/api/interpreter", "https://overpass-api.de/api/interpreter",
             "https://overpass.kumi.systems/api/interpreter", "https://overpass.private.coffee/api/interpreter"]

REAL = dict(trunk=16, trunk_link=8, primary=18, primary_link=8, secondary=14, tertiary=11, busway=4,
            residential=7, unclassified=7, living_street=6, service=5, pedestrian=6)
ART = ["trunk", "primary", "secondary"]
MINOR = {"tertiary", "residential", "unclassified", "living_street", "pedestrian"}
BIG, MIN, MAX_AREA = 28000, 5200, 15000

# 부수지 않는 시설 (docs/03_map_conversion.md)
PROTECTED_BUILDINGS = {"church", "cathedral", "chapel", "mosque", "temple", "shrine", "synagogue", "monastery", "hospital", "religious"}
PROTECTED_HISTORIC = {"memorial", "monument", "castle", "palace", "ruins", "archaeological_site", "temple", "church", "city_gate", "fort", "tomb", "shrine"}
GREEN_LEISURE = {"park", "garden", "nature_reserve", "golf_course"}
GREEN_LANDUSE = {"grass", "forest", "meadow", "village_green", "recreation_ground"}


def is_protected(t):
    if t.get("amenity") in ("place_of_worship", "hospital", "grave_yard"):
        return True
    if t.get("building") in PROTECTED_BUILDINGS:
        return True
    if t.get("historic") in PROTECTED_HISTORIC:
        return True
    return t.get("landuse") in ("cemetery", "religious")


def fetch(stage):
    """스테이지 둘레의 OSM 데이터를 받는다. 이미 받았으면 그것을 쓴다."""
    CACHE.mkdir(exist_ok=True)
    path = CACHE / (stage["key"].replace("/", "__") + ".json")
    if path.exists() and path.stat().st_size > 1000:
        return json.loads(path.read_text())["elements"]
    reach = math.hypot(W, H) / 2 + 40 if stage["rot"] % 180 else None
    hw = reach or W / 2 + 40
    hh = reach or H / 2 + 40
    dlat = hh / 110950
    dlon = hw / (111320 * math.cos(math.radians(stage["lat"])))
    b = "%.5f,%.5f,%.5f,%.5f" % (stage["lat"] - dlat, stage["lon"] - dlon, stage["lat"] + dlat, stage["lon"] + dlon)
    q = f"""[out:json][timeout:120];
(
  way["building"]({b}); relation["building"]({b});
  way["highway"~"^(trunk|primary|secondary|tertiary|residential|unclassified|living_street|pedestrian|trunk_link|primary_link)$"]({b});
  way["natural"~"^(water|coastline|wood)$"]({b}); relation["natural"="water"]({b});
  way["waterway"="riverbank"]({b}); relation["waterway"="riverbank"]({b});
  way["leisure"~"^(park|garden|nature_reserve|golf_course)$"]({b}); relation["leisure"~"^(park|garden)$"]({b});
  way["landuse"~"^(grass|forest|meadow|village_green|recreation_ground|cemetery|religious)$"]({b});
  way["historic"]({b}); relation["historic"]({b});
  way["amenity"~"^(place_of_worship|hospital|grave_yard)$"]({b}); relation["amenity"~"^(place_of_worship|hospital)$"]({b});
  node["amenity"~"^(fuel|pharmacy|police|parking|bank)$"]({b});
);
out geom({b});"""
    last = None
    for attempt in range(8):
        url = ENDPOINTS[attempt % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(url, data=urllib.parse.urlencode({"data": q}).encode(),
                                         headers={"User-Agent": "stage-baker/1.0"})
            with urllib.request.urlopen(req, timeout=150) as r:
                text = r.read().decode("utf-8")
            data = json.loads(text)
            if "elements" in data and len(data["elements"]) > 0:
                path.write_text(text)
                time.sleep(2)
                return data["elements"]
            last = "빈 결과"
        except Exception as e:  # 서버가 바쁘면 잠깐 쉬었다가 다시
            last = repr(e)[:120]
        time.sleep(4 + attempt * 4)
    raise RuntimeError("OSM 을 받지 못했다: %s (%s)" % (stage["key"], last))


def bake(stage, raw):
    lat0, lon0 = stage["lat"], stage["lon"]
    kx, ky = 111320 * math.cos(math.radians(lat0)), 110950
    th = math.radians(stage["rot"])
    cs, sn = math.cos(th), math.sin(th)

    def P(p):   # 화면 왼쪽 아래가 원점. y 는 패들에서 멀어지는 쪽으로 자란다.
        e, n = (p["lon"] - lon0) * kx, (p["lat"] - lat0) * ky
        return (W / 2 + e * cs - n * sn, H / 2 + e * sn + n * cs)

    def ring_poly(geom):
        pts = [P(p) for p in geom if p]
        if len(pts) < 4:
            return None
        g = make_valid(Polygon(pts))
        return None if g.is_empty else g

    def area_of(e):
        """way 나 멀티폴리곤 relation 을 면으로."""
        if e["type"] == "way":
            g = ring_poly(e.get("geometry", []))
            return g
        outer = [LineString([P(p) for p in m["geometry"] if p]) for m in e.get("members", [])
                 if m.get("role") in ("outer", "") and m.get("geometry") and len(m["geometry"]) >= 2]
        inner = [LineString([P(p) for p in m["geometry"] if p]) for m in e.get("members", [])
                 if m.get("role") == "inner" and m.get("geometry") and len(m["geometry"]) >= 2]
        if not outer:
            return None
        o = unary_union(list(polygonize(unary_union(outer))))
        if inner:
            o = o.difference(unary_union(list(polygonize(unary_union(inner)))))
        return None if o.is_empty else make_valid(o)

    def open_water(e):
        """큰 강은 판 밖으로 이어져 고리가 닫히지 않는다. 강둑 선과 판의 테두리로 조각을 낸 뒤, 건물이 없는 조각을 물로 본다."""
        banks = []
        for m in e.get("members", []):
            pts = [P(p) for p in (m.get("geometry") or []) if p]   # 받아 온 범위 밖의 점은 비어 있다
            if len(pts) >= 2:
                banks.append(LineString(pts))
        if not banks:
            return None
        found = []
        for piece in polygonize(unary_union(banks + [BOARD.exterior])):
            inner = piece.intersection(BOARD)
            if inner.area < 2000 or inner.area > 0.45 * BOARD.area:
                continue
            covered = sum(b["poly"].area for b in buildings if inner.contains(b["poly"].representative_point()))
            if covered < inner.area * 0.03:   # 강 위의 배나 선착장 건물은 봐준다
                found.append(inner)
        return unary_union(found) if found else None

    def polys(g):
        return [p for p in getattr(g, "geoms", [g]) if p.geom_type == "Polygon" and not p.is_empty]

    def levels_of(t):
        try:
            if "building:levels" in t:
                return max(1, int(float(t["building:levels"])))
            if "height" in t:
                return max(1, round(float(str(t["height"]).replace("m", "").strip()) / 3.2))
        except ValueError:
            pass
        return None

    buildings, roads, greens, waters, coast, prot, pois = [], [], [], [], [], [], []
    for e in sorted(raw, key=lambda e: 0 if "building" in e.get("tags", {}) else 1):
        t = e.get("tags", {})
        if e["type"] == "node":
            if t.get("amenity"):
                x, y = P(e)
                if 0 < x < W and 0 < y < H:
                    pois.append(dict(x=x, y=y, kind=t["amenity"], name=t.get("name", "")))
            continue
        if "highway" in t and e["type"] == "way":
            pts = [P(p) for p in e["geometry"] if p]
            if len(pts) >= 2:
                ln = LineString(pts).intersection(BOARD)
                if not ln.is_empty:
                    lanes = int(t["lanes"]) if t.get("lanes", "").isdigit() else None
                    roads.append(dict(line=ln, cls=t["highway"], lanes=lanes))
            continue
        if t.get("natural") == "coastline" and e["type"] == "way":
            pts = [P(p) for p in e["geometry"] if p]
            if len(pts) >= 2:
                coast.append(LineString(pts))
            continue
        try:
            g = area_of(e)
        except Exception:
            g = None
        if (g is None or g.area < 400) and e["type"] == "relation" and (t.get("natural") == "water" or t.get("waterway") == "riverbank"):
            g = open_water(e)
        if g is None:
            continue
        g = g.intersection(BOARD)
        if g.is_empty:
            continue
        guarded = is_protected(t)
        if "building" in t:
            names = " ".join(str(t.get(k, "")) for k in ("name", "name:en", "name:ko", "alt_name", "official_name"))
            for p in polys(g):
                if p.area >= 20:
                    buildings.append(dict(poly=p, lv=levels_of(t), names=names, kind=t["building"], guarded=guarded))
        elif t.get("natural") == "water" or t.get("waterway") == "riverbank":
            waters += [p for p in polys(g) if p.area > 400]
        elif t.get("leisure") in GREEN_LEISURE or t.get("landuse") in GREEN_LANDUSE or t.get("natural") == "wood":
            greens += [p for p in polys(g) if p.area > 300]
        if guarded and "building" not in t:
            prot += [p for p in polys(g) if p.area > 200]

    for b in buildings:
        if b["lv"] is None:
            a = b["poly"].area
            b["lv"] = 15 if b["kind"] == "apartments" else (4 if a < 400 else 6 if a < 1500 else 8)

    # --- 바다: 해안선으로 판을 가르고, 해안선의 오른쪽에 놓인 조각을 바다로 본다 (OSM 은 땅을 왼쪽에 둔다) ---
    sea = []
    if coast:
        try:
            net = unary_union(coast + [BOARD.exterior])
            for piece in polygonize(net):
                if not BOARD.contains(piece.representative_point()) or piece.area < 3000:
                    continue
                votes = 0
                for c in coast:
                    cc = list(c.coords)
                    for i in range(len(cc) - 1):
                        a, bb = cc[i], cc[i + 1]
                        mid = ((a[0] + bb[0]) / 2, (a[1] + bb[1]) / 2)
                        d = math.hypot(bb[0] - a[0], bb[1] - a[1])
                        if d < 1 or not BOARD.contains(Point(mid)):
                            continue
                        # 화면 좌표는 y 가 위로 자라므로 진행 방향의 오른쪽은 (dy, -dx) 쪽이다
                        rx, ry = (bb[1] - a[1]) / d, -(bb[0] - a[0]) / d
                        if piece.distance(Point(mid)) < 0.5:
                            votes += 1 if piece.contains(Point(mid[0] + rx * 4, mid[1] + ry * 4)) else -1
                if votes > 0:
                    sea.append(piece)
        except Exception:
            sea = []
    water = unary_union(waters + sea) if (waters or sea) else None

    def real_w(r):
        return r["lanes"] * 3.3 + 5 if r["lanes"] else REAL.get(r["cls"], 0)

    # --- 통로: 큰 도로만. 큰 도로가 너무 적은 동네는 한 등급 아래 도로까지 쓴다 ---
    def corridor(classes, width):
        parts = [r["line"].buffer(width.get(r["cls"], 2.0 * BALL) / 2) for r in roads if r["cls"] in classes]
        if not parts:
            return Polygon()
        c = unary_union(parts).intersection(BOARD)
        return c.buffer(-6).buffer(12).buffer(-6).simplify(2)

    gw = dict(trunk=2.4 * BALL, primary=2.4 * BALL, secondary=2.0 * BALL, tertiary=1.8 * BALL)
    used = list(ART)
    corr = corridor(used, gw)
    if corr.area / BOARD.area < 0.10:
        used.append("tertiary")
        corr = corridor(used, gw)
    if corr.area / BOARD.area > 0.30:   # 큰 도로가 너무 빽빽하면 가장 넓은 등급만
        used = ["trunk", "primary"]
        slim = corridor(used, gw)
        if slim.area / BOARD.area >= 0.10:
            corr = slim
        else:
            used = list(ART)
    # 물 위의 다리는 물로 치지 않는다. 그래야 강 건너로 공이 넘어간다.
    lake = None
    if water is not None:
        lake = water.intersection(BOARD).difference(corr.buffer(4)).buffer(-3).buffer(3)
        lake = unary_union([p for p in polys(lake) if p.area > 2500]) if not lake.is_empty else None
        if lake is not None and lake.is_empty:
            lake = None

    # --- 셀 ---
    solid = BOARD.difference(corr)
    if lake is not None:
        solid = solid.difference(lake.buffer(2))
    cut_lines = [r["line"].buffer(2.0) for r in roads if r["cls"] in MINOR and r["cls"] not in used]
    cuts = unary_union(cut_lines) if cut_lines else Polygon()
    pieces = [g for g in polys(solid.difference(cuts)) if g.area > 30]
    split = []
    for g in pieces:
        inside = [b for b in buildings if g.contains(b["poly"].representative_point())]
        if g.area > BIG and 2 <= len(inside) <= 400:
            vor = voronoi_polygons(MultiPoint([b["poly"].centroid for b in inside]), extend_to=g)
            for v in vor.geoms:
                split += [cc for cc in polys(v.intersection(g)) if cc.area > 30]
        else:
            split.append(g)
    cells = [c.buffer(2.2).buffer(-0.2) for c in split]
    # 작은 셀은 가장 넓게 맞닿은 이웃에 합친다
    from shapely import STRtree
    guard = 0
    while guard < 20000:
        guard += 1
        cells.sort(key=lambda c: c.area)
        if not cells or cells[0].area >= MIN:
            break
        tree = STRtree(cells)
        merged = False
        for i, c in enumerate(cells):
            if c.area >= MIN:
                break
            best, bl = None, 0
            for j in tree.query(c):
                if j == i:
                    continue
                l = c.intersection(cells[j]).area
                if l > bl:
                    best, bl = int(j), l
            if best is not None:
                m = unary_union([c, cells[best]])
                if m.geom_type == "Polygon":
                    cells[best] = m
                    cells.pop(i)
                    merged = True
                    break
        if not merged:
            break
    cells = [c.buffer(-2.0).simplify(1.5) for c in cells]
    cells = [max(polys(c), key=lambda x: x.area) for c in cells if polys(c)]
    cells = [c for c in cells if c.area > 600]

    def split_big(c, depth=0):
        if c.area <= MAX_AREA or depth > 6:
            return [c]
        r = c.minimum_rotated_rectangle
        xs, ys = r.exterior.coords.xy
        e1 = (xs[1] - xs[0], ys[1] - ys[0])
        e2 = (xs[2] - xs[1], ys[2] - ys[1])
        long = e1 if math.hypot(*e1) >= math.hypot(*e2) else e2
        n = math.hypot(*long)
        if n < 1:
            return [c]
        px, py = -long[1] / n, long[0] / n
        cx, cy = c.centroid.x, c.centroid.y
        cut = LineString([(cx - px * 3000, cy - py * 3000), (cx + px * 3000, cy + py * 3000)]).buffer(2.0)
        out = []
        for g in polys(c.difference(cut)):
            if g.area > 900:
                out += split_big(g, depth + 1)
        return out or [c]
    cells = [part for c in cells for part in split_big(c)]

    # --- 셀의 성격: 건물, 숲, 부수지 않는 시설 ---
    def hp_of(lv):
        return 1 if lv <= 3 else 2 if lv <= 10 else 3 if lv <= 25 else 4

    from shapely import STRtree as Tree
    btree = Tree([b["poly"] for b in buildings]) if buildings else None
    green = unary_union(greens) if greens else None
    guarded_area = unary_union(prot + [b["poly"] for b in buildings if b["guarded"]]) if (prot or any(b["guarded"] for b in buildings)) else None
    cell_out = []
    for k, c in enumerate(cells):
        inside = []
        if btree is not None:
            inside = [buildings[int(j)] for j in btree.query(c) if c.contains(buildings[int(j)]["poly"].representative_point())]
        open_inside = [b for b in inside if not b["guarded"]]
        built = sum(b["poly"].area for b in inside) / c.area
        g_share = green.intersection(c).area / c.area if green is not None else 0.0
        p_share = guarded_area.intersection(c).area / c.area if guarded_area is not None else 0.0
        is_solid = p_share > 0.3 or (guarded_area is not None and guarded_area.intersection(c).area > 3000)
        is_park = (not is_solid) and g_share > 0.6 and built < 0.08
        if open_inside:
            hp = hp_of(max(b["lv"] for b in open_inside))
        else:
            # 건물 자료가 없는 셀은 상상으로 채운다. 자리마다 늘 같은 높이가 나오게 좌표로 정한다.
            hp = 1 + (int(c.centroid.x) * 7 + int(c.centroid.y) * 13) % 3
        cell_out.append(dict(poly=c, hp=1 if is_park else hp, park=is_park, solid=is_solid, inside=inside, lm=False))

    # --- 목표 건물 ---
    depth = stage.get("depth", 0.5)   # 패들에서 판 세로의 몇 할 깊이에 목표를 둘지
    hints = [h.lower() for h in stage.get("landmark", "").split("|") if h]
    cands = [b for b in buildings if not b["guarded"] and b["poly"].area >= 150 and 0.2 * H < b["poly"].centroid.y < 0.94 * H]
    target = None
    named = [b for b in cands if any(h in b["names"].lower() for h in hints)] if hints else []
    if named:
        target = max(named, key=lambda b: (b["lv"], b["poly"].area))
    elif cands:
        def score(b):
            off = abs(b["poly"].centroid.y / H - depth)
            side = abs(b["poly"].centroid.x / W - 0.5)
            return b["lv"] * (1.0 - min(0.8, off * 1.6)) * (1.0 - min(0.5, max(0.0, side - 0.3) * 2.0))
        target = max(cands, key=score)
    lm_cell = None
    if target is not None:
        at = target["poly"].representative_point()
        for c in cell_out:
            if c["poly"].contains(at):
                lm_cell = c
                break
    if lm_cell is None:   # 건물 자료가 없으면 알맞은 깊이의 셀 하나를 목표로 삼는다
        open_cells = [c for c in cell_out if not c["solid"]]
        lm_cell = min(open_cells, key=lambda c: abs(c["poly"].centroid.y / H - depth) + abs(c["poly"].centroid.x / W - 0.5))
        target = None
    lm_cell.update(lm=True, solid=False, park=False)
    # 목표 건물의 바닥 모양. 너무 크거나 작으면 탑이 어색하므로 알맞은 크기의 둥근 바닥으로 바꾼다.
    if target is not None and 700 <= target["poly"].area <= 5000 and lm_cell["poly"].contains(target["poly"].centroid):
        foot = target["poly"].simplify(1.0)
    else:
        centre = lm_cell["poly"].representative_point()
        foot = Point(centre.x, centre.y).buffer(min(36.0, math.sqrt(lm_cell["poly"].area) * 0.3), 6)
    lm_name = (target["names"].split("  ")[0].strip() if target is not None else "") or stage["name"]

    def ring(p, nd=0):
        return [round(v, nd) if nd else int(round(v)) for xy in list(p.exterior.coords)[:-1] for v in xy]

    def lines(g):
        return [[int(round(v)) for xy in l.coords for v in xy] for l in getattr(g, "geoms", [g]) if l.geom_type == "LineString"]

    areas = sorted(c["poly"].area for c in cell_out)
    report = dict(
        cells=len(cell_out), median_area=round(areas[len(areas) // 2]),
        parks=sum(1 for c in cell_out if c["park"]), solid=sum(1 for c in cell_out if c["solid"]),
        imagined=sum(1 for c in cell_out if not c["inside"] and not c["park"] and not c["solid"]),
        hp=dict(sorted(collections.Counter(c["hp"] for c in cell_out if not c["park"] and not c["solid"]).items())),
        corridor_share=round(corr.area / BOARD.area, 3), corridor_classes=used,
        water_share=round(lake.area / BOARD.area, 3) if lake is not None else 0.0,
        buildings=len(buildings), landmark=lm_name,
        landmark_at=[round(lm_cell["poly"].centroid.x), round(lm_cell["poly"].centroid.y)],
        landmark_depth=round(lm_cell["poly"].centroid.y / H, 2),
    )
    shown = [b for b in buildings if b["poly"].area >= 400 and not b["guarded"]]
    shown.sort(key=lambda b: -b["poly"].area)
    out = dict(
        W=W, H=H, ball=BALL, source="© OpenStreetMap contributors, ODbL", center=[lat0, lon0], rot=stage["rot"], report=report,
        buildings=[dict(p=ring(foot, 1), lv=target["lv"] if target is not None else 30, lm=1)]
        + [dict(p=ring(b["poly"].simplify(1.2), 0), lv=b["lv"], lm=0) for b in shown[:500]],
        roads=[dict(l=l, c=r["cls"], w=round(real_w(r), 1)) for r in roads if r["cls"] in used or r["cls"] == "tertiary" for l in lines(r["line"])],
        cells=[{k: v for k, v in dict(p=ring(c["poly"]), hp=c["hp"], lm=1 if c["lm"] else 0, e=1 if c["park"] else 0, s=1 if c["solid"] else 0).items() if k in ("p", "hp") or v}
               for c in cell_out],
        corridors=[dict(p=ring(g), h=[ring(Polygon(i)) for i in g.interiors]) for g in polys(corr)],
        lake=[dict(p=ring(g.simplify(1.5)), h=[]) for g in polys(lake)] if lake is not None else [],
        parks=[ring(g.simplify(2.0)) for g in polys(green.intersection(BOARD)) if g.area > 1500] if green is not None else [],
        pois=[dict(x=round(p["x"]), y=round(p["y"]), k=p["kind"], n=p["name"]) for p in pois if p["kind"] in ("fuel", "police", "pharmacy", "parking", "bank")][:60],
    )
    return out, report


def all_stages():
    world = json.loads((HERE / "world.json").read_text())
    out = []
    for ri, region in enumerate(world["regions"]):
        for si, s in enumerate(region["stages"]):
            out.append(dict(s, key=region["id"] + "/" + s["id"], region=region["id"], region_name=region["name"],
                            theme=s.get("theme", region["theme"]), rot=s.get("rot", 0), index=ri * 10 + si, order=si, region_index=ri))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    want = args or ["all"]
    failed = []
    for stage in all_stages():
        if "all" not in want and stage["key"] not in want:
            continue
        if stage.get("bake") is False:
            continue
        target = STAGES / stage["region"] / stage["id"] / "map.json"
        if target.exists() and not force and "all" in want:
            continue
        # 뒤 스테이지일수록 목표가 깊다
        stage.setdefault("depth", round(0.42 + 0.04 * stage["order"], 2))
        try:
            out, report = bake(stage, fetch(stage))
        except Exception as e:
            failed.append(stage["key"])
            print("실패", stage["key"], repr(e)[:200], flush=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        text = json.dumps(out, ensure_ascii=False, separators=(",", ":"))
        target.write_text(text, encoding="utf-8")
        print(stage["key"], len(text) // 1024, "KB", json.dumps(report, ensure_ascii=False), flush=True)
    if failed:
        print("실패한 스테이지:", " ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
