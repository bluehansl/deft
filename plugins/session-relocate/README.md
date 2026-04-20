# session-relocate

Claude Code 세션 로그(`~/.claude/projects/<pwd-encoded>/<session>.jsonl`)를 다른 pwd 프로젝트 디렉토리로 이동시켜 해당 디렉토리에서 `/resume` 대상으로 보이도록 만드는 플러그인.

## Prerequisites

- **Claude Code** (latest version)
- macOS / Linux (Windows 미지원)
- **Python 3** (권장, 경로 인코딩/검증 로직에 사용)

## Installation

```bash
/plugin marketplace add bluehansl/bluehansl-plugins
/plugin install session-relocate@bluehansl-plugins
```

## Usage

인자 없이 호출 (인터랙티브 모드):

```
/session-relocate
```

인자와 함께 호출:

```
/session-relocate <session-id> <absolute-path>
```

자연어 트리거 예시:

- "세션 이동"
- "세션 경로 옮기기"
- "resume 리스트로 옮겨"
- "move session"

## How It Works

Claude Code는 세션 로그를 `~/.claude/projects/<pwd를 치환 인코딩한 디렉토리>/<session-id>.jsonl` 구조로 저장한다. 이 플러그인은 대상 pwd를 동일한 규칙으로 인코딩한 뒤, 세션 파일과 사이드카 디렉토리(`<session-id>/`)를 함께 이동시킨다. 현재 실행 중인 자기 세션은 이동 대상에서 제외되며, 실제 이동 전에 드라이런으로 변경 요약을 보여주고 사용자 컨펌을 받은 뒤 실행한다.

## Safety Features

14개의 엣지 케이스를 사전에 차단/경고한다. 모든 경고 메시지는 `⚠️` prefix로 출력된다.

| # | 상황 | 동작 |
|---|------|------|
| 1 | 인자 id == 자기 세션 | 차단 (새 터미널에서 실행하도록 안내) |
| 2 | source pwd == target pwd | 중단 (이동 불필요) |
| 3 | target에 동일 id 파일 존재 | 중단 (덮어쓰기 위험) |
| 4 | UUID 형식 오류 | 에러 (올바른 형식 예시 안내) |
| 5 | 현재 pwd 프로젝트에 세션 없음 | 전체 스캔 후 실제 위치 안내 + 1회 컨펌 |
| 6 | target이 절대경로 아님 | 에러 (절대경로 요구) |
| 7 | 사이드카 디렉토리 없음 | 정상 처리 (메인 jsonl만 이동) |
| 8 | 시스템 경로 (`/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`, `/`) | 차단 |
| 9 | target이 HOME 외부 | 경고 + 1회 컨펌 |
| 10 | 순환 경로 (source ⊂ target 또는 target ⊂ source) | 차단 |
| 11 | Cross-filesystem 이동 | 경고 + 1회 컨펌 (atomic 미보장) |
| 12 | Disk 용량 부족 | 중단 (필요/가용 용량 표시) |
| 13 | source 파일 잠김 (lsof) | 중단 (잠금 프로세스 PID 안내) |
| 14 | 이동 도중 실패 | 자동 롤백 시도 → 실패 시 수동 복구 경로 안내 |

## Limitations

- macOS / Linux만 지원 (Windows 경로 인코딩 미구현)
- 실험적 기능: Claude Code의 세션 저장 경로 규칙에 의존하므로, 상위 버전에서 규칙이 바뀌면 동작이 변경될 수 있음
- 다중 사용자 환경에서 동시에 같은 세션을 이동하는 케이스는 보장하지 않음

## Changelog

버전별 변경 이력은 [CHANGELOG.md](./CHANGELOG.md) 를 참고하세요.

## License

Personal use only
