#!/usr/bin/env bash
# Minimal bats formatter for AI agent consumption.
# Only shows failures — passing tests are silent to minimize token usage.
#
# Usage:
#   ./test/bats/bin/bats -F "$PWD/test/formatters/agents.bash" test/*.bats

set -e
trap '' INT

# shellcheck source=../bats/lib/bats-core/formatter.bash
source "$BATS_ROOT/$BATS_LIBDIR/bats-core/formatter.bash"

_pass=0
_fail=0
_skip=0

bats_tap_stream_plan() {
  :
}

bats_tap_stream_begin() {
  :
}

bats_tap_stream_ok() {
  (( ++_pass ))
  # Silent on success
}

bats_tap_stream_not_ok() {
  (( ++_fail ))
  printf "  FAIL  %s\n" "$2"
}

bats_tap_stream_skipped() {
  (( ++_skip ))
  # Silent on skip (mention in summary)
}

bats_tap_stream_comment() {
  # Only show comments that follow a failure (diagnostic output)
  if [[ "$2" == "not_ok" ]]; then
    printf "        # %s\n" "$1"
  fi
}

bats_tap_stream_suite() {
  :
}

bats_tap_stream_unknown() {
  :
}

bats_parse_internal_extended_tap

printf "%d passed" "$_pass"
(( _fail > 0 )) && printf ", %d failed" "$_fail"
(( _skip > 0 )) && printf ", %d skipped" "$_skip"
printf "\n"

# Exit non-zero if any test failed
(( _fail > 0 )) && exit 1
exit 0
