#!/bin/bash
#
# Runs the UI test suite on Limrun (https://limrun.com), sharded across
# independent cloud Mac sandboxes and iOS simulators.
#
# Requirements:
#   npm install --global lim
#   lim login   (or export LIM_API_KEY=lim_...)
#
# Usage:
#   scripts/limrun-test.sh [-s "UI Tests -swift -automatic"] [-n shards] [-t "0 5 12"] [-x 27] [-o 27] [-r dir]
#
#   -s  Scheme to run (default: "UI Tests -swift -automatic").
#   -n  Number of shards, each with its own sandbox and simulator (default: 20,
#       the organization's limit of 20 simulators and 20 sandboxes at once).
#   -t  Space-separated test numbers to run (default: every test).
#   -x  Xcode major version to build with (default: 27, matching local development).
#   -r  Results directory (default: limrun-results). Give each run its own when
#       running several schemes at once.
#   -o  iOS major version of the simulator runtime (default: 27, matching the
#       screen references). Without it Limrun picks its default runtime.
#
# Each shard gets its own fresh instances (an iOS simulator and an Xcode
# sandbox attached to it), set to en_GB, runs `lim xcode test` on them and
# deletes them. Organizations have a concurrency limit per instance type, so
# shards wait and retry when instances can't be created.
# Tests are split so every shard gets about the same total time, using each
# test's duration from previous runs (scripts/test-durations.json, updated at
# the end of every run). Failed tests get one retry, spread across shards too.
# Results are written as NDJSON to the results directory and summarised at the end.
# The exit code is non-zero if any test failed or any shard died before
# finishing.
#
# The suite asserts on screen descriptions (SWK_ASSERT_MODE=screen, the
# default), so it doesn't depend on Limrun's device model (an iPhone 16 Pro,
# the only iPhone Limrun offers). Pixel references only match an iPhone 14
# Pro on iOS 16.4 and aren't bundled for remote runs.

set -euo pipefail

cd "$(dirname "$0")/.."

scheme="UI Tests -swift -automatic"
shards=20
tests=""
xcode_version=27
os_version=27

results="limrun-results"
while getopts "s:n:t:x:o:r:" option; do
  case "$option" in
    s) scheme="$OPTARG" ;;
    n) shards="$OPTARG" ;;
    t) tests="$OPTARG" ;;
    x) xcode_version="$OPTARG" ;;
    o) os_version="$OPTARG" ;;
    r) results="$OPTARG" ;;
    *) sed -n '2,24p' "$0"; exit 2 ;;
  esac
done

if ! command -v lim >/dev/null; then
  echo "The Limrun CLI isn't installed: npm install --global lim" >&2
  exit 2
fi
# `lim login` or LIM_API_KEY. Checked up front so a missing login doesn't
# show up as every shard failing.
if ! lim xcode version list >/dev/null 2>&1; then
  echo "Not logged in to Limrun: run \`lim login\` or set LIM_API_KEY." >&2
  exit 2
fi

if [ -z "$tests" ]; then
  # Same rule as the "Autogenerate functions" build phase: every number up to
  # the highest `func testN` in the Swift tests.
  highest=$(grep -oE '^\s*func test[0-9]+\(' "UI Tests/UI Tests/UITests_Swift.swift" | grep -oE '[0-9]+' | sort -n | tail -1)
  tests=$(seq 0 "$highest" | tr '\n' ' ')
fi

rm -rf "$results"
mkdir -p "$results"

# Local run output and the PNG references (pixel mode is local-only) aren't
# needed remotely and would dominate the upload.
sync_ignores=(
  --ignore '^test-results(/|$)'
  --ignore '^limrun-results(/|$)'
  --ignore "^$(printf '%s' "${results#./}" | sed 's/[][\.^$*+?(){}|]/\\&/g')(/|\$)"
  --ignore '^\.git(/|$)'
  --ignore '^Automated UI Testing/__Snapshots__/.*\.png$'
)

durations="scripts/test-durations.json"

# Prints one line of test numbers per shard, balancing each shard's total
# expected time: longest test first, each to the shard with the least work so
# far. Tests without a recorded duration count as the median.
plan_shards() {
  python3 - "$durations" "$scheme" "$1" "$2" <<'PY'
import json, statistics, sys
path, scheme, count, tests = sys.argv[1], sys.argv[2], int(sys.argv[3]), [int(t) for t in sys.argv[4].split()]
try:
    known = json.load(open(path))
except (OSError, ValueError):
    known = {}
own = known.get(scheme, {})
# Another scheme's timing is a better guess than none: they run the same scenarios.
merged = {k: v for other in known.values() for k, v in other.items()}
merged.update(own)
default = statistics.median(merged.values()) if merged else 30
cost = lambda t: merged.get(str(t), default)
shards = [[0.0, []] for _ in range(max(1, min(count, len(tests))))]
for test in sorted(tests, key=cost, reverse=True):
    shard = min(shards, key=lambda s: s[0])
    shard[0] += cost(test)
    shard[1].append(test)
for total, numbers in shards:
    print(" ".join(map(str, sorted(numbers))))
PY
}

# Prints the ID from `lim ... create --json` output on stdin.
instance_id() {
  python3 -c 'import json, sys; print(json.load(sys.stdin)["metadata"]["id"])'
}

# Runs one shard: its own simulator and Xcode sandbox, created here rather
# than by `lim xcode test` so the simulator can be prepared first, and so
# parallel shards each name their instance (`lim` otherwise resolves "the
# latest instance" per repository, and shards collide with "409 workspace
# sync is still in progress").
#
# Limrun's simulators take their region from the host (e.g. en_US@rg=nlzzzz),
# and storekitd reads the prices in Products.storekit with that locale: in a
# comma-decimal region $4.99 becomes $4.00. The references were recorded in
# en_GB, as runTests.sh sets locally, so the simulator is set to en_GB too.
run_shard() {
  local name="$1"
  shift
  local ios="" xcode="" attempt
  for attempt in 1 2 3 4 5; do
    ios=$(lim ios create --model iphone --os-version "$os_version" \
      --inactivity-timeout "$idle_timeout" --no-open --json --label "shard=$name" | instance_id) && break
    ios=""
    sleep $((attempt * 20))
  done
  [ -n "$ios" ] || { echo "Couldn't create a simulator for $name" >&2; return 1; }
  for attempt in 1 2 3 4 5; do
    xcode=$(lim xcode create --attach --simulator-id "$ios" \
      --inactivity-timeout "$idle_timeout" --json --label "shard=$name" | instance_id) && break
    xcode=""
    sleep $((attempt * 20))
  done
  if [ -z "$xcode" ]; then
    echo "Couldn't create an Xcode sandbox for $name" >&2
    lim ios delete "$ios" >/dev/null 2>&1 || true
    return 1
  fi
  echo "$name: simulator $ios, sandbox $xcode" >&2
  echo "$ios $xcode" >> "$instances"

  lim ios simctl --id "$ios" -- spawn booted defaults write -g AppleLocale -string "${LOCALE:-en_GB}" >&2
  lim ios simctl --id "$ios" -- spawn booted defaults write -g AppleLanguages -array "${LANGUAGE:-en-GB}" >&2

  local status=0
  lim xcode test . \
    --id "$xcode" \
    --scheme "$scheme" \
    --xcode-version "$xcode_version" \
    --json \
    "${sync_ignores[@]}" \
    "$@" || status=$?

  # Free the organization's instance quota now rather than after the
  # inactivity timeout, so retries and the next run don't wait.
  lim xcode delete "$xcode" >/dev/null 2>&1 || true
  lim ios delete "$ios" >/dev/null 2>&1 || true
  return $status
}

# Instances are deleted when their shard ends, and on exit or Ctrl-C if the
# script stops early. The inactivity timeout is only a backstop for a script
# that's killed outright: it has to outlast a shard, because traffic from the
# sandbox to the simulator during a test run doesn't count as activity (a 5m
# timeout cut shards off mid-run).
idle_timeout=30m
instances="$results/instances.txt"
: > "$instances"
cleanup() {
  trap - EXIT INT TERM
  local ios xcode
  jobs -p | xargs kill 2>/dev/null || true
  while read -r ios xcode; do
    lim xcode delete "$xcode" >/dev/null 2>&1 &
    lim ios delete "$ios" >/dev/null 2>&1 &
  done < "$instances"
  wait 2>/dev/null || true
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# Runs one shard per line of test numbers on stdin, in parallel, writing
# <prefix>-<index>.ndjson/.log into the results directory.
run_shards() {
  local prefix="$1" index=0 pids=() numbers selection number
  while read -r numbers; do
    [ -n "$numbers" ] || continue
    selection=()
    for number in $numbers; do
      selection+=(--only-testing "Automated UI Testing/Automated_UI_Testing_test${number}")
    done
    echo "$numbers" > "$results/$prefix-$index.tests"
    run_shard "$prefix-$index" "${selection[@]}" \
      > "$results/$prefix-$index.ndjson" 2> "$results/$prefix-$index.log" &
    pids+=($!)
    index=$((index + 1))
    # Instance creation is the busy part; don't start every shard at once.
    sleep 3
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done
}

echo "Running $(echo "$tests" | wc -w | tr -d ' ') tests of \"$scheme\" across $shards Limrun shards..."
plan_shards "$shards" "$tests" | run_shards shard

# UI tests on shared cloud machines have occasional timing flakes (a slow page
# load, StoreKit being slow to answer). Give each failed test one more try on
# a fresh instance; a test only fails the run if it fails both times.
# Limrun's NDJSON events don't have a fixed key order, so parse them as JSON.
# `results.py failed FILES...` prints the numbers of tests whose last result
# failed or never ran (their shard stopped early); `results.py summary
# FILES...` prints the summary and exits non-zero if any test failed or never
# ran. Skipped tests (XCTSkip) and tests whose only failures were expected
# (XCTExpectFailure, a known SDK issue showing up) leave no trace in
# Limrun's results, so a test without a result counts as one of those if its
# shard's plan finished (each shard's tests are listed in <shard>.tests) and
# as never run otherwise.
results_py() {
  python3 - "$@" <<'PY'
import json, re, sys
mode, files = sys.argv[1], sys.argv[2:]
last, unfinished, skipped = {}, [], set()
for path in files:
    finished = False
    seen = set()
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
            seen.add(int(match.group(1)))
    if finished:
        try:
            given = open(path[:-len(".ndjson")] + ".tests").read().split()
        except FileNotFoundError:
            given = []
        skipped |= {int(t) for t in given} - seen
    if not finished:
        unfinished.append(path)
failed = sorted(n for n, e in last.items() if not e.get("passed"))
requested = [int(t) for t in __import__("os").environ.get("REQUESTED_TESTS", "").split()]
skipped -= set(last)
missing = sorted(set(requested) - set(last) - skipped)
if mode == "failed":
    print(" ".join(map(str, sorted(set(failed) | set(missing)))))
    sys.exit(0)
if mode == "unrun":
    print(" ".join(map(str, missing)))
    sys.exit(0)
for n in failed:
    message = (last[n].get("failureMessage") or "").replace("\n", " ")
    print(f"FAIL test{n}: {message[:250]}")
for path in unfinished:
    print(f"{path} did not finish; see {path[:-len('.ndjson')]}.log")
passed = len(last) - len(failed)
results_dir = __import__("os").path.dirname(files[0]) if files else "."
if skipped:
    print("Skipped, or failed only as a known issue (Limrun reports neither): " + " ".join(f"test{n}" for n in sorted(skipped)))
if missing:
    print("Never ran (shard stopped early, even on retry): " + " ".join(f"test{n}" for n in missing))
print(f"\n{passed} passed, {len(failed)} failed, {len(skipped)} skipped or known issues, {len(missing)} never ran. Raw results: {results_dir}/")
# A shard that stopped early only matters if its tests got no result from the retry either.
sys.exit(1 if failed or missing else 0)
PY
}

export REQUESTED_TESTS="$tests"
failed_tests=$(results_py failed "$results"/shard-*.ndjson)
if [ -n "$failed_tests" ] && [ "${NO_RETRY:-0}" != "1" ]; then
  echo "Retrying failed or unrun tests once: $failed_tests"
  plan_shards "$shards" "$failed_tests" | run_shards retry

  # A test whose first shard died before running it has only had one attempt
  # (the retry), so it gets one more if that failed.
  unrun_first=$(results_py unrun "$results"/shard-*.ndjson)
  still_failing=$(results_py failed "$results"/shard-*.ndjson "$results"/retry-*.ndjson "$results"/retry2-*.ndjson)
  second=$(comm -12 <(tr ' ' '\n' <<< "$unrun_first" | sort) <(tr ' ' '\n' <<< "$still_failing" | sort) | grep . | sort -n | tr '\n' ' ' || true)
  if [ -n "${second// /}" ]; then
    echo "Retrying again (their first shard never ran them): $second"
    plan_shards "$shards" "$second" | run_shards retry2
  fi
fi

# Record how long each test took, for the next run's split. A test's last
# attempt counts, so a test that now fails keeps its (long) failing time.
python3 - "$durations" "$scheme" "$results" <<'PY'
import glob, json, re, sys
path, scheme, results = sys.argv[1:4]
try:
    known = json.load(open(path))
except (OSError, ValueError):
    known = {}
own = known.setdefault(scheme, {})
for file in sorted(glob.glob(f"{results}/shard-*.ndjson")) + sorted(glob.glob(f"{results}/retry-*.ndjson")) + sorted(glob.glob(f"{results}/retry2-*.ndjson")):
    for line in open(file):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        match = re.search(r"test(\d+)$", event.get("method") or event.get("testClass") or "")
        if event.get("type") == "case" and match and event.get("durationMs"):
            own[match.group(1)] = round(event["durationMs"] / 1000, 1)
known[scheme] = dict(sorted(own.items(), key=lambda item: int(item[0])))
with open(path, "w") as f:
    json.dump(dict(sorted(known.items())), f, indent=2)
    f.write("\n")
PY

# Summarise: each test's last result counts (the retry's, if it was retried).
echo
results_py summary "$results"/shard-*.ndjson "$results"/retry-*.ndjson "$results"/retry2-*.ndjson
