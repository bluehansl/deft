---
name: session-relocate
description: Codex 세션을 다른 프로젝트의 `/resume` 목록에 표시되도록 이동한다. 트리거 예시 "세션 이동", "세션 경로 옮기기", "resume 리스트로 옮겨", "move session", "relocate session", "/session-relocate", "deft:session-relocate".
---

# session-relocate

Codex 세션 파일을 물리적으로 옮기지 않는다. Codex의 `/resume` 목록은 세션 JSONL 파일 위치가 아니라 `~/.codex/state_*.sqlite`의 `threads.cwd` 인덱스를 기준으로 필터링한다.

## 핵심 결론

- Claude Code 원본 방식: `~/.claude/projects/<encoded-pwd>/<sid>.jsonl` 파일을 대상 프로젝트 디렉터리로 이동.
- Codex 방식: `~/.codex/sessions/YYYY/MM/DD/rollout-...<sid>.jsonl` 파일은 그대로 두고, 세션 JSONL의 `cwd` 메타데이터와 `~/.codex/state_*.sqlite`의 `threads` 레코드를 함께 갱신.
- `~/.codex/session_index.jsonl`은 `/resume` 표시 성공에 필요하지 않았고, 수동 수정 시 되돌려야 한다.
- `~/.codex/history.jsonl`과 `~/.codex/shell_snapshots/*`도 기본 변경 대상이 아니다.
- `rollout_path`는 그대로 둔다. 세션 파일 경로를 바꾸면 SQLite 인덱스와 불일치할 수 있다.

## 근거

이전 Codex 세션 변경 이력에서 다음 순서가 확인되었다.

1. JSONL의 `cwd`와 git 메타데이터만 바꿨을 때 `/resume` 목록에 나오지 않았다.
2. `session_index.jsonl`에 항목을 추가해도 `/resume` 목록에 나오지 않았다.
3. `~/.codex/state_5.sqlite`의 `threads` row를 아래처럼 갱신한 뒤 `/resume` 목록에 표시되었다.

```sql
update threads
set cwd='<새 cwd 절대경로>',
    git_branch='<대상 경로의 현재 브랜치>',
    git_origin_url='<대상 경로의 origin url>',
    updated_at=strftime('%s','now')
where id='<session-id>';
```

따라서 Codex 포팅의 성공 조건은 `threads.cwd` 갱신이다. JSONL 갱신은 세션 내부 메타데이터 정합성을 맞추기 위한 보조 작업이다.

## 실행 원칙

사용자가 `/session-relocate`, `deft:session-relocate`, 또는 자연어 트리거를 입력하면 설명을 먼저 출력하지 말고 도구 호출부터 시작한다.

| 호출 형태 | 첫 동작 |
|---|---|
| 인자 없음 | 마커 주입(P1-1) → 세션 목록 수집(P1-2) → 카드 5개 출력 |
| `<sid> <target>` | 마커 주입(P1-1) → self 판별(P1-2) → 검증(P2) → 이동 대상 확정 출력 |

금지:

- 스킬 소개, 사용법 재설명, 의도 재확인
- `session_index.jsonl` 수정
- 세션 JSONL 파일 이동
- 현재 실행 중인 자기 세션 이동
- 백업 없는 수정
- 카드 선택, target 경로 입력, `Y/N` 외 추가 사용자 입력 요청
- target 입력 후 검증 전 안내 문구 출력
- `Y` 입력 후 작업 시작 안내 문구 출력

로컬 Bash/Python 명령은 세션 이동 실행에 필요한 작업이므로 추가 승인 질문 없이 바로 실행한다. Codex CLI로 별도 실행해야 하고 권한 확인이 작업을 막는 경우에는 `--dangerously-bypass-approvals-and-sandbox` 상태에서 실행한다.

## 사용자 출력

인자 없이 호출한 경우 아래 두 줄을 먼저 출력한 뒤 카드 목록을 보여준다.

```text
최근 사용된 5개의 세션 리스트가 제공 됩니다. 이동하려는 세션의 no를 입력해주세요.
(오래된 세션을 이동하려면 해당 세션을 1회 이상 사용 후 시도해 주세요.)
```

카드 템플릿:

```markdown
| no | 항목 | 값 |
|:---:|---|---|
| N | session-id | {sid} |
|  | 이름 | {name} |
|  | 시작 대화 | {first} |
|  | 끝 대화 | {last} |
|  | 최종 업데이트 | {updated_at_kst} |
```

카드 뒤에는 `세션 no를 선택해주세요.`만 출력한다. 세션 번호를 받으면 `이동할 target 절대경로를 입력하세요:`만 출력한다. target 경로 입력 후에는 검증 안내 문장을 출력하지 말고 P2를 실행한다.

## P1-1. 현재 세션 마커 주입

매 호출마다 새 literal을 만들어 no-op 명령을 실행한다. shell 확장을 쓰지 않는다.

```bash
: "SESSION_RELOCATE_MARKER_<literal>"
```

## P1-2. self 판별 및 최근 세션 조회

아래 Python은 현재 세션에 주입한 marker를 최근 세션 파일에서 찾아 `SELF_SESSION`을 판별하고, SQLite `threads` 테이블 기준으로 현재 cwd의 최근 세션 5개를 출력한다. SQLite가 없거나 row를 찾지 못하면 파일 스캔으로 fallback한다. marker가 아직 JSONL에 flush되지 않았을 수 있으므로 짧게 재시도한다.

**카드 3줄의 출처 (2026-10-26 결함 수정)**: 이름은 `threads.name`(사용자가 붙인 세션 이름), 시작·끝 대화는 **rollout JSONL 에서 직접** 읽는다.

- ⚠️ `threads` 의 `title`·`first_user_message`·`preview` **세 컬럼은 Codex 가 모두 같은 값(첫 사용자 메시지)으로 채운다**(실측 2026-10-26: 406행 전수에서 셋이 동일). 그래서 이 셋을 쓰면 카드 3줄이 **전부 같은 문장**이 되어 정보가 없다. `name` 은 다르다 — 사용자가 붙인 이름이 들어 있다(34행 보유).
- ⚠️ rollout 의 `role: "user"` 에는 **시스템 주입이 섞인다** — `# AGENTS.md instructions…`·`<environment_context>`·`<skill>` 등. 거르지 않으면 "시작 대화"가 지침 본문이 된다. `MM` 접두 목록으로 마스킹한다(Claude 판의 같은 처방과 대응).
- 큰 rollout(실측 29MB)을 통독하지 않는다 — 첫 메시지는 앞에서, 마지막은 **끝 1MB 블록**에서 찾는다.

```bash
NONCE="<P1-1 literal>" python3 <<'PY'
import glob, json, os, re, sqlite3, time
from datetime import datetime, timezone, timedelta

HOME = os.path.expanduser("~")
CODEX = os.path.join(HOME, ".codex")
NONCE = os.environ.get("NONCE", "")
CUR = os.getcwd()
KST = timezone(timedelta(hours=9))
FDL = 50
# rollout 의 role:user 에 섞여 들어오는 시스템 주입. 이 접두로 시작하면 사용자 발화가 아니다.
MM = ("# AGENTS.md", "# CLAUDE.md", "<environment_context", "<user_instructions", "<skill",
      "<system-reminder", "<command-name", "<command-message", "<command-args",
      "<local-command-stdout", "<bash-input", "<bash-stdout", "<bash-stderr", "<file-hook",
      "<cross-session-message", "<task-notification", "SESSION_RELOCATE_MARKER")

def tr(s):
    s = (s or "").replace("\n", " ").replace("\r", " ").strip()
    if not s:
        return "—"
    return s[:FDL - 1] + "…" if len(s) > FDL else s

def kst_from_epoch(v):
    try:
        n = int(v)
        if n > 10_000_000_000:
            n = n / 1000
        return datetime.fromtimestamp(n, tz=timezone.utc).astimezone(KST).strftime("%Y년 %m월 %d일 %H:%M:%S")
    except Exception:
        return "—"

def user_text(obj):
    """rollout 한 줄에서 **사용자 발화**만 뽑는다. 시스템 주입은 ""를 돌려준다."""
    payload = obj.get("payload") or {}
    text = ""
    if obj.get("type") == "response_item" and payload.get("type") == "message" and payload.get("role") == "user":
        parts = []
        for item in payload.get("content") or []:
            if isinstance(item, dict):
                parts.append(item.get("text") or item.get("input_text") or "")
        text = " ".join(p for p in parts if p).strip()
    elif obj.get("type") == "event_msg" and payload.get("type") == "user_message":
        text = (payload.get("message") or "").strip()
    if not text or any(text.startswith(m) for m in MM):
        return ""
    return text

def first_last_user(path):
    """첫·마지막 사용자 발화. 통독하지 않는다 — 앞에서 첫 건, 끝 1MB 에서 마지막 건."""
    first = last = ""
    try:
        with open(path, "rb") as fh:
            size = fh.seek(0, 2)
            fh.seek(0)
            for _ in range(20000):
                line = fh.readline()
                if not line:
                    break
                try:
                    msg = user_text(json.loads(line))
                except Exception:
                    continue
                if msg:
                    first = msg
                    break
            fh.seek(max(0, size - 1024 * 1024))
            if size > 1024 * 1024:
                fh.readline()          # 잘린 첫 줄 버림
            for line in fh:
                try:
                    msg = user_text(json.loads(line))
                except Exception:
                    continue
                if msg:
                    last = msg
    except Exception:
        return "", ""
    return first, last or first

def all_session_files():
    return glob.glob(os.path.join(CODEX, "sessions", "*", "*", "*", "rollout-*.jsonl"))

def session_id_from_path(p):
    base = os.path.basename(p)
    if base.startswith("rollout-") and base.endswith(".jsonl"):
        return base[-42:-6]
    return ""

def find_self():
    if not NONCE:
        return "", "1"
    for attempt in range(5):
        files = sorted(all_session_files(), key=lambda p: os.path.getmtime(p), reverse=True)[:50]
        for path in files:
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                    if NONCE in fh.read():
                        return session_id_from_path(path), "0"
            except Exception:
                pass
        if attempt < 4:
            time.sleep(0.2)
    return "", "1"

def find_state_dbs():
    def key(path):
        match = re.search(r"state_(\d+)\.sqlite$", os.path.basename(path))
        version = int(match.group(1)) if match else -1
        try:
            mtime = os.path.getmtime(path)
        except Exception:
            mtime = 0
        return (version, mtime)
    return sorted(glob.glob(os.path.join(CODEX, "state_*.sqlite")), key=key, reverse=True)

def read_sqlite(self_id):
    rows = []
    for db in find_state_dbs():
        try:
            con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
            con.row_factory = sqlite3.Row
            cur = con.execute(
                """
                select id, name, title, updated_at_ms, updated_at, rollout_path
                from threads
                where cwd=? and archived=0 and id != ?
                order by coalesce(updated_at_ms, updated_at * 1000) desc, id desc
                limit 5
                """,
                (CUR, self_id),
            )
            rows = [dict(r) for r in cur.fetchall()]
            con.close()
            if rows:
                return rows, "sqlite"
        except Exception:
            pass
    return [], "jsonl_fallback"

def parse_jsonl(path):
    """SQLite 를 못 쓸 때의 fallback. cwd 가 다르면 None(대상 아님)."""
    updated = os.path.getmtime(path)
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            for _ in range(500):
                line = fh.readline()
                if not line:
                    break
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("type") == "session_meta":
                    if (obj.get("payload") or {}).get("cwd") != CUR:
                        return None
                    break
    except Exception:
        return None
    first, last = first_last_user(path)
    return {
        "id": session_id_from_path(path),
        "name": "",            # 세션 이름은 SQLite 전용 — fallback 에서는 비운다
        "title": "",
        "updated_at": int(updated),
        "rollout_path": path,
        "first": first,
        "last": last,
    }

self_id, self_unknown = find_self()
rows, list_source = read_sqlite(self_id)
if not rows:
    rows = []
    for path in sorted(all_session_files(), key=lambda p: os.path.getmtime(p), reverse=True):
        sid = session_id_from_path(path)
        if sid == self_id:
            continue
        row = parse_jsonl(path)
        if row:
            rows.append(row)
        if len(rows) >= 5:
            break

print(f"SELF_SESSION={self_id}")
print(f"SELF_SESSION_UNKNOWN={self_unknown}")
print(f"LIST_SOURCE={list_source}")
print(f"SESSION_COUNT={len(rows)}")
for row in rows:
    updated = row.get("updated_at_ms") or row.get("updated_at")
    path = row.get("rollout_path") or ""
    if path.startswith("~"):
        path = os.path.expanduser(path)
    if path and not os.path.isabs(path):
        path = os.path.join(CODEX, path)
    # sqlite 경로면 여기서 rollout 을 읽어 첫·끝을 채운다(fallback 은 이미 들어 있다).
    first = row.get("first")
    last = row.get("last")
    if first is None and os.path.isfile(path):
        first, last = first_last_user(path)
    # rollout 이 지워진 옛 세션은 DB row 만 남는다(실측 — threads 에 있으나 파일 없음).
    #   그때는 title 로 **시작 대화만** 채운다. title 은 첫 사용자 메시지의 복사본이라
    #   시작 대화의 폴백으로는 정확하다. 끝 대화는 알 수 없으므로 비운다 — 모르는 것을
    #   아는 척하지 않는다.
    if not first:
        first = (row.get("title") or "").strip()
        last = last or ""
    # 이름은 **사용자가 붙인 name 만** 쓴다. 없으면 비운다 — title 로 내려가면 이름과
    #   시작 대화가 같은 문장이 되어 이 결함이 되살아난다.
    name = (row.get("name") or "").strip()
    print("---CARD---")
    print(f"sid={row.get('id') or ''}")
    print(f"name={tr(name)}")
    print(f"first={tr(first)}")
    print(f"last={tr(last)}")
    print(f"ts={kst_from_epoch(updated)}")
    print(f"rollout_path={path}")
PY
```

## P2. 통합 검증

검증 대상:

- `sid`는 UUID 형식이어야 한다.
- `sid`가 `SELF_SESSION`과 같으면 중단한다.
- `SELF_SESSION_UNKNOWN=1`이면 현재 세션 오인 이동을 막기 위해 중단한다.
- `target`은 `~` 확장 후 절대경로여야 한다.
- 위험 경로는 거부한다: `/`, `/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`.
- 대상 경로가 존재하지 않거나 디렉터리가 아니면 중단한다.
- 대상 경로에 읽기/탐색 권한이 없으면 중단한다.
- source cwd와 target cwd가 같으면 중단한다.
- 대상 경로가 git repo면 `branch`, `origin`을 읽는다. branch 또는 origin이 없으면 해당 항목은 기존 값을 유지한다.
- 대상 경로가 git repo가 아니면 git 메타데이터는 기존 값을 유지한다고 확정 출력 내부 상태에 반영한다.
- `~/.codex/state_*.sqlite` 중 해당 `threads.id` row를 가진 DB를 찾아야 한다. 없으면 Codex `/resume` 표시 성공을 보장할 수 없으므로 중단한다.
- `rollout_path` 또는 파일 스캔으로 세션 JSONL 파일을 찾아야 한다.
- 볼트 후처리 훅 `"${BIV_ROOT:-$HOME/obsidian-vault/BIV}/_tools/bootstrap/post-session-relocate-v2.sh"` 의 **실행 가능 여부**를 판정해 `POSTHOOK_AVAILABLE` 로 출력한다(이동 전 안내용). 없어도 중단하지 않는다 — 볼트 후처리는 선택 단계다.
- `git_sha`/`commit_hash`는 세션 당시의 기준 커밋으로 남겨 둔다. 과거 성공 이력도 sha는 갱신하지 않았다.

```bash
SELF_SESSION="<self>" SELF_SESSION_UNKNOWN="<0|1>" SESSION_ID="<sid>" TARGET="<abs path>" python3 <<'PY'
import glob, json, os, re, sqlite3, subprocess, sys

HOME = os.path.expanduser("~")
CODEX = os.path.join(HOME, ".codex")
SID = os.environ["SESSION_ID"]
SELF = os.environ.get("SELF_SESSION", "")
SELF_UNKNOWN = os.environ.get("SELF_SESSION_UNKNOWN") == "1"
TARGET_IN = os.path.expanduser(os.environ["TARGET"])
BAD = ("/", "/etc", "/var", "/usr", "/bin", "/sbin", "/System", "/Library/System", "/private", "/dev", "/proc", "/root")

def out(k, v):
    print(f"{k}={v}")

if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", SID):
    out("RESULT", "BAD_SESSION_ID"); sys.exit(0)
if SELF_UNKNOWN:
    out("RESULT", "SELF_SESSION_UNKNOWN"); sys.exit(0)
if SELF and SID == SELF:
    out("RESULT", "SELF_SESSION"); sys.exit(0)
if not os.path.isabs(TARGET_IN):
    out("RESULT", "TARGET_NOT_ABSOLUTE"); sys.exit(0)
TARGET = os.path.realpath(TARGET_IN)
if any(TARGET == b or TARGET.startswith(b + "/") for b in BAD):
    out("RESULT", "DANGEROUS_TARGET"); sys.exit(0)
if not os.path.isdir(TARGET):
    out("RESULT", "TARGET_NOT_DIRECTORY"); sys.exit(0)
if not os.access(TARGET, os.R_OK | os.X_OK):
    out("RESULT", "TARGET_ACCESS_DENIED"); sys.exit(0)

def state_dbs():
    def key(path):
        match = re.search(r"state_(\d+)\.sqlite$", os.path.basename(path))
        version = int(match.group(1)) if match else -1
        try:
            mtime = os.path.getmtime(path)
        except Exception:
            mtime = 0
        return (version, mtime)
    return sorted(glob.glob(os.path.join(CODEX, "state_*.sqlite")), key=key, reverse=True)

db_path = ""
thread = None
for db in state_dbs():
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        con.row_factory = sqlite3.Row
        row = con.execute("select * from threads where id=?", (SID,)).fetchone()
        con.close()
        if row:
            db_path = db
            thread = dict(row)
            break
    except Exception:
        pass
if not db_path:
    out("RESULT", "THREAD_NOT_FOUND"); sys.exit(0)
if os.path.realpath(thread.get("cwd") or "") == TARGET:
    out("RESULT", "SAME_CWD"); sys.exit(0)

rollout = thread.get("rollout_path") or ""
if rollout.startswith("~"):
    rollout = os.path.expanduser(rollout)
if rollout and not os.path.isabs(rollout):
    rollout = os.path.join(CODEX, rollout)
if not rollout or not os.path.isfile(rollout):
    matches = glob.glob(os.path.join(CODEX, "sessions", "*", "*", "*", f"rollout-*{SID}.jsonl"))
    rollout = matches[0] if matches else ""
if not rollout:
    out("RESULT", "SESSION_FILE_NOT_FOUND"); sys.exit(0)

def git(args):
    try:
        return subprocess.check_output(["git", "-C", TARGET] + args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

branch = git(["symbolic-ref", "--short", "HEAD"])
origin = git(["config", "--get", "remote.origin.url"])
has_git = "1" if branch or origin else "0"
git_policy = []
if branch:
    git_policy.append("branch 갱신")
else:
    git_policy.append("branch 기존 값 유지")
if origin:
    git_policy.append("origin 갱신")
else:
    git_policy.append("origin 기존 값 유지")

out("RESULT", "OK")
out("SESSION_ID", SID)
out("STATE_DB", db_path)
out("SESSION_FILE", rollout)
out("SRC_CWD", thread.get("cwd") or "")
out("TARGET_REAL", TARGET)
out("HAS_TARGET_GIT", has_git)
out("TARGET_GIT_BRANCH", branch)
out("TARGET_GIT_ORIGIN", origin)
out("GIT_METADATA_POLICY", ", ".join(git_policy))
out("OLD_GIT_BRANCH", thread.get("git_branch") or "")
out("OLD_GIT_ORIGIN", thread.get("git_origin_url") or "")
out("OLD_GIT_SHA", thread.get("git_sha") or "")
biv = os.environ.get("BIV_ROOT") or os.path.join(HOME, "obsidian-vault", "BIV")
hook = os.path.join(biv, "_tools", "bootstrap", "post-session-relocate-v2.sh")
out("POSTHOOK_AVAILABLE", "1" if os.access(hook, os.X_OK) else "0")
PY
```

## 이동 대상 확정 출력

P2 결과가 `RESULT=OK`일 때만 아래 형식으로 출력하고 사용자 확인을 받는다. 별도 라벨, 검증 안내, 백업/변경 대상 상세 설명은 사용자에게 출력하지 않는다.

```markdown
이동 대상이 확정되었습니다.
- session id: {sid}
- target: {TARGET_REAL}
- 볼트 후처리: {POSTHOOK_AVAILABLE=1 이면 "실행 예정(스크립트 있음)" / 0 이면 "없음"}

진행할까요? (Y/N)
```

## P5. 적용

사용자가 `y` 또는 `yes`로 확인한 경우에만 실행한다. `Y` 입력 후에는 작업 시작 안내 문구를 출력하지 말고 바로 P5를 실행한다. SQLite 백업은 Python `sqlite3.Connection.backup()`으로 만든다. 백업은 세션 파일 옆이나 repo 안에 만들지 않고 OS 임시 디렉터리의 실행별 하위 디렉터리에 만든다. JSONL은 줄 단위로 임시 파일에 준비한 뒤, SQLite update 성공을 확인하고 원본으로 교체한다.

```bash
SESSION_ID="<sid>" \
STATE_DB="<state db>" \
SESSION_FILE="<jsonl>" \
TARGET_REAL="<target>" \
SRC_CWD="<P2 의 SRC_CWD — 훅 --from 용>" \
HAS_TARGET_GIT="<0|1>" \
TARGET_GIT_BRANCH="<branch>" \
TARGET_GIT_ORIGIN="<origin>" \
python3 <<'PY'
import hashlib, json, os, shutil, sqlite3, subprocess, tempfile, time

SID = os.environ["SESSION_ID"]
DB = os.environ["STATE_DB"]
JSONL = os.environ["SESSION_FILE"]
TARGET = os.environ["TARGET_REAL"]
HAS_GIT = os.environ.get("HAS_TARGET_GIT") == "1"
BRANCH = os.environ.get("TARGET_GIT_BRANCH", "")
ORIGIN = os.environ.get("TARGET_GIT_ORIGIN", "")
TS = time.strftime("%Y%m%d%H%M%S")

def update_git_dict(payload):
    git = payload.get("git")
    if isinstance(git, dict):
        if BRANCH:
            git["branch"] = BRANCH
        if ORIGIN:
            git["repository_url"] = ORIGIN
            git["origin_url"] = ORIGIN
def fail(error, rollback="OK"):
    print("RESULT=FAIL")
    print(f"ERROR={error}")
    print(f"ROLLBACK={rollback}")
    if "json_bak" in globals():
        print(f"JSON_BACKUP={json_bak}")
    if "db_bak" in globals():
        print(f"DB_BACKUP={db_bak}")

def connect_db(path):
    return sqlite3.connect(path, timeout=5)

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()

# 바꾼 필드의 변경 전/후 값을 남긴다. 전체 DB 복사로 되돌리면 **같은 DB 안의 다른 세션이
#   그 사이에 바꾼 값까지 되돌아간다**(제목·보관 상태 등 — 실측 재현). 복구는 이 기록으로
#   대상 row 의 대상 필드만, 현재 값이 "후" 값과 같을 때에만 되돌린다.
restore = {"session_id": SID, "db": DB, "jsonl": JSONL, "fields": {}}

def update_thread_with_retry():
    last_error = None
    for attempt in range(3):
        con = None
        try:
            con = connect_db(DB)
            cols = {r[1] for r in con.execute("pragma table_info(threads)").fetchall()}
            # 변경 전 값을 먼저 읽어 복구 기록에 남긴다(같은 트랜잭션 안).
            keys = [k for k in ("cwd", "updated_at", "updated_at_ms", "git_branch", "git_origin_url") if k in cols]
            prev = con.execute(f"select {', '.join(keys)} from threads where id=?", (SID,)).fetchone()
            before = dict(zip(keys, prev)) if prev else {}
            sets = ["cwd=?", "updated_at=strftime('%s','now')"]
            params = [TARGET]
            if "updated_at_ms" in cols:
                sets.append("updated_at_ms=cast(strftime('%s','now') as integer) * 1000")
            if BRANCH and "git_branch" in cols:
                sets.append("git_branch=?"); params.append(BRANCH)
            if ORIGIN and "git_origin_url" in cols:
                sets.append("git_origin_url=?"); params.append(ORIGIN)
            params.append(SID)
            cur = con.execute(f"update threads set {', '.join(sets)} where id=?", params)
            if cur.rowcount != 1:
                con.rollback()
                return 0, f"threads update rowcount={cur.rowcount}"
            after = dict(zip(keys, con.execute(f"select {', '.join(keys)} from threads where id=?", (SID,)).fetchone()))
            con.commit()
            for k in keys:
                if before.get(k) != after.get(k):
                    restore["fields"][k] = {"before": before.get(k), "after": after.get(k)}
            return cur.rowcount, ""
        except sqlite3.OperationalError as exc:
            last_error = str(exc)
            if con:
                try:
                    con.rollback()
                except Exception:
                    pass
            if "locked" not in last_error.lower() or attempt == 2:
                break
            time.sleep(0.3 * (attempt + 1))
        except Exception as exc:
            last_error = str(exc)
            if con:
                try:
                    con.rollback()
                except Exception:
                    pass
            break
        finally:
            if con:
                con.close()
    return 0, last_error or "sqlite update failed"

backup_dir = tempfile.mkdtemp(prefix="codex-session-relocate-backup-")
json_bak = os.path.join(backup_dir, os.path.basename(JSONL) + f".bak-{TS}")
db_bak = os.path.join(backup_dir, os.path.basename(DB) + f".bak-{TS}")
shutil.copy2(JSONL, json_bak)

try:
    src = connect_db(DB)
    dst = connect_db(db_bak)
    src.backup(dst)
    dst.close()
    src.close()
except Exception as exc:
    fail(f"sqlite backup failed: {exc}", "OK")
    raise SystemExit(0)

tmp_fd, tmp_path = tempfile.mkstemp(prefix=os.path.basename(JSONL) + ".", suffix=".tmp", dir=os.path.dirname(JSONL))
changed_lines = 0
try:
    with os.fdopen(tmp_fd, "w", encoding="utf-8") as out, open(JSONL, "r", encoding="utf-8", errors="ignore") as inp:
        for line in inp:
            raw = line
            try:
                obj = json.loads(line)
            except Exception:
                out.write(raw)
                continue
            before = json.dumps(obj, ensure_ascii=False, sort_keys=True)
            payload = obj.get("payload")
            if isinstance(payload, dict):
                if obj.get("type") == "session_meta" and payload.get("id") == SID:
                    payload["cwd"] = TARGET
                    update_git_dict(payload)
                elif obj.get("type") == "turn_context":
                    if isinstance(payload.get("cwd"), str):
                        payload["cwd"] = TARGET
                    update_git_dict(payload)
            if isinstance(obj.get("cwd"), str):
                obj["cwd"] = TARGET
            after = json.dumps(obj, ensure_ascii=False, sort_keys=True)
            if before != after:
                changed_lines += 1
                out.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n")
            else:
                out.write(raw)
except Exception as exc:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    fail(f"jsonl temp write failed: {exc}", "OK")
    raise SystemExit(0)

rows_updated, update_error = update_thread_with_retry()
if update_error:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    fail(update_error, "OK")
    raise SystemExit(0)

restore["jsonl_sha256_before"] = sha256(json_bak)
meta_path = os.path.join(backup_dir, f"restore-{SID}-{TS}.json")

try:
    os.replace(tmp_path, JSONL)
except Exception as exc:
    try:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
    except Exception:
        pass
    # DB 는 이미 커밋됐고 JSONL 은 옛 값이다 — 두 자원이 어긋난 상태다.
    #   종전에는 ROLLBACK=FAIL 로 끝나 사용자가 전체 DB 를 복사해야 했고, 그러면 같은 DB 의
    #   다른 세션 변경까지 되돌아갔다. 이제 **대상 row 의 대상 필드만** 조건부로 되돌린다.
    rb = "OK"
    try:
        con = connect_db(DB)
        try:
            for k, v in restore["fields"].items():
                cur = con.execute(f"select {k} from threads where id=?", (SID,)).fetchone()
                if cur is None:
                    rb = "FAIL"; break
                if cur[0] != v["after"]:
                    # 그 사이 누군가(대상 세션 자신 포함) 이 필드를 또 바꿨다.
                    #   새 값을 보존하고 복구를 포기한다 — 덮으면 그 변경이 사라진다.
                    rb = "FAIL"; break
                con.execute(f"update threads set {k}=? where id=?", (v["before"], SID))
            else:
                con.commit()
            if rb == "FAIL":
                con.rollback()
        finally:
            con.close()
    except Exception:
        rb = "FAIL"
    with open(meta_path, "w", encoding="utf-8") as fh:
        json.dump(restore, fh, ensure_ascii=False, indent=2)
    print("RESULT=FAIL")
    print(f"ERROR=jsonl replace failed after sqlite update: {exc}")
    print(f"ROLLBACK={rb}")
    print(f"JSON_BACKUP={json_bak}")
    print(f"DB_BACKUP={db_bak}")
    print(f"RESTORE_METADATA={meta_path}")
    raise SystemExit(0)

restore["jsonl_sha256_after"] = sha256(JSONL)
with open(meta_path, "w", encoding="utf-8") as fh:
    json.dump(restore, fh, ensure_ascii=False, indent=2)

print("RESULT=OK")
print(f"JSON_BACKUP={json_bak}")
print(f"DB_BACKUP={db_bak}")
print(f"RESTORE_METADATA={meta_path}")
print(f"JSON_CHANGED_LINES={changed_lines}")
print(f"THREAD_ROWS_UPDATED={rows_updated}")
print("SESSION_INDEX_TOUCHED=0")

# 볼트 후처리 훅 — 이동 성공 직후 **1회**. 실패해도 이동 결과는 OK 로 둔다(이동은 이미 끝났고
#   후처리는 영속 저장소 쪽 편의 기능이므로 롤백 사유가 아니다 — 계약 2026-10-20).
#   **실구현인 -v2 를 직접 부른다.** 구 이름은 호환 래퍼일 뿐이고 유지가 보장되지 않으며,
#   구 볼트 체크아웃에는 v2 가 없어 ABSENT(무변경)로 떨어진다 — 안전한 실패다. 구 이름으로
#   폴백하지 않는다: 구 훅은 뒤 옵션을 무시해 `--tool codex` 가 먹지 않고 Claude memory 를
#   건드릴 수 있었다(그래서 파일명을 분리했다).
#   `--tool codex` 는 필수다 — 훅이 memory 단계를 건너뛰고 resume 안내를 claudex 로 낸다.
#   Codex 의 memory 는 `codex_home/memories` 전역이고 소스가 루트 심링크를 거부하므로
#   Claude 식 슬러그별 memory 링크는 구조적으로 불가능하다.
#   인자는 **리스트로** 넘긴다 — 셸 문자열로 만들면 zsh 의 공백 옵션 비분리에 걸린다.
biv = os.environ.get("BIV_ROOT") or os.path.join(os.path.expanduser("~"), "obsidian-vault", "BIV")
hook = os.path.join(biv, "_tools", "bootstrap", "post-session-relocate-v2.sh")
sreal = os.environ.get("SRC_CWD", "")
if os.access(hook, os.X_OK):
    try:
        argv = [hook, SID, TARGET, "--tool", "codex"]
        if sreal and sreal != TARGET:
            argv += ["--from", sreal]
        argv.append("--apply")
        r = subprocess.run(argv, capture_output=True, text=True, timeout=120)
        print("POSTHOOK=OK" if r.returncode == 0 else "POSTHOOK=FAIL")
        print("POSTHOOK_OUT<<EOF"); print((r.stdout or "").rstrip()); print("EOF")
        if r.returncode != 0:
            print(f"POSTHOOK_ERR={(r.stderr or '').strip()[:200]}")
    except Exception as he:
        print("POSTHOOK=FAIL"); print(f"POSTHOOK_ERR={he}")
else:
    print("POSTHOOK=ABSENT")
PY
```

## P6. 결과 출력

성공 시:

```markdown
세션 경로를 변경이 완료되었습니다.

{POSTHOOK_OUT 내용을 그대로 붙인다}        ← POSTHOOK=OK 일 때만. ABSENT 면 아무것도 쓰지 않는다.
```

- `POSTHOOK=OK`: 훅 stdout 을 **요약하지 않고 그대로** 붙인다(memory 병합·인덱스 재키·원문 cwd 갱신·resume 명령이 그 안에 있다).
- `POSTHOOK=ABSENT`: 아무것도 쓰지 않는다. 볼트가 없거나 구 체크아웃이라는 뜻이고 **이동은 정상**이다.
- `POSTHOOK=FAIL`: 아래 한 줄만 덧붙인다 — **이동 결과는 변경하지 않는다**(훅 실패는 롤백 사유가 아니다).

```markdown
⚠️ 볼트 후처리 실패 — **이동은 정상 완료**됐습니다. 수동 실행:
"${BIV_ROOT:-$HOME/obsidian-vault/BIV}/_tools/bootstrap/post-session-relocate-v2.sh" "<sid>" "<새 cwd>" --tool codex --from "<옛 cwd>" --apply
```

- 훅이 Orca 터미널·폴더 컨텍스트 재지정은 **안내 한 줄만** 낸다(CLI 로 재지정이 불가능하다 — 요청자 실측 2026-10-19). 그 줄도 그대로 붙인다.

실패 시:

- `BAD_SESSION_ID`: `⚠️ session-id 형식이 올바르지 않습니다.`
- `SELF_SESSION`: `⚠️ 현재 실행 중인 세션은 이동하지 않습니다.`
- `SELF_SESSION_UNKNOWN`: `⚠️ 현재 실행 중인 세션을 판별하지 못했습니다. 현재 세션 오인 이동을 막기 위해 중단합니다. 잠시 후 다시 시도해 주세요.`
- `TARGET_NOT_ABSOLUTE`: `⚠️ target은 절대경로여야 합니다.`
- `DANGEROUS_TARGET`: `⚠️ 시스템 경로는 target으로 사용할 수 없습니다.`
- `TARGET_NOT_DIRECTORY`: `⚠️ target 경로가 존재하는 디렉터리가 아닙니다.`
- `TARGET_ACCESS_DENIED`: `⚠️ target 경로에 접근할 수 없습니다. 읽기/탐색 권한을 확인해 주세요.`
- `SAME_CWD`: `⚠️ 이미 해당 cwd에 연결된 세션입니다. 이동이 필요 없습니다.`
- `THREAD_NOT_FOUND`: `⚠️ state_*.sqlite의 threads에서 세션을 찾지 못했습니다. Codex /resume 반영을 보장할 수 없어 중단합니다.`
- `SESSION_FILE_NOT_FOUND`: `⚠️ 세션 JSONL 파일을 찾지 못했습니다.`

## 복구 절차

적용 후 문제가 있으면 P5 stdout의 `RESTORE_METADATA` 기록으로 **이 작업이 바꾼 것만** 되돌린다. 백업·기록은 OS 임시 디렉터리에 저장되며 장기간 보존을 전제로 하지 않는다.

> 🚨 **전체 DB 를 덮어쓰지 않는다.** `cp "<DB_BACKUP>" "<STATE_DB>"` 는 같은 DB 안의 **다른 세션이 그 사이에 바꾼 값까지 되돌린다**(제목 변경·보관 처리 등 — 실측 재현). `DB_BACKUP` 은 진단용으로만 남기고, 복원은 아래 절차로 대상 row 의 대상 필드만 조건부로 한다. 실행 중인 DB 위에 복사하지도 않는다.
>
> 복구는 **대상 세션이 종료된 상태**를 전제한다. 그 세션이 돌고 있으면 복원 중에 다시 쓸 수 있다.

```bash
RESTORE_METADATA="<P5 의 RESTORE_METADATA>" JSON_BACKUP="<P5 의 JSON_BACKUP>" python3 <<'PY'
import hashlib, json, os, sqlite3, shutil, sys

META = json.load(open(os.environ["RESTORE_METADATA"], encoding="utf-8"))
JBAK = os.environ.get("JSON_BACKUP", "")
SID, DB, JSONL = META["session_id"], META["db"], META["jsonl"]

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 16), b""):
            h.update(c)
    return h.hexdigest()

# 1) 충돌 검사 — 현재 값이 "후" 값과 다르면 그 사이 누군가 또 바꿨다. 덮으면 그 변경이 사라지므로 중단한다.
con = sqlite3.connect(DB, timeout=5)
try:
    for k, v in META["fields"].items():
        row = con.execute(f"select {k} from threads where id=?", (SID,)).fetchone()
        if row is None:
            print(f"RESTORE=ABORT\nREASON=threads row not found: {SID}"); sys.exit(0)
        if row[0] != v["after"]:
            print(f"RESTORE=ABORT\nREASON=conflict on {k}: 현재 값이 이 작업의 결과와 다릅니다 — 그 사이 변경이 있었습니다. 무변경으로 중단합니다."); sys.exit(0)
    # JSONL 도 같은 기준으로 본다. 백업이 변조됐거나 현재 파일이 그 뒤 또 바뀌었으면 손대지 않는다.
    do_jsonl = False
    if JBAK and os.path.isfile(JBAK) and META.get("jsonl_sha256_before"):
        if sha256(JBAK) != META["jsonl_sha256_before"]:
            print("RESTORE=ABORT\nREASON=JSON_BACKUP 해시가 기록과 다릅니다(변조·손상)."); sys.exit(0)
        if META.get("jsonl_sha256_after") and os.path.isfile(JSONL) and sha256(JSONL) != META["jsonl_sha256_after"]:
            print("RESTORE=ABORT\nREASON=현재 JSONL 이 이 작업의 결과와 다릅니다 — 그 뒤 세션이 더 기록했습니다. DB 만 되돌리려면 --db-only 로 다시 실행하세요."); sys.exit(0)
        do_jsonl = True

    # 2) DB 를 트랜잭션으로 되돌린다.
    try:
        for k, v in META["fields"].items():
            con.execute(f"update threads set {k}=? where id=?", (v["before"], SID))
        if do_jsonl:
            # 3) JSONL 교체 실패 시 DB 를 보상 복구(커밋 전이라 rollback 으로 충분).
            shutil.copy2(JBAK, JSONL)
        con.commit()
    except Exception as exc:
        con.rollback()
        print(f"RESTORE=FAIL\nREASON={exc}"); sys.exit(0)
finally:
    con.close()

print("RESTORE=OK")
print(f"FIELDS={','.join(META['fields'])}")
print(f"JSONL_RESTORED={'1' if do_jsonl else '0'}")
PY
```

- `RESTORE=OK` 는 **이 코드 경로에서 복구가 끝났다**는 뜻이다. 모든 현실 실패를 검증했다는 뜻이 아니다.
- 기록·백업이 없어진 뒤(임시 디렉터리 정리 등)의 자동 복구는 **지원하지 않는다**.
- 두 자원(DB·JSONL)을 하나의 원자적 트랜잭션으로 묶은 것은 아니다 — 프로세스 강제 종료·전원 단절 사이 구간까지 해결했다고 주장하지 않는다.
- `session_index.jsonl`·`history.jsonl`·`shell_snapshots/`는 이 스킬의 변경 대상이 아니므로 복구 대상에도 포함하지 않는다. 볼트 훅도 이들을 건드리지 않는다(계약).
- 볼트 쪽 후처리(memory·인덱스·원문 `cwd:`)의 복구는 **훅 소유자 영역**이다 — 이 절차는 Codex 상태만 되돌린다.
