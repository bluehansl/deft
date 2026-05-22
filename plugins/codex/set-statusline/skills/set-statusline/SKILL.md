---
name: set-statusline
description: Codex TUI status line을 `$HOME/.codex/config.toml`의 `[tui].status_line`으로 설정한다. 설치 전 현재 config와 기존 status_line 블록을 snapshot으로 저장하여 `/restore-statusline` 으로 원복 가능. 트리거 예시 "statusline 적용", "statusline 설치", "Codex statusline 설정", "apply statusline", "/set-statusline", "/set-statusline:set-statusline".
---

# set-statusline

## EXEC_IMMEDIATE

사용자가 `/set-statusline`, `/set-statusline:set-statusline`, 또는 자연어 트리거("statusline 적용" 등)를 입력했다는 것 자체가 "이 PC에 Codex status line을 설정해 달라"는 명시적 의도 표명이다. 스킬 소개, 의도 재확인, 사용법 재설명을 하지 않는다.

첫 응답은 assistant 텍스트가 아니라 아래 Bash 도구 호출로 시작한다.

## BG

- 대상 파일: `$HOME/.codex/config.toml`
- 수정 대상: `[tui]` 섹션의 `status_line` 키만
- 기본 preset: `["model-with-reasoning", "context-remaining", "current-dir"]`
- 스냅샷 디렉토리: `$HOME/.codex/.set-statusline-snapshot/`
  - `latest` - 가장 최근 snapshot ID
  - `<snapshot-id>/meta.json` - config/status_line 존재 여부와 대상 값
  - `<snapshot-id>/config.toml.bak` - 설치 직전 전체 config 백업
  - `<snapshot-id>/status_line.toml` - 설치 직전 `status_line` 원문 블록

`git-branch`는 Codex 버전별 동작 차이가 있을 수 있는 experimental preset이다. 사용자가 명시적으로 요청한 경우에만 `["model-with-reasoning", "context-remaining", "current-dir", "git-branch"]` 형태를 실험 옵션으로 안내하고, 기본 설치값에는 포함하지 않는다.

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

TARGET = ["model-with-reasoning", "context-remaining", "current-dir"]
TARGET_BLOCK = 'status_line = ["model-with-reasoning", "context-remaining", "current-dir"]\n'
CONFIG = Path(os.environ.get("CODEX_STATUSLINE_CONFIG", Path.home() / ".codex" / "config.toml")).expanduser()
SNAP_DIR = Path(os.environ.get("CODEX_STATUSLINE_SNAPSHOT_DIR", Path.home() / ".codex" / ".set-statusline-snapshot")).expanduser()


def load_toml(text: str):
    if tomllib is None or not text.strip():
        return {}
    return tomllib.loads(text)


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


def patch_status_line(text: str) -> tuple[str, str | None]:
    lines = text.splitlines(keepends=True)
    tui_start, tui_end = find_tui_range(lines)
    original_block = None

    if tui_start is not None:
        block_range = find_status_line_block(lines, tui_start, tui_end)
        if block_range is not None:
            start, end = block_range
            original_block = "".join(lines[start:end])
            lines = lines[:start] + [TARGET_BLOCK] + lines[end:]
        else:
            lines = lines[: tui_start + 1] + [TARGET_BLOCK] + lines[tui_start + 1 :]
        return "".join(lines), original_block

    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    if "".join(lines).strip():
        lines.append("\n")
    lines.extend(["[tui]\n", TARGET_BLOCK])
    return "".join(lines), None


def unique_snapshot_dir(parent: Path, base_name: str) -> Path:
    candidate = parent / base_name
    index = 1
    while candidate.exists():
        candidate = parent / f"{base_name}-{index}"
        index += 1
    return candidate


config_existed = CONFIG.exists()
old_text = CONFIG.read_text(encoding="utf-8") if config_existed else ""
validate_toml(old_text, "CONFIG")

parsed = load_toml(old_text)
if parsed.get("tui", {}).get("status_line") == TARGET:
    print("이미 동일하게 설정되어 있습니다.")
    print(f"CONFIG={CONFIG}")
    raise SystemExit(0)

new_text, original_block = patch_status_line(old_text)
validate_toml(new_text, "PATCHED_CONFIG")

if new_text == old_text:
    print("이미 동일하게 설정되어 있습니다.")
    print(f"CONFIG={CONFIG}")
    raise SystemExit(0)

snapshot_dir = unique_snapshot_dir(SNAP_DIR, _dt.datetime.now().strftime("%Y%m%dT%H%M%S"))
snapshot_id = snapshot_dir.name
snapshot_dir.mkdir(parents=True, exist_ok=False)

meta = {
    "snapshot_id": snapshot_id,
    "config_path": str(CONFIG),
    "config_existed": config_existed,
    "status_line_existed": original_block is not None,
    "target_status_line": TARGET,
}
(snapshot_dir / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if config_existed:
    shutil.copy2(CONFIG, snapshot_dir / "config.toml.bak")
if original_block is not None:
    (snapshot_dir / "status_line.toml").write_text(original_block, encoding="utf-8")

CONFIG.parent.mkdir(parents=True, exist_ok=True)
tmp_path = CONFIG.with_name(CONFIG.name + ".tmp")
tmp_path.write_text(new_text, encoding="utf-8")
tmp_path.replace(CONFIG)

SNAP_DIR.mkdir(parents=True, exist_ok=True)
(SNAP_DIR / "latest").write_text(snapshot_id + "\n", encoding="utf-8")

print("RESULT=UPDATED")
print(f"CONFIG={CONFIG}")
print(f"SNAPSHOT={snapshot_dir}")
print(f"STATUS_LINE={TARGET}")
backup_path = snapshot_dir / "config.toml.bak"
if backup_path.exists():
    print(f"EMERGENCY_BACKUP={backup_path}")
PY
BASH
```

## RESULT HANDLING

- `이미 동일하게 설정되어 있습니다.` 가 출력되면 파일을 변경하지 않았다고 보고한다.
- `RESULT=UPDATED` 가 출력되면 `$HOME/.codex/config.toml`의 `[tui].status_line` 설정이 완료되었다고 보고한다.
- `SNAPSHOT` 경로를 함께 알려주고, 원복은 `/restore-statusline` 으로 가능하다고 안내한다.
- `ERROR=CONFIG_TOML_PARSE_FAILED` 또는 `ERROR=PATCHED_CONFIG_TOML_PARSE_FAILED` 가 출력되면 기존 config 문법을 먼저 수동 점검해야 하며 파일은 변경하지 않았다고 보고한다.

## NOTES

- 주석 처리된 `[tui]` 또는 `status_line`은 실제 설정으로 보지 않는다.
- 기존 `status_line`이 단일 라인 또는 멀티라인 배열이어도 전체 값 블록을 교체한다.
- 전체 config 백업은 emergency 복구용이다. 일반 원복은 `/restore-statusline`이 `[tui].status_line`만 되돌린다.
