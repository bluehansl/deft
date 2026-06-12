---
name: deft-test
description: 'deft 플러그인 스킬(multi-check/multi-round/agent-teams) 개발 후 검증 절차. 본 repo 작업 세션 전용 — 배포하지 않는 프로젝트 로컬 스킬. 트리거 — "스킬 테스트", "전체 테스트", "deft 테스트", "셀프테스트", "검증 돌려", "재테스트".'
---

# deft-test — 스킬 개발 후 검증 절차 (비배포)

deft 스킬을 수정·추가한 뒤 커밋 전후로 돌리는 검증 모음. 2026-06-10~12 의 실전 테스트 사이클(릴리스 25건)에서 축적된 시행착오와 검증 방법을 절차화했다.

> **비배포**: 본 스킬은 `.claude/skills/` (프로젝트 로컬) — marketplace source(`./plugins/deft`) 밖이라 배포에 포함되지 않는다. 이 repo 에서 작업하는 세션에서만 로드된다.

---

## 0. 테스트 레벨 선택

| 레벨 | 언제 | 소요 |
|---|---|---|
| **L1 정적** | 모든 커밋 전 (필수) | ~10초 |
| **L2 버스 단위** | `bin/multi-round-bus` 수정 시 | ~1분 |
| **L3 배관 E2E** | 워커 spawn 인자·MCP 주입 변경 시 | ~2분 (headless) |
| **L4 실전 풀사이클** | 스킬 절차(SKILL.md) 변경 시 / 사용자 "전체 테스트" 요청 시 | 스킬당 5~15분 |

L4 는 **사용자가 화면을 보고 있을 때만** 가능 (§함정 3 — pane lazy-init).

---

## 1. L1 — 정적 검증 (커밋 전 필수)

```bash
cd ~/git/bluehansl-plugins

# (a) 전 SKILL.md frontmatter strict YAML — codex 파서는 strict 라 깨지면 스킬 로드 자체가 실패
python3 - <<'EOF'
import glob, io, yaml
fail = 0
for f in sorted(glob.glob("plugins/**/skills/*/SKILL.md", recursive=True)):
    s = io.open(f, encoding="utf-8").read()
    try: yaml.safe_load(s.split("---")[1])
    except Exception as e: print("FAIL", f, str(e).split("\n")[0]); fail += 1
print("frontmatter:", "전부 OK" if not fail else f"{fail}건 FAIL")
EOF

# (b) bin 스크립트 문법
node --check plugins/deft/bin/multi-round-bus && echo "bus syntax OK"
bash -n plugins/deft/bin/claude-bin-keepalive && echo "keepalive syntax OK"
python3 -m json.tool plugins/deft/hooks/hooks.json >/dev/null && echo "hooks.json OK"

# (c) bin 동기화 (Claude ↔ Codex 측 동일해야)
diff -q plugins/deft/bin/multi-round-bus plugins/codex/deft/bin/multi-round-bus && echo "bus 동기화 OK"

# (d) 버전 정합 — marketplace ↔ plugin.json 일치 + CHANGELOG 헤더 존재
grep -o 'claude-[0-9.]*' .claude-plugin/marketplace.json plugins/deft/.claude-plugin/plugin.json
```

**스킬 본문에 새 외부 명령을 적었으면 반드시 실재 검증** — 부재 명령(`cmux focus-surface`, `cmux current --json` 등)을 스킬에 넣었던 실수가 2회 있었다. `cmux help | grep <명령>` / `<cli> --help` 로 확인 후 기재.

---

## 2. L2 — 버스 단위 테스트 (mktemp 패턴)

원칙: **임시 세션 + 더미/무 surface** — cmux 노크 부작용 0. 테스트 후 디렉토리 삭제.

```bash
BUS=plugins/deft/bin/multi-round-bus
T=$(mktemp -d /tmp/bus-test.XXXXXX)

# 기본 라운드트립
node "$BUS" register --session "$T" --name lead --kind lead
node "$BUS" register --session "$T" --name w1                       # surface 없음 → 노크 skip 경로
node "$BUS" post --session "$T" --from lead --to w1 --content "Q1"
node "$BUS" check --session "$T" --as w1                            # 본인 수신 + 미응답 큐 노출
node "$BUS" check --session "$T" --as w1                            # 재check — 큐 반복 노출 (자기 치유)
node "$BUS" post --session "$T" --from w1 --to lead --type response --reply-to 1 --content "A1"
node "$BUS" check --session "$T" --as w1                            # 큐 해소 확인

# 레이스 재현 (핵심 회귀): 처리 중 추가 요청 → 커서 전진 후에도 미응답 반복 노출
node "$BUS" post --session "$T" --from lead --to w1 --content "Q2"
node "$BUS" post --session "$T" --from lead --to w1 --content "Q3(처리 중 추가)"
node "$BUS" check --session "$T" --as w1 >/dev/null                 # 둘 다 읽음 (커서 끝)
node "$BUS" post --session "$T" --from w1 --to lead --type response --reply-to 4 --content "A2"
node "$BUS" check --session "$T" --as w1 | grep "미응답"            # Q3 잔존해야 PASS

# 특수 입력: '---' 시작 본문 (frontmatter — parseArgs 회귀)
printf -- '---\nname: x\n본문' | node "$BUS" post --session "$T" --from lead --to w1

# aged 재노크: knocks.json ts 를 61초 과거로 조작 후 post → 재노크 시도 확인
# lock: (죽은 holder) mkdir .bus-lock + 가짜 pid + 옛 mtime → post 성공 / (산 holder) 본인 pid → 10s timeout
# watch: 응답 케이스 exit 0 RESPONDED / 무응답 timeout 4s → exit 1 STALLED + 재노크
# transcript: 자동 저장·-o -·--full·inject 발췌·← #N 표기·DONE 비최종행 경고
node "$BUS" transcript "$T" -o - | head -20
rm -rf "$T"
```

**MCP handshake** (stdin JSON-RPC 주입 — 서버 죽음·스키마 회귀 검증):

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | MULTI_ROUND_SESSION_DIR=$(mktemp -d) BUS_PARTICIPANT=probe node "$BUS" mcp
# tools/list 에 post_message(reply_to 포함)/check_messages/list_participants 3종 확인
```

**keepalive** (가짜 버전 — 반드시 sort -V 최신 번호로, 구번호는 prune 에 즉시 정리됨):

```bash
KA=plugins/deft/bin/claude-bin-keepalive
echo fake > ~/.local/share/claude/versions/9.9.9-katest
bash "$KA" >/dev/null && rm ~/.local/share/claude/versions/9.9.9-katest
bash "$KA"   # "복원" INFO 떠야 PASS
rm -f ~/.local/share/claude/versions/9.9.9-katest ~/.claude/plugin-data/deft/bin-keepalive/9.9.9-katest
bash "$KA" status
```

---

## 3. L3 — 배관 E2E (headless, pane 불요)

워커 spawn 인자(MCP 주입·격리·승인)를 바꿨을 때 — TUI 없이 `claudex exec` 로 MCP 배관만 검증:

```bash
SESSION_DIR=$(mktemp -d); BUS=~/.local/bin/multi-round-bus
node "$BUS" register --session "$SESSION_DIR" --name lead --kind lead >/dev/null
node "$BUS" post --session "$SESSION_DIR" --from lead --to probe --content "PONG 이라고 응답하세요" >/dev/null

DISABLE=""; for N in $(claudex mcp list --json | jq -r '.[].name'); do DISABLE="$DISABLE -c mcp_servers.$N.enabled=false"; done
claudex exec -m gpt-5.5 --disable tool_call_mcp_elicitation --dangerously-bypass-approvals-and-sandbox $DISABLE \
  -c "mcp_servers.bus={command=\"$BUS\",args=[\"mcp\"],env={MULTI_ROUND_SESSION_DIR=\"$SESSION_DIR\",BUS_PARTICIPANT=\"probe\"}}" \
  "check_messages 호출 후 수신 요청에 reply_to 명시해 post_message 로 응답" 2>&1 | grep "mcp:"
# 기대: bus/check_messages (completed) + bus/post_message (completed). "user cancelled" 면 승인 인자 회귀
node "$BUS" history --session "$SESSION_DIR"; rm -rf "$SESSION_DIR"
```

---

## 4. L4 — 실전 풀사이클 (사용자 화면 활성 필수)

### 4-1. multi-round (스킬 절차 그대로 + 검증 포인트 주입)

- 구성: **기본 워커 3명** — 페르소나 자동 도출(명확 주제) 또는 후보 질문(애매 주제 — 양쪽 경로 모두 한 번씩 테스트), **엔진 mix** (claudex + 진짜 codex + claude — 3엔진 전부 거치기. claude 워커는 skip-permissions 경로 확인)
- 의도적 레이스 1회: 워커가 R1 처리 중일 때 추가 요청 게시 → 미응답 큐 회복 확인
- 체크: reply_to 전 응답 / 디바운스(연속 post 시 skip) / 워치독 RESPONDED / inject 발췌 / 비수신 워커 자발 발언(3인부터) / Phase 5 transcript 자동 생성 / **pane 자동 close + rebalancing + focus 복원**

### 4-2. multi-check (Claude 측)

- 팀명 **유니크 suffix** 확인 (`multi-check-<HHMMSS>`) — 고정명이면 회귀
- keepalive preflight 1회 / reviewer 3종 단일 메시지 병렬 spawn / spawn 직후 + **재spawn 시마다** rebalancing
- reviewer 가 SendMessage 로 보고하는지 (출력만 내고 끝나면 페르소나 회귀)
- 취합 → shutdown(본 세션 생성분만 — 소유 확인) → TeamDelete → 죽은 pane 정리

### 4-3. agent-teams

- work-id 규약 로드(공통 config) → work.md 생성/이어받기 → **multi-round 회의록 교차 참조** (있으면 설계 결정 반영 확인)
- 팀원 2~3 페르소나 혼합 (직전 테스트와 다른 조합 권장 — backendDev/qa ↔ frontendDev/qa/reviewer 교대)
- Plan 게이트(보고→승인→구현) / role.md 즉시 기록 / Lead diff 검증 / cascade(구현→qa→reviewer VERDICT)
- 종료: shutdown 3건(소유 확인) → TeamDelete → pane 정리

### 4-4. 종료 후 공통 정리 체크리스트

```bash
pgrep -fl "BUS_PARTICIPANT|multi-round-bus mcp" || echo "버스 워커 0"
ps -axo args | grep -- "--agent-id" | grep -v grep || echo "teammate 0"
# claudex/codex 고아: 인자에 mcp_servers= 가 있는 detached 프로세스 — cmux top 으로 pane 소속 확인 후만 kill
cmux tree   # 작업 pane 잔존 0 (Lead 제외), rebalancing + focus-pane 복원
```

---

## 5. 시행착오 사전 (알려진 함정 — 발견순)

| # | 함정 | 증상 | 올바른 처리 |
|---|---|---|---|
| 1 | SKILL frontmatter 에 따옴표 없는 `예:` 콜론 | codex 가 스킬 로드 실패 (invalid YAML) | description 은 작은따옴표 스칼라. L1-(a) 가 잡음 |
| 2 | `--content` 값이 `---` 로 시작 | parseArgs 가 stdin 대기 행 | VALUE_OPTS 가 무조건 소비 (수정됨). 긴 본문은 stdin 파이프 권장 |
| 3 | **cmux surface lazy-init** | 화면 미렌더 pane 은 쉘 미기동 — send 유실·capture 실패, `simulate-app-active` 로도 안 깨움 | readiness 마커 가드 필수. **L4 는 사용자 화면 활성 전제** |
| 4 | `-c mcp_servers.X` 인라인은 **병합** (교체 아님) | 기존 grafana/atlassian 등 동반 로드 | 기존 서버 `enabled=false` 전수 비활성 (claude 는 `--strict-mcp-config` 가 완전 격리) |
| 5 | MCP 도구 승인 elicitation (`tool_call_mcp_elicitation` stable) | 호출마다 다이얼로그 / exec 는 "user cancelled" (`request_user_input` 미지원) | claudex/codex: `--disable tool_call_mcp_elicitation --dangerously-bypass-approvals-and-sandbox` (영구 신뢰 설정 없음 — 후보 키 전수 무효 실측) |
| 6 | claude 워커 don't ask 모드 | 버스 도구 자동 거부 — "수신만 되는 반쪽 참가자" → 조용한 데드락 | `--dangerously-skip-permissions` + `--allowedTools mcp__bus__*` 3종 |
| 7 | 게시·응답 시점 교차 레이스 | 처리 중 게시된 추가 요청을 "지나간 것"으로 오판 — 묻힘 | reply_to + 미응답 큐 (커서 독립 재계산). 워커는 시점 추론 금지 |
| 8 | Lead 는 노크로만 깨어남 | 워커가 막히면 회의가 조용히 정지 | post 후 `watch` 워치독 백그라운드 (RESPONDED/STALLED 가 Lead 를 깨움) |
| 9 | rebalancing "첫 분할 1회" 신화 | 재spawn pane 비율 미적용 / 순차 down 분할 row 1/2·1/4·1/4 | **spawn·재spawn 으로 pane 이 바뀔 때마다 직후 1회** + 전 분할 후 1회 더 |
| 10 | spawn 직후 사망 워커의 pane 잔존 | 빈 pane 누적 — 레이아웃·식별 혼란 | `cmux top --processes` 로 프로세스 0 확인 후 close → 재spawn → rebalancing |
| 11 | teammate spawn 버전 경로 (`versions/X` 삭제) | `env: ...: No such file or directory` | keepalive (hook 자동 + preflight). launcher 세션은 comm 이 순수 버전명 — 검출 주의. 보존본 없으면 대체 복원 |
| 12 | **고정 팀명 = 크로스 세션 충돌** | 타 세션과 워커 메시지 교차, 정리 오발 (실사고) | 팀명 `<HHMMSS>` suffix. **정리 전 소유 확인** — `-N` 접미 워커 = 타 리드 신호, `--parent-session-id` 대조 |
| 13 | reviewer 가 출력만 내고 SendMessage 안 함 | Lead 가 결과 못 받음 | 페르소나에 보고 의무 명시 (반영됨). spawn prompt 에도 보고 의무 1줄 |
| 14 | Lead 재촉 ↔ 팀원 완료 보고 확인 시점 레이스 | "작업 안 했네" 오판 → 불필요 재촉 | 재촉 전 git diff + role.md 직접 확인. idle ≠ 미작업 |
| 15 | TeamCreate "한 lead 한 team" | Already leading 에러 | 이전 팀 TeamDelete 선행. **단 Task\* 가 팀 리스트로 전환돼 기존 태스크 소실** — 팀 삭제 전 태스크 상태 갈무리 |
| 16 | 검증과 파괴를 한 Bash 블록에 | 검증 출력 보기 전에 삭제 실행 (크로스 세션 사고의 직접 원인) | **검증 → 출력 읽고 판단 → 별도 호출로 삭제** |
| 17 | 노크 첫 글자 잘림 (`bus] 메시지 확인`) | 1회 관찰 — 영향 없음 | 모니터링. 재발 빈도 생기면 매칭 느슨화 |

---

## 6. 판정·마감

- **PASS 기준**: 해당 레벨 체크 전부 통과 + §4-4 정리 체크리스트 0 잔존
- **FAIL 시**: 수정 → 해당 레벨부터 재실행 (L4 실패면 L1~L3 먼저 — 정적/단위에서 잡히는 회귀가 대부분)
- 발견 이슈는 CHANGELOG 에 **발견 경위와 함께** 기록 (이력의 사실성), 버전 bump 정책 준수 (`claude-X.Y.Z`/`codex-X.Y.Z` 독립, 매 커밋, 다운그레이드 금지)
- 실측으로 확인된 환경 동작(cmux·codex 특성)은 본 스킬 §5 에 추가해 다음 테스트에 전수
