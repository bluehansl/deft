<!-- 기록 계층(영속화) 규약의 단일 소스 문서. 산출물 경로는 artifact-routing.md 가 이 문서의 projects/ 칸을 상세화한다. -->

# 기록 계층 규약 (도구 무관 — 영속 저장소가 있는 환경의 기본값)

작업 기록이 놓이는 자리를 한곳에 모은 문서다. **경로·파일명의 정본은 이 문서와 `artifact-routing.md`이고, 다른 스킬(deft `agent-teams`·`multi-round`·`multi-check` 등)은 자체 정의 없이 이 문서를 가리킨다** — 소유자를 하나로 두어야 저장 구조가 바뀔 때 한 곳만 고치면 된다.

루트는 `BIV="${BIV_ROOT:-$HOME/obsidian-vault/BIV}"`. 이 저장소는 git(+LFS)이며 **커밋·push 는 저장소 쪽이 자동으로 한다** — 스킬이 커밋하지 않는다.

## 1. 무엇이 어디로 가는가

| 기록 | 자리 | 누가 쓰는가 |
|---|---|---|
| **프로젝트 레코드** | `$BIV/<소유>/projects/<ID>/<ID>.md` (폴더 노트 — 파일명 = 폴더 ID) | 스킬·Lead. 스키마는 `ticket-md-schema.md` |
| **대외 완성물** (사용자 보고·타팀 공유·배포 파일) | 레코드와 **같은 폴더** `$BIV/<소유>/projects/<ID>/` | 상세 규칙은 `artifact-routing.md` |
| **결정·지식** (여러 프로젝트에 걸치거나 프로젝트가 없는 것) | `$BIV/<소유>/knowledge/` — 결정 노트는 `knowledge/decisions/` 에 고유 이름으로 | 회의 결론·설계 판정 등 |
| **세션 원문** (대화 전문·결정 문장 후보·세션 간 메시지 장부) | `$BIV/<소유>/sessions/raw/` — **턴 종료 훅이 자동 기록**한다 | 훅. 스킬은 쓰지 않는다 |
| **요약 워크로그** | `$BIV/<소유>/sessions/` | `/session-save`(Claude) · `$session-save`(claudex) |
| **세션 ↔ 프로젝트 매핑** | `$BIV/_index/session-project.json` | `/biv-import` 가 갱신. **스킬이 직접 쓰지 않는다** |
| **세션 간 의뢰·응답** | `$BIV/inbox/` — 요청서·응답 파일이 **정본**이고 크로스세션 메시지는 "파일 읽어 달라"와 짧은 문의·회신용. 요청자가 `status: done` 으로 닫는다(`inbox/README.md` 규약) | 의뢰 세션·수행 세션 |
| **도구/팀 내부물** (작업노트·역할노트·오케스트레이션 로그·세션 임시물) | 각 도구의 데이터 영역 (`~/.claude/plugin-data/…` · `~/.codex/plugin-data/…`) | **프로젝트 폴더에 두지 않는다** (`artifact-routing.md` §표) |

`<소유>` 는 `fassto`(회사 티켓) 또는 `personal`(개인 주제). `<ID>` 는 이슈 키(`IT-12345`) 또는 ASCII 슬러그(`[a-z0-9][a-z0-9-]{2,40}`).

- **`_index/*` 는 저장소 내부 파일이다.** 스킬이 직접 읽거나 쓰지 않는다 — 필요한 것은 아래 스크립트·스킬을 통해 얻는다. 스킬이 인덱스 구조에 결합되면 저장소 쪽 변경이 스킬 수정을 강제한다.
- 스킬이 부르는 저장소 스크립트는 셋뿐이다: `_tools/index/resolve_project.py`(이름→ID 해석) · `_tools/index/import_pack.py`(맥락 팩) · `_tools/index/build_projects_index.py --quiet`(레코드 생성 직후 1회).

## 2. 세션을 프로젝트에 묶는다 (워커·회의·리뷰어를 띄울 때 필수)

보조 세션의 대화 원문도 훅이 자동으로 남기지만, **그 세션이 어느 프로젝트의 것인지는 자동으로 정해지지 않는다.** 그래서 세션을 띄울 때 킥오프 지시문에 맥락 복원 호출을 **한 번** 넣는다. 넣지 않으면 그 세션의 원문이 프로젝트에 묶이지 않아 나중에 `/biv-import` 로 되찾을 수 없다.

| 띄우는 도구 | 킥오프에 넣을 한 줄 |
|---|---|
| Claude (`Agent` · `claude` CLI · 팀원) | `/biv-import <ID> --light` |
| claudex / codex | `$biv-import <ID> --light` — Codex 호스트는 스킬을 `$이름` 으로 호출한다 |

- 프로젝트가 없는 독립 작업은 `<ID>` 대신 `--self` 를 쓴다 (`/biv-import --self --light`).
- **추가 인자는 없다.** 세션 식별은 호출된 스킬이 스스로 한다 — Claude 는 `CLAUDE_CODE_SESSION_ID`, claudex 는 저장소 인덱스의 도구별 키를 쓴다. 같은 폴더에서 Claude·claudex 세션이 동시에 돌아도 섞이지 않는다.
- 도구별로 **표기가 다르다**(`/` vs `$`). 틀린 표기를 넣으면 워커가 조용히 아무것도 하지 않으므로, 어느 도구를 띄우는지에 맞춰 넣는다.

## 3. work-id ↔ 프로젝트 ID 변환

deft 스킬의 `work-id` 규약은 기본값이 git 브랜치명(예 `feature/IT-14610`)인데 레코드 ID 는 `IT-14610`·슬러그다. 변환은 아래 순서로 한 번만 한다.

1. work-id 에서 **이슈 키 패턴**(`[A-Z]+-\d+`)을 찾으면 그것이 ID 다 — `feature/IT-14610` → `IT-14610`.
2. 없으면 **슬러그 해석**을 시도한다: `python3 -I "$BIV/_tools/index/resolve_project.py" "<work-id 또는 작업 이름>"`.
   - 결과가 `ambiguous`(동점)이거나 `id: null` 이면 **추측하지 않고 사용자에게 확인**한다. 해석기는 동점을 실제로 돌려준다.
3. 그래도 없으면 **프로젝트 없음**으로 보고 산출물은 작업 repo 에, 결정은 `knowledge/` 에 둔다.

`work-id` 규약 자체(명명 메뉴·변경 절차)는 deft 가 소유하고 config 에 저장한다. Claude 는 `~/.claude/plugin-data/deft/config.json`, Codex 는 `~/.codex/plugin-data/deft/config.json` → 없으면 Claude 측을 읽어 복사한다. **한쪽에서 규약을 바꾸면 다른 쪽도 맞춘다** — 복사 뒤에는 두 파일이 갈린다.

## 4. 하지 않기로 한 것도 남긴다

검토 뒤 기각·보류한 작업은 **요약 워크로그의 `## 하지 않기로 한 것` 절**에 이유와 함께 남긴다. 팀·회의 작업에서는 리드가 종료 시 한 번 쓴다.

- 작업노트(`work.md`)·역할노트는 도구 내부물이라 다른 기기·다른 도구에서 보이지 않는다. **결정과 기각 사유는 워크로그로 내보내야** 남는다.
- 세션을 시작할 때 그 절을 먼저 읽고, 거기 적힌 작업을 다시 하려면 **사용자에게 그 결정을 먼저 알린다**.
