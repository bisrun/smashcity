#!/usr/bin/env python3
"""기획서 점검.

확인하는 것:
  1. 마크다운 문서의 상대 링크가 실제 파일을 가리키는가
  2. docs/ 의 번호 붙은 문서가 모두 docs/README.md 목차에 있는가
  3. docs/stages/ 의 스테이지 기획서가 모두 docs/04_stage_map.md 에 걸려 있는가
  4. 본문에 [미결정] 이 있는 문서가 결정 기록의 미결정 표에서 참조되는가

내용의 어긋남(숫자, 용어, 낡은 서술)은 잡지 못한다. 그것은 doc-keeper 에이전트가 본다.

실행: python3 tools/check_docs.py  (저장소 루트에서)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
CODE_FENCE = re.compile(r"```.*?```", re.S)
INLINE_CODE = re.compile(r"`[^`\n]*`")


def markdown_files() -> list[Path]:
    files = [ROOT / "README.md", ROOT / "CLAUDE.md"]
    files += sorted(DOCS.rglob("*.md"))
    files += sorted((ROOT / ".claude").rglob("*.md"))
    return [f for f in files if f.is_file()]


def links_in(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    text = CODE_FENCE.sub("", text)
    text = INLINE_CODE.sub("", text)
    return LINK.findall(text)


def check_links(errors: list[str]) -> None:
    for path in markdown_files():
        for target in links_in(path):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                continue
            file_part = target.split("#", 1)[0]
            if not file_part:
                continue
            resolved = (path.parent / file_part).resolve()
            if not resolved.exists():
                errors.append(f"깨진 링크: {path.relative_to(ROOT)} → {target}")


def check_index(errors: list[str]) -> None:
    index = (DOCS / "README.md").read_text(encoding="utf-8")
    for doc in sorted(DOCS.glob("[0-9][0-9]_*.md")):
        if f"({doc.name})" not in index:
            errors.append(f"목차 누락: docs/README.md 에 {doc.name} 이 없다")


def check_stages(errors: list[str]) -> None:
    stage_map = (DOCS / "04_stage_map.md").read_text(encoding="utf-8")
    for doc in sorted((DOCS / "stages").glob("*.md")):
        if doc.name.startswith("_"):
            continue
        if f"(stages/{doc.name})" not in stage_map:
            errors.append(
                f"스테이지 목록 누락: docs/04_stage_map.md 에 stages/{doc.name} 이 없다"
            )


def check_open_questions(errors: list[str]) -> None:
    log = (DOCS / "90_decision_log.md").read_text(encoding="utf-8")
    match = re.search(r"^## 미결정\n(.*?)(?=^## )", log, re.S | re.M)
    open_table = match.group(1) if match else ""
    for doc in sorted(DOCS.glob("[0-9][0-9]_*.md")):
        if doc.name in ("90_decision_log.md", "91_glossary.md"):
            continue
        text = INLINE_CODE.sub("", doc.read_text(encoding="utf-8"))
        if "[미결정]" in text and f"({doc.name})" not in open_table:
            errors.append(
                f"결정 기록 누락: {doc.name} 에 [미결정] 이 있으나 "
                "90_decision_log.md 미결정 표에 이 문서를 가리키는 질문이 없다"
            )


def main() -> int:
    errors: list[str] = []
    check_links(errors)
    check_index(errors)
    check_stages(errors)
    check_open_questions(errors)

    if errors:
        for error in errors:
            print(error)
        print(f"\n실패: {len(errors)}건")
        return 1

    print(f"통과: 문서 {len(markdown_files())}개 점검")
    return 0


if __name__ == "__main__":
    sys.exit(main())
