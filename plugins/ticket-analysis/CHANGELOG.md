# Changelog — ticket-analysis

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
