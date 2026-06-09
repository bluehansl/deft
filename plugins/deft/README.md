# deft

bluehansl 개인 워크플로 도구 모음. Claude Code / Codex 양쪽에서 동일하게 **`deft:<skill>`** 로 호출한다.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI **1회성** 교차검증/비교 (fan-out) |
| `deft:multi-round` | **여러 AI가 N라운드 양방향으로 토론·합의 도달** 하는 멀티턴 회의. cmux 환경에선 pane 시각화, cmux 외부에선 `claudex mcp-server` 경유. [상세 가이드](skills/multi-round/GUIDE.md) |
| `deft:agent-teams` | **Claude 내장 팀 기능으로 다중 에이전트 팀(Lead+backend/frontend/qa 등) 운영**. 분담 구현·검증·리뷰. work-id 기반 영속 작업노트. [상세 가이드](skills/agent-teams/GUIDE.md) |
| `deft:session-relocate` | Claude Code 세션 로그를 다른 프로젝트 디렉토리로 이동(`/resume` 대상화) |
| `deft:set-statusline` | 터미널 상태줄(statusline) 설정 |
| `deft:restore-statusline` | 상태줄 복원 |

### 3-도구 비교 — 언제 어느 걸 쓸까

| 도구 | 통신 | AI 조합 | 의존성 | 한 줄 |
|---|---|---|---|---|
| `multi-check` | **1회성** fan-out | Codex/Claude/Gemini 동시 | CLI 직접 (MCP 무관) | "한 번 물어보고 답만 비교" |
| `multi-round` | **지속 N라운드 양방향** | Claude + Claudex mix | **cmux 환경: pane 시각화 / cmux 외부: MCP 경유** | "의견 갈리는 문제 토론해서 합의" |
| `agent-teams` | 지속 multi-turn 협업 | Claude끼리만 | **Claude 내장 팀 기능** | "코드 분담 구현·검증·리뷰·작업노트 관리" |

→ **답이 하나면** `multi-check`, **답을 좁혀가야 하면** `multi-round`, **코드를 만져야 하면** `agent-teams`.

## 설치 (Claude Code)

```
/plugin marketplace add bluehansl/deft
/plugin install deft@bluehansl
```

## 사용자 데이터 경로 컨벤션

deft 플러그인의 모든 스킬은 사용자 데이터(세션·메타·hooks 등)를 다음 경로 하위에 **스킬별로 구분하여** 저장한다.

- **Claude 측**: `~/.claude/plugin-data/deft/<skill>/`
- **Codex 측**: `~/.codex/plugin-data/deft/<skill>/`

플러그인 cache 영역(`~/.claude/plugins/cache/...`, `~/.codex/plugins/cache/...`)에는 사용자 데이터를 두지 않는다.

## 마이그레이션 (개별 플러그인 → deft 통합)

기존 개별 플러그인 `multi-check` / `session-relocate` / `set-statusline` 은 단일 브랜드 `deft` 로 통합되었다. 네임스페이스 매핑:

| 구 (v1) | 신 (deft) |
|---|---|
| `multi-check:multi-check` | `deft:multi-check` |
| `session-relocate:session-relocate` | `deft:session-relocate` |
| `set-statusline:set-statusline` | `deft:set-statusline` |
| `set-statusline:restore-statusline` | `deft:restore-statusline` |

> 스킬명은 그대로 유지되고 플러그인 네임스페이스만 `deft` 로 통일되었다. 기존 사용자는 구 플러그인 3개를 제거한 뒤 `deft` 를 새로 설치하면 된다. (네임스페이스 변경 = breaking → `claude-2.0.0`)
