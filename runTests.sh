#!/bin/bash
#
# Run the whole suite on this Mac, one scheme after another.
#
# For a single scheme, a subset, or a run on a remote Mac, use the runner
# directly:
#
#   scripts/run-tests.py run --scheme "UI Tests -swift -automatic" --shard 0/10
#   scripts/run-tests.py plan --shards 10
#
# Set DESTINATION to pick a different simulator.

set -o pipefail

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

declare -a schemes=(
  "UI Tests -swift -automatic"
  "UI Tests -swift -advanced"
  "UI Tests -objc -automatic"
  "UI Tests -objc -advanced"
)

status=0

for scheme in "${schemes[@]}"; do
  echo "Running tests for scheme: $scheme"
  "${SCRIPT_DIR}/scripts/run-tests.py" run \
    --scheme "$scheme" \
    --destination "$DESTINATION" || status=1
done

exit $status
