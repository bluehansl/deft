# bluehansl-plugins

Codex and Claude Code plugins by bluehansl.

## Plugins

| Plugin | Codex path | Description |
|---|---|---|
| [multi-check](./plugins/multi-check/) | [`plugins/codex/multi-check`](./plugins/codex/multi-check/) | Codex, Gemini, Claude 등 여러 AI reviewer로 단발성 교차 검증을 수행 |
| [session-relocate](./plugins/session-relocate/) | [`plugins/codex/session-relocate`](./plugins/codex/session-relocate/) | Codex 세션을 다른 프로젝트의 `/resume` 목록에 보이도록 연결 |
| [set-statusline](./plugins/set-statusline/) | [`plugins/codex/set-statusline`](./plugins/codex/set-statusline/) | statusline 설정/복원 |

## Codex Installation

```bash
codex plugin marketplace add bluehansl/bluehansl-plugins
codex plugin add multi-check@bluehansl-codex-plugins
codex plugin add session-relocate@bluehansl-codex-plugins
codex plugin add set-statusline@bluehansl-codex-plugins
```

로컬 repo를 직접 등록하는 경우:

```bash
codex plugin marketplace add /path/to/bluehansl-plugins
codex plugin add multi-check@bluehansl-codex-plugins
codex plugin add session-relocate@bluehansl-codex-plugins
codex plugin add set-statusline@bluehansl-codex-plugins
```

## Claude Code Installation

```bash
# Register marketplace
/plugin marketplace add bluehansl/bluehansl-plugins

# Install plugin
/plugin install multi-check@bluehansl-plugins
/plugin install session-relocate@bluehansl-plugins
/plugin install set-statusline@bluehansl-plugins
```
