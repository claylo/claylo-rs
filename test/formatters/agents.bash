#!/usr/bin/env bash
# Minimal bats formatter for AI agent consumption.
# Only shows failures — passing tests are silent to minimize token usage.
#
# Writes per-test progress to a sidecar file so agents can check status
# without consuming stdout. File is named by test suite:
#   target/template-tests/.bats-progress-presets
#   target/template-tests/.bats-progress-conditional_files
#
# Check progress:  tail -5 target/template-tests/.bats-progress-*
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
_total=0
_progress_dir=""
_progress_file=""

_progress() {
  [[ -n "$_progress_file" ]] || return 0
  local status="$1" name="$2"
  printf "[%d/%d] %-4s  %s\n" "$(( _pass + _fail + _skip ))" "$_total" "$status" "$name" >> "$_progress_file"
}

bats_tap_stream_plan() {
  # $1 is the test count
  _total="$1"
}

bats_tap_stream_begin() {
  :
}

bats_tap_stream_ok() {
  (( ++_pass ))
  _progress "PASS" "$2"
}

bats_tap_stream_not_ok() {
  (( ++_fail ))
  _progress "FAIL" "$2"
  printf "  FAIL  %s\n" "$2"
}

bats_tap_stream_skipped() {
  (( ++_skip ))
  _progress "SKIP" "$2"
}

bats_tap_stream_comment() {
  # Only show comments that follow a failure (diagnostic output)
  if [[ "$2" == "not_ok" ]]; then
    printf "        # %s\n" "$1"
  fi
}

bats_tap_stream_suite() {
  # $1 is the test file path — derive progress filename from it
  local suite_name
  suite_name="$(basename "$1" .bats)"

  # Find project root (where target/ lives) by walking up from formatter
  if [[ -z "$_progress_dir" ]]; then
    _progress_dir="${BATS_CWD:-$PWD}/target/template-tests"
    mkdir -p "$_progress_dir"
  fi

  _progress_file="$_progress_dir/.bats-progress-${suite_name}"
  # Reset on each suite start
  : > "$_progress_file"
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
