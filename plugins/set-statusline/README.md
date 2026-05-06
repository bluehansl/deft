# set-statusline

Claude Code statusline을 **folder / git branch / model+effort / ctx progress bar** 4-segment 구성으로 즉시 설정하는 플러그인.

## 구성 미리보기

```
📁 FOLDER      BRANCH      🤖 Model : effort      ● ctx │████░░░░░░│ 45%
```

| Segment | 내용 |
|---|---|
| 📁 | 현재 작업 디렉토리 basename (대문자) |
| `` | Git 현재 브랜치 (Nerd Font U+E725, 흰색) |
| 🤖 | 모델명 : effort 레벨 (iTerm2 inline image 지원 시 커스텀 아이콘) |
| ● | 녹색 원 + `ctx │██████████│ XX%` 컨텍스트 진행바 |

세그먼트들은 터미널 폭에 맞춰 자동 양끝 정렬(justify)됩니다.

## 스킬

| 슬래시 명령 | 기능 |
|---|---|
| `/set-statusline` | statusline 설치 (스냅샷 저장 → 스크립트 배포 → settings.json 등록) |
| `/restore-statusline` | 설치 직전 상태로 원복 |

## 요구사항

| 항목 | 필수 | 설치 (macOS) |
|---|---|---|
| bash 3.2+ | ✅ (시스템 기본) | — |
| jq | ✅ | `brew install jq` |
| python3 | ✅ | `brew install python` |
| Nerd Font | ✅ | `brew install --cask font-jetbrains-mono-nerd-font` |
| Truecolor 터미널 | ✅ | iTerm2, VS Code Terminal 등 |

## 사용법

### 설치

```
/set-statusline
```

동작 흐름:
1. 의존성·기존 상태 점검 결과 출력
2. 설치 컨펌 (y/N)
3. `$HOME/.claude/.set-statusline-snapshot/` 에 **현재 상태 스냅샷** 저장
4. `$HOME/.claude/statusline-command.sh` 에 스크립트 배포
5. `$HOME/.claude/settings.json` 의 `.statusLine` 키 패치
6. Claude Code 재시작 시 반영

### 원복

```
/restore-statusline
```

스냅샷에 저장된 "설치 직전 상태"로 되돌림. 원복 직전 상태는 `.pre-restore/` 에 추가 백업되므로 원복 자체를 되돌리는 것도 가능.

## 파일 위치

| 파일 | 용도 |
|---|---|
| `$HOME/.claude/statusline-command.sh` | statusline 렌더링 스크립트 |
| `$HOME/.claude/settings.json` | Claude Code가 읽는 설정 (`.statusLine` 필드) |
| `$HOME/.claude/.set-statusline-snapshot/statusline-command.sh` | 설치 직전 스크립트 사본 |
| `$HOME/.claude/.set-statusline-snapshot/statusLine.json` | 설치 직전 `.statusLine` 값 |
| `$HOME/.claude/.set-statusline-snapshot/meta.env` | 스냅샷 메타데이터 (타임스탬프, 존재 플래그) |
| `$HOME/.claude/.set-statusline-snapshot/.pre-restore/` | 원복 직전 상태 (원복 취소 대비) |

## 디자인 결정

- **블럭 문자**: `█` (U+2588 FULL BLOCK) — edge-to-edge fill로 괄호와의 간격 대칭 확보
- **괄호**: `│` (U+2502 BOX DRAWINGS LIGHT VERTICAL) — 블럭과 시각 무게 통일
- **채움 색**: `#AFD7FF` (밝은 하늘색)
- **빈 색**: `#495767` (어두운 청록-회색)
- **ctx 아이콘 색**: `#00D26A` (트루컬러 녹색)

## 제약

- Claude Code가 statusline 명령어를 실행하는 환경에 `jq`, `python3`이 있어야 정확하게 동작합니다.
- Nerd Font 미설치 시 git 브랜치 아이콘(U+E725)이 네모/물음표로 렌더링됩니다.
- Truecolor 미지원 터미널에서는 색상이 가장 가까운 256색으로 근사됩니다.

## 라이선스

Personal use only.
