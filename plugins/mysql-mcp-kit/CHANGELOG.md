# Changelog — mysql-mcp-kit

## claude-0.1.1 / codex-0.1.1 (2026-10-26)

### Fixed
- **Claude 판 버전 표기가 레포 규약(`claude-X.Y.Z`)을 어기고 있던 것** — 최초 등록(`5bf3a954`, 2026-07-22)부터 Claude 쪽만 `0.1.0` 이었고 Codex 쪽은 처음부터 `codex-0.1.0` 이었다. 같은 커밋에서 한쪽만 접두를 빠뜨린 것이고, 이후 한 번도 bump 되지 않아 그대로 남았다. `plugin.json`·`marketplace.json`·스킬 frontmatter `metadata.version` **세 곳** 모두 교정했다.
  - 접두 없는 버전이 "공유라서 그렇다"로 보일 수 있으나 **공유가 아니다** — 두 트리는 심링크·하드링크가 아닌 별개 파일이고(inode 상이), 같은 값이라면 Codex 쪽에 `codex-` 가 붙어 있을 이유가 없다.

### Added
- **`db-access` §6 "영속 저장소(볼트)와의 관계 — 연계 없음"** (양 트리). 이 스킬은 접속·조회 지침이라 보조 세션을 띄우지도, 파일 산출물을 만들지도 않는다 — 기록 계층 연계가 해당하지 않는다(`set/restore-statusline` 과 같은 범주). 감사 로그 `~/.ai/db-audit/` 는 도구 데이터 영역이고, 조회 결과로 보고서를 쓸 때는 `ticket-analysis` 의 `artifact-routing.md` 가 스킬 무관하게 강제되므로 따로 가리킬 필요가 없다.
  - 2026-10-26 스킬 영속화 리빌딩 **범위에서 이 플러그인이 빠져 있었다**(요청서·점검표 언급 0건). 전수 점검에서 발견했고, 확인 결과 **누락이지만 결함은 아니다** — 다음 점검에서 또 "빠진 것"으로 보이지 않도록 판정 근거를 스킬에 남겼다.

### Verified
- 양 트리 `plugin.json`·`marketplace.json`·스킬 frontmatter 버전이 전부 `claude-`/`codex-` 형식(전수 6개 플러그인 확인). `.agents/plugins/marketplace.json` 에는 `version` 필드가 없어 미변경(레포 지침 §1-2).
- 양 트리 `db-access` 의 남은 차이는 **의도된 것 2건뿐**(트리별 `description` 문구·`version`).
