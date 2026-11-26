# 포털 API 참고 (자동 생성 — build/admin-api-ref.py)

부르는 법: `KA api <메서드> <경로> [JSON 본문 | @파일]` (KA = kitadmin.sh). 권한: 주관리자 > 관리자 > 로그인한 누구나.
쓰기(POST·PUT·DELETE)는 관리자에게 무엇이 바뀌는지 말하고 '예' 를 받은 뒤에만 부른다.

## 메뉴 밖 API (개발 플러그인·CI·내부용 포함)
### account/auth.py
- `GET /api/me` · 로그인한 누구나 — me
### account/people.py
- `POST /api/scim/token` · 주관리자 — scim token
- `GET /api/users/offboard` · 주관리자 — offboard list
- `POST /api/users/{login}/handover/{name}` · 주관리자 — handover
  - 본문: action: str, successor: str = ''
- `POST /api/users/{login}/offboard` · 주관리자 — offboard api
  - 본문: mode: str, reason: str
### account/roles.py
- `GET /api/access` · 주관리자 — access get
- `PUT /api/access` · 주관리자 — access put
  - 본문: mode: str, entries: list[AccessRule] = [], confirm: bool = False
- `GET /api/roles` · 주관리자 — roles list
- `POST /api/roles` · 주관리자 — roles set
  - 본문: login: str, role: str
- `POST /api/roles/request` · 로그인한 누구나 — role request
  - 본문: reason: str
### devkit/ci.py
- `POST /api/ci/basic` · 로그인한 누구나 — ci basic
  - 본문: repo: str, sha: str
- `POST /api/ci/check` · 없음 — ci check
  - 본문: repo: str, sha: str
- `GET /api/ci/gate` · 로그인한 누구나 — ci gate
  - 쿼리: repo, ref='main'
- `GET /api/ci/workflow` · 로그인한 누구나 — ci workflow
### devkit/client.py
- `GET /api/devkit/policy` · 없음 — devkit policy
  - 쿼리: repo='', sha='', dirty=0
- `GET /api/devkit/reports` · 관리자 — 모인 기록 — 관리자(와 관리자 플러그인으로 키트를 고치는 사람)가 본다
  - 쿼리: login='', cmd='', since=0, limit=100
- `POST /api/devkit/reports` · 없음 — 개발 플러그인이 실패하면 명령 · 출력 그대로 · PC 상태를 보낸다(디버깅용) — 로그인 문제도 오류라 로그인 없이도 받고, 누군지 알면 계정을 붙인다
  - 본문: cmd: str = '', argv: list[str] = [], code: int | None = None, fail: str = '', output: str = '', os: str = '', plugin: str = '', kit: str = '', repo: str = '', state: dict = {}
- `GET /api/devkit/reports/{rid}` · 관리자 — devkit report one
- `POST /api/devkit/run` · 없음 — devkit run
  - 본문: event: str, mode: str = '', os: str = '', code: int | None = None, secrets: list[str] = [], error: str = ''
- `POST /api/devkit/secrets` · 없음 — devkit secrets
  - 본문: names: list[str], repo: str = ''
- `GET /api/secrets/names` · 로그인한 누구나 — my secret names
### devkit/devpolicy.py
- `GET /api/devpolicy` · 관리자 — devpolicy get
- `PUT /api/devpolicy` · 주관리자 — devpolicy put
  - 본문: secret_sources: list[str] = ['kms', 'keyring', 'env'], weekly_llm_usd: float | None = None, expected_version: int
### devkit/download.py
- `GET /api/devkit/identity` · 없음 — devkit identity
- `GET /api/devkit/plugin` · 로그인한 누구나 — 개발 시작 화면 — 개발 플러그인을 사내 마켓플레이스에서 까는 명령에 쓰는 값
- `GET /api/download` · 로그인한 누구나 — download info
### devkit/projects.py
- `POST /api/projects` · 로그인한 누구나 — new project
  - 본문: name: str, description: str = ''
### devkit/tokens.py
- `GET /api/devkit/budget` · 로그인한 누구나 — my budget
- `POST /api/devkit/run-token` · 로그인한 누구나 — run token
- `POST /api/dlcode` · 로그인한 누구나 — issue dlcode
- `GET /api/token` · 로그인한 누구나 — token info
- `POST /api/tokens/revoke` · 로그인한 누구나 — revoke tokens
  - 본문: login: str = '', reason: str = ''
### governance/agents.py
- `GET /api/agents` · 관리자 — agents list
- `GET /api/agents/config` · 없음 — agent config
- `POST /api/agents/policy` · 주관리자 — agents policy
  - 본문: checkin: str, auth: str
### governance/egress.py
- `GET /api/egress` · 관리자 — egress state
- `POST /api/egress` · 주관리자 — add rule
  - 본문: host: str, port: int = 443, reason: str
- `GET /api/egress/log` · 관리자 — egress log
  - 쿼리: limit=200
- `POST /api/egress/selftest` · 관리자 — run selftest
- `DELETE /api/egress/{host}/{port}` · 주관리자 — remove rule
### governance/inspection.py
- `GET /api/assets` · 관리자 — assets get
  - 쿼리: login=''
- `GET /api/dlp` · 관리자 — dlp get
- `PUT /api/dlp` · 주관리자 — dlp put
  - 본문: patterns: list[Pattern], expected_version: int
- `GET /api/watchers` · 관리자 — watchers get
- `PUT /api/watchers` · 주관리자 — watchers put
  - 본문: watchers: list[Watcher], expected_version: int
### mcp/registry.py
- `GET /api/registry` · 관리자 — registry
- `POST /api/registry/sync` · 관리자 — registry sync
- `POST /api/registry/{name}/revoke` · 관리자 — revoke
  - 본문: reason: str
### mcp/requests.py
- `GET /api/approval` · 관리자 — 승인 방식 — 수동 | 자동(CI·배포감사 통과면 바로 승인 → 사내 마켓플레이스). 자동은 관리자 자기 MCP 도 승인되니 주관리자만 바꾼다
- `PUT /api/approval` · 주관리자 — set approval mode
  - 본문: mode: str
- `GET /api/repos` · 로그인한 누구나 — my repos
- `GET /api/requests` · 로그인한 누구나 — list requests
  - 쿼리: limit=200, before=''
- `POST /api/requests` · 로그인한 누구나 — new request
  - 본문: repo: str, ref: str = 'main'
- `GET /api/requests/{rid}` · 로그인한 누구나 — get request
- `POST /api/requests/{rid}/decision` · 관리자 — decide
  - 본문: action: str, reason: str = ''
- `POST /api/requests/{rid}/findings/{fid}/appeal` · 로그인한 누구나 — appeal
  - 본문: text: str
- `POST /api/requests/{rid}/findings/{fid}/appeal/decision` · 관리자 — appeal decision
  - 본문: accept: bool, note: str = ''
### ops/backups.py
- `GET /api/backup` · 관리자 — backup get
- `POST /api/backup/key-ack` · 주관리자 — backup key ack
- `POST /api/backup/run` · 주관리자 — backup run
  - 본문: cmd: str
- `PUT /api/backup/settings` · 주관리자 — backup settings
  - 본문: hour: int, keep: int, verify_days: int, rto_minutes: int = 60, expected_version: int
### ops/company.py
- `GET /api/company` · 주관리자 — state
- `POST /api/company/apply` · 주관리자 — apply
- `GET /api/company/plugin.zip` · 주관리자 — plugin zip
- `DELETE /api/company/tls` · 주관리자 — reset tls
### ops/monitor.py
- `GET /api/logs` · 관리자 — logs get
- `POST /api/logs/clear` · 주관리자 — logs clear
  - 본문: scope: str
- `PUT /api/logs/retention` · 주관리자 — logs retention
  - 본문: days: int, expected_version: int
- `GET /api/monitor` · 관리자 — monitor get
  - 쿼리: hours=24
### ops/versions.py
- `GET /api/update/status` · 로그인한 누구나 — update status
- `GET /api/versions` · 주관리자 — versions
