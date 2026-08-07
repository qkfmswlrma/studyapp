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
  if "$@" >"$log" 2>&1; then
    cat "$log"
    echo "::endgroup::"
    return 0
  fi

  local code=$?
  cat "$log"
  echo "::endgroup::"

  # 줄바꿈은 %0A 로, 퍼센트는 %25 로 바꿔야 한 줄짜리 주석에 담긴다
  local msg
  msg="$(tail -c 3500 "$log" \
    | sed -e 's/%/%25/g' -e $'s/\r//g' \
    | awk '{ printf "%s%%0A", $0 }')"
  echo "::error title=${name} 실패 (exit ${code})::${msg}"
  exit "$code"
}
