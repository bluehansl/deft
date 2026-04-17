---
name: session-relocate
description: Claude Code 세션 파일을 다른 pwd 프로젝트 디렉토리로 이동. 트리거 예시 "세션 이동", "세션 경로 옮기기", "resume 리스트로 옮겨", "move session", "relocate session", "/session-relocate".
---

# Session Relocate Skill

Claude Code 세션 로그(`~/.claude/projects/<encoded-pwd>/<session-id>.jsonl`)와 사이드카 디렉토리(`<session-id>/`)를 다른 pwd 기반 프로젝트 디렉토리로 이동시켜, 다른 경로에서 `claude` 실행 후 `/resume` 리스트에 해당 세션이 노출되도록 한다.

세션 파일의 실제 pwd는 jsonl 내부 엔트리에 기록되지만, `/resume` 목록은 파일이 위치한 프로젝트 디렉토리(= 현재 pwd를 인코딩한 이름) 기준으로 탐색되므로, 단순히 파일을 옮기면 목적을 달성할 수 있다.

## 호출 방식

1. **인자 없음** (`/session-relocate`) — 리스트업 모드 → 사용자가 번호로 세션 선택 → target 경로 입력
2. **인자 있음** (`/session-relocate <session-id> <절대경로>`) — 리스트업 생략, Phase 2부터 바로 진입

---

## 사용자 노출 출력 규칙 (중요)

이 스킬을 실행할 때, Claude는 **내부 Phase/Step 이름이나 진행 상황을 서술하지 않는다**. 다음과 같은 안내 문장을 출력하지 말 것:

- ❌ "Phase 1부터 시작하겠습니다"
- ❌ "자기 세션 식별용 마커를 주입합니다"
- ❌ "이제 세션 목록을 스캔합니다"
- ❌ "NONCE를 생성 중입니다"
- ❌ Phase/Step 번호, NONCE 값, encoded pwd 내부 문자열 등

**사용자에게 보이는 출력은 다음만 허용한다**:

1. **(인자 없음)** 최상단 안내(고정 문구, 두 줄):
   ```
   최근 사용된 5개의 세션 리스트가 제공 됩니다. 이동하려는 세션의 no를 입력해주세요.
   (오래된 세션을 이동하려면 해당 세션을 1회 이상 사용 후 시도해 주세요.)
   ```
2. 세션 리스트 (카드 5개)
3. 경로 입력 프롬프트: `이동할 target 절대경로를 입력하세요:`
4. 엣지 케이스 경고(⚠️ prefix, 필요 시)
5. Phase 3 드라이런 계획
6. Phase 4 컨펌 프롬프트 `진행할까요? (y/N)`
7. Phase 6 최종 결과 (`✅ 세션 이동 완료` 블록)

**절대 출력하지 않는다**:
- Phase/Step 번호, NONCE 값, encoded pwd
- 진행 상황 서술("~하겠습니다", "~을 실행합니다", "~중입니다")
- 리스트 하단 보조 안내(예: "번호를 입력하거나 /resume로 돌아가세요" 같은 부가 문구)
- 사용자가 이미 카드에서 본 내용의 재요약
- 불필요한 "10번 이상은 상세 확인 후 진행" 류의 안내 (항상 5개만 노출하므로 해당 없음)

내부 Bash/Python 실행은 도구 호출로만 수행한다. 한 번에 필요한 Bash/Python을 실행하고, 결과가 나오면 위 허용 출력만 사용자에게 노출한다.

---

## Phase 1: 입력 수집 (인자 없을 때만)

### 1-1. 자기 세션 판별용 마커 주입

현재 세션 jsonl에 Bash 호출을 기록하여 고유 NONCE를 심는다. Claude는 생성된 NONCE를 기억해 다음 단계에서 재사용한다.

```bash
NONCE="SESSION_RELOCATE_MARKER_$(date -u +%s%N)_$RANDOM$RANDOM"
echo "MARKER_NONCE=$NONCE"
```

이 Bash 호출의 `command` 문자열과 `stdout`이 현재 세션 jsonl에 `tool_use` + `tool_result` 엔트리로 기록되므로, 그 파일을 자기 세션으로 식별할 수 있다.

### 1-2. 현재 pwd 및 프로젝트 디렉토리 확인

```bash
CURRENT_PWD=$(pwd)
ENCODED_PWD="${CURRENT_PWD//\//-}"   # / → -
PROJECT_DIR="$HOME/.claude/projects/$ENCODED_PWD"
ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -20
```

### 1-3. 자기 세션 확정

최신 5개 jsonl에서 NONCE를 검색한다(대부분 최신 1~2개 안에 존재).

```bash
SELF_SESSION=""
for f in $(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -5); do
  if grep -q "$NONCE" "$f"; then
    SELF_SESSION=$(basename "$f" .jsonl)
    break
  fi
done
echo "SELF_SESSION=$SELF_SESSION"
```

- 매칭 있음 → 자기 세션 id 확정
- 매칭 없음 → `SELF_SESSION=""` 로 두고 진행(경고/컨펌 없이). 이후 단계에서 자기 제외가 불가능하면 상위 목록에 자기 세션이 포함될 수 있으나 사용자 선택 시 엣지 1로 차단된다.

### 1-4. 상위 5개 세션 풀 파싱 (카드용)

자기 세션을 제외한 mtime 최신 **5개** jsonl에서 아래 항목을 추출한다. 큰 파일 처리를 위해 Python 스트리밍 파싱을 사용한다.

추출 항목:
- `customTitle`: `type=="custom-title"` 엔트리의 `customTitle` 최신값
- `first-user`: 첫 유효 `type=="user"` 엔트리의 사용자 입력 텍스트
- `last-user`: 마지막 유효 `type=="user"` 엔트리의 사용자 입력 텍스트
- `last-ts`: 마지막 유효 `type=="user"` 엔트리의 `timestamp`

**메타 컨텐츠 필터링 (구조적, "유효 user 엔트리" 판정)**

- `message.content`가 string이면 그대로 사용
- `message.content`가 array면 `type=="text"` 블록만 추출 후 join
- 다음 마커로 시작하는 경우 건너뛰고 다음 user 엔트리 사용:
  - `<system-reminder>`, `<command-name>`, `<command-message>`, `<command-args>`, `<local-command-stdout>`, `<user-prompt-submit-hook>`, `<bash-input>`, `<bash-stdout>`, `<bash-stderr>`, `<file-hook>`
- `isMeta==true` 플래그가 있으면 건너뛰기
- `tool_result` 역할로 채워진 user 엔트리(`content` 내 `tool_use_id` 존재) 제외

**포맷 규칙**
- 대화 40자 절삭: 개행→공백 치환, 초과 시 앞 39자 + `…`
- rename 40자 절삭: 없으면 `—`
- 시간 포맷: UTC → KST(+9h), `YYYY년 MM월 DD일 HH:mm:ss`

Python 스트리밍 파서 예시:

```bash
python3 - "$PROJECT_DIR" "$SELF_SESSION" <<'PY'
import sys, os, json, glob
from datetime import datetime, timedelta, timezone

proj_dir, self_id = sys.argv[1], sys.argv[2]
META_MARKERS = (
    "<system-reminder>", "<command-name>", "<command-message>",
    "<command-args>", "<local-command-stdout>", "<user-prompt-submit-hook>",
    "<bash-input>", "<bash-stdout>", "<bash-stderr>", "<file-hook>",
)

def extract_text(entry):
    msg = entry.get("message") or {}
    content = msg.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for b in content:
            if isinstance(b, dict):
                if b.get("type") == "tool_result" or "tool_use_id" in b:
                    return None
                if b.get("type") == "text":
                    parts.append(b.get("text", ""))
        return "\n".join(parts) if parts else None
    return None

def is_valid_user(entry):
    if entry.get("type") != "user":
        return False
    if entry.get("isMeta") is True:
        return False
    text = extract_text(entry)
    if text is None:
        return False
    stripped = text.lstrip()
    for m in META_MARKERS:
        if stripped.startswith(m):
            return False
    return True if stripped else False

def truncate40(s):
    if s is None:
        return "—"
    s = s.replace("\n", " ").replace("\r", " ").strip()
    if not s:
        return "—"
    if len(s) > 40:
        return s[:39] + "…"
    return s

def kst(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return "—"
    dt = dt.astimezone(timezone(timedelta(hours=9)))
    return dt.strftime("%Y년 %m월 %d일 %H:%M:%S")

files = sorted(
    glob.glob(os.path.join(proj_dir, "*.jsonl")),
    key=lambda p: os.path.getmtime(p), reverse=True,
)
files = [f for f in files if os.path.basename(f) != f"{self_id}.jsonl"]
top5 = files[:5]

for f in top5:
    sid = os.path.basename(f)[:-6]
    custom_title = None
    first_user_text = None
    last_user_text = None
    last_user_ts = None
    with open(f, "r", encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get("type") == "custom-title":
                ct = e.get("customTitle")
                if ct:
                    custom_title = ct
            if is_valid_user(e):
                txt = extract_text(e)
                if first_user_text is None:
                    first_user_text = txt
                last_user_text = txt
                last_user_ts = e.get("timestamp")
    print("---CARD---")
    print(f"sid={sid}")
    print(f"rename={truncate40(custom_title)}")
    print(f"first={truncate40(first_user_text)}")
    print(f"last={truncate40(last_user_text)}")
    print(f"ts={kst(last_user_ts) if last_user_ts else '—'}")
PY
```

### 1-5. 출력 (마크다운)

상위 5개 세션을 카드형(2컬럼 테이블)으로만 출력한다. 요약 테이블/10번 이후 로직은 사용하지 않는다.

**카드 예시**:

```markdown
### [1]

| 항목 | 값 |
|---|---|
| rename | IT-14465 입고 UI 수정 |
| session-id | 40869acf-3ecf-44ef-99fa-73a88a8388ef |
| 시작 대화 | 화면에서 버튼 클릭 시 이벤트 바인딩이… |
| 끝 대화 | 테스트 코드 돌려서 결과 확인해줘 |
| 최종 업데이트 시간 | 2026년 04월 17일 13:41:08 |
```

카드 5개를 `### [1]` ~ `### [5]` 로 출력한 뒤, 추가 안내 문구 없이 사용자 입력을 기다린다.

### 1-6. 사용자 선택

사용자가 1~5 중 번호를 입력하면 해당 full session-id 확정 → Phase 2 (2-4 target 경로 입력 요청)로 진입.

- 세션이 0개 → ⚠️ "현재 프로젝트 디렉토리에 이동 가능한 세션이 없습니다." 안내 후 종료
- 세션이 1~4개 → 있는 만큼만 카드 출력 후 동일 처리
- 숫자 외 입력 → ⚠️ "1~N 중 번호를 입력해주세요." 1회 재요청 후에도 실패 시 종료

---

## Phase 2: 경로 검증 및 정규화

### 2-1. 인자 파싱 (인자 호출인 경우)

`/session-relocate <session-id> <target>` 에서 두 값을 그대로 추출한다. 공백 포함 target은 따옴표로 묶여 있을 수 있으므로 문자열 그대로 받는다.

### 2-2. session-id 검증

UUID v4 형식 검사:

```bash
if [[ ! "$SESSION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  echo "INVALID_UUID"
fi
```

- 불일치 → **엣지 4** 안내 후 중단

### 2-3. 자기 세션 비교 (인자 호출도 수행)

인자 호출이어도 1-1(NONCE 주입) + 1-3(자기 세션 id 확정)을 먼저 수행한다. 그 후:

```bash
if [ "$SESSION_ID" = "$SELF_SESSION" ]; then
  echo "SELF"
fi
```

- 동일 → **엣지 1** 안내 후 중단

### 2-4. target 경로 정규화

```bash
# ~ expansion
TARGET="${TARGET/#\~/$HOME}"

# 절대경로 체크
case "$TARGET" in
  /*) ;;
  *) echo "NOT_ABSOLUTE"; exit 0 ;;
esac

# realpath 정규화 (symlink 해제 및 .. 제거)
TARGET_REAL=$(realpath -m "$TARGET")
echo "TARGET_REAL=$TARGET_REAL"
```

- 절대경로 아님 → **엣지 6** 안내 후 중단
- macOS에 `realpath`가 없으면 `python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$TARGET"` 로 대체 가능

### 2-5. 시스템 경로 차단

다음 prefix로 시작하거나 `/` 자체면 **엣지 8** 로 중단:

```
/etc  /var  /usr  /bin  /sbin  /System  /Library/System  /private  /dev  /proc  /root
```

```bash
case "$TARGET_REAL" in
  /etc|/etc/*|/var|/var/*|/usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|\
  /System|/System/*|/Library/System|/Library/System/*|\
  /private|/private/*|/dev|/dev/*|/proc|/proc/*|/root|/root/*|/)
    echo "SYSTEM_PATH"; exit 0 ;;
esac
```

### 2-6. HOME 외부 경고

```bash
case "$TARGET_REAL" in
  "$HOME"|"$HOME"/*) ;;
  *) echo "OUTSIDE_HOME" ;;
esac
```

- 외부면 **엣지 9**: 1회 컨펌 요청, 거부 시 중단

### 2-7. source 파일 위치 찾기

```bash
SRC="$HOME/.claude/projects/$ENCODED_PWD/${SESSION_ID}.jsonl"
SRC_PROJECT_DIR="$HOME/.claude/projects/$ENCODED_PWD"
FALLBACK_USED=0

if [ ! -f "$SRC" ]; then
  FOUND=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
  if [ -n "$FOUND" ]; then
    SRC="$FOUND"
    SRC_PROJECT_DIR=$(dirname "$FOUND")
    FALLBACK_USED=1
  else
    echo "SOURCE_NOT_FOUND"
    exit 0
  fi
fi
```

- 현재 pwd 프로젝트에 없음 + 다른 경로에서 발견 → **엣지 5**: 1회 컨펌 후 진행
- 어디에도 없음 → 에러로 중단

### 2-8. source pwd와 target 비교

source가 위치한 프로젝트 디렉토리 이름을 디코딩(`-` → `/`)해 source pwd 경로를 복원:

```bash
SRC_DIR_NAME=$(basename "$SRC_PROJECT_DIR")
SRC_PWD="${SRC_DIR_NAME//-/\/}"   # 간단 디코딩 (pwd에 '-'가 포함된 경우는 jsonl의 cwd 필드로 확인하는 것이 정확)

# 더 정확한 방법: jsonl 첫 엔트리의 cwd 필드 사용
SRC_PWD=$(grep -m1 '"cwd":' "$SRC" 2>/dev/null \
  | python3 -c 'import sys,json
try:
  e=json.loads(sys.stdin.read()); print(e.get("cwd",""))
except: print("")')

if [ "$SRC_PWD" = "$TARGET_REAL" ]; then
  echo "SAME_PWD"
fi
```

- 동일 → **엣지 2** 안내 후 중단

### 2-9. target 프로젝트 디렉토리 인코딩/생성

```bash
TARGET_ENCODED="${TARGET_REAL//\//-}"
TARGET_PROJ="$HOME/.claude/projects/$TARGET_ENCODED"

if [ ! -d "$TARGET_PROJ" ]; then
  echo "TARGET_PROJ_MISSING=$TARGET_PROJ"
  # 1회 컨펌 후:
  mkdir -p "$TARGET_PROJ"
fi
```

### 2-10. target 충돌 체크

```bash
if [ -f "$TARGET_PROJ/${SESSION_ID}.jsonl" ]; then
  echo "TARGET_CONFLICT"
fi
```

- 존재 → **엣지 3** 안내 후 중단

### 2-11. 순환 차단

source 디렉토리와 target의 경로 prefix 비교(정규화된 절대경로 기준).

```bash
SRC_DIR_REAL=$(realpath -m "$SRC_PROJECT_DIR")
case "$SRC_DIR_REAL/" in
  "$TARGET_PROJ"/*) echo "LOOP"; exit 0 ;;
esac
case "$TARGET_PROJ/" in
  "$SRC_DIR_REAL"/*) echo "LOOP"; exit 0 ;;
esac
```

- 해당 → **엣지 10**

### 2-12. 같은 파일시스템 확인

```bash
SRC_FS=$(stat -f "%d" "$(dirname "$SRC")")
TGT_FS=$(stat -f "%d" "$TARGET_PROJ")
if [ "$SRC_FS" != "$TGT_FS" ]; then
  echo "CROSS_FS"
fi
```

- 다름 → **엣지 11**: 1회 컨펌

### 2-13. disk full 사전 체크

```bash
SIDE_CAR="$SRC_PROJECT_DIR/${SESSION_ID}"
TOTAL=$(du -sk "$SRC" ${SIDE_CAR:+"$SIDE_CAR"} 2>/dev/null | awk '{s+=$1} END {print s+0}')
AVAIL=$(df -k "$TARGET_PROJ" | tail -1 | awk '{print $4}')
if [ "$TOTAL" -gt "$AVAIL" ]; then
  echo "DISK_FULL NEED=${TOTAL}KB AVAIL=${AVAIL}KB"
fi
```

- 부족 → **엣지 12** 안내 후 중단

### 2-14. source 잠김 여부

```bash
LOCK_PIDS=$(lsof "$SRC" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u | tr '\n' ',' | sed 's/,$//')
if [ -n "$LOCK_PIDS" ]; then
  echo "LOCKED pids=$LOCK_PIDS"
fi
```

- 존재 → **엣지 13** 안내 후 중단

---

## Phase 3: 드라이런

사용자에게 이동 계획을 명확히 출력한다.

```
이동 계획:
  source: /Users/you/.claude/projects/-Users-you-git-foo/<id>.jsonl
  target: /Users/you/.claude/projects/-Users-you-git-bar/

이동 대상:
  - 메인 jsonl: <id>.jsonl  (크기: 1.2 MB)
  - 사이드카 디렉토리: <id>/
      - subagents/ (파일 3개)
      - tool-results/ (파일 42개)

정리 대상:
  - <id>/.DS_Store (있을 경우)

사이드카가 없으면 "사이드카 없음 — 메인 jsonl만 이동" 으로 표기.
```

사이드카 내용 요약 예시:

```bash
SIDE_CAR="$SRC_PROJECT_DIR/${SESSION_ID}"
if [ -d "$SIDE_CAR" ]; then
  for sub in subagents tool-results; do
    if [ -d "$SIDE_CAR/$sub" ]; then
      cnt=$(find "$SIDE_CAR/$sub" -type f 2>/dev/null | wc -l | tr -d ' ')
      echo "  - $sub/: $cnt files"
    fi
  done
fi
```

---

## Phase 4: 사용자 컨펌

```
진행할까요? (y/N)
```

- `y` / `yes` 만 진행으로 간주
- 그 외(빈 입력 포함) → "변경 없음. 작업을 중단했습니다." 안내 후 종료

---

## Phase 5: 이동 실행 (단계별 검증 + 롤백)

### Step 1: 메인 jsonl 이동

```bash
mv "$SRC" "$TARGET_PROJ/"
if [ -f "$TARGET_PROJ/${SESSION_ID}.jsonl" ] && [ ! -f "$SRC" ]; then
  echo "STEP1_OK"
else
  echo "STEP1_FAIL"
  exit 1   # 아직 다른 파일 건드리지 않았으므로 상태 미변경
fi
```

실패 시: 상태가 변경되지 않았으므로 롤백 불필요. 에러 메시지와 함께 종료.

### Step 2: 사이드카 이동 (있는 경우만)

```bash
SIDE_CAR="$SRC_PROJECT_DIR/${SESSION_ID}"
TARGET_SIDE="$TARGET_PROJ/${SESSION_ID}"

if [ -d "$SIDE_CAR" ]; then
  mkdir -p "$TARGET_SIDE"
  STEP2_FAIL=0

  for sub in subagents tool-results; do
    if [ -d "$SIDE_CAR/$sub" ]; then
      if ! mv "$SIDE_CAR/$sub" "$TARGET_SIDE/"; then
        STEP2_FAIL=1
        FAILED_SUB="$sub"
        break
      fi
    fi
  done

  if [ "$STEP2_FAIL" = "1" ]; then
    echo "STEP2_FAIL sub=$FAILED_SUB — 롤백 시도"
    # 롤백: 이미 옮긴 것들을 다시 source로
    for sub in subagents tool-results; do
      [ -d "$TARGET_SIDE/$sub" ] && mv "$TARGET_SIDE/$sub" "$SIDE_CAR/" 2>/dev/null
    done
    # 메인 jsonl 롤백
    mv "$TARGET_PROJ/${SESSION_ID}.jsonl" "$SRC" 2>/dev/null
    # 빈 target sidecar 정리
    rmdir "$TARGET_SIDE" 2>/dev/null

    # 롤백 결과 검증
    if [ -f "$SRC" ] && [ ! -f "$TARGET_PROJ/${SESSION_ID}.jsonl" ]; then
      echo "ROLLBACK_OK"
    else
      echo "ROLLBACK_FAIL"
      echo "수동 복구 필요:"
      echo "  현재 메인: $(ls -la "$SRC" "$TARGET_PROJ/${SESSION_ID}.jsonl" 2>/dev/null)"
      echo "  현재 사이드카: source=$SIDE_CAR, target=$TARGET_SIDE"
    fi
    exit 1
  fi
fi
```

### Step 3: 정리

```bash
# 남은 .DS_Store 제거
if [ -d "$SIDE_CAR" ]; then
  rm -f "$SIDE_CAR/.DS_Store"
  # 빈 디렉토리만 제거
  rmdir "$SIDE_CAR" 2>/dev/null
fi
```

---

## Phase 6: 결과 보고

```
✅ 세션 이동 완료

이동된 파일:
  - <id>.jsonl
  - <id>/subagents/* (N개)
  - <id>/tool-results/* (M개)

최종 경로:
  $TARGET_PROJ/<id>.jsonl
  $TARGET_PROJ/<id>/

Resume 방법:
  cd <target_pwd>
  claude
  # 프롬프트에서 `/resume` 입력 후 해당 세션 선택
```

메모리/노트 기록 불필요 (단순 파일 이동 작업).

---

## 엣지 케이스 총 14개 (모두 ⚠️ prefix)

| # | 상황 | 안내 메시지 |
|---|---|---|
| 1 | 인자 id == 자기 세션 | ⚠️ 현재 대화가 이 세션입니다. session-id: `<id>` — 자기 자신은 이동할 수 없습니다. 새 터미널에서 target 경로로 이동 후 `/session-relocate <id> <절대경로>` 로 실행해주세요. |
| 2 | source pwd == target pwd | ⚠️ 이미 `<target>` 에 존재합니다. 이동이 필요 없습니다. |
| 3 | target에 동일 id 파일 존재 | ⚠️ 충돌: `<target>/<id>.jsonl` 이 이미 존재합니다. 덮어쓰면 기존 로그가 손실됩니다. 수동으로 확인 후 삭제하거나 다른 경로를 지정해주세요. |
| 4 | UUID 형식 오류 | ⚠️ 유효한 UUID 형식이 아닙니다. 예) `40869acf-3ecf-44ef-99fa-73a88a8388ef` |
| 5 | 현재 pwd 프로젝트에 없음 | ⚠️ 현재 프로젝트에 해당 세션이 없습니다. `<실제 위치>` 에서 발견됨 — 이 경로를 source로 사용할까요? (y/N) |
| 6 | target 절대경로 아님 | ⚠️ 절대경로가 필요합니다. (예: `/Users/you/git/project`) |
| 7 | sidecar 없음 | (정보) sidecar 디렉토리 없음 — 메인 jsonl만 이동합니다. (에러 아님) |
| 8 | 시스템 경로 | ⚠️ 시스템 디렉토리(`/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`, `/`)로는 이동할 수 없습니다. |
| 9 | HOME 외부 | ⚠️ target이 홈 디렉토리 외부입니다(`<path>`). 계속 진행할까요? (y/N) |
| 10 | 순환 (source ⊂ target 또는 target ⊂ source) | ⚠️ 순환 경로입니다. source와 target은 서로의 하위일 수 없습니다. |
| 11 | cross-filesystem | ⚠️ source와 target이 다른 파일시스템에 있습니다. 이동이 atomic하게 보장되지 않으며 실패 시 데이터 분리 가능성이 있습니다. 계속 진행할까요? (y/N) |
| 12 | disk 용량 부족 | ⚠️ 대상 파일시스템 용량이 부족합니다. 필요: `<NEED>KB`, 가용: `<AVAIL>KB`. 중단합니다. |
| 13 | source 파일 잠김 | ⚠️ source 파일이 다른 프로세스에 의해 열려있습니다(PID: `<pids>`). 세션이 활성 중일 수 있습니다. 중단합니다. |
| 14 | 이동 도중 실패 | ⚠️ 이동 중 오류 발생. 자동 롤백 시도 결과: `<성공/실패>`. 실패 시 다음 경로를 수동으로 확인해주세요: source=`<...>`, target=`<...>` |

---

## 구현 힌트

- **JSON 파싱**: 파일이 크므로 `python3` 의 라인 단위 `json.loads(line)` 스트리밍을 사용한다. 파일 전체를 메모리에 올리지 않는다.
- **마지막 user 엔트리**: 파일이 매우 큰 경우 `tac "$f" | python3 -c '...'` 로 역순 읽기 후 첫 유효 user에서 조기 종료. macOS에 `tac` 이 없으면 `tail -r` 사용.
- **조기 종료**: `grep -m1 '"type":"custom-title"' "$f"` 처럼 `-m1` 로 스트리밍 조기 종료.
- **경로 인코딩**: Bash/zsh `${VAR//\//-}` 로 `/` → `-` 치환. macOS 기본 bash(3.x)/zsh 모두 동작.
- **경로 디코딩**: `${VAR//-/\/}` 는 pwd에 원래 `-`가 포함되어 있는 경우 왜곡되므로, 가능하면 jsonl 첫 엔트리의 `cwd` 필드를 신뢰한다.
- **realpath**: macOS 기본 없음. `brew install coreutils` 로 `grealpath` 설치되어 있을 수 있고, 없으면 `python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))"` 대체.
- **환경**: macOS/Linux 기본 전제. Windows는 README에서 미지원 명시.
- **권한**: 이동 대상 경로는 사용자 권한으로 쓰기 가능한 곳이어야 한다. `sudo` 없이 실패하면 곧바로 에러로 중단.
- **원자성**: 같은 파일시스템 내 `mv` 는 POSIX rename(2)로 atomic. cross-fs `mv` 는 내부적으로 copy+unlink라 중단 시 부분 상태가 남을 수 있음 → 엣지 11 컨펌.

---

## 빠른 실행 체크리스트

- [ ] 인자 유무 판별
- [ ] 인자 없음 → Phase 1 전체 수행 (NONCE, 자기 세션, 상위 5개 카드, 사용자 선택)
- [ ] 인자 있음 → Phase 1-1/1-3만 수행 후 바로 Phase 2
- [ ] Phase 2 검증 14 단계 순차 실행, 엣지 발생 시 해당 번호의 메시지 출력
- [ ] Phase 3 드라이런 출력
- [ ] Phase 4 사용자 `y` 컨펌 필수
- [ ] Phase 5 단계별 이동 + 실패 시 롤백
- [ ] Phase 6 결과 보고 및 `/resume` 안내
