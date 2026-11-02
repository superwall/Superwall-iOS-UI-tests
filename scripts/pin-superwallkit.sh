#!/bin/bash
#
# Points the project's SuperwallKit package at one commit instead of the
# `develop` branch, so a run tests exactly that commit (the SDK's release
# workflow uses this to test the commit it's about to release).
#
# Usage:
#   scripts/pin-superwallkit.sh <commit SHA> [repository URL]
#
# Only the working copy changes; don't commit the result. Package.resolved
# isn't tracked, so Xcode (locally or on Limrun) resolves the pinned commit.

set -euo pipefail

cd "$(dirname "$0")/.."

revision="${1:?Usage: scripts/pin-superwallkit.sh <commit SHA> [repository URL]}"
url="${2:-}"
project="UI Tests.xcodeproj/project.pbxproj"

if ! [[ "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Expected a full 40-character commit SHA, got '$revision'." >&2
  exit 2
fi

python3 - "$project" "$revision" "$url" <<'PY'
import re, sys
path, revision, url = sys.argv[1:4]
text = open(path).read()
pattern = re.compile(
    r'(/\* XCRemoteSwiftPackageReference "SuperwallKit-iOS" \*/ = \{\s*'
    r'isa = XCRemoteSwiftPackageReference;\s*'
    r'repositoryURL = ")([^"]*)(";\s*requirement = \{)(.*?)(\};)',
    re.S,
)
match = pattern.search(text)
if not match:
    sys.exit("Couldn't find the SuperwallKit package reference in " + path)
indent = "\n\t\t\t\t"
requirement = f"{indent}kind = revision;{indent}revision = {revision};\n\t\t\t"
text = (
    text[:match.start()]
    + match.group(1) + (url or match.group(2)) + match.group(3) + requirement + match.group(5)
    + text[match.end():]
)
open(path, "w").write(text)
PY

# A resolved file from an earlier run would keep the old commit.
rm -f "UI Tests.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

echo "SuperwallKit pinned to $revision"
