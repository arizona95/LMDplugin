# LMDplugin

Local MCP Dev 키트 플러그인 마켓플레이스.

| 플러그인 | 누가 | 어디서 |
|---|---|---|
| `kit-admin-plugin` | 키트 서버를 올리는 관리자 | 리눅스 서버의 Claude Code CLI — "환경 빌드해줘" |
| `local-mcp-dev-plugin` | MCP 를 만드는 임직원 | 개발 PC 의 Claude Code |

관리자(리눅스 서버):
```
claude plugin marketplace add https://github.com/arizona95/LMDplugin.git
claude plugin install kit-admin-plugin@lmdplugin
```

개발 임직원:
```
claude plugin marketplace add https://github.com/arizona95/LMDplugin.git
claude plugin install local-mcp-dev-plugin@lmdplugin --scope project
```
