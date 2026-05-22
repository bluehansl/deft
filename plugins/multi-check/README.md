# multi-check

여러 AI reviewer에게 같은 내용을 단발성으로 검토시킨 뒤, Lead가 결과를 취합하는 교차 검증 플러그인입니다.

## 지원 환경

- **Codex용 최신 포팅본**: `plugins/codex/multi-check`
- **Claude Code용 원본**: `plugins/multi-check`

현재 Codex 포팅본은 장기 협업용 team workflow가 아니라, **one-shot 병렬 reviewer 실행 + 결과 취합**에 초점을 둡니다.

## Codex 설치

```bash
codex plugin marketplace add bluehansl/bluehansl-plugins
codex plugin add multi-check@bluehansl-codex-plugins
```

로컬 repo를 직접 등록하는 경우:

```bash
codex plugin marketplace add /path/to/bluehansl-plugins
codex plugin add multi-check@bluehansl-codex-plugins
```

## 사용법

```text
/multi-check
```

자연어 트리거 예시:

- `멀티 체크`
- `교차 검증해줘`
- `다른 AI한테도 물어봐`
- `cross verify`
- `ask other AIs too`

## 동작 방식

- Lead는 현재 Codex 세션입니다.
- reviewer는 독립된 단발성 검토자로 실행됩니다.
- 가능한 reviewer를 병렬로 실행하고, 실패하거나 사용할 수 없는 reviewer는 skip합니다.
- reviewer는 결과를 반환한 뒤 세션이나 프로세스를 유지하지 않습니다.
- Claude CLI가 토큰/인증 제한 상태이면 Claude reviewer는 시도하지 않고 skip합니다.

## Reviewer

| Reviewer | 실행 방식 | 비고 |
|---|---|---|
| Lead Codex | 현재 세션 | 최종 취합 담당 |
| Codex reviewer | Codex sub-agent 또는 Codex CLI | 독립 Codex 관점 검토 |
| Gemini reviewer | Gemini CLI headless | `gemini-3-flash-preview` 기준 |
| Claude reviewer | Claude CLI headless | 사용 가능할 때만 optional |

## 결과 형식

최종 응답은 보통 다음 항목을 포함합니다.

- 요약 결론
- AI별 검토 결과
- 공통 의견
- 충돌/불일치
- 보완된 최종안
- 추가 확인 필요

## Claude Code 원본 설치

Claude Code에서 원본 플러그인을 사용할 경우:

```bash
/plugin marketplace add bluehansl/bluehansl-plugins
/plugin install multi-check@bluehansl-plugins
```

## License

Personal use only
