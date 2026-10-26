# Changelog — ticket-analysis

## claude-0.3.0 / codex-0.3.0 (2026-10-26)

> **기록 계층 규약 단일 소스 신설 + 구 레코드 파일명 호환 제거** — 의뢰: `BIV/inbox/2026-10-26-요청-deft-ticket-analysis-스킬-영속화-구조-리빌딩.md`(요구 A·B·C). 영속 저장소 구조가 2026-10-19~26 에 바뀌어 스킬이 읽고 쓰는 자리를 맞췄다. 양 트리 동시 반영(`skills/` 는 바이트 동일).

### Added
- **`references/vault-layout.md` 신설** — 기록 계층 전체의 단일 소스. 레코드 `<소유>/projects/<ID>/<ID>.md` · 대외 완성물(같은 폴더) · 결정·지식 `<소유>/knowledge/` · 세션 원문 `<소유>/sessions/raw/`(훅 자동) · 요약 워크로그(`/session-save`) · 세션↔프로젝트 매핑 `_index/session-project.json` · 도구 내부물(plugin-data, 프로젝트 폴더 금지)을 한 표에 모았다.
  - **새 문서를 deft 가 아니라 ticket-analysis 에 둔 이유**: `claude-2.55.0` 이 경로 소유자를 ticket-analysis 하나로 모았고(그 전에는 deft 에 옛 경로 리터럴이 남아 **별칭 제거가 막혔다**), deft 쪽은 포인터만 둔다. deft 에 문서를 새로 만들면 소유자가 둘로 돌아가 같은 결함이 재발한다. 요청 원안(`plugins/deft/references/vault-layout.md`)에 이 근거를 제시해 **대안 A′ 로 확정**됐다(요청자 판단 2026-10-26).
  - **`_index/*` 는 스킬이 직접 읽거나 쓰지 않는다**고 명문화했다. 실측: 전 스킬 문서에서 `current-session.json`·`session-project.json`·`raw-state`·`graph.json` 참조 **0건**. 스킬이 인덱스 구조에 결합되면 저장소 변경이 스킬 수정을 강제한다.
- **세션↔프로젝트 묶기 규약**(요구 B) — 워커·회의·리뷰어 세션을 띄울 때 킥오프에 맥락 복원 호출을 **한 번** 넣는다. **도구별로 표기가 다르다**: Claude `/biv-import <ID> --light`, claudex/codex **`$biv-import <ID> --light`**(Codex 호스트가 스킬을 `$이름` 으로 호출 — 요청자 실측). 프로젝트가 없으면 `--self`. 추가 인자는 없다(세션 식별은 호출된 스킬이 한다). 틀린 표기를 넣으면 워커가 조용히 아무것도 하지 않으므로 도구에 맞춰 넣는다.
- **work-id ↔ 프로젝트 ID 변환**(요구 C) — ① work-id 에서 이슈 키 패턴(`[A-Z]+-\d+`) 추출(`feature/IT-14610` → `IT-14610`) ② 없으면 `resolve_project.py` 로 슬러그 해석, **`ambiguous`·`id: null` 이면 추측하지 않고 사용자 확인**(해석기는 동점을 실제로 돌려준다) ③ 그래도 없으면 프로젝트 없음. config 가 Claude·Codex 둘로 갈리는 문제는 "복사 뒤에는 갈리므로 한쪽을 바꾸면 양쪽을 맞춘다"로 명시.
- **"하지 않기로 한 것"을 워크로그로 내보내는 규약** — 작업노트·역할노트는 도구 내부물이라 다른 기기·다른 도구에서 보이지 않는다. 기각·보류 사유는 요약 워크로그의 `## 하지 않기로 한 것` 절에 남기고, 세션 시작 시 먼저 읽는다. 거기 적힌 작업을 다시 하려면 사용자에게 먼저 알린다.
- `README.md` 문서 목록에 `vault-layout.md` 행 추가.
- `vault-layout.md` §1 에 **세션 간 의뢰·응답(`inbox/`)** 행 — 요청서·응답 파일이 정본이고 크로스세션 메시지는 보조라는 점, 요청자가 `status: done` 으로 닫는다는 점(요청자 제안 2026-10-26 수용 — 기록 계층의 단일 소스라면 세션 간 의뢰 자리도 있어야 완결이다).

### Removed
- **구 레코드 파일명 호환 탐지 제거** — 읽기 순서가 `<ID>.md` → `project.md` → `ticket.md` 3단이었다. 이제 **`<ID>.md` 하나만** 본다. `ticket-md-schema.md`(머리 주석·읽기 순서 2곳), `ticket-workflow.md`(§2 팩 폴백·§4 Lead 단독 writer 2곳), `README.md`(2곳), `plugin.json` 설명(Claude 1곳 / Codex `description`·`longDescription` 2곳).
  - 근거: 볼트는 **git 단일 저장소**라 모든 기기가 같은 트리를 받으므로 "다른 기기용 호환 경로"라는 전제 자체가 성립하지 않는다(요청자 확인 2026-10-26). 실측(2026-10-20)에서 레코드 39개가 전부 `<ID>.md`, `project.md` 는 0개였고 잔존 `ticket.md` 4건은 `backup/`·`analysis/*/before/` 스냅샷으로 레코드가 아니다.
- **"호환을 제거했다"는 설명도 스킬 문서에 남기지 않았다.** 처음엔 각 지점에 제거 경위를 적었는데, 자체 검증(라이브 문서 옛 이름 0건)이 그 설명 문장을 잡아냈다 — 요구가 "호환 설명까지 포함해 전부 제거"였다. 기준을 느슨하게 고치지 않고 문서를 기준에 맞췄다. 변경 경위는 CHANGELOG 가 소유하고 스킬 문서는 **현재 규칙만** 적는다(문서 3분할 관례).
- `~/.ai/tickets` 는 **제거 대상이 아니었다** — 라이브 문서에 0건이고 CHANGELOG 이력에만 있다. 이력 문서는 "그때 무엇이 사실이었나"를 남기므로 현재 기준으로 고치지 않는다(`0.2.1` 과 같은 판단).

### Changed
- `artifact-routing.md` — 본 문서가 **기록 계층 중 `projects/` 칸(산출물)을 상세화**한 것임을 1줄로 연결. 산출물 경로의 정본성은 그대로 유지하고, 전체 자리는 `vault-layout.md` 가 소유한다.
- `plugin.json` 설명의 `ticket.md` → `레코드 <ID>.md`. **트리거 문구(티켓 선언·요건 분석·Plan·버그 원인 등)는 건드리지 않았다** — 바뀐 것은 괄호 안 산출물 이름 하나다.

### Verified
- 라이브 문서(`skills/`·`README.md`·`plugin.json`)에서 `ticket.md`·`project.md` **0건**. CHANGELOG 이력은 보존.
- 양 트리 `skills/` `diff -rq` **무차이**(Claude 수정 후 Codex 로 동기, `vault-layout.md` 양쪽 5,855 bytes 동일).
- JSON 3건 파싱 통과(`plugin.json` 양 트리 · `marketplace.json`). `.agents/plugins/marketplace.json` 의 ticket-analysis 항목에는 `version` 필드가 없어 미변경(레포 지침 §1-2).
- **미검증(한계 명시)**: `plugin.json` 설명 변경의 트리거 발동 영향을 eval 로 측정하지 않았다 — ticket-analysis 용 eval 스위트가 아직 없다(`plugins/deft/evals/` 는 deft 전용). 변경이 트리거 문구가 아닌 괄호 안 이름 하나이므로 위험은 낮다고 보지만, **측정한 것은 아니다.** 스위트 신설은 별 과제로 둔다.

## claude-0.2.1 / codex-0.2.1 (2026-10-20)

### Removed
- `ticket-workflow.md` §1 — **볼트 루트 3순위 폴백 제거**. 구 홈 별칭이 2026-10-20 03:01 KST 에 실제로 제거되면서(볼트 세션 수행) 그 경로를 경유하던 폴백이 죽은 코드가 됐다. 폴백은 `BIV_ROOT` → `$HOME/obsidian-vault/BIV` **2단**으로 줄였고, `../..` 단계 수를 설명하던 주석도 함께 삭제했다.
- `artifact-routing.md` — "하위 호환 별칭" 설명을 제거하고 "볼트 규칙이 유일한 정본"으로 정리.

### Verified
- 전 스킬 문서(`plugins/*/skills/`, `plugins/codex/*/skills/`)에서 구 별칭 경로 **0건**. CHANGELOG 의 과거 이력 언급은 **의도적으로 보존**한다 — 이력 문서는 "그때 무엇이 사실이었나"를 남기므로 현재 기준으로 고치지 않는다.
- 양 트리 `diff -rq` 무차이, frontmatter strict YAML OK.

## claude-0.2.0 / codex-0.2.0 (2026-10-20)

> **프로젝트 선언·임포트 확장** — 티켓 키(`IT-\d+`)뿐 아니라 주제 프로젝트 슬러그·한글 제목으로도 작업을 선언·임포트한다. 해석·팩 생성은 **볼트 스크립트를 호출만** 하고 스킬에 로직을 중복 구현하지 않는다. 의뢰: 볼트 영속화 세션(요청서 `BIV/inbox/2026-10-19-요청-ticket-analysis-…`), v2 + 정정 2건 반영.

### Added
- `ticket-workflow.md` §1 — **선언 확장**. `현재 프로젝트가 <ID|제목>`·`<제목> 프로젝트 임포트`·`<ID|제목> 이어서` 감지. 해석은 `resolve_project.py` 에 위임하고 `match` 4값 전부 분기를 정의: `exact`(즉시) / `partial`(1위 추천 + **질문 1회**) / `ambiguous`(`id: null` — 후보만 제시, **추천 세우지 않음**) / `none`(새 프로젝트 제안).
- `ticket-workflow.md` §2 — **임포트 팩 로드**(`import_pack.py --budget 3000`). 레코드 재독 없이 팩 출력을 컨텍스트로 쓴다. **Jira 로드는 `jira` 키가 있을 때만**(주제 프로젝트는 Jira 없음).
- `ticket-workflow.md` §2 — **`epic` 기입**: Jira parent 의 레코드가 볼트에 있을 때만 위키링크 기입, 없으면 키 생략, **에픽 노드 신규 생성 금지**, 기존 값 보존(레코드 직접 확인 후 기입).
- `ticket-workflow.md` §2 — **`system` 기본값**: cwd 레포 매핑(`fsswms`·`fsswms2`→`fsswms` / `fassto-eye` / `fsshome2`→`homepage`), 분석 중 추가, 개인 주제는 `[]`.
- `ticket-workflow.md` §4 — **frontmatter 링크 기입**: 요건 분석 끝에 `mentions_screens`·`mentions_tables`, 결과 보고에 `related`·`status`·`status_text`·`updated`(KST). **frontmatter 만 수정·본문과 키 순서 보존**, 파일 단위 단일 편집자, 새 프로젝트 후 `build_projects_index.py --quiet` 1회.
- `ticket-md-schema.md` — **frontmatter 표준 머리** 신설 + **키 순서 고정** 명시(`epic` 은 `status_text` 다음·`touches` 앞).

### Changed
- **레코드 파일명이 `<ID>.md`** (폴더 ID와 동일 — 옵시디언 폴더 노트). 읽기는 `<ID>.md` → `project.md` → `ticket.md` 순 탐지(뒤 둘은 과거 트리·다른 기기용). 이유: 그래프·탐색기가 파일명을 노드 이름으로 쓰므로 `ticket`·`project` 가 수십 개면 정보 노드가 되지 못한다.
- **경로 정본이 볼트**로 이동 — `$BIV/<소유>/projects/<ID>/`(`BIV_ROOT` → `$HOME/obsidian-vault/BIV` → `realpath ~/.ai/tickets`/../.. 순 폴백). `~/.ai/tickets` 는 하위 호환 별칭이며 새 문서에 쓰지 않는다. `artifact-routing.md` 경로 표현 4곳 교체 + 볼트 자동 커밋 안내.
- `SKILL.md` — `description` 에 프로젝트 선언 문구 추가(트리거 확장), 소유권·라우팅 표를 "프로젝트/레코드" 용어로 갱신.
- 양 트리(Claude·Codex) **동일 적용** — `diff -rq` 무차이 확인.

### Fixed (적용 중 검증이 잡은 자체 오류 2건)
- **폴백 경로가 볼트 루트를 못 가리켰다** — `realpath ~/.ai/tickets`/`..` 는 별칭이 `<BIV>/fassto/projects` 를 가리키므로 **`<BIV>/fassto`** 가 된다. `../..` 두 단계로 정정(요청서 v1 의 `BIV/tickets` 기준 표현을 그대로 가져온 실수).
- **"팩은 `epic` 을 출력하지 않는다"는 서술이 사실과 달랐다** — 팩은 `epic` 을 출력한다. 다만 팩이 레코드보다 오래된 스냅샷일 수 있어(세션 주입 팩에 `epic` 없음 → 이후 볼트가 19건 채움) "기입 전 레코드 직접 확인" 지침은 유지하고 근거만 정정.
- **`ambiguous` 분기 누락** — 초안은 "`ambiguous` 는 관측되지 않음"으로 단정해 분기를 비워 뒀으나, 검증에서 실제로 발생(`"파스토아이 인프라 IAM 권한 변경"` → `id: null`, 동점 2점 후보 2개). 표본 4개로 부재를 단정한 오류. 4값 전부 정의로 수정.

### Verified (실측 2026-10-20)
- 해석기 분기 4값 전부 재현 — `exact`(IT-15507) / `partial`(1위 3점 단독) / `ambiguous`(2점 동점) / `none`(토큰 일치 0).
- `epic` 형식 볼트 기존 19건과 동일(`[[fassto/projects/IT-14535/IT-14535]]`), `system` 분포 대조(단일 24·복수 9).
- 스키마 문서의 YAML 블록을 **파싱해 키 순서 일치 확인**(예시가 곧 계약이므로 기계 검증).
- 폴백 `../..` 가 볼트 루트를 정확히 반환. frontmatter strict YAML 양 트리 OK(Codex 파서 호환).

## codex-0.1.0 (2026-07-31)

- Codex 포팅본 최초 릴리스 (`plugins/codex/ticket-analysis/`) — Claude판 claude-0.1.0과 동일 내용 (스킬 6문서 verbatim 복사)
- `.codex-plugin/plugin.json` 메타 + Codex 마켓(`.agents/plugins/marketplace.json`) 등록

## claude-0.1.0 (2026-07-31)

- 최초 릴리스: 티켓 분석·운영 스킬
  - `ticket-workflow` — 티켓 선언·컨텍스트 로드(이슈 트래커 본문·댓글·연결 이슈)·도구 선택·단계별 승인 절차(7단계)·체크리스트 문법 (호스트 지침에서 이전)
  - `artifact-routing` — 산출물 경로 라우팅·브라우저 리뷰 문서/Export 규칙·제출 감시 (호스트 지침에서 이전)
  - `ticket-md-schema` — ticket.md 표준 스키마 (호스트 지침에서 이전)
  - `requirement-refinement` — 요건 정제 (superpowers brainstorming 이식)
  - `plan-writing` — 구현 계획 작성 (superpowers writing-plans 이식, TDD 실행 체인 제외)
  - `defect-analysis` — 버그 원인 진단 (superpowers systematic-debugging Phase 1~3 이식)
- 설계: 스킬이 티켓 프로세스의 단일 소스, 호스트 지침에는 트리거 문구만 잔존
- 검증: 가상 티켓 3종 with/without 벤치마크 100% vs 80%, 사용자 정성 리뷰 통과
