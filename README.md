# Superwall iOS UI Tests

179 numbered tests, each run under four schemes: Swift and Objective-C, in
automatic and advanced configuration. That is a few hundred cases and several
hours end to end on one machine, so day to day you run a slice of it.

### Run some tests

```bash
# One scheme, every test
scripts/run-tests.py run --scheme "UI Tests -swift -automatic"

# A tenth of them, for a quick check
scripts/run-tests.py run --scheme "UI Tests -swift -automatic" --shard 0/10

# Everything, one scheme after another
./runTests.sh
```

`DESTINATION` picks the simulator; it defaults to an iPhone 17 Pro on the
newest runtime you have installed. Snapshots are recorded against that, so a
different device or a different iOS major will fail on image comparison.

In Xcode, option-click the run button and turn off parallel execution, then
run the schemes one at a time.

### Run them on a remote Mac

CI runs the suite on [Limrun](https://limrun.com) from Linux, which is what
lets the shards go wide. The same command works from your machine once `lim`
is installed and `LIM_API_KEY` is set:

```bash
scripts/run-tests.py run --runner lim --scheme "UI Tests -swift -automatic" --shard 0/10
```

Each shard takes one Xcode sandbox and one simulator. The org is capped on how
many instances it may hold at once, so CI runs ten shards at a time.

### Which SDK gets tested

The project tracks SuperwallKit's `develop`. CI pins the commit that triggered
the run instead:

```bash
scripts/pin-sdk.py --commit <sha>   # test one commit
scripts/pin-sdk.py --branch develop # back to tracking the branch
```

### Adding a test

Add `testN` to `UITests_Swift.swift` and its Objective-C twin. A build phase
regenerates `Testable.swift` and `Tests.swift` from the highest test number it
finds, so the class the runner needs appears on the next build.
