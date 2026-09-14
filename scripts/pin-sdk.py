#!/usr/bin/env python3
"""Point the project's SuperwallKit dependency at one commit, or back at a branch.

The project tracks `develop` by default, which means a test run picks up
whatever that branch holds at the moment it resolves rather than the commit
that asked for the run. CI pins the commit it was handed before building.
"""

import argparse
import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent / "UI Tests.xcodeproj" / "project.pbxproj"
PACKAGE = "SuperwallKit-iOS"

# The package reference block, captured so we can swap only its requirement.
BLOCK = re.compile(
  r'(/\* XCRemoteSwiftPackageReference "' + PACKAGE + r'" \*/ = \{.*?'
  r'requirement = \{)(.*?)(\};)',
  re.DOTALL,
)


def rewrite(requirement: str) -> None:
  if not PROJECT.exists():
    sys.exit(f"No project file at {PROJECT}")

  text = PROJECT.read_text(encoding="utf-8")
  new_text, count = BLOCK.subn(lambda m: m.group(1) + requirement + m.group(3), text)

  if count != 1:
    sys.exit(f"Expected one {PACKAGE} package reference, found {count}")
  if new_text == text:
    print(f"{PACKAGE} already set to the requested version")
    return

  PROJECT.write_text(new_text, encoding="utf-8")
  print(f"{PACKAGE} now resolves to{requirement.rstrip()}")


def main() -> None:
  parser = argparse.ArgumentParser(description=__doc__)
  group = parser.add_mutually_exclusive_group(required=True)
  group.add_argument("--commit", help="Full or short commit SHA to pin to")
  group.add_argument("--branch", help="Branch to track instead of a fixed commit")
  args = parser.parse_args()

  if args.commit:
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", args.commit):
      sys.exit(f"Not a commit SHA: {args.commit}")
    rewrite(f"\n\t\t\t\tkind = revision;\n\t\t\t\trevision = {args.commit};\n\t\t\t")
  else:
    rewrite(f"\n\t\t\t\tbranch = {args.branch};\n\t\t\t\tkind = branch;\n\t\t\t")


if __name__ == "__main__":
  main()
