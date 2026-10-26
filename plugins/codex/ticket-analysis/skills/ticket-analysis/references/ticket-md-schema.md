<!-- 프로젝트 레코드 `<ID>.md` 표준 스키마의 단일 소스 문서. 호스트 지침에서 스킬로 이전(2026-07-31). -->

# 프로젝트 레코드 표준 구조 (`<ID>.md`)

볼트 `$BIV/<소유>/projects/<ID>/<ID>.md` 의 표준 스키마. 단일 Claude·팀 작업 공통.

레코드 **파일명은 폴더 ID와 같다**(옵시디언 폴더 노트) — 예 `fassto/projects/IT-15507/IT-15507.md`.
옵시디언 그래프·탐색기·검색이 파일명을 노드 이름으로 쓰기 때문이다(`ticket`·`project` 가 수십 개면 정보 노드가 되지 못한다).
읽을 때도 **`<ID>.md` 하나만** 본다 — 볼트는 git 단일 저장소라 모든 기기가 같은 트리를 받으므로 기기별 파일명 차이가 없다.

## frontmatter (필수 머리)

```yaml
---
type: project
id: "IT-15507"                 # 폴더명. Jira 키 또는 [a-z0-9][a-z0-9-]{2,40}
owner: fassto                  # fassto | personal — 폴더 <owner>/projects/<id>
title: "[FMS] 파스토아이 촬영 시작 개선 — …"
aliases: []                    # 사람이 부르는 다른 이름(한글 가능) — 해석기가 매칭에 쓴다
jira: IT-15507                 # 없으면 키 자체를 생략 (주제 프로젝트)
system: ["fsswms", "fassto-eye"]   # cwd 레포 기반 기본값 — ticket-workflow.md §2
status: in-progress            # draft | in-progress | blocked | verifying | done | unknown
status_text: "…"               # 상태 줄 원문(120자)
epic: "[[fassto/projects/IT-14535/IT-14535]]"   # 상위 에픽 레코드가 볼트에 있을 때만. 없으면 키 생략
touches: []                    # 시스템 노드 위키링크
process: []                    # 도메인 프로세스 노드
related: ["[[fassto/projects/IT-15444/IT-15444]]"]   # 연결 프로젝트(볼트 절대경로)
mentions_screens: ["pac014"]   # 본문 2회 이상 언급
mentions_tables: ["TB_OUT_PACK_ERR_LOG"]
created: 2026-10-02T17:06:01+09:00
updated: 2026-10-07T14:54:05+09:00
---
```

**키 순서 (고정)**: `type, id, owner, title, aliases, jira, system, status, status_text, epic, touches, process, related, mentions_screens, mentions_tables, created, updated`
— `epic` 은 `status_text` 다음, `touches` 앞. **순서를 바꾸지 않는다** — 그래프·Breadcrumbs 가 키를 읽고, 순서가 흔들리면 diff 가독성도 떨어진다.

갱신 시에는 **frontmatter 만 고치고 본문은 보존**한다(`ticket-workflow.md` §4 규약).

## 본문

```markdown
# {ID} - {제목}

## META
- 티켓: {TICKET_ID}
- 상태: {Draft | In Progress | Blocked | 검증중 | 완료}
- 작성일 / 최종 수정일: {YYYY-MM-DD}
- 브랜치: {feature/TICKET_ID}
- 대상 메뉴/모듈: {메뉴명 (모듈코드)}
- 핵심 파일: `{파일경로}` ({메서드/쿼리id}, 라인 {N~M})
- 연결 이슈: (relates to 가 있는 경우)

## 요건 분석
### 작업 목표 / 작업 범위(포함·제외) / 요구사항 상세 / 원인 분석(버그·튜닝)

## 영향도 확인
### Controller / Service / Mapper · SQL / Entity · 기타

## 설계 결정
### 채택한 방식 / 미채택 대안 및 사유
### 미해결 결정사항
- [ ] {Q1} → 해결 시 [해결] {결론, YYYY-MM-DD}

## 작업 계획
<!-- 체크리스트가 유일한 진행 상태 소스. 의존: ← (N번과 병렬) / ← (N번 후속) -->
### Phase 1 DB/Mapper · Phase 2 Backend · Phase 3 Frontend · Phase 4 검증

## 협의사항
- 역할 간 인터페이스 협의·기획 변경 이력

## FRONTEND / BACKEND / QA / REVIEW
- 각 역할 작업노트 취합본 + 코드 리뷰·테스트 결과

## 검증 이력
### {YYYY-MM-DD} {제목} — 목적 / 방식 / 결과 / 잔여물

## 롤백/복구
- DB 롤백: {SQL 또는 절차} / 코드 롤백: {브랜치·커밋 해시}
```

- 체크리스트 플래그·상위 상태 종합·넘버링·의존 표기 문법은 `ticket-workflow.md` §5를 따른다.
