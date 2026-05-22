# session-relocate

Codex 또는 Claude Code 세션을 다른 프로젝트의 `/resume` 대상에 보이도록 연결하는 플러그인입니다.

## 지원 환경

- **Codex용 최신 포팅본**: `plugins/codex/session-relocate`
- **Claude Code용 원본**: `plugins/session-relocate`

Codex와 Claude Code는 세션 저장 구조가 다르므로 동작 방식도 다릅니다. 이 README는 Codex 포팅본을 기준으로 설명하고, Claude Code 원본은 하단에 별도로 안내합니다.

## Codex 설치

```bash
codex plugin marketplace add bluehansl/bluehansl-plugins
codex plugin add session-relocate@bluehansl-codex-plugins
```

로컬 repo를 직접 등록하는 경우:

```bash
codex plugin marketplace add /path/to/bluehansl-plugins
codex plugin add session-relocate@bluehansl-codex-plugins
```

## 사용법

인자 없이 호출하면 현재 프로젝트의 최근 세션 카드 5개를 보여줍니다.

```text
/session-relocate
```

직접 지정할 수도 있습니다.

```text
/session-relocate <session-id> <absolute-path>
```

자연어 트리거 예시:

- `세션 이동`
- `세션 경로 옮기기`
- `resume 리스트로 옮겨`
- `move session`

## Codex 동작 방식

Codex는 세션 본문과 `/resume` 목록 정보를 분리해서 관리합니다.

- 세션 로그: `~/.codex/sessions/YYYY/MM/DD/rollout-...<session-id>.jsonl`
- `/resume` 목록 인덱스: `~/.codex/state_*.sqlite`의 `threads` 테이블

따라서 Codex 포팅본은 세션 파일을 물리적으로 이동하지 않습니다. 대신 다음 정보를 갱신합니다.

- JSONL 내부 `cwd`, branch/origin 메타데이터
- SQLite `threads.cwd`, `git_branch`, `git_origin_url`, `updated_at`

다음 항목은 변경하지 않습니다.

- `session_index.jsonl`
- `history.jsonl`
- `shell_snapshots`
- `rollout_path`
- 세션 파일 위치
- `git_sha` / `commit_hash`

## 사용자 흐름

1. 세션 카드를 선택합니다.
2. 이동할 target 절대경로를 입력합니다.
3. 이동 대상이 확정되면 `Y/N`만 확인합니다.
4. `Y` 입력 시 추가 안내 없이 바로 작업합니다.
5. 성공 시 `세션 경로를 변경이 완료되었습니다.`만 출력합니다.

백업은 로컬 OS 임시 디렉터리에 생성됩니다.

```text
$TMPDIR/codex-session-relocate-backup-*/
```

백업은 장기 보존을 전제로 하지 않습니다. 임시 디렉터리 정리 정책에 따라 자동 삭제될 수 있습니다.

## 안전 장치

- 현재 실행 중인 자기 세션은 이동하지 않습니다.
- target은 존재하는 절대 디렉터리여야 합니다.
- 시스템 경로(`/`, `/etc`, `/var`, `/usr`, `/bin`, `/sbin`, `/System`, `/Library/System`, `/private`, `/dev`, `/proc`, `/root`)는 차단합니다.
- target 접근 권한이 없으면 중단합니다.
- 이미 같은 cwd에 연결된 세션이면 중단합니다.
- SQLite row를 찾지 못하면 `/resume` 반영을 보장할 수 없어 중단합니다.
- SQLite update 성공을 확인한 뒤 JSONL을 교체합니다.

## Claude Code 원본

Claude Code 원본은 `~/.claude/projects/<encoded-pwd>/<session-id>.jsonl` 파일과 sidecar 디렉터리를 target 프로젝트 디렉터리로 이동하는 방식입니다.

Claude Code에서 원본 플러그인을 사용할 경우:

```bash
/plugin marketplace add bluehansl/bluehansl-plugins
/plugin install session-relocate@bluehansl-plugins
```

## Changelog

Claude Code 원본의 변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참고하세요.

## License

Personal use only
