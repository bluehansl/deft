# deft

bluehansl 개인 워크플로 도구 모음. Claude Code / Codex 양쪽에서 동일하게 **`deft:<skill>`** 로 호출한다.

## 스킬

| FQN | 동작 |
|---|---|
| `deft:multi-check` | Codex + Claude + Gemini 다중 AI 교차검증/비교 |
| `deft:session-relocate` | Claude Code 세션 로그를 다른 프로젝트 디렉토리로 이동(`/resume` 대상화) |
| `deft:set-statusline` | 터미널 상태줄(statusline) 설정 |
| `deft:restore-statusline` | 상태줄 복원 |

## 설치 (Claude Code)

```
/plugin marketplace add bluehansl/deft
/plugin install deft@bluehansl
```

## 마이그레이션 (개별 플러그인 → deft 통합)

기존 개별 플러그인 `multi-check` / `session-relocate` / `set-statusline` 은 단일 브랜드 `deft` 로 통합되었다. 네임스페이스 매핑:

| 구 (v1) | 신 (deft) |
|---|---|
| `multi-check:multi-check` | `deft:multi-check` |
| `session-relocate:session-relocate` | `deft:session-relocate` |
| `set-statusline:set-statusline` | `deft:set-statusline` |
| `set-statusline:restore-statusline` | `deft:restore-statusline` |

> 스킬명은 그대로 유지되고 플러그인 네임스페이스만 `deft` 로 통일되었다. 기존 사용자는 구 플러그인 3개를 제거한 뒤 `deft` 를 새로 설치하면 된다. (네임스페이스 변경 = breaking → `claude-2.0.0`)
