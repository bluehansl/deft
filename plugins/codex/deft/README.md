# deft (Codex)

bluehansl 개인 워크플로 도구 모음의 Codex 포팅본. Codex에서 **`deft:<skill>`** 로 호출한다.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI 교차검증/비교 |
| `deft:session-relocate` | 세션 로그를 다른 프로젝트 디렉토리로 이동(`/resume` 대상화) |
| `deft:set-statusline` | Codex TUI status line 설정 (`~/.codex/config.toml`) |
| `deft:restore-statusline` | status line 복원 |

## 설치 (Codex)

```
codex plugin marketplace add bluehansl/deft
codex plugin add deft@bluehansl-codex
```

## 마이그레이션 (개별 플러그인 → deft 통합)

기존 `multi-check` / `session-relocate` / `set-statusline` 3개 Codex 플러그인이 단일 `deft` 로 통합되었다. 스킬명은 유지되고 네임스페이스만 `deft` 로 통일. 네임스페이스 변경 = breaking → `codex-1.0.0`. 기존 사용자는 구 3개 제거 후 `deft` 재설치.
