# Superwall iOS UI Tests

End-to-end UI tests for [SuperwallKit](https://github.com/superwall/Superwall-iOS). The app in this
repo configures the SDK, runs one scenario per test (register a placement, purchase, restore, dismiss,
…) and reports back to an XCUITest runner, which checks what ends up on screen.

The tests are numbered (`test0`, `test1`, …), and each runs in four schemes:

| Scheme | Language | Purchases handled by |
|---|---|---|
| `UI Tests -swift -automatic` | Swift | the SDK |
| `UI Tests -swift -advanced` | Swift | a purchase controller in the app |
| `UI Tests -objc -automatic` | Objective-C | the SDK |
| `UI Tests -objc -advanced` | Objective-C | a purchase controller in the app |

SuperwallKit releases are gated on all four schemes passing on [Limrun](https://limrun.com), against the
exact commit being released.

## Requirements

- macOS 27 and Xcode 27.
- The iOS 27 simulator runtime. Tests run on an iPhone 18 Pro locally; Limrun's simulators are
  iPhone 16 Pros.
- For Limrun: Node, `npm install --global lim`, and `lim login` (or `LIM_API_KEY`).

## Running the tests

### Locally

```bash
./runTests.sh                                 # all four schemes
./runTests.sh "UI Tests -swift -automatic"    # one scheme
TESTS="0 5 12" ./runTests.sh "UI Tests -swift -automatic"   # only these tests
```

`runTests.sh` creates one simulator per shard (`SHARDS`, default 4), sets them to en_GB and runs each
shard with its own `xcodebuild`. A failed test gets one retry. Results go to `test-results/`.

Other options: `DEVICE` and `RUNTIME` pick the simulator, `LOCALE` / `LANGUAGE` its region (the
references are en_GB). See the top of `runTests.sh`.

You can also run a scheme from Xcode, with parallel testing turned off.

### On Limrun

```bash
scripts/limrun-test.sh                                    # Swift automatic, every test, 20 shards
scripts/limrun-test.sh -s "UI Tests -objc -advanced"      # another scheme
scripts/limrun-test.sh -t "4 60 103"                      # a few tests
scripts/limrun-test.sh -f                                 # stop at the first test that fails twice
```

Each shard creates its own iOS 27 simulator and Xcode 27 sandbox, sets the simulator to en_GB, runs its
tests with `lim xcode test`, and deletes both instances. Tests are split by their recorded durations
(`scripts/test-durations.json`, updated after every run). Failed tests, and tests whose shard died
before running them, are retried. Results are written as NDJSON to `limrun-results/` and summarised at
the end.

Options: `-n` shards (default 20, the organization's limit per instance type), `-x` / `-o` the Xcode
and iOS versions (default 27), `-r` the results directory (give each run its own when running schemes
at the same time), `-f` (or `FAIL_FAST=1`) to stop early.

With `-f`, a failed test is retried straight away on a fresh instance instead of at the end. If it fails
again, every shard is stopped, its instances are deleted and the run fails, so you only see that
failure. SuperwallKit's release workflow uses it. Leave it off to get the full list of failures.

Limrun leaves skipped tests and known issues (below) out of its results, so the summary lists them as
"skipped or known issues".

### Testing a particular SDK commit

The project tracks SuperwallKit's `develop` branch. To test a specific commit instead:

```bash
scripts/pin-superwallkit.sh <full commit SHA>
```

This changes the project file only in your working copy; don't commit it. The SDK's release workflow
uses it to test the commit it's about to release.

## How it works

- **Runner and app.** `Automated UI Testing` (XCUITest) launches the app and tells it which test to run.
  The app runs the scenario from `UITests_Swift.swift` or `UITests_ObjC.m` and asks the runner over
  HTTP for anything that needs XCUITest: taps, assertions, StoreKit actions. `Communicator.swift`
  handles both sides. Ports come from the simulator's UDID, so several runs can share a Mac.
- **Assertions.** `assert(after:)` waits until the screen settles, then compares a JSON description of
  it (paywall identifier, loading state, visible text, alerts) with
  `Automated UI Testing/__Snapshots__/Screens/Test-N.K.json`. These references don't depend on the
  device, so they work on Limrun as well as locally.
- **Recorded network responses.** Superwall API responses and paywall pages are replayed from
  `Fixtures/`, so tests don't depend on the dev backend or dashboard changes. Anything not recorded
  goes to the network.
- **StoreKit.** Products and purchases come from `Products.storekit` through StoreKit testing.
- **Generated code.** The "Autogenerate functions" build phase generates `Testable.swift` and
  `Tests.swift` (one test class per test number) from the test functions. Don't edit them by hand.

## Known issues

Tests that fail because of an SDK bug (not the test) are listed in `KnownIssue` in
`Automated UI Testing/Automated_UI_Testing.swift`. Their failures are recorded as expected, so the run
stays green and the reason appears in the results. At the moment:

- **9 and 99:** a "present always" paywall shown to a subscribed user is sometimes closed straight
  away.
- **134 and 169** (advanced): `restorePurchases()` called from code with a purchase controller doesn't
  send `restoreStart`.

Remove an entry once the SDK is fixed.

## Troubleshooting

- **A screen doesn't match its reference.** The failure shows a diff. If the paywall or campaign
  changed on the dashboard on purpose, re-record its fixtures and references (see
  [CONTRIBUTING.md](CONTRIBUTING.md)).
- **Prices like `$4.00` instead of `$4.99`.** The simulator's region uses a decimal comma, and
  StoreKit reads `Products.storekit` with it. `runTests.sh` and `limrun-test.sh` set en_GB; check the
  simulator if you run tests another way.
- **No products, or purchases that never happen.** StoreKit testing only applies to an app that has
  been launched on that simulator before. The runner does this once per run; a fresh simulator used
  outside the runner may need a launch first.
- **SDK logs.** Set `TEST_RUNNER_SWK_SDK_DEBUG=1` for a run to turn on SuperwallKit's debug logging.

See [CONTRIBUTING.md](CONTRIBUTING.md) for adding tests and re-recording references.
