# 작업 의뢰서 — multi-round Phase 3-A 재작성 (회의 워커 2채널 공존 복원)

> 이 문서는 **리줌 없는 새 세션**에 작업을 인계하기 위한 자기완결 의뢰서다.
> 새 세션은 이 대화 맥락을 모르므로, 아래만 읽고 작업을 완수할 수 있어야 한다.
> 작성: 2026-06-25 / 작성 세션: claude-opus-4-8 / 현재 배포 버전: **claude-2.42.1**

---

## 0. 가장 먼저 읽을 것 (순서)

1. 이 의뢰서 전체
2. `plugins/deft/RATIONALE.md` 의 **R-16**(회의 워커 2채널 공존 — 핵심 절차), R-8(cmux --workspace), R-15(send 3규약), R-7(회의=버스)
3. `plugins/deft/PENDING.md` 의 "🔴 Phase 3-A 재작성" 항목(설계 요약)
4. `plugins/deft/skills/multi-round/SKILL.md` 의 **Phase 3-A(현재 코드)** + **§NTP 절차(192~196행대)·운영 용례 1(228~274행대)**

> ⚠️ 새 세션은 cwd 가 `~/git/bluehansl-plugins` 인지 먼저 확인(`git -C ~/git/bluehansl-plugins log --oneline -1` → `2362937` 또는 그 이후).

---

## 1. 한 줄 목표

**multi-round 회의 모드의 Phase 3-A 워커 부팅을, "빈 pane + CLI 직접부팅"(현재·회귀)에서 "첫 워커 Agent tool + 나머지 헬퍼(DEFT_BUS_DIR 주입)"(R-16·정답)로 재작성**해서, 회의 워커가 **pane 이름표(`@logistics`) + NTP 노크 + board 토론**을 모두 갖게 한다.

---

## 2. 왜 이 작업이 필요한가 (배경)

- 정상 동작(사용자 실측 확정): 회의 워커가 `--claude-team … --claude-team-agent <name> -c mcp_servers.bus` 로 떠서 **NTP binding(이름표·노크) + 버스 MCP(board 토론) 2채널 공존**.
- **회귀**: claude-2.40.0(회의=버스 복원)에서 Phase 3-A 를 "빈 pane + CLI 직접부팅"(`claudex -c mcp_servers.bus` / `claude --model …`)으로 단순화하며 **`--claude-team-agent` binding 을 빠뜨림** → ① pane 이름표 사라짐 ② NTP 노크(ntpPush) 대신 cmuxKnock(느림) 폴백.
- 사용자가 별도 세션에서 2채널 공존을 **수동 재현·성공**하고 정확한 절차를 제공 → **RATIONALE R-16** 에 보존됨. 그 절차를 스킬에 박는 것이 이 작업.

---

## 3. 정확한 해법 (RATIONALE R-16 — 그대로 구현)

회의 모드 Phase 3-A 를 다음 절차로 교체한다. **모든 인프라는 이미 준비됨**(아래 헬퍼 repo·설치 존재 확인 완료).

1. **첫 워커 = claude `Agent` tool**(team 생성) → 반환 `<name>@session-<id>` 에서 **team-id(TID)** 획득.
   - 이 워커는 board MCP 직결 불가 → board 는 Lead 가 `SendMessage` 로 중계, 응답은 `team-lead.json` 직접 회수(R-1·R-2).
2. 첫 워커 pane:ref 를 `~/.claude/teams/<TID>/.last-worker-pane` 에 기록(헬퍼가 그 아래로 스택 — pane 레이아웃 유지).
3. **나머지 워커 = 헬퍼**(전부 `DEFT_BUS_DIR` 주입 → 이름표+board 공존):
   - claudex: `DEFT_BASE_WORKSPACE=<ws> DEFT_BUS_DIR=<SESSION_DIR> deft-claudex-native-spawn <TID> <name>`
   - claude CLI: `DEFT_LEAD_SESSION=$CLAUDE_CODE_SESSION_ID DEFT_BASE_WORKSPACE=<ws> DEFT_BUS_DIR=<SESSION_DIR> deft-claude-native-spawn <TID> <name> "" opus`
   - `DEFT_BUS_DIR` 설정 시 헬퍼가 자동 주입: claudex→`-c 'mcp_servers.bus={…}'`, claude→`--strict-mcp-config --mcp-config <bus>.json`.
4. board 등록 + 의제 게시: `multi-round-bus register --session <SD> --name <w> --surface <surf>` (워커별) → `multi-round-bus post --session <SD> --from lead --to <w> --type request --inject --content "<의제>"` → 발신자 제외 전원 노크, board 전원 공개 → 토론 성립.
5. 응답 회수 2경로: board 워커는 `multi-round-bus check --as lead`, 첫 워커(Agent)는 `team-lead.json` 직접 회수.

### 준비된 인프라 (확인 완료)
- `plugins/deft/bin/deft-claudex-native-spawn` — `DEFT_BUS_DIR` 시 binding+버스 공존 명령 생성(143행 LAUNCH + 134행 BUS_OPT). `--workspace`·readiness 내장.
- `plugins/deft/bin/deft-claude-native-spawn` — `DEFT_BUS_DIR`(버스 주입)·`DEFT_LEAD_SESSION`(onboarding 회피, 48행) 처리 내장.
- `multi-round-bus` — register(`--inbox` 인자 지원)·post·check. 노크는 `info.inbox ? ntpPush : cmuxKnock`(179행) — 헬퍼로 띄우면 inbox 등록되어 ntpPush.

---

## 4. 반드시 지킬 제약 (어기면 회귀)

1. **pane 화면 구성은 현 개발 버전(빈 pane 선분할 레이아웃) 유지** — 사용자 명시 제약. 헬퍼의 `.last-worker-pane` 스택이 이를 만족(첫 워커 아래로 세로 스택, 2컬럼). 레이아웃을 새로 설계하지 말 것.
2. **세션 고유값 하드코딩 절대 금지** — `workspace:N`·`pane:N`·`session-<특정>` 을 코드에 박지 말 것. 전부 `cmux identify` 런타임 발견(`LEAD_WORKSPACE`/`LEAD_PANE`) + Agent spawn 결과(TID). (R-8)
3. **모든 cmux 호출에 `--workspace "$LEAD_WORKSPACE"` 동반** (R-8). cmux send 는 C-u 클리어·source 파일화·명시적 나열(R-15) 유지.
4. **활성 team 디렉토리 `rm` 금지** — 런타임이 team-id 참조 못 해 spawn 에러(R-16 교훈).
5. **회의=버스 강제 가드 유지** — 회의 모드는 board 필수(R-7). board.jsonl 생성 확인.

---

## 5. 검증 방법 (⚠️ R-8 맹점 주의)

- 🚫 **bash 로 직접 헬퍼를 호출해 검증하지 말 것** — 검증자가 아는 함정(`--workspace`·source 등)을 무의식적으로 보정하고, Lead 와 같은 워크스페이스라 우연히 되어 **코드 버그를 못 잡는다**(R-8 검증 맹점, 실측).
- ✅ **진짜 검증 = 별도 세션이 스킬을 날것으로, 다른 워크스페이스에서 실행.** 새 워크스페이스에 claude 를 띄워 `deft:multi-round` 로 "토론"을 요청 → ① 워커 pane 하단 이름표(`@name`) ② board.jsonl 에 워커 간 상호 발언(`to:"all"` + 서로 인용) ③ 출력이 의미 이벤트만 — 세 가지를 사용자가 직접 확인.
- 수정 후 사용자에게 "별도 워크스페이스 + 날것 실행으로 검증해 달라"고 요청.

---

## 6. 작업 절차 (권장)

1. 현재 Phase 3-A (2)~(5)(빈 pane 선분할~CLI 직접부팅~register) 코드 정독 + §용례1(헬퍼 절차) 정독 → **둘이 중복/상충**함을 확인(현재 둘이 따로 놂).
2. Phase 3-A 를 R-16 절차(헬퍼 기반)로 재작성. §용례1 과 중복되면 Phase 3-A 가 용례1 을 참조하도록 통합(중복 제거).
3. claude CLI 워커 부팅도 `deft-claude-native-spawn` 헬퍼로 전환(현재 `claude --model` 직접부팅 → 헬퍼). `--name`/이름표는 헬퍼 binding 으로 자동.
4. 버전 bump: claude-2.43.0 (MINOR — 회의 spawn 동작 분기 변경). CHANGELOG + PENDING(이 항목 [x] 완료 이관) 갱신.
5. 커밋·push(master 직접). 꼬리말:
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
   `Claude-Session: <새 세션 URL>`
6. 사용자에게 §5 방식 검증 요청.

---

## 7. 버전·커밋 규약 (bluehansl-plugins)

- Claude 측: `claude-X.Y.Z`. 매 커밋 적절히 bump, 다운그레이드 금지. deft 는 **플러그인 단위** bump(스킬 하나 고쳐도 deft 전체).
- 동기화 3곳: `plugins/deft/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` / `plugins/deft/CHANGELOG.md`.
- 응답 언어 한국어. 코드 식별자·프로토콜 키워드는 영어.

---

## 8. 한 줄 요약

회의 워커 이름표·NTP 노크가 사라진 건 2.40.0 에서 헬퍼(binding) 대신 CLI 직접부팅으로 바꾼 회귀다. 해법(사용자 실측 확정, RATIONALE R-16)은 **첫 워커 Agent tool + 나머지 헬퍼(DEFT_BUS_DIR 주입)로 NTP+버스 2채널 공존**. 인프라는 다 준비됐다. pane 구성 유지·하드코딩 금지·R-8 검증맹점만 지키면 된다. PENDING 의 해당 항목을 완료로 옮기고 claude-2.43.0 으로 배포.
