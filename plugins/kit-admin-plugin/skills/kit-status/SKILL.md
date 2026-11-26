---
name: kit-status
description: 이 리눅스 서버에 설치된 사내 MCP 개발 키트의 상태를 보고 문제를 찾는다. 관리자가 "키트 상태 봐줘", "키트 점검해줘", "포털이 안 열려", "개발자 안내 메일 만들어줘", "새 판으로 올려줘" 라고 하면 쓴다.
---

# kit-status — 설치 뒤 점검·문제 해결

## 지금 상황 — 먼저 읽는다
- 이 Claude CLI 는 키트가 설치된 리눅스 서버에서 돈다. 키트는 쿠버네티스 네임스페이스 `mcp-kit` 의 `kit-0`(포털·사내 Git·검사기) 과 `runner`(CI) 로 돈다.
- 도우미: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/kitadmin.sh"` (`KA`). kubectl 은 root 권한이 필요하다 — sudo 가 비밀번호를 물으면 `KA` 가 관리자가 칠 `! sudo …` 줄을 알려 준다.

## 할 일
- **상태** — `KA status`: 파드 목록 · 키트 이미지(판) · `kit verify` 결과를 표로 정리한다. `[FAIL]` 줄은 무엇이 문제이고 무엇을 하면 되는지 한 문장씩.
  - 파드가 Running 이 아니면: `kubectl -n mcp-kit describe pod <파드>` · `kubectl -n mcp-kit logs kit-0 -c kit --tail=80` 을 보고 까닭을 찾는다.
  - LLM 호출 실패 → LLM 주소·모델·키(포털 '회사 환경' 또는 setup/llm.key 넣고 다시 설치) · 서버에서 LLM API 로 나갈 수 있는지.
  - osv.dev 실패 → 서버에서 osv.dev:443 으로 나가는 방화벽·회사 프록시.
- **개발자 안내 메일** — `sudo k3s kubectl -n mcp-kit exec kit-0 -c kit -- kit mail-template` 출력을 그대로 보여 준다.
- **업그레이드** — 새 묶음을 받았으면 kit-build 스킬로 같은 순서(묶음 풀기 → setup 은 이전 값 그대로 → 설치)를 밟는다. 데이터는 그대로 남는다. 포털 '버전 관리' 화면에서 올려도 된다.
- **설정 바꾸기** — 인증서·LLM·회사 프록시·SSO 는 포털 '회사 환경'(`/admin/company`)에서 바꾸고 '적용하고 다시 시작'. 화면 값이 setup/kit.conf 보다 우선한다.

## 하지 않는 것
- 키트 파드·네임스페이스·데이터 볼륨을 지우지 않는다(관리자가 명시해서 시킬 때만, 무엇이 지워지는지 먼저 말하고).
- 이 서버의 다른 프로그램(다른 컨테이너·서비스)을 멈추지 않는다. 포트가 겹치면 무엇이 쓰는지만 보여 준다.
