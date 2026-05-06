---
name: set-statusline
description: Claude Code statusline을 folder / git branch / model+effort / ctx progress bar 4-segment 구성으로 즉시 설정한다. 설치 전 현재 상태를 스냅샷으로 저장하여 `/restore-statusline` 으로 원복 가능. 트리거 예시 "statusline 적용", "statusline 설치", "statusline 복제", "apply statusline", "/set-statusline", "/set-statusline:set-statusline".
---

# set-statusline

## ⚡ EXEC_IMMEDIATE (최우선 규칙, 절대 준수)

사용자가 `/set-statusline`, `/set-statusline:set-statusline`, 또는 자연어 트리거("statusline 적용" 등)를 입력했다는 것 자체가 **"이 PC에 statusline을 설치해 달라"는 명시적 의도 표명**이다. 스킬 소개·의도 재확인·사용법 재설명을 **절대 하지 않는다**.

### 호출 시 가장 먼저 수행할 행동

**첫 응답은 assistant 텍스트가 아니라 도구 호출로 시작한다.**

| 호출 형태 | 즉시 수행할 첫 동작 |
|---|---|
| `/set-statusline` / `/set-statusline:set-statusline` / 자연어 트리거 | Bash P1(의존성 + 기존 상태 점검) → TXT(검사 결과 + 설치 컨펌) → 사용자 y/N → Bash P2(스냅샷 + 배포) → TXT(P3 완료 보고) |

### 금지되는 문장

- ❌ `set-statusline 스킬이 준비되었습니다`
- ❌ `이 스킬은 ... 설정하는 기능입니다`
- ❌ `statusline을 설치하시려고 하시나요?`
- ❌ Phase/Step 번호를 사용자에게 노출
- ❌ "~하겠습니다/실행합니다/중입니다" 류 진행 중계

## BG
- 대상 파일:
    - `$HOME/.claude/statusline-command.sh` (스크립트 본체)
    - `$HOME/.claude/settings.json` (Claude Code 등록)
- 스크립트 원본: `${CLAUDE_PLUGIN_ROOT}/skills/set-statusline/assets/statusline-command.sh`.
- 스냅샷 디렉토리: `$HOME/.claude/.set-statusline-snapshot/`
    - `statusline-command.sh` — 설치 직전 스크립트 사본 (있었을 때만)
    - `statusLine.json` — 설치 직전 `settings.json`의 `.statusLine` 값 (JSON)
    - `meta.env` — `SCRIPT_EXISTED`, `STATUSLINE_EXISTED`, `SNAPSHOT_TS`
- 표시 segment: 📁 폴더 / Git branch (Nerd Font U+E725) / 🤖 모델:effort / ● ctx `│██...███│` 진행바.

## FLOW
- **P1**: 의존성(jq, python3, bash) + 기존 설정 여부 확인 → 결과 텍스트 + `진행할까요? (y/N)` 컨펌.
- **CONFIRM**: y/yes → P2. 그 외 → `변경 없음. 작업을 중단했습니다.` 출력 후 종료.
- **P2**: 스냅샷 저장 → 스크립트 복사 + chmod +x → settings.json 패치.
- **P3**: 결과 요약 텍스트. 원복 방법 안내 포함.

## P1 (bash, 의존성 + 기존 상태 점검)

```bash
bash <<'BASH'
set -u
HOME_DIR="${HOME}"
STATUSLINE_DST="${HOME_DIR}/.claude/statusline-command.sh"
SETTINGS="${HOME_DIR}/.claude/settings.json"
SNAP_DIR="${HOME_DIR}/.claude/.set-statusline-snapshot"
SRC="${CLAUDE_PLUGIN_ROOT}/skills/set-statusline/assets/statusline-command.sh"

echo "=== 의존성 ==="
if command -v jq >/dev/null 2>&1;      then echo "jq: OK ($(jq --version))";      else echo "jq: MISSING"; fi
if command -v python3 >/dev/null 2>&1; then echo "python3: OK ($(python3 --version 2>&1))"; else echo "python3: MISSING"; fi
echo "bash: $(bash --version | head -1)"

echo ""
echo "=== 폰트 / 터미널 ==="
echo "TERM=${TERM:-unset}  (truecolor 권장: xterm-256color 이상 + iTerm2/VS Code)"
echo "(Git 아이콘(U+E725)이 보이려면 Nerd Font 설치 필요 — 수동 확인)"

echo ""
echo "=== 파일 상태 ==="
if [ -f "${SRC}" ]; then
  echo "src: OK (${SRC})"
else
  echo "src: MISSING (${SRC})"
fi

if [ -f "${STATUSLINE_DST}" ]; then
  if cmp -s "${SRC}" "${STATUSLINE_DST}" 2>/dev/null; then
    echo "dst: IDENTICAL (${STATUSLINE_DST}) — 덮어쓸 필요 없음"
  else
    echo "dst: EXISTS_DIFFERENT (${STATUSLINE_DST}) — 스냅샷 저장 후 교체 예정"
  fi
else
  echo "dst: NOT_INSTALLED (${STATUSLINE_DST})"
fi

if [ -f "${SETTINGS}" ]; then
  if command -v jq >/dev/null 2>&1; then
    current=$(jq -r '.statusLine.command // empty' "${SETTINGS}" 2>/dev/null)
    if [ -n "${current}" ]; then
      echo "settings.statusLine: EXISTS (command=${current})"
    else
      echo "settings.statusLine: NOT_SET"
    fi
  else
    echo "settings.statusLine: CHECK_SKIPPED (jq 미설치)"
  fi
else
  echo "settings.json: NOT_EXIST — 새로 생성 예정"
fi

echo ""
echo "=== 스냅샷 상태 ==="
if [ -d "${SNAP_DIR}" ] && [ -f "${SNAP_DIR}/meta.env" ]; then
  . "${SNAP_DIR}/meta.env"
  echo "snapshot: EXISTS (ts=${SNAPSHOT_TS:-unknown})"
  echo "  → 이번 설치로 이 스냅샷이 덮어쓰기됩니다 (이전 원복 지점 상실)"
else
  echo "snapshot: NONE — 첫 설치입니다"
fi
BASH
```

P1 결과 해석:
- `jq: MISSING` → `⚠️ jq 미설치. 계속 진행 시 settings.json 패치를 자동화할 수 없습니다. 설치 후 재시도 권장. (macOS: brew install jq)` 경고 후 컨펌.
- `python3: MISSING` → `⚠️ python3 미설치. statusline의 Unicode 폭 계산이 정확하지 않을 수 있습니다. 설치 권장. (macOS: brew install python)` 경고 후 컨펌.
- `src: MISSING` → `❌ 플러그인 에셋이 없습니다. 플러그인 재설치가 필요합니다.` 중단.
- `dst: IDENTICAL` 그리고 `settings.statusLine: EXISTS (동일 경로)` → `이미 설치 완료 상태입니다. 재설치하시겠습니까? (y/N)`.
- `snapshot: EXISTS` → P1 결과 텍스트에 `⚠️ 기존 스냅샷이 덮어쓰기됩니다` 명시.

## CONFIRM
입력 소문자화 후 {`y`,`yes`} → P2 실행. 그 외 → `변경 없음. 작업을 중단했습니다.`

## P2 (bash, 스냅샷 + 배포 + 등록)

```bash
bash <<'BASH'
set -eu
HOME_DIR="${HOME}"
CLAUDE_DIR="${HOME_DIR}/.claude"
STATUSLINE_DST="${CLAUDE_DIR}/statusline-command.sh"
SETTINGS="${CLAUDE_DIR}/settings.json"
SNAP_DIR="${CLAUDE_DIR}/.set-statusline-snapshot"
SRC="${CLAUDE_PLUGIN_ROOT}/skills/set-statusline/assets/statusline-command.sh"
TS=$(date +%Y-%m-%dT%H:%M:%S)

mkdir -p "${CLAUDE_DIR}" "${SNAP_DIR}"

# --- 1. 스냅샷 저장 (설치 직전 상태) ---
SCRIPT_EXISTED=0
STATUSLINE_EXISTED=0

if [ -f "${STATUSLINE_DST}" ]; then
  cp -p "${STATUSLINE_DST}" "${SNAP_DIR}/statusline-command.sh"
  SCRIPT_EXISTED=1
else
  rm -f "${SNAP_DIR}/statusline-command.sh"
fi

if [ -f "${SETTINGS}" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.statusLine' "${SETTINGS}" >/dev/null 2>&1; then
    jq '.statusLine' "${SETTINGS}" > "${SNAP_DIR}/statusLine.json"
    STATUSLINE_EXISTED=1
  else
    rm -f "${SNAP_DIR}/statusLine.json"
  fi
else
  rm -f "${SNAP_DIR}/statusLine.json"
fi

cat > "${SNAP_DIR}/meta.env" <<META
SCRIPT_EXISTED=${SCRIPT_EXISTED}
STATUSLINE_EXISTED=${STATUSLINE_EXISTED}
SNAPSHOT_TS=${TS}
META

echo "SNAPSHOT_DIR=${SNAP_DIR}"
echo "SNAPSHOT_TS=${TS}"
echo "SCRIPT_EXISTED=${SCRIPT_EXISTED}"
echo "STATUSLINE_EXISTED=${STATUSLINE_EXISTED}"

# --- 2. 스크립트 배포 ---
cp "${SRC}" "${STATUSLINE_DST}"
chmod +x "${STATUSLINE_DST}"
echo "INSTALLED_SCRIPT=${STATUSLINE_DST}"

# --- 3. settings.json 패치 ---
STATUSLINE_CMD="bash ${STATUSLINE_DST}"
if [ ! -f "${SETTINGS}" ]; then
  echo '{}' > "${SETTINGS}"
fi

if command -v jq >/dev/null 2>&1; then
  jq --arg cmd "${STATUSLINE_CMD}" '.statusLine = {type: "command", command: $cmd}' \
     "${SETTINGS}" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "${SETTINGS}"
  echo "PATCHED_SETTINGS=${SETTINGS}"
else
  echo "SETTINGS_SKIPPED=jq not found — 수동으로 settings.json에 다음 추가 필요:"
  echo "  \"statusLine\": { \"type\": \"command\", \"command\": \"${STATUSLINE_CMD}\" }"
fi

# --- 4. 검증 ---
if [ -x "${STATUSLINE_DST}" ]; then
  echo "VERIFY_EXEC=OK"
else
  echo "VERIFY_EXEC=FAIL"
fi
BASH
```

## P3 (결과 텍스트 템플릿)

```
✅ statusline 설치 완료

설치된 파일:
  - {INSTALLED_SCRIPT}
  - settings.json (statusLine 등록)

스냅샷 저장:
  {SNAPSHOT_DIR}
    ts: {SNAPSHOT_TS}
    script_existed: {SCRIPT_EXISTED}         (1=기존 스크립트 있었음, 0=없었음)
    statusline_existed: {STATUSLINE_EXISTED} (1=기존 settings.statusLine 있었음)

적용 방법:
  Claude Code를 재시작하면 하단에 다음 형태로 표시됩니다:
  📁 FOLDER      BRANCH      🤖 Model : effort      ● ctx │████░░░░░░│ 45%

원복 방법:
  이전 상태로 되돌리려면 `/restore-statusline` 실행

확인 체크리스트:
  - [ ] 터미널 폰트가 Nerd Font인가? (깃 아이콘 U+E725 렌더링용)
  - [ ] 터미널이 truecolor(24-bit) 지원하는가? (색상 정확도용)
  - [ ] TERM 환경변수가 xterm-256color 이상인가?

Nerd Font 미설치 시 (macOS):
  brew tap homebrew/cask-fonts && brew install --cask font-jetbrains-mono-nerd-font
  → iTerm2 Settings → Profiles → Text → Font 에서 "JetBrainsMono Nerd Font" 선택
```

## EDGES (모두 ⚠️ prefix, 내용 변경 금지)

| # | 조건 | 메시지 |
|---|---|---|
| 1 | `src: MISSING` | ❌ 플러그인 에셋 파일이 없습니다: `<src>`. 플러그인을 재설치해주세요. |
| 2 | `jq: MISSING` | ⚠️ jq 미설치. settings.json 자동 패치 및 스냅샷 저장이 불가능합니다. `brew install jq` 후 재시도 권장. |
| 3 | `python3: MISSING` | ⚠️ python3 미설치. statusline의 Unicode 폭 계산이 부정확할 수 있습니다. `brew install python` 권장. |
| 4 | `dst: IDENTICAL` 그리고 `settings.statusLine` 동일 | (정보) 이미 동일 상태로 설치됨 — 스냅샷만 갱신 후 종료합니다. |
| 5 | `VERIFY_EXEC=FAIL` | ⚠️ 스크립트 실행 권한 설정에 실패했습니다. 수동으로 `chmod +x <path>` 실행해주세요. |
| 6 | CONFIRM 거부 | 변경 없음. 작업을 중단했습니다. |
| 7 | 기존 스냅샷 존재 | ⚠️ 이전 스냅샷(`<ts>`)이 덮어쓰기됩니다. 원복 지점이 이번 설치 직전 상태로 갱신됩니다. |

## TOOL_CALL_BUDGET
- bash(P1) + TXT(검사결과+컨펌) + bash(P2) + TXT(P3) = **bash 2회 + text 2회**.

## HINTS
- `$CLAUDE_PLUGIN_ROOT`는 플러그인 실행 시 Claude Code가 자동 주입하는 env. 설치 위치에 관계없이 에셋 접근 가능.
- 스냅샷은 "설치 직전 상태"만 저장 (단일 복원 지점). 매 설치마다 덮어쓰기.
- settings.json 패치 시 기존 다른 키(`permissions`, `theme` 등)는 보존 (`jq`가 `.statusLine`만 수정).
- macOS 기본 bash는 3.2 — 스크립트는 bash 3.2 호환으로 작성됨 (`printf '\xNN'` 바이트 escape, `$'\U...'` 미사용).
