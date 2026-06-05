---
name: multi-round
description: broker 없이 여러 AI(Claudex/Codex/Claude)가 N라운드에 걸쳐 의견을 주고받으며 수렴·반박하는 멀티턴 토론 skill. claudex mcp-server + cmux pane 제어로 동작하며 외부 cloud(api.relaycast.dev 등) 송신 zero. 트리거 — "멀티 라운드", "라운드 회의", "라운드 토론", "N라운드 토론", "여러 라운드 돌려", "왔다갔다 토론", "주거니 받거니", "핑퐁 토론", "AI끼리 토론시켜", "서로 반박하며 좁혀줘", "수렴할 때까지 주고받아", "합의될 때까지 토론", "코덱스랑 클로드 토론", "클로덱스랑 토론", "multi round", "multi-round debate", "back-and-forth between AIs". 1발 비교는 multi-check, 파일 작업·장기 협업은 Agent Teams를 쓰세요. agent-relay broker(cloud-coupled)와는 별개 — broker 사용 불가 환경의 대체 도구입니다.
---

# Multi-Round Skill

여러 AI가 **여러 라운드에 걸쳐 양방향으로 의견을 주고받는** 토론·합의 도구. agent-relay broker(cloud-coupled)를 사용하지 않고 **claudex의 내장 `mcp-server` + cmux pane 제어**로 동작. 외부 cloud 송신 zero.

## 3-도구 멘탈 모델 (사용자 안내용)

| 도구 | 언제 쓰는가 | 핵심 |
|---|---|---|
| `multi-check` | "한 번 물어보고 답만 비교" | 1-shot 병렬 fan-out. 빠름 |
| **`multi-round`** | "의견 갈려서 여러 번 주고받으며 좁히고 싶다 / 토론" | N라운드 양방향. broker 無. 수렴 목적 |
| Agent Teams | "실제 코드 분담·구현·리뷰 루프·티켓 작업" | broker·워커·파일 작업. 장기 협업 |

판단 키워드: **답이 하나면 multi-check, 답을 좁혀가야 하면 multi-round, 코드를 만져야 하면 Agent Teams.**

## 회의 모드

| 모드 | 종료 조건 | 적용 예시 |
|---|---|---|
| `consult` | 첫 응답 1회 + DONE | 단발 자문 |
| `dialogue` (기본) | `CONSENSUS` 양쪽 일치 또는 max-round 도달 (기본 5) | 페어 토론 |
| `collaborate` | 양쪽 `REVIEW_PASS` 교차 | 분담→구현→상호리뷰 (동일 역할 페어) |
| `debate` | 한쪽 `CONCEDE` 또는 max-round 도달 | 반박 검증 |

상세 모드 정의: `~/git/AGENTS.teams.md` §12. 본 skill은 그 정의를 그대로 이식.

## 신호 프로토콜

기본: `ACK / STATUS / BLOCKED / DONE` (`~/AGENTS.md` §1)
모드별 확장: `CONSENSUS / AGREED / DISSENT / CONCEDE / REVIEW_PASS / REVIEW_FAIL / VERDICT`

## Workflow

### Phase 0: 보안 Preflight (필수 게이트 — skip 금지)

회의 시작 전 다음을 차례로 검증. **하나라도 실패 시 abort + 사용자 보고**.

```bash
# A. 외부 cloud 송신 0 확인 (relaycast / agentrelay)
LEAKS=$(lsof -nP -iTCP -sTCP:ESTABLISHED 2>/dev/null \
  | grep -v "localhost\|127.0.0.1\|::1" \
  | grep -iE "relaycast|agentrelay|104\.21\.|172\.67\.174|104\.18\.1[23]\.48")
[ -n "$LEAKS" ] && echo "ABORT: 외부 cloud 송신 의심 — 다음 줄 확인" && echo "$LEAKS" && exit 1

# B. claudex 또는 codex 존재 (claudex 우선)
if which claudex >/dev/null 2>&1; then ENGINE="claudex"
elif which codex >/dev/null 2>&1; then ENGINE="codex"; echo "WARN: claudex 미설치 — real codex로 진행"
else echo "ABORT: claudex 또는 codex 가 필요합니다"; exit 1
fi

# C. /etc/hosts 차단 권장 (cloud 우발적 spawn 차단 — 사용자 정책)
grep -q "api.relaycast.dev" /etc/hosts 2>/dev/null && echo "OK: hosts cloud 차단 적용됨" || echo "WARN: /etc/hosts에 api.relaycast.dev 차단 라인 없음 (권장)"
```

### Phase 1: 회의 모드 + 참가자 결정

1. 사용자 요청에서 의도 추출 (단발 자문 / 합의 도달 / 분담 협업 / 반박 검증)
2. 회의 모드 결정 (consult / dialogue / collaborate / debate)
3. 참가자 수·역할·AI 결정. 권장 조합:
   - **2명 dialogue**: Lead(Claude) + 1× claudex 또는 codex
   - **3명**: Lead + claudex + Claude CLI 독립 세션
   - **4명 collaborate** (동일 역할 페어): BE×2 (Claudex+Claude) + FE×2 — 단 본 multi-round는 *토론*이 목적이라 4인은 cmux pane 분할 한계 고려

### Phase 2: claudex MCP 등록 가이드 (자동 write 금지 — 사용자 정책 §6-3)

`~/.claude/settings.json`이 사용자 환경 파일이므로 **자동 수정 금지**. 미등록 시 사용자에게 다음 스니펫을 출력하고 수동 등록을 요청한다.

```json
// ~/.claude/settings.json — mcpServers 키 추가
{
  "mcpServers": {
    "claudex": {
      "command": "claudex",
      "args": [
        "mcp-server",
        "-c", "mcp_servers={}"
      ]
    }
  }
}
```

**핵심**: `-c mcp_servers={}` 인자가 **downstream MCP (relaycast/atlassian/grafana 등) 차단**. 누락 시 본업 코드 외부 송신 위험 (`~/AGENTS.md` §6-1 위반).

등록 확인:
```bash
# Claude Code 재시작 후
which mcp__claudex__codex >/dev/null 2>&1 || echo "WARN: claudex MCP 미등록 — settings.json 확인 + Claude Code 재시작 필요"
```

미등록 시 fallback: cmux pane에 `claudex` TUI를 직접 spawn (Phase 3-B).

### Phase 3: 워커 spawn

회의 모드와 등록 상태에 따라 두 경로:

#### 3-A. claudex MCP 경유 (자동화 우선, 시각화 약함)

각 워커별로 conversation 시작:
```
mcp__claudex__codex(
  prompt: "<페르소나 + 라운드 1 prompt>",
  model: "<model>",
  cwd: "<원하는 cwd>",
  developer-instructions: "<페르소나 골격 — agents/codex-participant.md 본문>"
)
→ 반환된 conversationId를 워커별로 저장 ({backendDev-claudex: conv-uuid1, ...})
```

이후 라운드는 `codex-reply`로:
```
mcp__claudex__codex-reply(
  conversationId: "<해당 워커 conv id>",
  prompt: "<다음 라운드 prompt>"
)
```

장점: 부담 최소, 자동 lifecycle (Claude Code 자식 프로세스).
단점: cmux pane 시각화 없음 — Lead 출력으로 진행 표시.

#### 3-B. cmux pane + claudex TUI (시각화·사용자 개입 강함)

Lead surface 캡처:
```bash
LEAD_SURFACE=$(cmux identify 2>/dev/null | jq -r '.caller.surface_ref' 2>/dev/null)
[ -z "$LEAD_SURFACE" ] && LEAD_SURFACE="${CMUX_SURFACE_ID:-}"
# fallback 실패 시 사용자에게 직접 surface id 요청
```

⚠️ **주의**: `cmux current --json` 명령은 존재하지 않음. 반드시 `cmux identify`의 `.caller.surface_ref` 사용 (이전 지침에 잘못 적힌 부분 정정).

첫 워커: 우측 분할
```bash
SPLIT=$(cmux new-split right --focus false 2>&1)
W1_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
```

이후 워커: 아래 분할 (직전 워커 pane 기준 §7-1 정책)
```bash
SPLIT=$(cmux new-split down --pane "<prev_pane>" --focus false 2>&1)
W2_SURFACE=$(printf '%s' "$SPLIT" | grep -oE 'surface:[0-9]+' | head -1)
```

워커 pane에 claudex TUI 기동 + 초기 prompt:
```bash
cmux send --surface "$W1_SURFACE" "claudex -c mcp_servers={}"
cmux send-key --surface "$W1_SURFACE" Enter
sleep 3  # TUI readiness 확인 (capture-pane으로 프롬프트 박스 출현 감지 권장)
```

### Phase 4: 라운드 진행 (양방향 통신)

#### 4-A. prompt 주입 — 줄바꿈 sanitize 필수

⚠️ **`cmux send`의 `\n`은 Enter로 해석되어 다중 라인 prompt가 조기 제출**. 다음 패턴 강제:

```bash
# WRONG — 줄바꿈마다 조기 제출
cmux send --surface "$W1_SURFACE" "$(cat /tmp/prompt.md)"

# RIGHT — 줄바꿈 공백 치환, 제출은 send-key 단독
PROMPT_SAFE=$(tr '\n' ' ' < /tmp/prompt.md)
cmux send --surface "$W1_SURFACE" "$PROMPT_SAFE"
cmux send-key --surface "$W1_SURFACE" Enter
```

긴 prompt는 사용자 파일로 전달 후 워커가 직접 Read하도록 안내 — 본문 전송 자체를 줄여 안전성 확보.

#### 4-B. 응답 완료 감지 — 2단 폴링

(1) **DONE 센티넬 grep** (1차):
```bash
# 워커 페르소나에 "응답 마지막 줄에 'DONE:'으로 시작" 강제 (agents/*.md)
cmux capture-pane --surface "$W1_SURFACE" --scrollback --lines 200 \
  | grep -qE '^DONE:' && echo "WORKER_DONE"
```

(2) **idle-stable 폴링** (2차, 보조):
```bash
PREV=""
for _ in $(seq 1 30); do
  CUR=$(cmux capture-pane --surface "$W1_SURFACE" --lines 20)
  if [ "$CUR" = "$PREV" ]; then
    echo "IDLE_STABLE"; break
  fi
  PREV="$CUR"; sleep 8
done
```

⚠️ claudex TUI는 ANSI/스피너로 diff 노이즈 발생 → **센티넬이 1차, idle-stable은 2차 보조**.

#### 4-C. 라운드 게이트 (사용자 개입 break point)

라운드 종료마다 Lead가 사용자에게 다음 옵션 노출:

```
[라운드 N/M] 응답 수신 완료. 다음 선택:
  1. 계속 — 다음 라운드 진행
  2. 의견 추가 — 사용자 한 줄 prompt 삽입 후 진행
  3. 조기 종료 — 현재까지로 종합 작성
```

사용자 입력 없으면 회의 모드별 기본 동작 (dialogue=CONSENSUS 도달까지 진행, max-round=5 도달 시 보고+컨펌).

#### 4-D. 다음 라운드 메시지 (MCP 경유의 경우)

```
mcp__claudex__codex-reply(
  conversationId: "<워커 conv id>",
  prompt: "<이전 라운드 다른 워커 의견 요약 + Lead 입장 + 질문>"
)
```

cmux 경로의 경우 4-A 패턴 반복.

### Phase 5: 종합 + 정리

#### 5-A. 결과 종합 (Lead Claude 단독)

```markdown
## Multi-Round Results

### 회의 정보
- 모드: {consult|dialogue|collaborate|debate}
- 참가자: {Claudex(GPT-5.5), Claude(Opus 4.8), ...}
- 진행 라운드: {N/M}
- 종료 사유: {CONSENSUS 도달 | max-round | 사용자 조기 종료}

### Consensus (합의된 부분)
- ...

### Unresolved (라운드 종료 시 미합의)
- 각 입장 + Lead 판단

### 결론
- 최종 권장안 (Lead 종합)
```

#### 5-B. 정리 (워커 + pane)

**MCP 경유 (3-A)**:
- conversation은 별도 종료 명령 없음. 다음 사용 시 새 conversationId로 시작
- 잔존 mcp-server 자식 프로세스 확인:
  ```bash
  pgrep -f "claudex mcp-server" 2>/dev/null
  ```
  (정상 시 Claude Code 종료 시 함께 정리됨. 강제종료 시 잔존 가능 — 수동 kill)

**cmux pane 경유 (3-B)**:
- 워커 pane은 release 시 자동 close 안 함 (관찰 보존)
- 회의 전체 종료 시 사용자에게 "워커 pane 닫을까요?" 컨펌 후 `cmux close-surface --surface surface:N`

#### 5-C. cmux search.db 잔존 처리 (선택)

cmux는 pane 출력을 `~/Library/Application Support/cmux/search.db` (SQLite FTS)에 평문 인덱싱. 본업 코드를 pane으로 흘린 경우 평문 잔존.

권장:
```bash
# 권한 정리 (1회만)
chmod 600 ~/Library/Application\ Support/cmux/search.db*

# 회의 종료 시 선택적 purge (사용자 컨펌)
# rm -f ~/Library/Application\ Support/cmux/search.db*  # 주의: 전체 cmux 이력 삭제됨
```

## 보안 가드 요약

| # | 가드 | 위반 시 |
|---|---|---|
| 1 | Phase 0 preflight 통과 (외부 cloud 송신 0) | abort |
| 2 | claudex mcp-server 기동 시 `-c mcp_servers={}` 강제 (downstream MCP 차단) | 본업 코드 외부 송신 위험 |
| 3 | cmux send 줄바꿈 sanitize | 조기 제출 / prompt 손상 |
| 4 | cmux search.db 권한 600 | 평문 평문 노출 |
| 5 | settings.json 자동 write 금지 (수동 가이드만) | §6-3 사전 컨펌 정책 위반 |
| 6 | claudex/codex 둘 다 없으면 명시 에러 (silent 실패 X) | 사용자 혼란 |
| 7 | `cmux current --json` 사용 금지 → **`cmux identify .caller.surface_ref`** | 명령 부재 → fallback 작동 |
| 8 | agent-relay 영구 삭제 금지 (사용자 보존 의도) | 미래 재활성화 불가 |

## Error Handling

| 시나리오 | 동작 |
|---|---|
| claudex 미설치 | real codex로 graceful fallback + WARN 로그 |
| codex도 미설치 | "claudex/codex 미설치 — multi-check로 전환하시겠어요?" 안내 + 중단 |
| MCP 등록 X | Phase 3-B (cmux pane) 경로로 자동 전환 |
| 외부 cloud 연결 발견 (Phase 0) | abort + 사용자에게 connection 상세 보고 |
| 응답 timeout (라운드당 120s) | 해당 워커 skip, 남은 워커로 종합 |
| 한 워커 BLOCKED | 사용자에게 즉시 보고 + 결정 위임 |
| max-round 도달 (기본 5) | 사용자 보고 + "추가 진행/종료/사용자 결정" 선택 요청 |

## Trigger 회피 매트릭스 (오발동 방지)

`multi-round`가 매칭되어선 안 되는 어휘 (relay 전용):
- "회의", "회의 좀 해줘", "한번 봐줘", "같이 봐줘"
- "검토해줘", "워커 띄워", "둘이서 얘기해봐"

`multi-check` 와 혼동되지 않게 — `description` 안에 "1발 비교는 multi-check, 파일 작업은 Agent Teams" 한 줄로 모델에게 경계 학습.

## 본업 정책 자동 inject (worker prompt 안에 명시)

각 워커 prompt에 다음 라인 inject:
```
- 응답 언어: 한국어 (~/AGENTS.md §1)
- 본업 코드 외부 송신 금지 (~/AGENTS.md §6-1)
- 응답 마지막 줄에 'DONE:' 센티넬 출력 (multi-round skill 응답 완료 감지용)
- 회의 모드: {consult|dialogue|collaborate|debate}
- 신호 프로토콜 사용 (ACK/STATUS/BLOCKED/DONE + 모드별 확장)
```

## 참가자 페르소나

상세 페르소나는 `agents/` 하위 파일 참조:
- `agents/codex-participant.md` — claudex/codex 워커용
- `agents/claude-participant.md` — claude CLI 워커용 (선택)
