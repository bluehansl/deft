---
name: session-relocate
description: Codex 세션을 다른 프로젝트의 `/resume` 목록에 표시되도록 이동한다. 트리거 예시 "세션 이동", "세션 경로 옮기기", "resume 리스트로 옮겨", "move session", "relocate session", "/session-relocate", "/session-relocate:session-relocate".
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
set cwd='/Users/jeongsaehanseul/git/fss-notice',
    git_branch='feature/IT-14397',
    git_origin_url='https://gitlab.fssuniverse.com/fasstonotice/fss-notice.git',
    updated_at=strftime('%s','now')
where id='019d1e68-75ae-7e33-8322-84c82c01529a';
```

따라서 Codex 포팅의 성공 조건은 `threads.cwd` 갱신이다. JSONL 갱신은 세션 내부 메타데이터 정합성을 맞추기 위한 보조 작업이다.

## 실행 원칙

사용자가 `/session-relocate`, `/session-relocate:session-relocate`, 또는 자연어 트리거를 입력하면 설명을 먼저 출력하지 말고 도구 호출부터 시작한다.

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
|  | 이름 | {title} |
|  | 시작 대화 | {first} |
|  | 끝 대화 | {preview} |
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
                select id, title, first_user_message, preview, updated_at_ms, updated_at, rollout_path
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
    title = first = preview = ""
    updated = os.path.getmtime(path)
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("type") == "session_meta":
                    payload = obj.get("payload") or {}
                    if payload.get("cwd") != CUR:
                        return None
                if obj.get("type") == "response_item":
                    payload = obj.get("payload") or {}
                    if payload.get("type") == "message" and payload.get("role") == "user":
                        texts = []
                        for item in payload.get("content") or []:
                            if isinstance(item, dict):
                                texts.append(item.get("text") or item.get("input_text") or "")
                        msg = "\n".join(t for t in texts if t).strip()
                        if msg:
                            first = first or msg
                            preview = msg
                if obj.get("type") == "event_msg":
                    payload = obj.get("payload") or {}
                    if payload.get("type") == "user_message":
                        msg = (payload.get("message") or "").strip()
                        if msg:
                            first = first or msg
                            preview = msg
    except Exception:
        return None
    return {
        "id": session_id_from_path(path),
        "title": title,
        "first_user_message": first,
        "preview": preview,
        "updated_at": int(updated),
        "rollout_path": path,
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
    print("---CARD---")
    print(f"sid={row.get('id') or ''}")
    print(f"title={tr(row.get('title'))}")
    print(f"first={tr(row.get('first_user_message'))}")
    print(f"preview={tr(row.get('preview'))}")
    print(f"ts={kst_from_epoch(updated)}")
    print(f"rollout_path={row.get('rollout_path') or ''}")
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
PY
```

## 이동 대상 확정 출력

P2 결과가 `RESULT=OK`일 때만 아래 형식으로 출력하고 사용자 확인을 받는다. 별도 라벨, 검증 안내, 백업/변경 대상 상세 설명은 사용자에게 출력하지 않는다.

```markdown
이동 대상이 확정되었습니다.
- session id: {sid}
- target: {TARGET_REAL}

진행할까요? (Y/N)
```

## P5. 적용

사용자가 `y` 또는 `yes`로 확인한 경우에만 실행한다. `Y` 입력 후에는 작업 시작 안내 문구를 출력하지 말고 바로 P5를 실행한다. SQLite 백업은 Python `sqlite3.Connection.backup()`으로 만든다. 백업은 세션 파일 옆이나 repo 안에 만들지 않고 OS 임시 디렉터리의 실행별 하위 디렉터리에 만든다. JSONL은 줄 단위로 임시 파일에 준비한 뒤, SQLite update 성공을 확인하고 원본으로 교체한다.

```bash
SESSION_ID="<sid>" \
STATE_DB="<state db>" \
SESSION_FILE="<jsonl>" \
TARGET_REAL="<target>" \
HAS_TARGET_GIT="<0|1>" \
TARGET_GIT_BRANCH="<branch>" \
TARGET_GIT_ORIGIN="<origin>" \
python3 <<'PY'
import json, os, shutil, sqlite3, tempfile, time

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

def update_thread_with_retry():
    last_error = None
    for attempt in range(3):
        con = None
        try:
            con = connect_db(DB)
            cols = {r[1] for r in con.execute("pragma table_info(threads)").fetchall()}
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
            con.commit()
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

try:
    os.replace(tmp_path, JSONL)
except Exception as exc:
    try:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
    except Exception:
        pass
    fail(f"jsonl replace failed after sqlite update: {exc}", "FAIL")
    raise SystemExit(0)

print("RESULT=OK")
print(f"JSON_BACKUP={json_bak}")
print(f"DB_BACKUP={db_bak}")
print(f"JSON_CHANGED_LINES={changed_lines}")
print(f"THREAD_ROWS_UPDATED={rows_updated}")
print("SESSION_INDEX_TOUCHED=0")
PY
```

## P6. 결과 출력

성공 시:

```markdown
세션 경로를 변경이 완료되었습니다.
```

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

적용 후 문제가 있으면 P5 stdout의 `JSON_BACKUP`, `DB_BACKUP` 경로를 사용한다. 백업은 OS 임시 디렉터리에 저장되며 장기간 보존을 전제로 하지 않는다.

```bash
cp "<JSON_BACKUP>" "<SESSION_FILE>"
cp "<DB_BACKUP>" "<STATE_DB>"
```

`session_index.jsonl`은 이 스킬의 변경 대상이 아니므로 복구 대상에 포함하지 않는다.
