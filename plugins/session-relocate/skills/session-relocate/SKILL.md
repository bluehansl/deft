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

---

## 실행 순서 규칙 (강제)

텍스트 응답과 도구 호출을 **섞지 않는다**. 사용자가 한 번의 응답 안에서 "안내 → 툴 실행 로그 → 결과" 순으로 UI를 분해해 확인하지 않도록, 다음 순서를 엄격히 지킨다.

### 인자 없이 호출된 경우 (리스트업 모드)

**1단계: 백그라운드 수집 (사용자 텍스트 출력 없음)**
- 다음을 모두 **단일 응답 턴 안에서 연속 도구 호출**로만 수행하고, 이 과정에서 assistant 텍스트는 일체 출력하지 않는다:
  - NONCE 주입 (Phase 1-1)
  - PROJECT_DIR 확인 (Phase 1-2)
  - 자기 세션 확정 (Phase 1-3)
  - 상위 5개 세션 풀 파싱 (Phase 1-4)
- 파서(Python)의 stdout은 **내부 데이터**로만 취급. 사용자에게 그대로 보이게 하지 않는다.

**2단계: 한 번의 assistant 텍스트 응답 (모든 백그라운드 종료 후)**
- 내부 데이터에서 카드 마크다운을 조립하여 아래 3요소를 **하나의 연속된 텍스트 블록**으로 출력:
  1. 최상단 안내 2줄 (고정 문구)
  2. 카드 5개 (`### [1]` ~ `### [5]`)
  3. 한 줄 프롬프트: `세션 no를 선택해주세요.`
- 이 블록 안에서 문구-카드-프롬프트 사이에 빈 줄 외 다른 요소(추가 안내, 도구 호출 등) 삽입 금지.

**금지 사항**
- ❌ 백그라운드 수집 **전에** 안내 문구를 먼저 출력
- ❌ 백그라운드 수집 **중간**에 "~을 실행합니다" 같은 중계 문구
- ❌ 카드 데이터를 Python stdout 그대로 보여주고 사용자가 툴 결과 펼쳐보게 하기
- ❌ "번호를 입력하거나 ctrl+o..." 같은 UI 조작 안내

### 인자와 함께 호출된 경우
- Phase 1-1 / 1-3만 백그라운드로 수행 (자기 세션 비교용)
- 이후 Phase 2 검증으로 진입. 검증 중 사용자 입력이 필요한 엣지 케이스(5·9·11 등)를 만나면 그 시점에만 assistant 텍스트 출력.

### 사용자 입력 수신 이후 각 단계 공통 규칙
- 드라이런 계획 출력 → **바로** 컨펌 프롬프트 → 사용자 y/N 입력까지 **같은 assistant 메시지 한 번**에 노출
- 이동 실행은 컨펌 받은 다음 턴의 도구 호출로 수행. 실행 중 진행 멘트 금지. 완료 후 Phase 6 결과 한 번에 출력.

### 도구 호출 최소화 (속도 개선)

사용자가 체감하는 지연의 가장 큰 원인은 **도구 호출 횟수**다. 아래 기본 원칙을 지킨다.

1. **한 단계 = 한 호출이 기본**. Phase 1 백그라운드 수집은 NONCE 주입(1회) + 통합 스캔/파싱(1회) = **총 2회** 의 도구 호출로 끝낸다.
2. **Phase 2 검증은 통합 Python 1회** 호출로 끝낸다. UUID/절대경로/`~` expansion/시스템 경로 prefix 같은 trivial 검사는 Claude가 텍스트로 선처리하고, 파일시스템이 필요한 검사(`realpath`·`stat`·`df`·`lsof`)만 Python 안에서 일괄 수행한다.
3. **Phase 5 이동은 단일 Python** 으로 메인 + 사이드카 + 롤백 + 검증을 한 번에 처리한다.
4. **공유 상태는 환경변수**(`SESSION_ID`, `TARGET`, `NONCE`, `SELF_SESSION`, `SRC`, `SRC_PROJECT_DIR`, `TARGET_PROJ`)로 전달하고, 중간 결과 덤프를 위한 별도 bash 호출을 만들지 않는다.
5. **Claude 내부 처리로 대체 가능한 검증은 bash 호출 금지**:
   - UUID v4 정규식 매칭 → Claude가 문자열 확인
   - `~` expansion (`~`로 시작하면 `$HOME` 치환) → Claude가 텍스트로 수행
   - 절대경로 여부 (`/` 로 시작 확인) → Claude가 확인
   - 시스템 경로 prefix 매칭 (`/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`, `/`) → Claude가 확인
6. **파일 파싱은 스트리밍 + 조기 종료**. 대용량 jsonl(수십 MB) 에서 마지막 user 엔트리는 파일 끝에서 역방향 chunk-seek 로 찾고, 첫 user / custom-title 은 헤드 스캔으로 조기 확보한다. 이 로직은 Phase 1-3 Python 스크립트에 반영되어 있다.

---

## Phase 1: 입력 수집 (인자 없을 때만)

### 1-1. 자기 세션 판별용 마커 주입 (무출력)

Claude가 매 호출마다 **새로운 literal NONCE 문자열**(예: `SESSION_RELOCATE_MARKER_<16자 hex>`)을 생성하고, 해당 literal을 Bash 명령 본문에 그대로 포함시켜 실행한다. 명령은 `:` no-op으로 stdout을 남기지 않으며, jsonl에는 `tool_use.command` 문자열 자체가 기록되어 추후 grep으로 자기 세션을 식별할 수 있다.

규칙:
- NONCE 값은 `$(date ...)`, `$RANDOM` 같은 shell 확장을 **쓰지 않는다**. Claude가 대화 맥락에서 충분히 유일한 문자열을 직접 생성해 literal로 박는다.
- stdout은 비워 둔다 (UI 노이즈 최소화).

```bash
: "SESSION_RELOCATE_MARKER_20260420a9f3e1b7"   # Claude가 매번 새로 literal 생성
```

이 단계에서 반환되는 stdout/stderr은 비어 있어야 하며, 내부적으로 "마커가 심어졌다"는 사실만 기억하면 된다.

### 1-2. 세션 스캔 및 파싱 (통합 Python — 단일 호출)

프로젝트 디렉토리 확인, 자기 세션 판별(Phase 1-1 의 NONCE 매칭), 상위 5개 세션 파싱을 **하나의 Python 호출**로 처리한다. Phase 1-1 에서 쓴 NONCE literal을 환경변수 `NONCE` 로 전달한다.

**추출 항목** (각 세션별):
- `customTitle`: `type=="custom-title"` 엔트리의 `customTitle` 최신값
- `first-user`: 첫 유효 `type=="user"` 엔트리 텍스트
- `last-user`: 마지막 유효 `type=="user"` 엔트리 텍스트
- `last-ts`: 마지막 유효 user 엔트리의 `timestamp`

**메타 컨텐츠 필터링 (구조적)**
- `message.content`가 string이면 그대로 사용
- array면 `type=="text"` 블록만 join. `tool_result` 또는 `tool_use_id` 포함 시 제외
- 텍스트가 `<system-reminder>`, `<command-name>`, `<command-message>`, `<command-args>`, `<local-command-stdout>`, `<user-prompt-submit-hook>`, `<bash-input>`, `<bash-stdout>`, `<bash-stderr>`, `<file-hook>` 로 시작하면 제외
- `isMeta==true` 엔트리 제외

**포맷 규칙**
- 대화/이름 40자 절삭: 개행→공백, 초과 시 앞 39자 + `…`, 없으면 `—`
- 시간: UTC → KST(+9h), `YYYY년 MM월 DD일 HH:mm:ss`

**속도 최적화**
- 첫 user / customTitle: 앞에서부터 **스트리밍 스캔**, 둘 다 확보되면 head 조기 종료 가능 지점 기억
- 마지막 user: 파일 끝에서 **역방향 chunk-seek (256 KB 단위)** 로 찾은 즉시 반환. 대용량 jsonl에서 결정적 이득.
- 파일당 독립적으로 처리 → 파일 5개는 순차 처리해도 충분 (병렬화 불필요)

```bash
NONCE="SESSION_RELOCATE_MARKER_20260420a9f3e1b7" \
python3 <<'PY'
import os, sys, json, glob
from datetime import datetime, timedelta, timezone

NONCE = os.environ.get("NONCE", "")
PROJECT_DIR = os.path.join(os.path.expanduser("~"), ".claude", "projects",
                           os.getcwd().replace("/", "-"))

META_MARKERS = (
    "<system-reminder>", "<command-name>", "<command-message>",
    "<command-args>", "<local-command-stdout>", "<user-prompt-submit-hook>",
    "<bash-input>", "<bash-stdout>", "<bash-stderr>", "<file-hook>",
)

def extract_text(e):
    msg = e.get("message") or {}
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        parts = []
        for b in c:
            if isinstance(b, dict):
                if b.get("type") == "tool_result" or "tool_use_id" in b:
                    return None
                if b.get("type") == "text":
                    parts.append(b.get("text", ""))
        return "\n".join(parts) if parts else None
    return None

def is_valid_user(e):
    if e.get("type") != "user" or e.get("isMeta") is True:
        return False
    t = extract_text(e)
    if t is None:
        return False
    s = t.lstrip()
    if not s:
        return False
    return not any(s.startswith(m) for m in META_MARKERS)

def truncate40(s):
    if s is None:
        return "—"
    s = s.replace("\n", " ").replace("\r", " ").strip()
    if not s:
        return "—"
    return s[:39] + "…" if len(s) > 40 else s

def kst(ts):
    try:
        dt = datetime.fromisoformat((ts or "").replace("Z", "+00:00"))
    except Exception:
        return "—"
    return dt.astimezone(timezone(timedelta(hours=9))).strftime("%Y년 %m월 %d일 %H:%M:%S")

# 1) mtime 최신 순으로 모든 jsonl 목록 확보
all_files = sorted(
    glob.glob(os.path.join(PROJECT_DIR, "*.jsonl")),
    key=os.path.getmtime, reverse=True,
)

# 2) 자기 세션 확정 (최신 5개 안에서 NONCE literal 검색)
self_id = ""
if NONCE:
    for f in all_files[:5]:
        try:
            with open(f, "r", encoding="utf-8", errors="ignore") as fh:
                if NONCE in fh.read():
                    self_id = os.path.basename(f)[:-6]
                    break
        except Exception:
            continue

# 3) 자기 제외 후 상위 5개
top5 = [f for f in all_files if os.path.basename(f)[:-6] != self_id][:5]

def parse_fast(path):
    custom_title = None
    first_user = None
    # Forward: custom_title(최신) + first_user(최초)
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
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
                if first_user is None and is_valid_user(e):
                    first_user = extract_text(e)
    except Exception:
        pass

    # Reverse: last_user via 256KB chunk-seek from end (대용량 파일 최적화)
    last_user = None
    last_ts = None
    CHUNK = 256 * 1024
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as fh:
            pos = size
            tail = b""
            while pos > 0 and last_user is None:
                read = min(CHUNK, pos)
                pos -= read
                fh.seek(pos)
                tail = fh.read(read) + tail
                parts = tail.split(b"\n")
                if pos > 0:
                    tail = parts[0]
                    parts = parts[1:]
                else:
                    tail = b""
                for lb in reversed(parts):
                    if not lb.strip():
                        continue
                    try:
                        e = json.loads(lb.decode("utf-8", errors="ignore"))
                    except Exception:
                        continue
                    if is_valid_user(e):
                        last_user = extract_text(e)
                        last_ts = e.get("timestamp")
                        break
    except Exception:
        pass

    return custom_title, first_user, last_user, last_ts

# 4) 각 세션 파싱 결과 출력 (Claude 내부 입력용, 사용자 노출 금지)
print(f"SELF_SESSION={self_id}")
print(f"SESSION_COUNT={len(top5)}")
for f in top5:
    sid = os.path.basename(f)[:-6]
    ct, fu, lu, lts = parse_fast(f)
    print("---CARD---")
    print(f"sid={sid}")
    print(f"rename={truncate40(ct)}")
    print(f"first={truncate40(fu)}")
    print(f"last={truncate40(lu)}")
    print(f"ts={kst(lts)}")
PY
```

**도구 호출 횟수**: Phase 1-1 (`:` no-op) + Phase 1-2 (통합 Python) = **2회**. 이전 구조 대비 Phase 1 구간만 4~5회 → 2회로 감소.

### 1-3. 출력 (마크다운)

Phase 1-2 Python stdout에서 파싱한 카드 데이터를 assistant 텍스트로 렌더링한다. 상위 5개 세션을 카드형(2컬럼 테이블)으로만 출력한다.

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

### 1-4. 사용자 선택

사용자가 1~5 중 번호를 입력하면 해당 full session-id 확정 → Phase 2 (2-4 target 경로 입력 요청)로 진입.

- 세션이 0개 → ⚠️ "현재 프로젝트 디렉토리에 이동 가능한 세션이 없습니다." 안내 후 종료
- 세션이 1~4개 → 있는 만큼만 카드 출력 후 동일 처리
- 숫자 외 입력 → ⚠️ "1~N 중 번호를 입력해주세요." 1회 재요청 후에도 실패 시 종료

---

## Phase 2: 경로 검증 및 정규화

### 2-0. 통합 검증 (단일 Python — 권장 경로)

아래 통합 Python 호출 하나로 Phase 2-4 ~ 2-14 에 해당하는 파일시스템 검증을 전부 처리한다. Claude는 2-1 ~ 2-3 의 **trivial 검사(UUID·자기 세션·`~` expansion·절대경로·시스템 경로 prefix)를 도구 호출 없이 텍스트 수준에서 먼저 수행**한 후, 이 스크립트를 실행하여 나머지 검증 결과를 한 번에 받는다.

**Claude 내부 선처리 (도구 호출 없음)**
- UUID 정규식 매칭: 불일치 시 **엣지 4** 즉시 안내
- 자기 세션 id 비교 (Phase 1-2 에서 확보한 `SELF_SESSION` 값 사용): 같으면 **엣지 1**
- `~` expansion: 입력 target이 `~` 로 시작하면 `$HOME` 로 치환
- 절대경로 여부: `/` 로 시작하지 않으면 **엣지 6**
- 시스템 경로 prefix 매칭: `/`, `/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root` 중 해당 시 **엣지 8**

**통합 검증 스크립트**

```bash
SESSION_ID="<선택된 or 인자 id>" TARGET="<~ expansion 후 절대경로>" \
python3 <<'PY'
import os, sys, json, glob, shutil, subprocess

session_id = os.environ["SESSION_ID"]
target_in = os.environ["TARGET"]
home = os.path.expanduser("~")
projects_dir = os.path.join(home, ".claude", "projects")

# realpath 정규화 (macOS 기본 realpath가 없어도 파이썬이 직접 처리)
target_real = os.path.realpath(target_in)
# 혹시 realpath가 상대적으로 해석되는 경우 방어
if not os.path.isabs(target_real):
    target_real = os.path.abspath(target_real)

# source 위치 찾기 (현재 pwd 기준 → 전체 스캔 fallback)
current_encoded = os.getcwd().replace("/", "-")
src = os.path.join(projects_dir, current_encoded, f"{session_id}.jsonl")
src_project_dir = os.path.dirname(src)
fallback = False

if not os.path.isfile(src):
    cands = glob.glob(os.path.join(projects_dir, "*", f"{session_id}.jsonl"))
    if cands:
        src = cands[0]
        src_project_dir = os.path.dirname(src)
        fallback = True
    else:
        print("RESULT=SOURCE_NOT_FOUND")
        sys.exit(0)

# source pwd 복원: jsonl 첫 cwd 엔트리 우선, 실패 시 디렉토리명 디코딩
src_pwd = None
try:
    with open(src, "r", encoding="utf-8", errors="ignore") as f:
        for _ in range(200):  # 앞 200줄 안에서 찾기
            line = f.readline()
            if not line:
                break
            try:
                e = json.loads(line)
            except Exception:
                continue
            if "cwd" in e and isinstance(e["cwd"], str):
                src_pwd = e["cwd"]
                break
except Exception:
    pass
if not src_pwd:
    src_pwd = os.path.basename(src_project_dir).replace("-", "/")

# target 프로젝트 디렉토리
target_encoded = target_real.replace("/", "-")
target_proj = os.path.join(projects_dir, target_encoded)
target_proj_exists = os.path.isdir(target_proj)
target_file = os.path.join(target_proj, f"{session_id}.jsonl")

# 순환 체크
src_dir_real = os.path.realpath(src_project_dir)
loop = (
    (src_dir_real + "/").startswith(target_proj + "/") or
    (target_proj + "/").startswith(src_dir_real + "/")
)

# 같은 fs 체크 (target이 없으면 부모 기준)
try:
    src_fs = os.stat(os.path.dirname(src)).st_dev
    tgt_ref = target_proj if target_proj_exists else os.path.dirname(target_proj)
    if not os.path.exists(tgt_ref):
        tgt_ref = os.path.dirname(tgt_ref)
    tgt_fs = os.stat(tgt_ref).st_dev
    cross_fs = src_fs != tgt_fs
except Exception:
    cross_fs = False

# disk 용량
def dir_size(p):
    total = 0
    if os.path.isdir(p):
        for root, _, files in os.walk(p):
            for n in files:
                try:
                    total += os.path.getsize(os.path.join(root, n))
                except Exception:
                    pass
    return total

sidecar = os.path.join(src_project_dir, session_id)
try:
    need_kb = (os.path.getsize(src) + dir_size(sidecar)) // 1024 + 1
    avail_kb = shutil.disk_usage(tgt_ref).free // 1024
    disk_full = need_kb > avail_kb
except Exception:
    need_kb, avail_kb, disk_full = 0, 0, False

# lsof (실패해도 무시)
lock_pids = ""
try:
    r = subprocess.run(["lsof", src], capture_output=True, text=True, timeout=3)
    if r.returncode == 0:
        pids = set()
        for line in r.stdout.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 2:
                pids.add(parts[1])
        lock_pids = ",".join(sorted(pids))
except Exception:
    pass

# HOME 외부
outside_home = not (target_real == home or target_real.startswith(home + "/"))

# 결과 출력 (Claude 파싱용)
print("RESULT=OK")
print(f"SRC={src}")
print(f"SRC_PROJECT_DIR={src_project_dir}")
print(f"SRC_PWD={src_pwd}")
print(f"TARGET_REAL={target_real}")
print(f"TARGET_PROJ={target_proj}")
print(f"TARGET_PROJ_EXISTS={1 if target_proj_exists else 0}")
print(f"TARGET_CONFLICT={1 if os.path.exists(target_file) else 0}")
print(f"SAME_PWD={1 if src_pwd == target_real else 0}")
print(f"LOOP={1 if loop else 0}")
print(f"CROSS_FS={1 if cross_fs else 0}")
print(f"DISK_FULL={1 if disk_full else 0}")
print(f"NEED_KB={need_kb}")
print(f"AVAIL_KB={avail_kb}")
print(f"LOCK_PIDS={lock_pids}")
print(f"SIDECAR_EXISTS={1 if os.path.isdir(sidecar) else 0}")
print(f"OUTSIDE_HOME={1 if outside_home else 0}")
print(f"FALLBACK_USED={1 if fallback else 0}")
PY
```

**출력 해석**
- `RESULT=SOURCE_NOT_FOUND` → 어디에도 세션 파일 없음. 에러 종료.
- `FALLBACK_USED=1` → **엣지 5**: 다른 경로에서 발견했음을 알리고 1회 컨펌.
- `SAME_PWD=1` → **엣지 2**.
- `TARGET_CONFLICT=1` → **엣지 3**.
- `LOOP=1` → **엣지 10**.
- `OUTSIDE_HOME=1` → **엣지 9**: 1회 컨펌.
- `CROSS_FS=1` → **엣지 11**: 1회 컨펌.
- `DISK_FULL=1` → **엣지 12**.
- `LOCK_PIDS` 비어 있지 않으면 → **엣지 13**.
- `TARGET_PROJ_EXISTS=0` → 생성 컨펌 1회 후 `mkdir -p` 는 Phase 5 통합 스크립트에서 일괄 수행.
- `SIDECAR_EXISTS=0` → 메인 jsonl만 이동 (엣지 7, 정상 처리).

**도구 호출 횟수**: Phase 2 전체 = **1회**. 이전 구조 2-2 ~ 2-14 별도 호출 대비 큰 단축.

> 아래 2-1 ~ 2-14 개별 서술은 각 검증의 의미·엣지 매핑을 문서화하기 위해 남긴 **레퍼런스**이며, 실제 실행은 위 통합 스크립트로 일괄 처리한다.

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

## Phase 5: 이동 실행 (단일 Python — 권장 경로)

메인 이동, 사이드카 이동, `.DS_Store` 정리, 실패 시 자동 롤백까지 **하나의 Python 호출**로 처리한다. 이전 3단계(bash Step 1 + Step 2 + Step 3) 개별 호출 대비 **1회 호출**로 단축.

```bash
SRC="<...>" SRC_PROJECT_DIR="<...>" TARGET_PROJ="<...>" SESSION_ID="<...>" \
python3 <<'PY'
import os, shutil

src = os.environ["SRC"]
src_project_dir = os.environ["SRC_PROJECT_DIR"]
target_proj = os.environ["TARGET_PROJ"]
session_id = os.environ["SESSION_ID"]

target_file = os.path.join(target_proj, f"{session_id}.jsonl")
sidecar_src = os.path.join(src_project_dir, session_id)
sidecar_tgt = os.path.join(target_proj, session_id)

moved_main = False
moved_subs = []

def rollback(err):
    ok = True
    # sub 역이동
    for sub in reversed(moved_subs):
        s = os.path.join(sidecar_tgt, sub)
        t = os.path.join(sidecar_src, sub)
        try:
            if os.path.isdir(s):
                os.makedirs(sidecar_src, exist_ok=True)
                shutil.move(s, t)
        except Exception:
            ok = False
    # 메인 역이동
    if moved_main and os.path.exists(target_file):
        try:
            shutil.move(target_file, src)
        except Exception:
            ok = False
    # 빈 target sidecar 정리
    try:
        os.rmdir(sidecar_tgt)
    except Exception:
        pass
    print("RESULT=FAIL")
    print(f"ERROR={err}")
    print("ROLLBACK=" + ("OK" if ok else "FAIL"))
    if not ok:
        print("MANUAL_CHECK:")
        print(f"  main: src={src} target={target_file}")
        print(f"  sidecar: src={sidecar_src} target={sidecar_tgt}")

try:
    os.makedirs(target_proj, exist_ok=True)

    # Step 1: 메인 이동
    shutil.move(src, target_file)
    if not (os.path.isfile(target_file) and not os.path.exists(src)):
        raise RuntimeError("main move verification failed")
    moved_main = True

    # Step 2: 사이드카 이동 (있는 경우)
    if os.path.isdir(sidecar_src):
        os.makedirs(sidecar_tgt, exist_ok=True)
        for sub in ("subagents", "tool-results"):
            s = os.path.join(sidecar_src, sub)
            t = os.path.join(sidecar_tgt, sub)
            if os.path.isdir(s):
                shutil.move(s, t)
                moved_subs.append(sub)

        # Step 3: 정리
        ds = os.path.join(sidecar_src, ".DS_Store")
        if os.path.isfile(ds):
            try:
                os.remove(ds)
            except Exception:
                pass
        try:
            os.rmdir(sidecar_src)
        except Exception:
            pass

    # 성공
    print("RESULT=OK")
    print(f"MAIN_MOVED=1")
    print(f"SIDECAR_SUBS={','.join(moved_subs) if moved_subs else '-'}")
    # 이동된 파일 수 집계 (Phase 6 보고용)
    cnt_sub = 0
    cnt_tr = 0
    sa = os.path.join(sidecar_tgt, "subagents")
    tr = os.path.join(sidecar_tgt, "tool-results")
    if os.path.isdir(sa):
        cnt_sub = sum(1 for _ in os.listdir(sa))
    if os.path.isdir(tr):
        cnt_tr = sum(1 for _ in os.listdir(tr))
    print(f"SUBAGENTS_COUNT={cnt_sub}")
    print(f"TOOL_RESULTS_COUNT={cnt_tr}")

except Exception as e:
    rollback(str(e))
PY
```

**도구 호출 횟수**: Phase 5 전체 = **1회**. 이전 구조 Step 1·2·3 별도 bash 호출 대비 1/3로 단축.

> 아래 Step 1 ~ Step 3 개별 서술은 각 단계의 의미·검증 포인트·롤백 규칙을 문서화하기 위해 남긴 **레퍼런스**이며, 실제 실행은 위 통합 Python 스크립트로 일괄 처리한다.

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

## 빠른 실행 체크리스트 (도구 호출 최소화 경로)

**인자 없이 호출**
- [ ] **[bash 1회]** Phase 1-1: `:` no-op 로 NONCE literal 주입 (stdout 없음)
- [ ] **[python 1회]** Phase 1-2: 통합 스크립트로 자기 세션 확정 + 상위 5개 카드 파싱
- [ ] **[assistant text 1회]** 안내 2줄 + 카드 5개 + `세션 no를 선택해주세요.` 를 **한 번에** 출력
- [ ] 사용자가 번호 입력 후 → target 경로 입력 요청 (assistant text 1회)
- [ ] Claude 내부: UUID·자기 세션·`~` expansion·절대경로·시스템 경로 prefix 사전 검증
- [ ] **[python 1회]** Phase 2-0 통합 검증 스크립트 실행, 엣지 해석
- [ ] **[assistant text 1회]** 드라이런 + 컨펌 프롬프트 묶음 출력
- [ ] 사용자 `y` 입력 후 → **[python 1회]** Phase 5 통합 이동 스크립트 실행
- [ ] **[assistant text 1회]** Phase 6 결과 보고

**인자와 함께 호출** (`/session-relocate <id> <path>`)
- [ ] Claude 내부: UUID·절대경로·`~` expansion·시스템 경로 prefix 사전 검증
- [ ] **[bash 1회]** Phase 1-1 NONCE 주입
- [ ] **[python 1회]** Phase 1-2 통합 (자기 세션 판별만 사용, 카드는 무시 가능)
- [ ] **[python 1회]** Phase 2-0 통합 검증
- [ ] **[assistant text 1회]** 드라이런 + 컨펌
- [ ] **[python 1회]** Phase 5 통합 이동
- [ ] **[assistant text 1회]** Phase 6 결과 보고

**총 도구 호출 수 (목표)**
- 인자 없음: 최대 5회 (NONCE / 스캔 / 검증 / 이동 / ✕ assistant text는 tool 아님)
- 인자 있음: 최대 4회
