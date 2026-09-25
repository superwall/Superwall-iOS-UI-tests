#!/bin/bash
#
# Runs the UI test suite locally, sharded across dedicated simulators.
#
# Usage: ./runTests.sh [scheme...]
#   Default: all four schemes. Environment:
#     SHARDS=4            simulators to spread the tests across
#     TESTS="0 5 12"      only these test numbers
#     DEVICE="iPhone 18 Pro"  the remaining coordinate taps are written for a
#                             393x852 point screen and scaled for others
#     RUNTIME="iOS 27"    runtime prefix, as listed by `xcrun simctl list runtimes`
#   For splitting a run across machines (see .github/workflows/ui-tests.yml):
#     DERIVED_DATA=path   build products location (default: Xcode's DerivedData)
#     BUILD_ONLY=1        build every given scheme for testing, then stop
#     SKIP_BUILD=1        use products already in DERIVED_DATA
#     SHARD_INDEX=0 SHARD_COUNT=5  run only this machine's share of the tests
#
# Each shard is its own simulator ("UITests Shard N (<device>)") with its own xcodebuild,
# rather than xcodebuild's parallel-testing clones: clones live in a set
# shared by every xcodebuild on the Mac, so another test session's cleanup
# can take them down mid-run. This is the same shape as scripts/limrun-test.sh.
#
# A failed test gets one retry: UI tests have occasional timing flakes (slow
# page loads, StoreKit), and a real failure fails both attempts.
# Diagnostics collection on failure is off: it tries to sysdiagnose the
# simulator and times out after 10 minutes, holding up the whole shard.
# A test that hangs (XCUITest occasionally stalls launching the app) is
# stopped after 5 minutes rather than holding up its shard for good.

set -uo pipefail
cd "$(dirname "$0")"

shards="${SHARDS:-4}"
device="${DEVICE:-iPhone 18 Pro}"
runtime_prefix="${RUNTIME:-iOS 27}"
if [ "$#" -gt 0 ]; then
  schemes=("$@")
else
  schemes=("UI Tests -swift -automatic" "UI Tests -swift -advanced" "UI Tests -objc -automatic" "UI Tests -objc -advanced")
fi

runtime=$(xcrun simctl list runtimes | grep "^$runtime_prefix" | grep -v unavailable | tail -1 | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.[A-Za-z0-9-]+')
device_type=$(xcrun simctl list devicetypes | grep "^$device (" | grep -oE 'com\.apple\.CoreSimulator\.SimDeviceType\.[A-Za-z0-9-]+')
if [ -z "$runtime" ] || [ -z "$device_type" ]; then
  echo "Couldn't find runtime \"$runtime_prefix\" or device type \"$device\"." >&2
  exit 2
fi

# Create (or reuse) and boot one simulator per shard.
udids=()
for index in $(seq 1 "$shards"); do
  name="UITests Shard $index ($device)"
  udid=$(xcrun simctl list devices -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"].get(runtime, [])
print(next((d["udid"] for d in devices if d["name"] == name and d["isAvailable"]), ""))
' "$name" "$runtime")
  if [ -z "$udid" ]; then
    udid=$(xcrun simctl create "$name" "$device_type" "$runtime")
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  udids+=("$udid")
done
for udid in "${udids[@]}"; do
  xcrun simctl bootstatus "$udid" >/dev/null 2>&1
done

mkdir -p test-results
derived_data=()
[ -n "${DERIVED_DATA:-}" ] && derived_data=(-derivedDataPath "$DERIVED_DATA")
if [ "${SKIP_BUILD:-}" != "1" ]; then
  # Each scheme gets its own .xctestrun (the schemes differ only in their test
  # environment), so build every one; after the first, the build is a no-op.
  for scheme in "${schemes[@]}"; do
    echo "Building \"$scheme\"..."
    xcodebuild build-for-testing -scheme "$scheme" -destination "platform=iOS Simulator,id=${udids[0]}" ${derived_data[@]+"${derived_data[@]}"} \
      >> test-results/build.log 2>&1 || { echo "Build failed; see test-results/build.log"; exit 1; }
  done
fi
[ "${BUILD_ONLY:-}" = "1" ] && exit 0

if [ -n "${TESTS:-}" ]; then
  tests="$TESTS"
else
  highest=$(grep -oE '^\s*func test[0-9]+\(' "UI Tests/UI Tests/UITests_Swift.swift" | grep -oE '[0-9]+' | sort -n | tail -1)
  tests=$(seq 0 "$highest" | tr '\n' ' ')
fi
if [ -n "${SHARD_COUNT:-}" ]; then
  tests=$(echo $tests | tr ' ' '\n' | awk -v count="$SHARD_COUNT" -v index_="${SHARD_INDEX:-0}" '(NR - 1) % count == index_' | tr '\n' ' ')
fi

# Runs one shard. If the test runner fails to launch (it occasionally does on a
# loaded host), the simulator is rebooted and the shard run once more, rather
# than silently skipping its share of the tests.
run_shard() {
  local scheme="$1" udid="$2" output="$3"
  shift 3
  local attempt
  for attempt in 1 2; do
    rm -rf "$output.xcresult"
    xcodebuild test-without-building -scheme "$scheme" -destination "platform=iOS Simulator,id=$udid" \
      -parallel-testing-enabled NO -retry-tests-on-failure -test-iterations 2 -collect-test-diagnostics never \
      -test-timeouts-enabled YES -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 300 \
      -resultBundlePath "$output.xcresult" ${derived_data[@]+"${derived_data[@]}"} "$@" \
      > "$output.log" 2>&1
    local result=$?
    if [ "$attempt" -eq 1 ] && grep -q "Failed to install or launch the test runner" "$output.log"; then
      xcrun simctl shutdown "$udid" 2>/dev/null
      xcrun simctl boot "$udid" 2>/dev/null
      xcrun simctl bootstatus "$udid" >/dev/null 2>&1
      continue
    fi
    return $result
  done
}

status=0
for scheme in "${schemes[@]}"; do
  echo "Running \"$scheme\" across $shards simulators..."
  slug=$(echo "$scheme" | tr ' ' '_')
  pids=()
  for shard in $(seq 0 $((shards - 1))); do
    selection=()
    index=0
    for number in $tests; do
      if [ $((index % shards)) -eq "$shard" ]; then
        selection+=(-only-testing:"Automated UI Testing/Automated_UI_Testing_test$number")
      fi
      index=$((index + 1))
    done
    [ "${#selection[@]}" -gt 0 ] || continue
    run_shard "$scheme" "${udids[$shard]}" "test-results/$slug-shard$((shard + 1))" "${selection[@]}" &
    pids+=($!)
  done

  scheme_status=0
  for pid in "${pids[@]}"; do
    wait "$pid" || scheme_status=1
  done
  summary=$(cat test-results/"$slug"-shard*.log | grep -oE "Test Case '.*' (passed|failed|skipped)" | awk '{print $NF}' | sort | uniq -c | tr '\n' ' ')
  if [ "$scheme_status" -eq 0 ]; then
    echo "PASSED: $scheme (attempts: $summary)"
  else
    echo "FAILED: $scheme (attempts: $summary); see test-results/$slug-shard*.log"
    status=1
  fi
done
exit $status
