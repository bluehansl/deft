# bluehansl-plugins

Codex and Claude Code plugins by bluehansl.

모든 스킬은 단일 브랜드 플러그인 **`deft`** 하나로 통합되어 있다. Claude/Codex 양쪽에서 동일하게 **`deft:<skill>`** 로 호출한다.

## deft 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex · Gemini · Claude 등 여러 AI reviewer로 단발성 교차 검증 |
| `deft:session-relocate` | 세션을 다른 프로젝트의 `/resume` 목록에 보이도록 이동 |
| `deft:set-statusline` | 상태줄(statusline / Codex `[tui].status_line`) 설정 |
| `deft:restore-statusline` | 상태줄 복원 |

- Claude: [`plugins/deft`](./plugins/deft/)
- Codex: [`plugins/codex/deft`](./plugins/codex/deft/)

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
