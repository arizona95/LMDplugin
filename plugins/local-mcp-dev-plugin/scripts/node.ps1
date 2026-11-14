# 사내 MCP 개발 키트 — kitdev.mjs 를 돌릴 Node 찾기(윈도우)
# PC 에 Node 22.12 이상이 있으면 그것, 없으면 사내 키트에서 휴대용 Node 를 받아 %LOCALAPPDATA%\mcp-kit\node 에 푼다(설치·관리자 권한 없음).
# 마지막 줄: KITDEV-NODE: <node.exe 전체 경로> — 이 세션의 kitdev 실행은 그 경로로 한다.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Ok($exe) {
  if (-not $exe -or -not (Test-Path $exe)) { return $false }
  & $exe -e "const [a,b]=process.versions.node.split('.').map(Number); process.exit(a>22||(a==22&&b>=12)?0:1)" 2>$null
  return $LASTEXITCODE -eq 0
}

$sys = (Get-Command node -ErrorAction SilentlyContinue).Source
if (Ok $sys) { Write-Output "KITDEV-NODE: $sys"; exit 0 }

$dir = Join-Path $env:LOCALAPPDATA 'mcp-kit\node'
$exe = Join-Path $dir 'node.exe'
if (-not (Ok $exe)) {
  # 키트 주소 — 사내 마켓플레이스 플러그인의 kit.json, 아니면 이 워크스페이스의 .kit\workspace.json
  $pub = $null
  foreach ($f in @((Join-Path $PSScriptRoot '..\kit.json'), (Join-Path (Get-Location) '.kit\workspace.json'))) {
    if (-not $pub -and (Test-Path $f)) { $pub = (Get-Content $f -Raw | ConvertFrom-Json).public }
  }
  if (-not $pub) { Write-Output 'KITDEV-FAIL: 사내 MCP 키트 주소를 모릅니다 — 사내 마켓플레이스에서 플러그인을 다시 받으세요'; exit 1 }
  $zip = Join-Path $env:TEMP 'mcp-kit-node.zip'
  $tmp = Join-Path $env:TEMP 'mcp-kit-node'
  Write-Output "Node 가 없어 사내 키트에서 휴대용 Node 를 받습니다(약 30MB, 설치 없음) — $dir"
  try {
    Invoke-WebRequest -UseBasicParsing -Uri "$($pub.TrimEnd('/'))/download/runtime/node-win-x64.zip" -OutFile $zip
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
    New-Item -ItemType Directory -Force -Path (Split-Path $dir) | Out-Null
    Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $dir
  } catch {
    Write-Output "KITDEV-FAIL: 휴대용 Node 를 받지 못했습니다 — $($_.Exception.Message)"; exit 1
  } finally {
    Remove-Item -Force $zip -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  }
  if (-not (Ok $exe)) { Write-Output "KITDEV-FAIL: 받은 Node($exe)가 실행되지 않습니다"; exit 1 }
}
Write-Output "KITDEV-NODE: $exe"
