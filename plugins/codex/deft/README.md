# deft (Codex)

bluehansl 개인 워크플로 도구 모음의 Codex 포팅본. Codex에서 **`deft:<skill>`** 로 호출한다.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI **1회성** 교차검증/비교 (fan-out) |
| `deft:multi-round` | **여러 AI가 N라운드 양방향으로 토론·합의 도달** 하는 멀티턴 회의. broker 없이 `claudex mcp-server` 경유 (cmux 환경) 또는 codex 내부 병렬 처리 (cmux 외부). [상세 가이드](skills/multi-round/GUIDE.md) |
| `deft:session-relocate` | 세션 로그를 다른 프로젝트 디렉토리로 이동(`/resume` 대상화) |
| `deft:set-statusline` | Codex TUI status line 설정 (`~/.codex/config.toml`) |
| `deft:restore-statusline` | status line 복원 |

## 설치 (Codex)

```
codex plugin marketplace add bluehansl/deft
codex plugin add deft@bluehansl-codex
```

## 사용자 데이터 경로 컨벤션

deft 플러그인의 모든 스킬은 사용자 데이터(세션·메타·hooks 등)를 다음 경로 하위에 **스킬별로 구분하여** 저장한다.

- **Codex 측**: `~/.codex/plugin-data/deft/<skill>/`
- **Claude 측**: `~/.claude/plugin-data/deft/<skill>/`

플러그인 cache 영역(`~/.codex/plugins/cache/...`, `~/.claude/plugins/cache/...`)에는 사용자 데이터를 두지 않는다.

## 마이그레이션 (개별 플러그인 → deft 통합)

기존 `multi-check` / `session-relocate` / `set-statusline` 3개 Codex 플러그인이 단일 `deft` 로 통합되었다. 스킬명은 유지되고 네임스페이스만 `deft` 로 통일. 네임스페이스 변경 = breaking → `codex-1.0.0`. 기존 사용자는 구 3개 제거 후 `deft` 재설치.
