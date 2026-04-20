# Changelog

이 파일은 session-relocate 플러그인의 모든 주목할 만한 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며, 버전 체계는 [Semantic Versioning](https://semver.org/lang/ko/) 을 사용합니다.

## [1.0.5] - 2026-04-20

### Performance
- **SKILL.md 토큰 사용량 대폭 감축**: 1,028줄 → 403줄 (약 -61%), 41 KB → 19 KB (약 -53%).
- 사용자 노출 문구(안내 2줄, 엣지 14개 메시지, 프롬프트, 드라이런/결과 템플릿)와 실행 스크립트(Python)는 **모두 그대로 유지**.
- 반복 서술/레퍼런스 섹션/장황한 prose 를 단축 기호·축약 표기로 치환.
- 통합 실행 섹션(P1-2, P2-0, P5) 의 Python 은 함수/변수명을 압축하되 로직 동치.
- Phase 2-1 ~ 2-14, Phase 5 Step 1~3 의 중복 레퍼런스 삭제 (통합 스크립트가 이미 같은 검증을 수행).

### Changed
- 섹션 헤더를 `EXEC_IMMEDIATE`, `FLOW`, `CHECK_INTERNAL`, `USER_OUTPUT`, `CARD_TEMPLATE`, `P1-1`, `P1-2`, `P2-0`, `DRYRUN_TEMPLATE`, `CONFIRM`, `P5`, `P6_RESULT_TEMPLATE`, `EDGES`, `HINTS`, `TOOL_CALL_BUDGET` 로 단축.

## [1.0.4] - 2026-04-20

### Fixed
- `/session-relocate` 호출 시 카드 리스트가 바로 뜨지 않고 "스킬이 로드되었습니다. Session Relocate는 ...입니다" 류의 소개 메시지 + "세션을 이동하려고 하시나요?" 재질문이 나오던 문제.
  - SKILL.md 최상단에 "⚡ 즉시 실행 규칙" 섹션 추가: 호출 즉시 도구부터 실행하고 소개/확인/사용법 안내 assistant 텍스트를 일체 금지.
  - frontmatter `description`을 "즉시 이동 실행" 중심의 능동형 문구로 개정. FQN `/session-relocate:session-relocate` 를 트리거 예시에 명시.

### Known Issues
- 슬래시 커맨드 자동완성이 FQN `/session-relocate:session-relocate` 를 제안하는 문제는 Claude Code 플랫폼 동작이므로 플러그인에서 제어 불가. FQN 형태여도 즉시 실행 규칙에 의해 동일하게 카드 리스트부터 출력됨. 단축형 `/session-relocate` 는 `/sess` 까지 타이핑한 뒤 `Esc` 로 자동완성을 닫고 직접 입력하거나, FQN 그대로 전송해도 됨.

## [1.0.3] - 2026-04-20

### Performance
- **도구 호출 횟수 대폭 감축**: Phase 1(4~5회) → 2회, Phase 2(10+회) → 1회, Phase 5(3회) → 1회. 체감 속도 개선.
- Phase 1-2/1-3/1-4 를 단일 통합 Python 스크립트로 병합 (프로젝트 디렉토리 조회 + 자기 세션 판별 + 상위 5개 파싱).
- Phase 2-2 ~ 2-14 를 단일 통합 Python 스크립트로 병합 (realpath·순환·fs·disk·lock·충돌 등 일괄 수행).
- Phase 5 메인·사이드카·정리·롤백을 단일 Python 스크립트로 병합.
- **대용량 jsonl 파싱 최적화**: 마지막 user 엔트리 추출을 256 KB chunk 역방향 seek 방식으로 전환. 수십 MB 파일에서도 빠른 조기 종료.

### Changed
- Claude 내부 선처리 규칙 명시: UUID/절대경로/`~` expansion/시스템 경로 prefix 검증은 도구 호출 없이 텍스트 수준에서 수행.
- 공유 상태를 환경변수(`SESSION_ID`, `TARGET`, `NONCE`, `SRC` 등)로 전달해 중간 덤프 호출 제거.
- 빠른 실행 체크리스트를 "도구 호출 횟수" 기반으로 재작성 (목표: 인자 없음 5회 / 인자 있음 4회).

### Documentation
- 기존 Phase 2-1 ~ 2-14, Phase 5 Step 1~3 개별 서술은 레퍼런스로 남김 (실행은 통합 스크립트 경로로).

## [1.0.2] - 2026-04-20

### Changed
- 실행 순서 규칙 강화: 모든 백그라운드 작업(NONCE 주입, 세션 스캔, 파싱)을 먼저 끝내고 최종 응답 한 번으로 안내 문구·카드·프롬프트를 출력.
- NONCE 주입 방식을 `echo` → `:` no-op + Claude가 매 호출마다 생성하는 literal 문자열로 변경. 툴 실행 로그 노이즈 최소화.
- 파서(Python) stdout을 사용자에게 그대로 노출하지 않고 내부 데이터로만 취급함을 명시.

### Fixed
- bash 출력과 카드 리스트가 뒤섞여 사용자가 `ctrl+o` 로 툴 결과를 펼쳐야 카드를 볼 수 있던 문제.
- 안내 문구와 카드 리스트가 bash 실행 전후로 갈라져 노출되던 순서 문제.

## [1.0.1] - 2026-04-17

### Changed
- 리스트업 범위를 상위 9개 → 상위 5개로 축소 (자기 세션 제외).
- 10번 이후 요약 테이블 및 상세 펼침 로직 제거.
- 인자 없이 호출 시 상단 안내를 2줄 고정 문구로 고정:
  - `최근 사용된 5개의 세션 리스트가 제공 됩니다. 이동하려는 세션의 no를 입력해주세요.`
  - `(오래된 세션을 이동하려면 해당 세션을 1회 이상 사용 후 시도해 주세요.)`
- 사용자 노출 출력 규칙 추가: Phase/Step 번호, 진행 상황 서술, 불필요한 보조 안내 금지.

### Removed
- 리스트 하단의 `번호를 입력하거나 /resume 로 돌아가세요.` 류 보조 안내 문구.

## [1.0.0] - 2026-04-17

### Added
- 초기 릴리스.
- Claude Code 세션 로그(`~/.claude/projects/<encoded-pwd>/<session-id>.jsonl`) 와 사이드카 디렉토리(`<session-id>/subagents/`, `<session-id>/tool-results/`)를 다른 pwd 프로젝트 디렉토리로 이동.
- 두 가지 호출 방식: 인자 없음(리스트업 모드) / `/session-relocate <session-id> <절대경로>`.
- NONCE 마커 기반 자기 세션 판별.
- 상위 9개 카드 + 10번 이후 요약 테이블 하이브리드 리스트업(1.0.1에서 5개 카드로 축소).
- 경로 보안: realpath 정규화, 시스템 디렉토리 차단, HOME 외부 경고, 순환 경로 차단.
- 이동 원자성: 같은 파일시스템 체크, disk 용량 사전 확인, 파일 잠김 검사, 실패 시 자동 롤백.
- 14개 엣지 케이스 처리 (모두 `⚠️` prefix).
- 드라이런 + 사용자 컨펌 2단 안전장치.
