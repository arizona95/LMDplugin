#!/usr/bin/env bash
# 사내 MCP 개발 키트 — 관리자 도우미. 관리자 리눅스 서버에서 Claude CLI 가 부른다(스킬 kit-build · kit-status).
# 사용: kitadmin.sh check [묶음 폴더] | find | unpack <묶음.tar> [풀 곳] | selfsign <묶음 폴더> <도메인>
#       certs <묶음 폴더> <파일>... | conf <묶음 폴더> KEY=값... | key <묶음 폴더> [--from <파일>]
#       reuse <묶음 폴더> | setup <묶음 폴더> | install <묶음 폴더> | status
# 줄 머리: [ OK ] 됨 · [주의] 설치는 되지만 볼 것 · [없음] 채워야 함 · [실패] 이대로는 설치 안 됨
set -u
LC_ALL=C.UTF-8 2>/dev/null; export LC_ALL
NS=mcp-kit
ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[주의] %s\n' "$*"; }
miss() { printf '[없음] %s\n' "$*"; MISSING=$((MISSING + 1)); }
bad() { printf '[실패] %s\n' "$*"; FAILS=$((FAILS + 1)); }
die() { printf '[실패] %s\n' "$*"; exit 2; }
FAILS=0 MISSING=0
gib() { awk -v k="$1" 'BEGIN { printf "%.0f", k / 1048576 }'; }
avail_kib() { df -Pk "$1" 2>/dev/null | awk 'NR == 2 { print $4 }'; }
existing_parent() { p="$1"; while [ ! -d "$p" ]; do p="$(dirname "$p")"; done; printf '%s' "$p"; }
# sudo 를 비밀번호 없이 쓸 수 있나 — 안 되면 sudo 줄은 관리자가 직접 친다(Claude CLI 에서 '! 명령')
can_sudo() { [ "$(id -u)" = 0 ] || sudo -n true 2>/dev/null; }
as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo -n "$@"; fi; }
bundle() {
  d="${1:-}"; [ -n "$d" ] || die "묶음 폴더를 주세요 (mcp-dev-server-kit-v<판>)"
  d="$(cd "$d" 2>/dev/null && pwd -P)" || die "묶음 폴더가 없습니다: $1"
  case "$(basename "$d")" in mcp-dev-server-kit-v?*) ;; *) die "묶음 폴더 이름이 mcp-dev-server-kit-v<판> 이 아닙니다: $d" ;; esac
  [ -f "$d/bootstrap.sh" ] || die "$d 에 bootstrap.sh 가 없습니다 — 묶음을 다시 풀어 주세요"
  printf '%s' "$d"
}
# 이 서버에 키트가 이미 설치돼 있나(다시 설치·업그레이드) — k3s 와 키트 데이터 폴더로 본다(root 없이 볼 수 있는 것)
installed() { [ -f /etc/rancher/k3s/k3s.yaml ] && [ -d /srv/kit ]; }
conf_get() {
  [ -f "$1/setup/kit.conf" ] || return 0
  sed -n "s/^[[:space:]]*$2=//p" "$1/setup/kit.conf" | tail -n 1 | sed 's/^["'\'']//; s/["'\'']$//'
}

# 1) 이 서버가 키트를 올릴 수 있는가 — 리눅스·사양·쿠버네티스·포트·도구
check() {
  [ "$(uname -s)" = Linux ] || { bad "리눅스가 아닙니다($(uname -s)) — 키트 서버는 리눅스 서버에만 올립니다"; echo "KIT-CHECK-FAIL"; exit 1; }
  os="$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-}")"
  ok "리눅스 ${os:-?} · 커널 $(uname -r)"
  case "$(uname -m)" in x86_64|amd64) ok "CPU 종류 x86_64" ;; *) bad "CPU 종류 $(uname -m) — 묶음의 k3s·이미지는 x86_64(amd64) 용입니다" ;; esac
  n="$(nproc 2>/dev/null || echo 0)"
  [ "$n" -ge 4 ] && ok "CPU $n 개 (권장 4 이상)" || warn "CPU $n 개 — 권장 4 이상(적으면 검사가 느림)"
  m="$(awk '/MemTotal/ { print $2 }' /proc/meminfo)"
  [ "$m" -ge 15000000 ] && ok "메모리 $(gib "$m")GB (권장 16GB 이상)" || warn "메모리 $(gib "$m")GB — 권장 16GB 이상"
  if [ -n "${KUBECONFIG:-}" ] && command -v kubectl >/dev/null 2>&1 && kubectl version >/dev/null 2>&1; then
    ok "쿠버네티스: 이미 있는 클러스터($(kubectl config current-context 2>/dev/null)) — 그것을 씁니다"; root=/var/lib/docker
  elif [ -f /etc/rancher/k3s/k3s.yaml ]; then
    ok "쿠버네티스: 이 서버의 k3s — 그것을 씁니다"; root=/var/lib/rancher
  else
    ok "쿠버네티스: 없음 → 설치 때 묶음에 든 k3s 를 이 서버에 설치합니다(인터넷 필요 없음)"; root=/var/lib/rancher
  fi
  r="$(existing_parent "$root")"; a="$(avail_kib "$r")"
  need=0
  # bootstrap 과 같은 기준 — 키트 이미지가 이미 클러스터에 있으면 이미지를 넣지 않으므로 넣을 자리를 따지지 않는다
  have_img=0
  if [ -n "${1:-}" ] && installed && can_sudo; then
    ref="$(awk '$1 == "kit" { print $2 }' "$1/k8s/images.txt" 2>/dev/null)"
    [ -n "$ref" ] && as_root k3s ctr -n k8s.io images ls -q 2>/dev/null | grep -q "^\(docker.io/library/\)\{0,1\}$ref\$" && have_img=1
  fi
  if [ "$have_img" = 1 ]; then
    ok "디스크 $r 남은 것 $(gib "$a")GB — 이 판의 이미지가 이미 있어 넣을 자리는 필요 없음"
  elif [ -n "${1:-}" ]; then
    d="$(bundle "$1")"; t=0
    for f in "$d"/*.tar "$d"/k8s/*.tar; do [ -f "$f" ] && t=$((t + $(du -k "$f" | cut -f1))); done
    total="$(df -Pk "$r" | awk 'NR == 2 { print $2 }')"
    need=$((t * 2 + 1048576 + total / 5))
  fi
  if [ "$have_img" = 1 ]; then :
  elif [ "$need" -gt 0 ]; then
    [ "$a" -ge "$need" ] && ok "디스크 $r 남은 것 $(gib "$a")GB (설치에 $(gib "$need")GB 필요)" \
      || bad "디스크 $r 남은 것 $(gib "$a")GB — 설치에 $(gib "$need")GB 필요(이미지 넣을 자리 + 디스크의 20% 여유) → 디스크를 늘리거나 비우세요"
  else
    [ "$a" -ge 67108864 ] && ok "디스크 $r 남은 것 $(gib "$a")GB" || warn "디스크 $r 남은 것 $(gib "$a")GB — 권장 64GB 이상(묶음을 풀면 정확히 계산합니다)"
  fi
  port="${KIT_PORT:-443}"
  if command -v ss >/dev/null 2>&1 && ss -ltnH "sport = :$port" 2>/dev/null | grep -q .; then
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then warn "포트 $port 를 쓰는 프로그램이 있습니다 — 이미 설치된 키트면 괜찮습니다"
    else bad "포트 $port 를 이미 다른 프로그램이 씁니다 → 그 프로그램을 멈추거나 KIT_PORT=<다른 포트> 로 설치"; fi
  else ok "포트 $port 비어 있음"; fi
  for c in openssl sha256sum tar awk sed; do command -v "$c" >/dev/null 2>&1 || bad "$c 가 없습니다 → 패키지 관리자로 설치"; done
  [ "$FAILS" = 0 ] && ok "도구 openssl · sha256sum · tar"
  if can_sudo; then ok "관리자 권한: 비밀번호 없이 sudo 가능 — 설치를 Claude 가 바로 실행합니다"
  else warn "관리자 권한: sudo 에 비밀번호가 필요합니다 — 설치 명령은 관리자가 직접 칩니다(Claude CLI 에서 '! sudo ...')"; fi
  [ "$FAILS" = 0 ] && echo "KIT-CHECK-OK" || { echo "KIT-CHECK-FAIL"; exit 1; }
}

# 2) 받은 묶음 찾기 — 홈·/tmp·/opt·/data·/srv 아래 3단계까지
find_bundles() {
  found=0
  for base in "$HOME" /tmp /opt /data /srv /mnt; do
    [ -d "$base" ] || continue
    while IFS= read -r f; do
      case "$f" in /srv/kit/releases/*) continue ;; esac
      if [ -d "$f" ]; then printf '폴더  %s\n' "$f"; else printf '묶음  %s (%s)\n' "$f" "$(du -h "$f" | cut -f1)"; fi
      found=1
    done < <(find "$base" -maxdepth 3 \( -name 'mcp-dev-server-kit-v*.kit.tar' -o -type d -name 'mcp-dev-server-kit-v*' \) 2>/dev/null | sort)
  done
  [ "$found" = 1 ] || echo "찾은 묶음 없음 — 통합관리자에게 받은 mcp-dev-server-kit-v<판>.kit.tar 의 위치를 물어보세요"
}

# 3) 묶음 풀기 + 해시 확인
unpack() {
  tarf="${1:-}"; [ -f "$tarf" ] || die "묶음 파일이 없습니다: $tarf"
  dest="${2:-$HOME/kit}"
  case "$dest" in /srv/kit/releases*) die "/srv/kit/releases 아래에는 풀지 않습니다(그 폴더는 키트 안에서 보입니다) → 예: ~/kit" ;; esac
  name="$(tar tf "$tarf" | head -n 1 | cut -d/ -f1)"
  case "$name" in mcp-dev-server-kit-v?*) ;; *) die "키트 묶음이 아닙니다(첫 폴더 $name)" ;; esac
  mkdir -p "$dest" && chmod 700 "$dest"
  if [ -d "$dest/$name" ]; then ok "이미 풀려 있음: $dest/$name"
  else echo "푸는 중 ($(du -h "$tarf" | cut -f1)) → $dest/$name"; tar xf "$tarf" -C "$dest" || die "묶음을 풀지 못했습니다"; fi
  (cd "$dest/$name" && sha256sum -c --quiet --ignore-missing SHA256SUMS) && ok "묶음 해시 확인(SHA256SUMS)" || die "묶음 파일 해시가 맞지 않습니다 → 통합관리자에게 묶음을 다시 받으세요"
  echo "BUNDLE=$dest/$name"
}

# 4) 사내 인증서가 없을 때 — 시험용 자체 서명 CA + 서버 인증서
selfsign() {
  d="$(bundle "${1:-}")"; dom="${2:-}"; [ -n "$dom" ] || die "도메인을 주세요"
  s="$d/setup"; mkdir -p "$s" && chmod 700 "$s"
  [ -f "$s/server.crt" ] && die "setup/server.crt 가 이미 있습니다 — 바꾸려면 먼저 그 파일을 옮기세요"
  t="$(mktemp -d)"; trap 'rm -rf "$t"' RETURN
  openssl req -x509 -newkey rsa:3072 -nodes -days 1825 -subj "/CN=MCP Kit CA ($dom)" \
    -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign,cRLSign \
    -keyout "$t/ca.key" -out "$s/ca.pem" 2>/dev/null || die "CA 를 만들지 못했습니다"
  openssl req -newkey rsa:2048 -nodes -subj "/CN=$dom" -keyout "$s/server.key" -out "$t/req.csr" 2>/dev/null || die "서버 키를 만들지 못했습니다"
  printf 'subjectAltName=DNS:%s\nbasicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n' "$dom" > "$t/ext"
  openssl x509 -req -in "$t/req.csr" -CA "$s/ca.pem" -CAkey "$t/ca.key" -CAcreateserial -days 825 -extfile "$t/ext" -out "$s/server.crt" 2>/dev/null || die "서버 인증서를 만들지 못했습니다"
  chmod 600 "$s/server.key"
  ok "시험용 인증서 setup/server.crt · server.key · ca.pem (도메인 $dom · CA 개인 키는 지움)"
  warn "개발자 PC 가 이 CA(setup/ca.pem)를 믿어야 접속됩니다 — 정식 운영은 사내 CA 인증서로 바꾸세요(포털 '회사 환경')"
}

# 5) 관리자가 가진 인증서 파일을 setup/ 에 넣기(.pfx 는 풀어서)
certs() {
  d="$(bundle "${1:-}")"; shift; s="$d/setup"; mkdir -p "$s" && chmod 700 "$s"
  [ "$#" -gt 0 ] || die "넣을 인증서 파일을 주세요"
  for f in "$@"; do
    [ -f "$f" ] || { bad "파일이 없습니다: $f"; continue; }
    case "$f" in
      *.pfx|*.p12) die "$f 는 PKCS#12 묶음입니다 — 암호가 필요하니 관리자가 직접 푸세요: openssl pkcs12 -in $f -nokeys -out $s/server.crt; openssl pkcs12 -in $f -nocerts -nodes -out $s/server.key" ;;
    esac
    cp "$f" "$s/" && chmod 600 "$s/$(basename "$f")" && ok "setup/$(basename "$f") 넣음"
  done
}

# 6) kit.conf 에 값 넣기(같은 키는 바꿈) — 비밀값은 받지 않는다
conf() {
  d="$(bundle "${1:-}")"; shift; c="$d/setup/kit.conf"; mkdir -p "$d/setup"; touch "$c"; chmod 600 "$c"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    case "$k" in
      LLM_API_KEY|*SECRET*|*TOKEN*) die "$k 는 kit.conf 에 적지 않습니다(디스크에 평문) — LLM 키는 key 명령, 나머지 비밀은 설치 뒤 포털 '회사 환경'에서" ;;
      *[!A-Z0-9_]*|"") die "'$kv' — KEY=값 형식(대문자 이름)이어야 합니다" ;;
    esac
    grep -v "^[[:space:]]*$k=" "$c" > "$c.new" || true
    printf '%s=%s\n' "$k" "$v" >> "$c.new" && mv "$c.new" "$c" && chmod 600 "$c"
    case "$k" in PORTAL_ADMIN_PASSWORD) ok "$k (값 숨김)" ;; *) ok "$k=$v" ;; esac
  done
}

# 7) LLM 키 — Claude 대화에 남지 않게 관리자가 다른 터미널에서 직접 넣는다(또는 이미 있는 키 파일에서)
key() {
  d="$(bundle "${1:-}")"; f="$d/setup/llm.key"
  if [ "${2:-}" = --from ]; then
    [ -f "${3:-}" ] || die "키 파일이 없습니다: ${3:-}"
    tr -d '\r' < "$3" | grep -v '^[[:space:]]*$' | head -n 1 | tr -d '[:space:]' > "$f"
  else
    [ -t 0 ] || die "이 명령은 관리자가 따로 연 터미널에서 직접 실행합니다(키를 대화에 붙여 넣지 않게): bash $0 key $d"
    printf 'LLM 공급자 키를 붙여 넣고 Enter (화면에 보이지 않음): '; IFS= read -rs k; echo
    [ -n "$k" ] || die "키가 비었습니다"
    printf '%s\n' "$k" > "$f"
  fi
  chmod 600 "$f"; ok "setup/llm.key 넣음(길이 $(tr -d '\n' < "$f" | wc -c)자 · 설치 뒤 키트 키 저장소로 옮기고 이 파일은 지워짐)"
}

# 7-1) 이미 설치된 키트가 쓰는 인증서를 setup/ 으로 가져오기(다시 설치·업그레이드 — bootstrap 은 setup/ 의 인증서로 설치한다)
reuse() {
  d="$(bundle "${1:-}")"; s="$d/setup"; mkdir -p "$s" && chmod 700 "$s"
  installed || die "이 서버에 설치된 키트가 없습니다 — 인증서는 certs 나 selfsign 으로 넣으세요"
  can_sudo || { echo "KIT-REUSE-NEEDS-SUDO"; echo "! sudo cp /srv/kit/tls/server.crt /srv/kit/tls/server.key $s/ && sudo sh -c '[ -f /srv/kit/tls/ca.pem ] && cp /srv/kit/tls/ca.pem $s/ || true' && sudo chown $(id -un) $s/*"; exit 0; }
  for f in server.crt server.key ca.pem; do
    as_root test -f "/srv/kit/tls/$f" || continue
    as_root cat "/srv/kit/tls/$f" > "$s/$f" && chmod 600 "$s/$f" && ok "지금 키트의 $f → setup/$f"
  done
}

# 8) setup/ 이 설치할 수 있는 상태인가 — bootstrap 의 사전 점검과 같은 것을 미리 본다
setup() {
  d="$(bundle "${1:-}")"; s="$d/setup"
  [ -d "$s" ] || { miss "setup/ 폴더"; echo "KIT-SETUP-INCOMPLETE"; exit 0; }
  leaf="" keyf="" cas=""
  for f in "$s"/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in README*|*.example|kit.conf|llm.key) continue ;; esac
    if grep -q 'ENCRYPTED PRIVATE KEY\|Proc-Type: 4,ENCRYPTED' "$f"; then bad "$(basename "$f") 는 암호가 걸린 개인 키 → openssl pkey -in 파일 -out 파일.plain 으로 풀어 바꿔 두세요"
    elif grep -q 'PRIVATE KEY-----' "$f"; then keyf="$f"
    elif grep -q 'BEGIN CERTIFICATE' "$f"; then
      if openssl x509 -in "$f" -noout -text 2>/dev/null | grep -q 'CA:TRUE'; then cas="$cas $f"; else leaf="$f"; fi
    fi
  done
  if [ -z "$leaf" ] && installed; then miss "서버 인증서·개인 키 — 이미 설치된 키트가 쓰는 것을 그대로 쓰려면 reuse, 새 인증서면 certs"
  elif [ -z "$leaf" ]; then miss "서버 인증서(server.crt) — 사내 CA 에서 받은 것을 넣거나, 시험이면 selfsign"
  else
    sans="$(openssl x509 -in "$leaf" -noout -text | awk '/Subject Alternative Name/ { getline; print }' | tr ',' '\n' | sed -n 's/^[[:space:]]*DNS://p' | tr '\n' ' ')"
    end="$(openssl x509 -in "$leaf" -noout -enddate | cut -d= -f2)"
    openssl x509 -in "$leaf" -noout -checkend 0 >/dev/null || bad "서버 인증서가 만료됐습니다($end)"
    [ -n "$sans" ] && ok "서버 인증서 $(basename "$leaf") · 도메인 $sans· 만료 $end" || bad "서버 인증서에 도메인(SAN DNS)이 없습니다 → SAN 을 넣어 다시 발급"
    if [ -z "$keyf" ]; then miss "서버 인증서의 개인 키(server.key)"
    elif [ "$(openssl x509 -in "$leaf" -noout -pubkey 2>/dev/null)" = "$(openssl pkey -in "$keyf" -pubout 2>/dev/null)" ]; then ok "개인 키 $(basename "$keyf") — 인증서와 짝"
    else bad "개인 키 $(basename "$keyf") 가 서버 인증서와 짝이 아닙니다"; fi
    if [ -n "$cas" ]; then
      cat $cas > "$s/.ca-check.pem"
      openssl verify -CAfile "$s/.ca-check.pem" -untrusted "$leaf" "$leaf" >/dev/null 2>&1 && ok "CA 인증서로 서버 인증서 확인됨" || bad "CA 인증서($cas)로 서버 인증서가 확인되지 않습니다 → 발급한 사내 CA 를 ca.pem 으로"
      rm -f "$s/.ca-check.pem"
    elif openssl verify "$leaf" >/dev/null 2>&1; then ok "공인 CA 인증서(ca.pem 없어도 됨)"
    else miss "사내 CA 인증서(ca.pem) — 서버 인증서를 발급한 CA"; fi
  fi
  # 이미지 파일 — 묶음 폴더만 복사하면 수 GB 짜리 이미지 tar 가 빠지기 쉽다. 이미 클러스터에 있으면 없어도 된다
  while read -r kind ref file; do
    [ -n "$kind" ] || continue
    if [ -f "$d/$file" ]; then ok "이미지 파일 $file"
    elif installed && can_sudo && as_root k3s ctr -n k8s.io images ls -q 2>/dev/null | grep -q "^\(docker.io/library/\)\{0,1\}$ref\$"; then ok "이미지 $ref — 이미 이 서버의 쿠버네티스에 있음"
    else miss "이미지 파일 $file — 묶음(.kit.tar)을 통째로 다시 풀어 주세요(폴더만 복사하면 빠짐)"; fi
  done < <(cat "$d/k8s/images.txt" 2>/dev/null)
  [ -f "$d/k8s/images.txt" ] || bad "묶음에 k8s/images.txt 가 없습니다 → 묶음을 다시 풀어 주세요"
  url="$(conf_get "$d" KIT_PUBLIC_URL)"
  if [ -n "$url" ]; then
    host="${url#https://}"; host="${host%%/*}"; host="${host%%:*}"
    case "$url" in https://*) ok "서버 주소 $url" ;; *) bad "서버 주소는 https:// 로 시작해야 합니다($url)" ;; esac
    [ -n "${sans:-}" ] && { printf ' %s ' "$sans" | grep -q " $host \| \*\.${host#*.} " || bad "서버 주소 $host 가 인증서 도메인($sans)에 없습니다"; }
    getent hosts "$host" >/dev/null 2>&1 && ok "$host DNS 찾아짐" || warn "$host 가 이 서버의 DNS 에 없습니다 — 개발자 PC 에서는 찾아져야 합니다(사내 DNS 등록)"
  else ok "서버 주소: 적지 않음 → 인증서의 첫 도메인"; fi
  m="$(conf_get "$d" LLM_MODEL)"; b="$(conf_get "$d" LLM_API_BASE)"
  case "$m" in ?*/?*) ok "LLM 모델 $m" ;; *) miss "LLM 모델(LLM_MODEL — 예 openai/gpt-4o-mini · anthropic/claude-haiku-4-5)" ;; esac
  case "$b" in http://?*|https://?*) ok "LLM API 주소 $b" ;; *) miss "LLM API 주소(LLM_API_BASE — 사내 반출 승인된 API)" ;; esac
  if [ -s "$s/llm.key" ]; then ok "LLM 키 setup/llm.key(길이 $(tr -d '\n' < "$s/llm.key" | wc -c)자)"
  elif installed; then ok "LLM 키: 이미 설치된 키트의 키 저장소에 있는 것을 그대로 씀(바꿀 때만 key)"
  else miss "LLM 키(setup/llm.key) — 관리자가 다른 터미널에서 key 명령으로"; fi
  p="$(conf_get "$d" PORTAL_ADMIN_PASSWORD)"
  [ -n "$p" ] && { [ "${#p}" -ge 8 ] && ok "kitadmin 비밀번호 정함(값 숨김)" || bad "kitadmin 비밀번호가 8자보다 짧습니다"; } || ok "kitadmin 비밀번호: 설치가 만들어 끝에 한 번 보여 줌"
  pi="$(conf_get "$d" PYPI_INDEX_URL)"; [ -n "$pi" ] && ok "사내 PyPI 미러 $pi" || ok "사내 PyPI 미러: 없음 → pypi.org 를 열어 씀"
  up="$(conf_get "$d" KIT_UPSTREAM_PROXY)"; [ -n "$up" ] && ok "회사 프록시 $up" || ok "회사 프록시: 없음(서버가 바로 나감)"
  if [ "$FAILS" -gt 0 ]; then echo "KIT-SETUP-FAIL"; exit 1; fi
  # 채울 것이 남은 건 오류가 아니다(Claude 화면에 '실패'로 보이지 않게 0 으로 끝냄) — 끝 줄 표식으로 판단한다
  [ "$MISSING" = 0 ] && echo "KIT-SETUP-READY" || echo "KIT-SETUP-INCOMPLETE"
}

# 9) 설치 — sudo 가 비밀번호 없이 되면 바로, 아니면 관리자가 칠 명령을 알려 준다
install() {
  d="$(bundle "${1:-}")"
  if can_sudo; then
    cd "$d" && as_root ./bootstrap.sh; rc=$?
    [ "$rc" = 0 ] && echo "KIT-INSTALL-OK" || echo "KIT-INSTALL-FAIL($rc)"; exit "$rc"
  fi
  echo "KIT-INSTALL-NEEDS-SUDO"
  echo "관리자가 Claude CLI 입력 칸에 그대로 칩니다(비밀번호를 물으면 넣기):"
  echo "! cd $d && sudo ./bootstrap.sh"
}

# 10) 설치 뒤 상태 — 파드·서비스·전체 점검
status() {
  if ! can_sudo; then
    echo "KIT-STATUS-NEEDS-SUDO"
    echo "! sudo k3s kubectl -n $NS get pods && sudo k3s kubectl -n $NS exec kit-0 -c kit -- kit verify"; exit 0
  fi
  if [ -f /etc/rancher/k3s/k3s.yaml ]; then K="as_root k3s kubectl"; else K="kubectl"; fi
  $K -n "$NS" get pods -o wide 2>&1 || { echo "키트가 설치돼 있지 않습니다(네임스페이스 $NS 없음)"; exit 1; }
  img="$($K -n "$NS" get statefulset kit -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
  echo "키트 이미지: ${img:-?}"
  echo "--- kit verify"
  $K -n "$NS" exec kit-0 -c kit -- kit verify 2>&1 | tail -n 40
}

cmd="${1:-}"; [ "$#" -gt 0 ] && shift
case "$cmd" in
  check) check "$@" ;; find) find_bundles ;; unpack) unpack "$@" ;; selfsign) selfsign "$@" ;;
  certs) certs "$@" ;; reuse) reuse "$@" ;; conf) conf "$@" ;; key) key "$@" ;; setup) setup "$@" ;;
  install) install "$@" ;; status) status ;;
  *) sed -n '3,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
