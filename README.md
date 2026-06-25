# bluehansl-plugins

Codex and Claude Code plugins by bluehansl.

모든 스킬은 단일 브랜드 플러그인 **`deft`** 하나로 통합되어 있다. Claude/Codex 양쪽에서 동일하게 **`deft:<skill>`** 로 호출한다.

## deft 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex · Gemini · Claude 다중 AI **1회성** 교차검증/비교 (fan-out) |
| `deft:multi-round` | **여러 AI(Claude/Claudex)가 N라운드 협업하는 멀티턴** — ① 회의 모드: 양방향 토론으로 합의 도달(board 브로드캐스트 + 노크) ② 작업 모드: NTP mesh 로 일 분담. cmux pane 시각화 |
| `deft:agent-teams` | **Claude 내장 팀으로 다중 에이전트(Lead+backend/frontend/qa 등) 운영** — 분담 구현·검증·리뷰, work-id 영속 작업노트 |
| `deft:session-relocate` | 세션을 다른 프로젝트의 `/resume` 목록에 보이도록 이동 |
| `deft:set-statusline` | 상태줄(statusline / Codex `[tui].status_line`) 설정 |
| `deft:restore-statusline` | 상태줄 복원 |

→ **답이 하나면** `multi-check`, **답을 좁혀가야 하면** `multi-round`, **코드를 만져야 하면** `agent-teams`. (상세 비교·트리거·예제는 [`plugins/deft/README.md`](./plugins/deft/README.md))

- Claude: [`plugins/deft`](./plugins/deft/)
- Codex: [`plugins/codex/deft`](./plugins/codex/deft/) — `multi-round`/`multi-check` 등 (agent-teams 는 Claude 전용)

## Claude Code Installation

```bash
# Register marketplace
/plugin marketplace add bluehansl/deft

# Install plugin
/plugin install deft@bluehansl
```

## Codex Installation

```bash
codex plugin marketplace add bluehansl/deft
codex plugin add deft@bluehansl-codex
```

로컬 repo를 직접 등록하는 경우:

```bash
codex plugin marketplace add /path/to/bluehansl-plugins
codex plugin add deft@bluehansl-codex
```

## 마이그레이션 (개별 플러그인 → deft)

기존 `multi-check` / `session-relocate` / `set-statusline` 3개 플러그인이 단일 `deft` 로 통합되었다. 스킬명은 유지되고 네임스페이스만 통일된다.

| 구 (v1) | 신 (deft) |
|---|---|
| `multi-check:multi-check` | `deft:multi-check` |
| `session-relocate:session-relocate` | `deft:session-relocate` |
| `set-statusline:set-statusline` | `deft:set-statusline` |
| `set-statusline:restore-statusline` | `deft:restore-statusline` |

네임스페이스 변경 = breaking. 기존 사용자는 구 플러그인 3개를 제거하고 `deft` 를 새로 설치한다. (Claude `claude-2.0.0`, Codex `codex-1.0.0`)
