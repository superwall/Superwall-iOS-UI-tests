#!/bin/bash
#
# Runs the UI test suite on Limrun (https://limrun.com), sharded across
# independent cloud Mac sandboxes and iOS simulators.
#
# Requirements:
#   npm install --global lim
#   export LIM_API_KEY=lim_...
#
# Usage:
#   scripts/limrun-test.sh [-s "UI Tests -swift -automatic"] [-n shards] [-t "0 5 12"] [-x 27]
#
#   -s  Scheme to run (default: "UI Tests -swift -automatic").
#   -n  Number of shards, each with its own sandbox and simulator (default: 8).
#   -t  Space-separated test numbers to run (default: every test).
#   -x  Xcode major version to build with (default: 27, matching local development).
#
# Each shard runs `lim xcode test` with its own fresh instances (an Xcode
# sandbox and a simulator), which clean themselves up after 5 minutes of
# inactivity; organizations have a concurrency limit, so a run started soon
# after another may need to wait for the previous run's instances to go.
# Results are written as NDJSON to limrun-results/ and summarised at the end.
# The exit code is non-zero if any test failed or any shard died before
# finishing.
#
# The suite asserts on screen descriptions (SWK_ASSERT_MODE=screen, the
# default), so it doesn't depend on Limrun's device model or iOS runtime.
# Pixel references only match an iPhone 14 Pro on iOS 16.4 and aren't
# bundled for remote runs.
#
# StoreKit's local test environment isn't available to apps that XCUITest
# launches under `lim xcode test` (storekitd reports the app "is not using
# StoreKit Testing in Xcode" and asks Apple's sandbox), so tests that need
# products or purchases are skipped on Limrun (KnownIssue.skipReason in the
# runner). Skipped tests don't appear in Limrun's results; the summary counts
# them. The rest of the suite runs as locally.

set -euo pipefail

cd "$(dirname "$0")/.."

scheme="UI Tests -swift -automatic"
shards=8
tests=""
xcode_version=27

while getopts "s:n:t:x:" option; do
  case "$option" in
    s) scheme="$OPTARG" ;;
    n) shards="$OPTARG" ;;
    t) tests="$OPTARG" ;;
    x) xcode_version="$OPTARG" ;;
    *) sed -n '2,20p' "$0"; exit 2 ;;
  esac
done

if ! command -v lim >/dev/null; then
  echo "The Limrun CLI isn't installed: npm install --global lim" >&2
  exit 2
fi
if [ -z "${LIM_API_KEY:-}" ]; then
  echo "Set LIM_API_KEY (see https://docs.limrun.com/docs/agents/cli)." >&2
  exit 2
fi

if [ -z "$tests" ]; then
  # Same rule as the "Autogenerate functions" build phase: every number up to
  # the highest `func testN` in the Swift tests.
  highest=$(grep -oE '^\s*func test[0-9]+\(' "UI Tests/UI Tests/UITests_Swift.swift" | grep -oE '[0-9]+' | sort -n | tail -1)
  tests=$(seq 0 "$highest" | tr '\n' ' ')
fi

results="limrun-results"
rm -rf "$results"
mkdir -p "$results"

# Local run output and the PNG references (pixel mode is local-only) aren't
# needed remotely and would dominate the upload.
sync_ignores=(
  --ignore '^test-results(/|$)'
  --ignore '^limrun-results(/|$)'
  --ignore '^\.git(/|$)'
  --ignore '^Automated UI Testing/__Snapshots__/.*\.png$'
)

# Round-robin so each shard gets a mix of fast and slow tests.
declare -a shard_args
index=0
for number in $tests; do
  shard=$((index % shards))
  shard_args[$shard]+="--only-testing|Automated UI Testing/Automated_UI_Testing_test${number}|"
  index=$((index + 1))
done

echo "Running $(echo "$tests" | wc -w | tr -d ' ') tests of \"$scheme\" across $shards Limrun shards..."

pids=()
for shard in $(seq 0 $((shards - 1))); do
  [ -n "${shard_args[$shard]:-}" ] || continue
  IFS='|' read -r -a selection <<< "${shard_args[$shard]%|}"
  (
    lim xcode test . \
      --scheme "$scheme" \
      --xcode-version "$xcode_version" \
      --inactivity-timeout 5m \
      --json \
      "${sync_ignores[@]}" \
      "${selection[@]}" \
      > "$results/shard-$shard.ndjson" 2> "$results/shard-$shard.log"
  ) &
  pids+=($!)
done

for pid in "${pids[@]}"; do
  wait "$pid" || true
done

# UI tests on shared cloud machines have occasional timing flakes (a slow page
# load, StoreKit being slow to answer). Give each failed test one more try on
# a fresh instance; a test only fails the run if it fails both times.
# Limrun's NDJSON events don't have a fixed key order, so parse them as JSON.
# `results.py failed FILES...` prints the numbers of tests whose last result
# failed; `results.py summary FILES...` prints the summary and exits non-zero
# if anything failed or a shard didn't finish.
results_py() {
  python3 - "$@" <<'PY'
import json, re, sys
mode, files = sys.argv[1], sys.argv[2:]
last, unfinished = {}, []
for path in files:
    finished = False
    try:
        lines = open(path).read().splitlines()
    except FileNotFoundError:
        continue
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("planFinished"):
            finished = True
        if event.get("type") != "case":
            continue
        name = event.get("method") or event.get("testClass") or ""
        match = re.search(r"test(\d+)$", name)
        if match:
            # Files are read in order, so a retry overrides the first attempt.
            last[int(match.group(1))] = event
    if not finished:
        unfinished.append(path)
failed = sorted(n for n, e in last.items() if not e.get("passed"))
if mode == "failed":
    print(" ".join(map(str, failed)))
    sys.exit(0)
for n in failed:
    message = (last[n].get("failureMessage") or "").replace("\n", " ")
    print(f"FAIL test{n}: {message[:250]}")
for path in unfinished:
    print(f"{path} did not finish; see {path[:-len('.ndjson')]}.log")
passed = len(last) - len(failed)
requested = int(__import__("os").environ.get("REQUESTED_TESTS", "0"))
skipped = max(requested - len(last), 0)
print(f"\n{passed} passed, {len(failed)} failed, {skipped} skipped, {len(unfinished)} incomplete shard(s). Raw results: limrun-results/")
if skipped:
    print("Skipped tests don't appear in Limrun's results; they need something Limrun doesn't provide (see KnownIssue.skipReason).")
sys.exit(1 if failed or unfinished else 0)
PY
}

failed_tests=$(results_py failed "$results"/shard-*.ndjson)
if [ -n "$failed_tests" ] && [ "${NO_RETRY:-0}" != "1" ]; then
  echo "Retrying failed tests once: $failed_tests"
  retry_args=()
  for number in $failed_tests; do
    retry_args+=(--only-testing "Automated UI Testing/Automated_UI_Testing_test${number}")
  done
  lim xcode test . \
    --scheme "$scheme" \
    --xcode-version "$xcode_version" \
    --inactivity-timeout 5m \
    --json \
    "${sync_ignores[@]}" \
    "${retry_args[@]}" \
    > "$results/retry.ndjson" 2> "$results/retry.log" || true
fi

# Summarise: each test's last result counts (the retry's, if it was retried).
echo
REQUESTED_TESTS=$(echo "$tests" | wc -w | tr -d ' ') results_py summary "$results"/shard-*.ndjson "$results"/retry.ndjson
