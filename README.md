# SmashCity

OSM 지도를 배경으로 한 3D 벽돌깨기 게임. 도로가 공의 통로이고 건물이 벽돌이다.
Flutter로 만들며 안드로이드를 먼저 내고 이후 아이폰을 지원한다.

기획서는 [docs/README.md](docs/README.md)에서 시작한다.

## 폴더 구조

```
smashcity/
├─ android/                 안드로이드 러너 (iOS는 추후 `flutter create --platforms ios .`)
├─ lib/
│  ├─ main.dart
│  ├─ app/                  앱 셸: 라우팅, 테마, 초기화
│  ├─ core/                 공용 유틸, 상수, 수학
│  ├─ data/                 스테이지 파일 모델, 로더, 저장소
│  ├─ game/                 게임 런타임
│  │  ├─ sim/               2D 판정·물리. 순수 Dart (Flutter import 금지)
│  │  ├─ render/            3D 렌더와 연출. sim 상태를 읽기만 한다
│  │  ├─ entities/          공, 패들, 벽돌, 블록, 랜드마크
│  │  ├─ items/             아이템 정의와 효과
│  │  ├─ catharsis/         터짐, 도미노
│  │  ├─ stage/             스테이지 구성, 클리어·실패 판정
│  │  ├─ scoring/           점수, 콤보, 별
│  │  └─ input/             터치 입력 → 패들
│  ├─ meta/                 진행, 해금, 도감, 세이브
│  └─ ui/
│     ├─ screens/           타이틀, 도시 선택, 스테이지 선택, 결과
│     ├─ hud/               플레이 중 HUD
│     └─ widgets/           공용 위젯
├─ assets/
│  ├─ stages/<city>/<stage>/  map.json (OSM 가공) + design.json (수작업 기획)
│  ├─ models/  textures/  audio/  fonts/
├─ tools/
│  └─ stage_baker/          OSM → 스테이지 파일 변환 (오프라인 도구)
├─ test/
│  └─ game/sim/             판정 로직 단위 테스트
└─ docs/                    기획서
```

구조의 핵심 규칙은 두 가지다.

- `lib/game/sim`은 Flutter에 의존하지 않는다. 그래야 렌더러를 바꿀 수 있고, 봇이 화면 없이 수천 판을 돌려 스테이지를 검증할 수 있다.
- 스테이지 데이터는 `map.json`(OSM에서 가공, ODbL 적용)과 `design.json`(아이템·HP·기믹 등 수작업)으로 나눈다. 이유는 [docs/13_data_pipeline.md](docs/13_data_pipeline.md)에 있다.

## 실행

```
flutter run
```

지금은 `flutter create` 기본 앱 상태다.

## 데이터 출처

지도 데이터 © OpenStreetMap contributors, ODbL.
