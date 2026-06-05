---
name: restore-statusline
description: set-statusline 설치 직전 상태로 statusline 설정을 원복한다. `$HOME/.claude/.set-statusline-snapshot/` 에 저장된 스냅샷에서 스크립트와 settings.json의 statusLine 항목을 복원. 트리거 예시 "statusline 원복", "statusline 되돌려", "restore statusline", "rollback statusline", "/restore-statusline", "deft:restore-statusline".
---

# restore-statusline

## ⚡ EXEC_IMMEDIATE (최우선 규칙, 절대 준수)

사용자가 `/restore-statusline`, `deft:restore-statusline`, 또는 자연어 트리거("statusline 원복" 등)를 입력했다는 것 자체가 **"원복해 달라"는 명시적 의도 표명**이다. 스킬 소개·의도 재확인·사용법 재설명을 **절대 하지 않는다**.

### 호출 시 가장 먼저 수행할 행동

**첫 응답은 assistant 텍스트가 아니라 도구 호출로 시작한다.**

| 호출 형태 | 즉시 수행할 첫 동작 |
|---|---|
| `/restore-statusline` / 자연어 트리거 | Bash P1(스냅샷 점검) → TXT(복원 대상 미리보기 + 컨펌) → 사용자 y/N → Bash P2(복원 실행) → TXT(P3 완료 보고) |

### 금지되는 문장

- ❌ `restore-statusline 스킬이 준비되었습니다`
- ❌ `원복하시려고 하시나요?`
- ❌ Phase/Step 번호를 사용자에게 노출
- ❌ "~하겠습니다/실행합니다/중입니다" 류 진행 중계

## BG
- 스냅샷 디렉토리: `$HOME/.claude/.set-statusline-snapshot/`
    - `statusline-command.sh` — 설치 직전 스크립트 사본 (없으면 설치 전에 스크립트 자체가 없었음을 의미)
    - `statusLine.json` — 설치 직전 `settings.json`의 `.statusLine` 값 (없으면 설치 전에 `statusLine` 키가 없었음)
    - `meta.env` — `SCRIPT_EXISTED`, `STATUSLINE_EXISTED`, `SNAPSHOT_TS`
- 대상 파일:
    - `$HOME/.claude/statusline-command.sh`
    - `$HOME/.claude/settings.json` (`.statusLine` 키만 수정)

## 원복 동작 원칙
- `SCRIPT_EXISTED=1` → 스냅샷의 스크립트로 복원
- `SCRIPT_EXISTED=0` → 현재 스크립트 파일 삭제 (설치 전엔 없었으니까)
- `STATUSLINE_EXISTED=1` → 스냅샷의 `statusLine` 값으로 `settings.json` 복원
- `STATUSLINE_EXISTED=0` → `settings.json`에서 `.statusLine` 키 제거
- **스냅샷은 복원 후에도 유지**: 재복원 가능

## FLOW
- **P1**: 스냅샷 존재 여부 확인 + 현재 상태 대비 변경 항목 미리보기.
- **CONFIRM**: y/yes → P2. 그 외 → `변경 없음. 작업을 중단했습니다.`
- **P2**: 복원 실행 (현재 상태를 먼저 `.pre-restore` 로 추가 백업 → 스냅샷 적용).
- **P3**: 결과 요약.

## P1 (bash, 스냅샷 점검 + 미리보기)

```bash
bash <<'BASH'
set -u
HOME_DIR="${HOME}"
STATUSLINE_DST="${HOME_DIR}/.claude/statusline-command.sh"
SETTINGS="${HOME_DIR}/.claude/settings.json"
SNAP_DIR="${HOME_DIR}/.claude/.set-statusline-snapshot"

if [ ! -d "${SNAP_DIR}" ] || [ ! -f "${SNAP_DIR}/meta.env" ]; then
  echo "SNAPSHOT_STATUS=NOT_FOUND"
  echo "(설치 기록이 없습니다. /set-statusline 으로 한 번 이상 설치한 적이 있어야 원복 가능합니다.)"
  exit 0
fi

. "${SNAP_DIR}/meta.env"
echo "SNAPSHOT_STATUS=OK"
echo "SNAPSHOT_TS=${SNAPSHOT_TS:-unknown}"
echo "SCRIPT_EXISTED=${SCRIPT_EXISTED:-0}"
echo "STATUSLINE_EXISTED=${STATUSLINE_EXISTED:-0}"
echo ""

echo "=== 복원 계획 ==="

# 스크립트 복원 계획
if [ "${SCRIPT_EXISTED:-0}" = "1" ]; then
  if [ -f "${SNAP_DIR}/statusline-command.sh" ]; then
    if [ -f "${STATUSLINE_DST}" ]; then
      if cmp -s "${SNAP_DIR}/statusline-command.sh" "${STATUSLINE_DST}"; then
        echo "script: NO_CHANGE (스냅샷과 현재 파일이 동일)"
      else
        echo "script: REPLACE — 스냅샷의 스크립트로 교체"
      fi
    else
      echo "script: RESTORE — 스크립트 재생성"
    fi
  else
    echo "script: SNAPSHOT_FILE_MISSING — 복원 불가 (meta=EXISTED지만 파일 없음)"
  fi
else
  if [ -f "${STATUSLINE_DST}" ]; then
    echo "script: DELETE — 설치 전엔 없었으므로 현재 파일 제거"
  else
    echo "script: NO_CHANGE (원래 없었고 지금도 없음)"
  fi
fi

# settings.statusLine 복원 계획
if command -v jq >/dev/null 2>&1; then
  current_sl=$(jq -r 'if .statusLine then "EXISTS" else "NONE" end' "${SETTINGS}" 2>/dev/null || echo "NONE")
  if [ "${STATUSLINE_EXISTED:-0}" = "1" ]; then
    if [ -f "${SNAP_DIR}/statusLine.json" ]; then
      snap_cmd=$(jq -r '.command // empty' "${SNAP_DIR}/statusLine.json")
      echo "settings.statusLine: RESTORE — command=${snap_cmd}"
    else
      echo "settings.statusLine: SNAPSHOT_FILE_MISSING"
    fi
  else
    if [ "${current_sl}" = "EXISTS" ]; then
      echo "settings.statusLine: REMOVE — 설치 전엔 없었으므로 키 제거"
    else
      echo "settings.statusLine: NO_CHANGE (원래 없었고 지금도 없음)"
    fi
  fi
else
  echo "settings.statusLine: CHECK_SKIPPED (jq 미설치)"
fi
BASH
```

P1 결과 해석:
- `SNAPSHOT_STATUS=NOT_FOUND` → `⚠️ 스냅샷이 없습니다. 원복할 수 있는 이전 상태가 없습니다.` 출력 후 종료 (컨펌 없이).
- `script: SNAPSHOT_FILE_MISSING` or `settings.statusLine: SNAPSHOT_FILE_MISSING` → `⚠️ 스냅샷 메타데이터와 실제 파일이 불일치합니다. 부분 복원만 가능합니다. 계속할까요? (y/N)`.
- 전부 `NO_CHANGE` → `(정보) 현재 상태가 이미 스냅샷과 동일합니다. 복원할 변경 사항이 없습니다.` 출력 후 종료.
- 그 외 정상 → `위 계획대로 원복하시겠습니까? (y/N)`.

## CONFIRM
입력 소문자화 후 {`y`,`yes`} → P2 실행. 그 외 → `변경 없음. 작업을 중단했습니다.`

## P2 (bash, 복원 실행)

```bash
bash <<'BASH'
set -eu
HOME_DIR="${HOME}"
CLAUDE_DIR="${HOME_DIR}/.claude"
STATUSLINE_DST="${CLAUDE_DIR}/statusline-command.sh"
SETTINGS="${CLAUDE_DIR}/settings.json"
SNAP_DIR="${CLAUDE_DIR}/.set-statusline-snapshot"
TS=$(date +%Y-%m-%dT%H:%M:%S)

if [ ! -d "${SNAP_DIR}" ] || [ ! -f "${SNAP_DIR}/meta.env" ]; then
  echo "RESULT=FAIL"
  echo "ERROR=snapshot not found"
  exit 0
fi

. "${SNAP_DIR}/meta.env"

# --- 1. 현재 상태를 .pre-restore 로 추가 백업 (원복 취소 대비) ---
PRE_DIR="${SNAP_DIR}/.pre-restore"
mkdir -p "${PRE_DIR}"
if [ -f "${STATUSLINE_DST}" ]; then
  cp -p "${STATUSLINE_DST}" "${PRE_DIR}/statusline-command.sh"
fi
if [ -f "${SETTINGS}" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.statusLine' "${SETTINGS}" >/dev/null 2>&1; then
    jq '.statusLine' "${SETTINGS}" > "${PRE_DIR}/statusLine.json"
  fi
fi
echo "PRE_RESTORE_DIR=${PRE_DIR}"
echo "PRE_RESTORE_TS=${TS}"

# --- 2. 스크립트 복원 ---
if [ "${SCRIPT_EXISTED:-0}" = "1" ]; then
  if [ -f "${SNAP_DIR}/statusline-command.sh" ]; then
    cp "${SNAP_DIR}/statusline-command.sh" "${STATUSLINE_DST}"
    chmod +x "${STATUSLINE_DST}"
    echo "SCRIPT=RESTORED"
  else
    echo "SCRIPT=SKIPPED (snapshot file missing)"
  fi
else
  if [ -f "${STATUSLINE_DST}" ]; then
    rm -f "${STATUSLINE_DST}"
    echo "SCRIPT=REMOVED"
  else
    echo "SCRIPT=NO_CHANGE"
  fi
fi

# --- 3. settings.json의 statusLine 복원 ---
if [ ! -f "${SETTINGS}" ]; then
  echo '{}' > "${SETTINGS}"
fi

if command -v jq >/dev/null 2>&1; then
  if [ "${STATUSLINE_EXISTED:-0}" = "1" ]; then
    if [ -f "${SNAP_DIR}/statusLine.json" ]; then
      jq --slurpfile sl "${SNAP_DIR}/statusLine.json" '.statusLine = $sl[0]' \
         "${SETTINGS}" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "${SETTINGS}"
      echo "SETTINGS=RESTORED"
    else
      echo "SETTINGS=SKIPPED (snapshot file missing)"
    fi
  else
    jq 'del(.statusLine)' "${SETTINGS}" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "${SETTINGS}"
    echo "SETTINGS=KEY_REMOVED"
  fi
else
  echo "SETTINGS=SKIPPED (jq not found)"
fi

echo "RESULT=OK"
BASH
```

## P3 (결과 텍스트 템플릿)

```
✅ statusline 원복 완료

원복 내용:
  script: {SCRIPT}           (RESTORED | REMOVED | NO_CHANGE | SKIPPED)
  settings: {SETTINGS}       (RESTORED | KEY_REMOVED | NO_CHANGE | SKIPPED)

스냅샷 정보:
  원복 대상 시점: {SNAPSHOT_TS}
  스냅샷 경로: {SNAP_DIR}

복원 직전 상태 백업 (원복 자체를 취소할 때 사용):
  {PRE_RESTORE_DIR}
  ts: {PRE_RESTORE_TS}

재설치:
  다시 설치하려면 `/set-statusline` 실행

(Claude Code를 재시작해야 변경된 statusline이 반영됩니다.)
```

## EDGES (모두 ⚠️ prefix, 내용 변경 금지)

| # | 조건 | 메시지 |
|---|---|---|
| 1 | `SNAPSHOT_STATUS=NOT_FOUND` | ⚠️ 원복할 스냅샷이 없습니다. `/set-statusline` 으로 한 번 이상 설치한 이력이 있어야 원복이 가능합니다. |
| 2 | 모든 항목 `NO_CHANGE` | (정보) 현재 상태가 이미 스냅샷과 동일합니다. 복원할 변경 사항이 없습니다. |
| 3 | `SNAPSHOT_FILE_MISSING` | ⚠️ 스냅샷 메타데이터와 실제 파일이 불일치합니다. 부분 복원만 가능합니다. 계속할까요? (y/N) |
| 4 | `jq: MISSING` | ⚠️ jq 미설치. settings.json 자동 복원이 불가능합니다. 스크립트만 복원됩니다. |
| 5 | CONFIRM 거부 | 변경 없음. 작업을 중단했습니다. |
| 6 | `RESULT=FAIL` | ❌ 복원 중 오류가 발생했습니다. 상세: `<ERROR>`. 수동 점검이 필요합니다. |

## TOOL_CALL_BUDGET
- bash(P1) + TXT(미리보기+컨펌) + bash(P2) + TXT(P3) = **bash 2회 + text 2회**.

## HINTS
- 스냅샷 **유지**: P2에서 `SNAP_DIR` 는 삭제하지 않음. 재복원 가능.
- `.pre-restore/`: 원복 직전 상태를 추가 백업. 원복 자체를 되돌려야 할 때 수동으로 활용 (`cp .pre-restore/statusline-command.sh ...`).
- `jq --slurpfile` 사용 이유: 스냅샷의 `statusLine.json`은 JSON 객체를 단독으로 담고 있으므로 배열 첫 원소로 읽어서 대입.
