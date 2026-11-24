#!/bin/sh
# 이 워크스페이스 샌드박스가 환경 점검으로 정해졌으면(.kit/env-check.json) 모든 답변 맨 앞에 [MXC]·[SRT] 를 붙이게 한다 — 어느 샌드박스에서 시험이 도는지 늘 보이게
for f in ".kit/env-check.json" "${CLAUDE_PROJECT_DIR:-.}/.kit/env-check.json"; do [ -f "$f" ] && break; done
[ -f "$f" ] || exit 0
case $(sed -n 's/.*"ok":true,"kind":"\([a-z]*\)".*/\1/p' "$f" | head -1) in
  mxc) t=MXC ;; srt) t=SRT ;; *) exit 0 ;;
esac
echo "이 워크스페이스의 샌드박스는 환경 점검에서 [$t] 로 정해졌다(.kit/env-check.json). 시험·실행은 이 샌드박스 하나로만 돈다. 사용자에게 하는 모든 답변 맨 앞에 [$t] 를 붙인다."
