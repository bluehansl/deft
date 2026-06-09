---
name: restore-statusline
description: set-statusline 실행 전 snapshot을 사용해 $HOME/.codex/config.toml 의 [tui].status_line 만 원복한다. 전체 config 백업은 emergency 복구용으로만 남긴다. 트리거 예시 "statusline 원복", "statusline 되돌려", "restore statusline", "rollback statusline", "/restore-statusline", "deft:restore-statusline".
---

# restore-statusline

## EXEC_IMMEDIATE

사용자가 `/restore-statusline`, `deft:restore-statusline`, 또는 자연어 트리거("statusline 원복" 등)를 입력했다는 것 자체가 "Codex status line을 원복해 달라"는 명시적 의도 표명이다. 스킬 소개, 의도 재확인, 사용법 재설명을 하지 않는다.

첫 응답은 assistant 텍스트가 아니라 아래 Bash 도구 호출로 시작한다.

## BG

- 대상 파일: `$HOME/.codex/config.toml`
- 수정 대상: `[tui]` 섹션의 `status_line` 키만
- 스냅샷 디렉토리: `$HOME/.codex/.set-statusline-snapshot/`
  - `latest` - 원복 대상 snapshot ID
  - `<snapshot-id>/meta.json` - 설치 전 존재 여부
  - `<snapshot-id>/config.toml.bak` - 설치 전 전체 config 백업, 자동 덮어쓰기 금지
  - `<snapshot-id>/status_line.toml` - 설치 전 `status_line` 원문 블록

## RUN

```bash
bash <<'BASH'
set -u

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR=python3 not found"
  echo "python3이 필요합니다. macOS에서는 Xcode Command Line Tools 또는 python.org/Homebrew Python을 설치한 뒤 다시 실행하세요."
  exit 0
fi

python3 <<'PY'
from __future__ import annotations

import datetime as _dt
import json
import os
import re
import shutil
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # Python < 3.11
    tomllib = None

CONFIG = Path(os.environ.get("CODEX_STATUSLINE_CONFIG", Path.home() / ".codex" / "config.toml")).expanduser()
SNAP_DIR = Path(os.environ.get("CODEX_STATUSLINE_SNAPSHOT_DIR", Path.home() / ".codex" / ".set-statusline-snapshot")).expanduser()


def validate_toml(text: str, label: str) -> None:
    if tomllib is None or not text.strip():
        return
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        print(f"ERROR={label}_TOML_PARSE_FAILED")
        print(str(exc))
        raise SystemExit(1)


def section_name(line: str) -> str | None:
    if line.lstrip().startswith("#"):
        return None
    match = re.match(r"^\s*\[([A-Za-z0-9_.-]+)\]\s*(?:#.*)?$", line)
    return match.group(1) if match else None


def find_tui_range(lines: list[str]) -> tuple[int | None, int]:
    start = None
    for index, line in enumerate(lines):
        name = section_name(line)
        if name is None:
            continue
        if start is not None:
            return start, index
        if name == "tui":
            start = index
    return start, len(lines)


def is_status_line_key(line: str) -> bool:
    return not line.lstrip().startswith("#") and re.match(r"^\s*status_line\s*=", line) is not None


def candidate_is_complete_status_line(candidate: str) -> bool:
    if tomllib is None:
        return False
    try:
        parsed = tomllib.loads("[tui]\n" + candidate)
    except tomllib.TOMLDecodeError:
        return False
    return "status_line" in parsed.get("tui", {})


def fallback_value_end(lines: list[str], start: int, section_end: int) -> int:
    first = lines[start].split("=", 1)[1].lstrip()
    if not first.startswith("["):
        return start + 1

    depth = 0
    in_string = False
    quote = ""
    escaped = False
    for index in range(start, section_end):
        line = lines[index]
        for char in line:
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\" and quote == '"':
                    escaped = True
                elif char == quote:
                    in_string = False
                continue
            if char in ("'", '"'):
                in_string = True
                quote = char
            elif char == "#":
                break
            elif char == "[":
                depth += 1
            elif char == "]":
                depth -= 1
        if depth <= 0:
            return index + 1
    return start + 1


def find_status_line_block(lines: list[str], section_start: int, section_end: int) -> tuple[int, int] | None:
    for index in range(section_start + 1, section_end):
        if not is_status_line_key(lines[index]):
            continue
        if tomllib is not None:
            for end in range(index + 1, section_end + 1):
                if candidate_is_complete_status_line("".join(lines[index:end])):
                    return index, end
        return index, fallback_value_end(lines, index, section_end)
    return None


def restore_status_line(text: str, original_block: str | None) -> str:
    lines = text.splitlines(keepends=True)
    tui_start, tui_end = find_tui_range(lines)

    if tui_start is not None:
        block_range = find_status_line_block(lines, tui_start, tui_end)
        if original_block is None:
            if block_range is None:
                return text
            start, end = block_range
            return "".join(lines[:start] + lines[end:])

        if not original_block.endswith("\n"):
            original_block += "\n"
        replacement = original_block.splitlines(keepends=True)
        if block_range is None:
            return "".join(lines[: tui_start + 1] + replacement + lines[tui_start + 1 :])
        start, end = block_range
        return "".join(lines[:start] + replacement + lines[end:])

    if original_block is None:
        return text

    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    if "".join(lines).strip():
        lines.append("\n")
    if not original_block.endswith("\n"):
        original_block += "\n"
    lines.extend(["[tui]\n", original_block])
    return "".join(lines)


def unique_snapshot_dir(parent: Path, base_name: str) -> Path:
    candidate = parent / base_name
    index = 1
    while candidate.exists():
        candidate = parent / f"{base_name}-{index}"
        index += 1
    return candidate


latest_path = SNAP_DIR / "latest"
if not latest_path.exists():
    print("SNAPSHOT_STATUS=NOT_FOUND")
    print("원복할 스냅샷이 없습니다.")
    raise SystemExit(0)

snapshot_id = latest_path.read_text(encoding="utf-8").strip()
snapshot_dir = SNAP_DIR / snapshot_id
meta_path = snapshot_dir / "meta.json"
if not meta_path.exists():
    print("SNAPSHOT_STATUS=NOT_FOUND")
    print(f"meta.json이 없습니다: {meta_path}")
    raise SystemExit(0)

meta = json.loads(meta_path.read_text(encoding="utf-8"))
status_line_existed = bool(meta.get("status_line_existed"))
status_line_path = snapshot_dir / "status_line.toml"

if status_line_existed:
    if not status_line_path.exists():
        print("ERROR=SNAPSHOT_STATUS_LINE_MISSING")
        print(f"스냅샷 메타데이터와 실제 파일이 불일치합니다: {status_line_path}")
        raise SystemExit(1)
    original_block = status_line_path.read_text(encoding="utf-8")
else:
    original_block = None

old_text = CONFIG.read_text(encoding="utf-8") if CONFIG.exists() else ""
validate_toml(old_text, "CONFIG")
new_text = restore_status_line(old_text, original_block)
validate_toml(new_text, "RESTORED_CONFIG")

if new_text == old_text:
    print("(정보) 현재 상태가 이미 스냅샷과 동일합니다. 복원할 변경 사항이 없습니다.")
    print(f"CONFIG={CONFIG}")
    print(f"SNAPSHOT={snapshot_dir}")
    raise SystemExit(0)

pre_restore_dir = unique_snapshot_dir(snapshot_dir, ".pre-restore-" + _dt.datetime.now().strftime("%Y%m%dT%H%M%S"))
pre_restore_dir.mkdir(parents=True, exist_ok=False)
if CONFIG.exists():
    shutil.copy2(CONFIG, pre_restore_dir / "config.toml.bak")

CONFIG.parent.mkdir(parents=True, exist_ok=True)
tmp_path = CONFIG.with_name(CONFIG.name + ".tmp")
tmp_path.write_text(new_text, encoding="utf-8")
tmp_path.replace(CONFIG)

print("RESULT=RESTORED")
print(f"CONFIG={CONFIG}")
print(f"SNAPSHOT={snapshot_dir}")
print(f"PRE_RESTORE_BACKUP={pre_restore_dir}")
if status_line_existed:
    print("STATUS_LINE=RESTORED")
else:
    print("STATUS_LINE=REMOVED")
backup_path = snapshot_dir / "config.toml.bak"
if backup_path.exists():
    print(f"EMERGENCY_BACKUP={backup_path}")
PY
BASH
```

## RESULT HANDLING

- `SNAPSHOT_STATUS=NOT_FOUND` 가 출력되면 원복할 snapshot이 없다고 보고하고 종료한다.
- `(정보) 현재 상태가 이미 스냅샷과 동일합니다.` 가 출력되면 파일을 변경하지 않았다고 보고한다.
- `RESULT=RESTORED` 가 출력되면 `[tui].status_line`만 원복했다고 보고한다.
- `STATUS_LINE=RESTORED` 는 설치 전 원문 블록을 복원했다는 뜻이다.
- `STATUS_LINE=REMOVED` 는 설치 전 `status_line` 키가 없었으므로 현재 키를 삭제했다는 뜻이다.
- `EMERGENCY_BACKUP`은 전체 config 수동 복구용이다. 자동으로 덮어쓰지 않는다.
