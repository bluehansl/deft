---
name: session-relocate
description: Claude Code 세션 파일을 다른 pwd 프로젝트 디렉토리로 즉시 이동 실행. 호출과 동시에 리스트업 또는 경로 검증을 시작한다. 트리거 예시 "세션 이동", "세션 경로 옮기기", "resume 리스트로 옮겨", "move session", "relocate session", "/session-relocate", "/session-relocate:session-relocate".
---

# session-relocate

## ⚡ EXEC_IMMEDIATE (최우선 규칙, 절대 준수)

사용자가 `/session-relocate`, `/session-relocate:session-relocate`, 또는 자연어 트리거("세션 이동" 등)를 입력했다는 것 자체가 **"세션을 이동해 달라"는 명시적 의도 표명**이다. 스킬 소개·의도 재확인·사용법 재설명을 **절대 하지 않는다**.

### 호출 시 가장 먼저 수행할 행동

**첫 응답은 assistant 텍스트가 아니라 도구 호출로 시작한다.**

| 호출 형태 | 즉시 수행할 첫 동작 |
|---|---|
| `/session-relocate` / `/session-relocate:session-relocate` / 자연어 트리거 (인자 없음) | Bash `: "SESSION_RELOCATE_MARKER_<literal>"` (P1-1) → Python (P1-2) → assistant 텍스트 1회(안내 2줄 + 카드 5개 + `세션 no를 선택해주세요.`) |
| `/session-relocate <sid> <path>` (인자 있음) | Claude 내부 CHECK → Bash (P1-1) → Python (P1-2, self만 사용) → Python (P2-0) → assistant 텍스트(DRYRUN + 컨펌) |

### 금지되는 문장 (단 한 글자도 출력 금지)

사용자 보고 기준 아래 패턴들이 반복 노출되었다. 이 문구들을 **절대 쓰지 않는다**:

- ❌ `session-relocate 스킬이 준비되었습니다`
- ❌ `스킬이 로드되었습니다`
- ❌ `Session Relocate는 ... 기능입니다`
- ❌ `현재 claude 세션을 다른 프로젝트 디렉토리로 이동하시려면`
- ❌ `이 명령어로 최근 5개 세션을 보고 선택하거나, 직접 지정하려면`
- ❌ `이 명령어로 ...`, `이렇게 하시면 ...`, `~하려면 ~를 사용하세요`
- ❌ `세션을 이동하시려고 하시나요?` / `세션을 이동하려고 하시나요?`
- ❌ `혹은 다른 작업이 필요하신가요?` / `다른 도움이 필요하신 부분이 있으신가요?`
- ❌ 사용자가 방금 입력한 `/session-relocate` 를 사용법 예시로 재인용
- ❌ "Phase 1부터 시작합니다", "마커를 주입하겠습니다" 등 진행 중계

### 판단 기준

"사용자가 이 스킬을 호출하면서도 의도가 불확실할 수 있다"는 가정을 **하지 않는다**. 호출 자체가 실행 지시이므로, 첫 응답은 도구 호출로 시작하고 이어지는 텍스트는 카드 리스트(또는 드라이런/경고) 만 출력한다.

## BG
- Claude Code 세션 로그 = `~/.claude/projects/<encoded-pwd>/<sid>.jsonl`, 사이드카 = 동일 dir 내 `<sid>/`.
- `/resume` 탐색 키 = 파일이 놓인 프로젝트 dir(= pwd의 `/` → `-` 치환). jsonl 내부 `cwd`는 스냅샷일 뿐, resume 입력값 아님. 파일 이동만으로 목적 달성.

## FLOW
- nargs=0: bash(P1-1) → py(P1-2) → TXT(안내+카드+세션no프롬프트) → 사용자 no 입력 → TXT(target경로프롬프트) → 사용자 경로 입력 → CHECK_INTERNAL → py(P2-0) → TXT(DRYRUN+CONFIRM) → 사용자 y/N → py(P5) → TXT(P6결과)
- nargs=2 (`/session-relocate <sid> <path>`): CHECK_INTERNAL → bash(P1-1) → py(P1-2, self 판별만 사용) → py(P2-0) → TXT(DRYRUN+CONFIRM) → 사용자 y/N → py(P5) → TXT(P6결과)
- 자연어 트리거 = nargs=0과 동일.

## CHECK_INTERNAL (Claude 텍스트 수준, 도구 없음)
- sid matches `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` → else E4.
- sid == SELF_SESSION → E1.
- target starts `~` → replace with $HOME.
- target starts `/` → ok; else E6.
- target prefix ∈ {`/`, `/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`} (exact or with `/`) → E8.

## USER_OUTPUT (허용된 출력만)
1. nargs=0 진입 시 상단 안내 2줄(고정, 글자 변경 금지):
```
최근 사용된 5개의 세션 리스트가 제공 됩니다. 이동하려는 세션의 no를 입력해주세요.
(오래된 세션을 이동하려면 해당 세션을 1회 이상 사용 후 시도해 주세요.)
```
2. 카드 5개 (없으면 있는 만큼; 0개면 `⚠️ 현재 프로젝트 디렉토리에 이동 가능한 세션이 없습니다.` 후 종료).
3. 카드 뒤 프롬프트 한 줄: `세션 no를 선택해주세요.`
4. 번호 수신 후 프롬프트 한 줄: `이동할 target 절대경로를 입력하세요:`
5. 엣지 경고(아래 EDGES 표). 모두 `⚠️ ` prefix.
6. DRYRUN 블록 + `진행할까요? (y/N)` → 한 assistant 메시지에 묶음.
7. ✅ P6 결과 블록.
**금지**: Phase/Step 번호, NONCE 값, encoded pwd, "~하겠습니다/실행합니다/중입니다", 카드 재요약, "번호를 입력하거나 ctrl+o..." / "10번 이상..." 류.

## CARD_TEMPLATE
P1-2 stdout에서 sid/rename/first/last/ts를 꺼내 아래 **마크다운 3컬럼 테이블**(`no` | `항목` | `값`) 포맷으로 5개(또는 실제 수 만큼) 렌더. 터미널 폭 자동 적응을 위해 마크다운 테이블만 사용하며 HTML 금지. `no` 값은 **각 카드의 첫 행(session-id 행)에만** 표시하고 나머지 행은 빈 칸으로 둔다(마크다운은 rowspan 미지원). 라벨 순서: `session-id` → `이름` → `시작 대화` → `끝 대화` → `최종 업데이트`. `### [N]` 외부 헤딩은 쓰지 않는다.

```markdown
| no | 항목 | 값 |
|:---:|---|---|
| N | session-id | {sid} |
|  | 이름 | {rename} |
|  | 시작 대화 | {first} |
|  | 끝 대화 | {last} |
|  | 최종 업데이트 | {ts} |
```

**카드가 여러 개일 때**: 카드마다 **별도 테이블**로 출력하고, 테이블 사이에 빈 줄 1개 삽입. 단일 대형 테이블로 합치지 않는다. 카드 전·후 추가 설명·주석 금지.

## P1-1 (bash, 무출력 NONCE literal 주입)
Claude가 매 호출 새 literal(영숫자 16자 정도) 생성 → `:` no-op에 박아 실행. shell 확장(`$(date)`,`$RANDOM`) 금지. stdout/stderr 비움.
```bash
: "SESSION_RELOCATE_MARKER_<claude_literal_per_call>"
```

## P1-2 (python, 단일 호출: self 판별 + 상위 5개 파싱)
env `NONCE`에 P1-1 literal 전달. PROJECT_DIR = `~/.claude/projects/<pwd치환>`.
추출: customTitle(최신), 첫 유효 user text, 마지막 유효 user text + timestamp.
유효 user: `type=="user"` AND `isMeta!=True` AND extract_text!=None/공백 AND 텍스트가 아래 marker 중 아무것으로도 시작 안 함:
`<system-reminder>`, `<command-name>`, `<command-message>`, `<command-args>`, `<local-command-stdout>`, `<user-prompt-submit-hook>`, `<bash-input>`, `<bash-stdout>`, `<bash-stderr>`, `<file-hook>`.
extract_text: content가 str→그대로; list→type=="text" 블록 join, 단 tool_result/tool_use_id 포함 시 None.
tr (truncate, 이름/시작 대화/끝 대화 공통): 개행→공백, `>FDL자` 시 `FDL-1자 + …`, 빈값 `—`. 상수 `FDL=30` 하나로 세 필드 일괄 제어.
KST: UTC+9, `YYYY년 MM월 DD일 HH:mm:ss`, 실패 `—`.
속도: 첫 user/customTitle은 head 스트리밍; 마지막 user는 파일 끝에서 256KB chunk 역seek → 첫 매치 즉시 break.
자기 세션 확정: mtime 최신 5개 안에서 NONCE literal in file → 일치 파일의 basename-".jsonl"이 SELF_SESSION. 실패 시 "".
카드 대상: 전체 jsonl을 mtime desc 정렬 → SELF_SESSION 제외 후 상위 5개.
stdout 포맷(Claude가 parse):
```
SELF_SESSION=<id|empty>
SESSION_COUNT=<n>
---CARD---
sid=<uuid>
rename=<str|—>
first=<str|—>
last=<str|—>
ts=<YYYY년 MM월 DD일 HH:mm:ss|—>
...(반복)
```

```bash
NONCE="<P1-1 literal>" python3 <<'PY'
import os, sys, json, glob
from datetime import datetime, timedelta, timezone
NONCE = os.environ.get("NONCE", "")
PROJECT_DIR = os.path.join(os.path.expanduser("~"), ".claude", "projects", os.getcwd().replace("/", "-"))
MM = ("<system-reminder>","<command-name>","<command-message>","<command-args>","<local-command-stdout>","<user-prompt-submit-hook>","<bash-input>","<bash-stdout>","<bash-stderr>","<file-hook>")
def xt(e):
    m=e.get("message") or {}; c=m.get("content")
    if isinstance(c,str): return c
    if isinstance(c,list):
        ps=[]
        for b in c:
            if isinstance(b,dict):
                if b.get("type")=="tool_result" or "tool_use_id" in b: return None
                if b.get("type")=="text": ps.append(b.get("text",""))
        return "\n".join(ps) if ps else None
    return None
def vu(e):
    if e.get("type")!="user" or e.get("isMeta") is True: return False
    t=xt(e)
    if t is None: return False
    s=t.lstrip()
    if not s: return False
    return not any(s.startswith(m) for m in MM)
FDL=30   # fontDisplayLength: 이름/시작 대화/끝 대화 공통 표시 글자수 (초과 시 FDL-1자 + …)
def tr(s):
    if s is None: return "—"
    s=s.replace("\n"," ").replace("\r"," ").strip()
    if not s: return "—"
    return s[:FDL-1]+"…" if len(s)>FDL else s
def kst(ts):
    try: dt=datetime.fromisoformat((ts or "").replace("Z","+00:00"))
    except: return "—"
    return dt.astimezone(timezone(timedelta(hours=9))).strftime("%Y년 %m월 %d일 %H:%M:%S")
af=sorted(glob.glob(os.path.join(PROJECT_DIR,"*.jsonl")), key=os.path.getmtime, reverse=True)
self_id=""
if NONCE:
    for f in af[:5]:
        try:
            with open(f,"r",encoding="utf-8",errors="ignore") as fh:
                if NONCE in fh.read(): self_id=os.path.basename(f)[:-6]; break
        except: pass
top5=[f for f in af if os.path.basename(f)[:-6]!=self_id][:5]
def parse(p):
    ct=None; fu=None
    try:
        with open(p,"r",encoding="utf-8",errors="ignore") as fh:
            for ln in fh:
                ln=ln.strip()
                if not ln: continue
                try: e=json.loads(ln)
                except: continue
                if e.get("type")=="custom-title":
                    v=e.get("customTitle")
                    if v: ct=v
                if fu is None and vu(e): fu=xt(e)
    except: pass
    lu=None; lts=None; CH=262144
    try:
        sz=os.path.getsize(p)
        with open(p,"rb") as fh:
            pos=sz; tail=b""
            while pos>0 and lu is None:
                r=min(CH,pos); pos-=r; fh.seek(pos); tail=fh.read(r)+tail
                ps=tail.split(b"\n")
                if pos>0: tail=ps[0]; ps=ps[1:]
                else: tail=b""
                for lb in reversed(ps):
                    if not lb.strip(): continue
                    try: e=json.loads(lb.decode("utf-8",errors="ignore"))
                    except: continue
                    if vu(e): lu=xt(e); lts=e.get("timestamp"); break
    except: pass
    return ct,fu,lu,lts
print(f"SELF_SESSION={self_id}")
print(f"SESSION_COUNT={len(top5)}")
for f in top5:
    sid=os.path.basename(f)[:-6]
    ct,fu,lu,lts=parse(f)
    print("---CARD---"); print(f"sid={sid}"); print(f"rename={tr(ct)}"); print(f"first={tr(fu)}"); print(f"last={tr(lu)}"); print(f"ts={kst(lts)}")
PY
```

## P2-0 (python, 통합 검증)
env `SESSION_ID`, `TARGET`(CHECK_INTERNAL에서 ~ expansion·절대경로 검증 통과분) 전달. realpath 정규화, source 탐색(현재 pwd dir → 전체 `projects/*/<sid>.jsonl` fallback), source pwd 복원(jsonl 앞 200줄 `cwd` 필드 우선, 없으면 dir명 `-`→`/`), target dir 인코딩/존재/충돌/순환/fs/disk/lock 체크.
stdout 포맷:
```
RESULT=OK|SOURCE_NOT_FOUND
SRC=<path>
SRC_PROJECT_DIR=<path>
SRC_PWD=<path>
TARGET_REAL=<path>
TARGET_PROJ=<path>
TARGET_PROJ_EXISTS=0|1
TARGET_CONFLICT=0|1
SAME_PWD=0|1
LOOP=0|1
CROSS_FS=0|1
DISK_FULL=0|1
NEED_KB=<int>
AVAIL_KB=<int>
LOCK_PIDS=<csv|empty>
SIDECAR_EXISTS=0|1
OUTSIDE_HOME=0|1
FALLBACK_USED=0|1
```
해석: RESULT=SOURCE_NOT_FOUND→중단+안내; FALLBACK_USED=1→E5(컨펌); SAME_PWD=1→E2; TARGET_CONFLICT=1→E3; LOOP=1→E10; OUTSIDE_HOME=1→E9(컨펌); CROSS_FS=1→E11(컨펌); DISK_FULL=1→E12; LOCK_PIDS nonempty→E13; TARGET_PROJ_EXISTS=0→P5 내부 `makedirs(exist_ok=True)`로 암묵 생성(별도 컨펌 생략 가능, 단 target이 처음 만들어지는 dir이면 사용자가 알 수 있도록 DRYRUN에 표기); SIDECAR_EXISTS=0→E7 정상(메인만).

```bash
SESSION_ID="<sid>" TARGET="<abs path>" python3 <<'PY'
import os, sys, json, glob, shutil, subprocess
sid=os.environ["SESSION_ID"]; tin=os.environ["TARGET"]
home=os.path.expanduser("~"); pdir=os.path.join(home,".claude","projects")
tr=os.path.realpath(tin)
if not os.path.isabs(tr): tr=os.path.abspath(tr)
ce=os.getcwd().replace("/","-")
src=os.path.join(pdir,ce,f"{sid}.jsonl"); spd=os.path.dirname(src); fb=False
if not os.path.isfile(src):
    cs=glob.glob(os.path.join(pdir,"*",f"{sid}.jsonl"))
    if cs: src=cs[0]; spd=os.path.dirname(src); fb=True
    else: print("RESULT=SOURCE_NOT_FOUND"); sys.exit(0)
spwd=None
try:
    with open(src,"r",encoding="utf-8",errors="ignore") as f:
        for _ in range(200):
            ln=f.readline()
            if not ln: break
            try: e=json.loads(ln)
            except: continue
            if "cwd" in e and isinstance(e["cwd"],str): spwd=e["cwd"]; break
except: pass
if not spwd: spwd=os.path.basename(spd).replace("-","/")
te=tr.replace("/","-"); tp=os.path.join(pdir,te); tpe=os.path.isdir(tp); tf=os.path.join(tp,f"{sid}.jsonl")
sdr=os.path.realpath(spd)
lp=(sdr+"/").startswith(tp+"/") or (tp+"/").startswith(sdr+"/")
try:
    sfs=os.stat(os.path.dirname(src)).st_dev
    tref=tp if tpe else os.path.dirname(tp)
    while not os.path.exists(tref): tref=os.path.dirname(tref)
    tfs=os.stat(tref).st_dev; cfs=sfs!=tfs
except: cfs=False; tref=home
def ds(p):
    t=0
    if os.path.isdir(p):
        for r,_,fs in os.walk(p):
            for n in fs:
                try: t+=os.path.getsize(os.path.join(r,n))
                except: pass
    return t
sc=os.path.join(spd,sid)
try:
    nk=(os.path.getsize(src)+ds(sc))//1024+1
    ak=shutil.disk_usage(tref).free//1024
    df=nk>ak
except: nk,ak,df=0,0,False
lpids=""
try:
    r=subprocess.run(["lsof",src],capture_output=True,text=True,timeout=3)
    if r.returncode==0:
        ps=set()
        for ln in r.stdout.splitlines()[1:]:
            pp=ln.split()
            if len(pp)>=2: ps.add(pp[1])
        lpids=",".join(sorted(ps))
except: pass
oh=not (tr==home or tr.startswith(home+"/"))
print("RESULT=OK")
print(f"SRC={src}"); print(f"SRC_PROJECT_DIR={spd}"); print(f"SRC_PWD={spwd}")
print(f"TARGET_REAL={tr}"); print(f"TARGET_PROJ={tp}")
print(f"TARGET_PROJ_EXISTS={1 if tpe else 0}")
print(f"TARGET_CONFLICT={1 if os.path.exists(tf) else 0}")
print(f"SAME_PWD={1 if spwd==tr else 0}")
print(f"LOOP={1 if lp else 0}")
print(f"CROSS_FS={1 if cfs else 0}")
print(f"DISK_FULL={1 if df else 0}")
print(f"NEED_KB={nk}"); print(f"AVAIL_KB={ak}"); print(f"LOCK_PIDS={lpids}")
print(f"SIDECAR_EXISTS={1 if os.path.isdir(sc) else 0}")
print(f"OUTSIDE_HOME={1 if oh else 0}")
print(f"FALLBACK_USED={1 if fb else 0}")
PY
```

## DRYRUN_TEMPLATE
```
이동 계획:
  source: {SRC}
  target: {TARGET_PROJ}/

이동 대상:
  - 메인 jsonl: {sid}.jsonl  (크기: {size})
  - 사이드카 디렉토리: {sid}/     ← SIDECAR_EXISTS=1일 때만
      - subagents/ (N개)
      - tool-results/ (M개)

정리 대상:
  - {sid}/.DS_Store (있을 경우)

진행할까요? (y/N)
```
사이드카 요약 수집(선택): P2-0 직후 단일 bash로 `find "$SIDECAR" -type f | wc -l` 정도만 추가, 또는 P5 결과의 SUBAGENTS_COUNT/TOOL_RESULTS_COUNT 사용 후 P3에 재인용 가능.

## CONFIRM
입력 소문자화 후 {`y`,`yes`} → P5 실행. 그 외 → `변경 없음. 작업을 중단했습니다.`

## P5 (python, 이동+롤백)
env `SRC`, `SRC_PROJECT_DIR`, `TARGET_PROJ`, `SESSION_ID` 전달. 순서: makedirs(target_proj) → shutil.move(main) → 검증 → (sidecar 있으면) subagents/tool-results 순차 move → .DS_Store 제거 + sidecar_src rmdir. 실패 시: moved_subs 역순 복구 → main 복구 → 빈 target sidecar rmdir.
stdout:
```
RESULT=OK|FAIL
MAIN_MOVED=1                (OK일 때)
SIDECAR_SUBS=csv|-          (OK일 때)
SUBAGENTS_COUNT=<int>       (OK일 때)
TOOL_RESULTS_COUNT=<int>    (OK일 때)
ERROR=<msg>                 (FAIL일 때)
ROLLBACK=OK|FAIL            (FAIL일 때)
MANUAL_CHECK:               (ROLLBACK=FAIL일 때)
  main: src=... target=...
  sidecar: src=... target=...
```

```bash
SRC="..." SRC_PROJECT_DIR="..." TARGET_PROJ="..." SESSION_ID="..." python3 <<'PY'
import os, shutil
src=os.environ["SRC"]; spd=os.environ["SRC_PROJECT_DIR"]; tp=os.environ["TARGET_PROJ"]; sid=os.environ["SESSION_ID"]
tf=os.path.join(tp,f"{sid}.jsonl"); ss=os.path.join(spd,sid); st=os.path.join(tp,sid)
mm=False; ms=[]
def rb(err):
    ok=True
    for sub in reversed(ms):
        s=os.path.join(st,sub); t=os.path.join(ss,sub)
        try:
            if os.path.isdir(s): os.makedirs(ss,exist_ok=True); shutil.move(s,t)
        except: ok=False
    if mm and os.path.exists(tf):
        try: shutil.move(tf,src)
        except: ok=False
    try: os.rmdir(st)
    except: pass
    print("RESULT=FAIL"); print(f"ERROR={err}"); print("ROLLBACK="+("OK" if ok else "FAIL"))
    if not ok:
        print("MANUAL_CHECK:"); print(f"  main: src={src} target={tf}"); print(f"  sidecar: src={ss} target={st}")
try:
    os.makedirs(tp,exist_ok=True)
    shutil.move(src,tf)
    if not (os.path.isfile(tf) and not os.path.exists(src)): raise RuntimeError("main move verification failed")
    mm=True
    if os.path.isdir(ss):
        os.makedirs(st,exist_ok=True)
        for sub in ("subagents","tool-results"):
            s=os.path.join(ss,sub); t=os.path.join(st,sub)
            if os.path.isdir(s): shutil.move(s,t); ms.append(sub)
        ds=os.path.join(ss,".DS_Store")
        if os.path.isfile(ds):
            try: os.remove(ds)
            except: pass
        try: os.rmdir(ss)
        except: pass
    print("RESULT=OK"); print("MAIN_MOVED=1"); print(f"SIDECAR_SUBS={','.join(ms) if ms else '-'}")
    csu=ctr=0
    sa=os.path.join(st,"subagents"); tr=os.path.join(st,"tool-results")
    if os.path.isdir(sa): csu=sum(1 for _ in os.listdir(sa))
    if os.path.isdir(tr): ctr=sum(1 for _ in os.listdir(tr))
    print(f"SUBAGENTS_COUNT={csu}"); print(f"TOOL_RESULTS_COUNT={ctr}")
except Exception as e:
    rb(str(e))
PY
```

## P6_RESULT_TEMPLATE (RESULT=OK)
```
✅ 세션 이동 완료

이동된 파일:
  - {sid}.jsonl
  - {sid}/subagents/* ({SUBAGENTS_COUNT}개)       ← 있을 때만
  - {sid}/tool-results/* ({TOOL_RESULTS_COUNT}개) ← 있을 때만

최종 경로:
  {TARGET_PROJ}/{sid}.jsonl
  {TARGET_PROJ}/{sid}/                            ← 있을 때만

Resume 방법:
  cd {TARGET_PWD}
  claude
  # 프롬프트에서 `/resume` 입력 후 해당 세션 선택
```
RESULT=FAIL → E14 표 문구로 대체 (ROLLBACK 상태 및 MANUAL_CHECK 내용 인용).

## EDGES (모두 ⚠️ prefix, Korean user-facing, 내용 변경 금지)

| # | 조건 | 메시지 |
|---|---|---|
| 1 | sid==SELF_SESSION | ⚠️ 현재 대화가 이 세션입니다. session-id: `<id>` — 자기 자신은 이동할 수 없습니다. 새 터미널에서 target 경로로 이동 후 `/session-relocate <id> <절대경로>` 로 실행해주세요. |
| 2 | SAME_PWD=1 | ⚠️ 이미 `<target>` 에 존재합니다. 이동이 필요 없습니다. |
| 3 | TARGET_CONFLICT=1 | ⚠️ 충돌: `<target>/<id>.jsonl` 이 이미 존재합니다. 덮어쓰면 기존 로그가 손실됩니다. 수동으로 확인 후 삭제하거나 다른 경로를 지정해주세요. |
| 4 | UUID 불일치 | ⚠️ 유효한 UUID 형식이 아닙니다. 예) `40869acf-3ecf-44ef-99fa-73a88a8388ef` |
| 5 | FALLBACK_USED=1 (컨펌) | ⚠️ 현재 프로젝트에 해당 세션이 없습니다. `<실제 위치>` 에서 발견됨 — 이 경로를 source로 사용할까요? (y/N) |
| 6 | 절대경로 아님 | ⚠️ 절대경로가 필요합니다. (예: `/Users/you/git/project`) |
| 7 | SIDECAR_EXISTS=0 | (정보) sidecar 디렉토리 없음 — 메인 jsonl만 이동합니다. (에러 아님) |
| 8 | 시스템 경로 prefix | ⚠️ 시스템 디렉토리(`/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`, `/`)로는 이동할 수 없습니다. |
| 9 | OUTSIDE_HOME=1 (컨펌) | ⚠️ target이 홈 디렉토리 외부입니다(`<path>`). 계속 진행할까요? (y/N) |
| 10 | LOOP=1 | ⚠️ 순환 경로입니다. source와 target은 서로의 하위일 수 없습니다. |
| 11 | CROSS_FS=1 (컨펌) | ⚠️ source와 target이 다른 파일시스템에 있습니다. 이동이 atomic하게 보장되지 않으며 실패 시 데이터 분리 가능성이 있습니다. 계속 진행할까요? (y/N) |
| 12 | DISK_FULL=1 | ⚠️ 대상 파일시스템 용량이 부족합니다. 필요: `<NEED>KB`, 가용: `<AVAIL>KB`. 중단합니다. |
| 13 | LOCK_PIDS nonempty | ⚠️ source 파일이 다른 프로세스에 의해 열려있습니다(PID: `<pids>`). 세션이 활성 중일 수 있습니다. 중단합니다. |
| 14 | P5 RESULT=FAIL | ⚠️ 이동 중 오류 발생. 자동 롤백 시도 결과: `<성공/실패>`. 실패 시 다음 경로를 수동으로 확인해주세요: source=`<...>`, target=`<...>` |

## HINTS
- jsonl = 한 줄에 한 JSON.
- macOS `realpath` 없으면 py `os.path.realpath`(P2-0 내부 이미 py로 처리).
- 같은 fs `mv` atomic / cross-fs copy+unlink 비원자 → E11.
- cwd decode: dir명 `-`→`/` 간이 변환, pwd에 `-` 포함 시 정확도 떨어짐 → jsonl 첫 `cwd` 필드 우선.
- ⚠️ 메모리/노트 기록 불필요 (단순 파일 이동).

## TOOL_CALL_BUDGET
- nargs=0: bash(P1-1)+py(P1-2)+py(P2-0)+py(P5) = **4**. assistant text 2~3회.
- nargs=2: bash(P1-1)+py(P1-2)+py(P2-0)+py(P5) = **4**. assistant text 2회.
- DRYRUN 단계에서 사이드카 카운트가 P5 이전에 필요하면 py(P2-0)의 SIDECAR_EXISTS만 사용하고 "(N/M개)" 자리는 비우거나, P2-0 스크립트에 `os.listdir` 카운트 추가 가능.
