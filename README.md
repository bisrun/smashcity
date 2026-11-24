# SmashCity

실제 도시의 지도를 뼈대로 삼아 상상으로 꾸민 도시에서, 도로를 따라 공을 튕겨 건물을 부수는 2.5D 벽돌깨기 게임.
Godot 4로 만들며 안드로이드를 먼저 내고 이후 아이폰을 지원한다.

기획서는 [docs/README.md](docs/README.md)에서 시작한다.

## 지금 상태

잠실 한 판을 플레이할 수 있다. 공이 통로를 따라 튀며 벽돌(작은 길로 둘러싸인 구획)을 부수고, 롯데월드타워가 선 벽돌을 부수면 클리어다. 공은 잃지 않고, 빠지면 패들로 돌아온다. 아이템과 터짐은 아직 없다.

## 폴더 구조

```
smashcity/
├─ project.godot            Godot 프로젝트 설정
├─ export_presets.cfg       안드로이드 내보내기 설정
├─ scenes/
│  └─ main.tscn             첫 장면
├─ src/
│  ├─ main.gd               첫 장면의 스크립트
│  ├─ data/                 스테이지 파일과 세이브의 모델, 읽기와 쓰기. 장면에 의존하지 않는다
│  ├─ sim/                  2D 판정. 장면에 의존하지 않는다
│  ├─ render/               2.5D 화면 표현과 연출. 상태를 읽기만 한다
│  ├─ stage/                스테이지 구성, 클리어 판정
│  ├─ items/                아이템 정의와 효과
│  ├─ catharsis/            터짐, 도미노
│  ├─ scoring/              점수, 콤보, 별
│  ├─ input/                터치 입력 → 패들
│  ├─ meta/                 진행, 해금, 도감, 세이브
│  └─ ui/                   화면과 HUD
├─ assets/
│  ├─ stages/<city>/<stage>/  map.json (OSM 가공) + design.json (수작업 기획과 상상)
│  ├─ balance.json          속도, 폭, 점수 같은 밸런스 값
│  ├─ models/  textures/  audio/  fonts/
├─ tests/
│  └─ run_tests.gd          화면 없이 도는 테스트
├─ tools/
│  ├─ check_docs.py         기획서 점검
│  └─ stage_baker/          OSM → 스테이지 파일 변환 (지금은 실험 스크립트)
└─ docs/                    기획서
```

구조의 핵심 규칙은 두 가지다.

- `src/sim`과 `src/data`는 장면 노드에 의존하지 않는다. 그래야 봇이 화면 없이 수천 판을 돌려 스테이지를 검증할 수 있다.
- 스테이지 데이터는 `map.json`(OSM에서 가공, ODbL 적용)과 `design.json`(아이템, 상상으로 더한 것 등 수작업)으로 나눈다. 이유는 [docs/13_data_pipeline.md](docs/13_data_pipeline.md)에 있다.

## 실행

```
godot --path .                                     # PC에서 실행. 마우스를 누른 채 움직이면 패들이 따라온다
SMASHCITY_AUTOPLAY=1 godot --path .                # 패들이 공을 따라다니는 자동 플레이
godot --headless --path . -s tests/run_tests.gd    # 테스트
```

안드로이드 단말기에서 실행하려면 Godot 내보내기 템플릿이 필요하다. 에디터의 "편집기 → 내보내기 템플릿 관리"에서 받는다.

```
godot --headless --path . --export-debug Android build/smashcity.apk
adb install -r build/smashcity.apk
```

## 데이터 출처

지도 데이터 © OpenStreetMap contributors, ODbL. `assets/stages/` 아래의 `map.json`은 OpenStreetMap 데이터를 가공한 것이다.
