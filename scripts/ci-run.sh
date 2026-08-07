#!/usr/bin/env bash
# 깃허브 액션의 자세한 로그는 로그인해야 볼 수 있다.
# 그래서 명령이 실패하면 그 끝부분을 주석(annotation)으로도 남긴다. 주석은 누구나 볼 수 있다.
#
#   source scripts/ci-run.sh
#   run "이름" 명령 인자...

set -uo pipefail

run() {
  local name="$1"; shift
  local log
  log="$(mktemp)"

  echo "::group::$name"

  # 상태는 여기서 바로 받아둔다.
  # `if cmd; then ...; fi` 뒤의 $? 를 읽으면 안 된다. 조건이 거짓이고 else 가 없으면
  # if 문 자체는 0 을 돌려줘서, 실패한 빌드가 성공으로 넘어간다.
  local code=0
  "$@" >"$log" 2>&1 || code=$?

  cat "$log"
  echo "::endgroup::"
  [ "$code" -eq 0 ] && return 0

  # 컴파일 오류는 로그 한복판에 있고 끝부분에는 요약만 남는다.
  # 끝만 잘라 보내면 정작 무엇이 틀렸는지가 빠진다. 오류 줄을 먼저 담는다.
  local errors
  errors="$(grep -E '(error|warning: will never be executed):' "$log" | head -40 || true)"
  local msg
  msg="$( { [ -n "$errors" ] && printf '%s\n----\n' "$errors"; tail -c 2000 "$log"; } \
    | sed -e 's/%/%25/g' -e $'s/\r//g' \
    | awk '{ printf "%s%%0A", $0 }')"
  echo "::error title=${name} 실패 (exit ${code})::${msg}"
  exit "$code"
}
