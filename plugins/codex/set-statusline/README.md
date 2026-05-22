# set-statusline

Codex TUI status line을 Codex 네이티브 설정 파일인 `$HOME/.codex/config.toml`로 관리하는 플러그인.

## Default Preset

```toml
[tui]
status_line = ["model-with-reasoning", "context-remaining", "current-dir"]
```

`git-branch`는 Codex 버전별 동작 차이가 있을 수 있어 기본값에서 제외했다. 사용자가 직접 요청한 경우에만 experimental preset으로 안내한다.

## Skills

| Command | Action |
|---|---|
| `/set-statusline` | `[tui].status_line`을 기본 preset으로 설정하고 snapshot 저장 |
| `/restore-statusline` | 최근 snapshot 기준으로 `[tui].status_line`만 원복 |

## Snapshot Files

| Path | Purpose |
|---|---|
| `$HOME/.codex/.set-statusline-snapshot/latest` | 최근 snapshot ID |
| `$HOME/.codex/.set-statusline-snapshot/<id>/meta.json` | 설치 전 상태 메타데이터 |
| `$HOME/.codex/.set-statusline-snapshot/<id>/status_line.toml` | 설치 전 `status_line` 원문 블록 |
| `$HOME/.codex/.set-statusline-snapshot/<id>/config.toml.bak` | 전체 config emergency 백업 |

일반 원복은 전체 config를 덮어쓰지 않고 `[tui].status_line`만 복원하거나 삭제한다.

## Notes

- 주석 처리된 `[tui]` 또는 `status_line`은 실제 설정으로 보지 않는다.
- 기존 `status_line`이 단일 라인 또는 멀티라인 배열이어도 전체 값 블록을 교체한다.
- Python 표준 라이브러리만 사용하며 외부 패키지는 필요 없다.
