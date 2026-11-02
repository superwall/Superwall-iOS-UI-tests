# Contributing

How to add or change tests, and what to check before opening a pull request. See the
[README](README.md) for running the suite.

## Adding a test

1. Add the next numbered function to `UI Tests/UI Tests/UITests_Swift.swift`:

   ```swift
   /// What the test checks, in one sentence.
   func test179() async throws {
     Superwall.shared.register(placement: "present_always_v4")

     await assert(after: Constants.paywallPresentationDelay)
   }
   ```

2. Add the same scenario to `UI Tests/UI Tests/UITests_ObjC.m` (`test179WithCompletionHandler:`), so it
   runs in the Objective-C schemes too. If it can't be written in Objective-C, skip it there with
   `TEST_SKIP(@"reason")`.
3. If the test needs a different API key, a purchased product at launch or other SDK options, add
   `testOptions179()` returning a `TestOptions` (`testOptions179` in Objective-C).
4. Build. The "Autogenerate functions" phase adds the test to `Testable.swift` and `Tests.swift`.
5. Run it in all four schemes and record its references (below).

Tests are numbered in order and the generator expects every number up to the highest, so don't leave
gaps. To retire a test, keep the function and call `skip("reason")` (`TEST_SKIP` in Objective-C) instead of
deleting it.

### Writing the scenario

- **Taps:** use accessibility labels where you can: `await tap("Purchase Primary")` for paywall
  content and alerts, `await tapSystemElement("Subscribe")` for the StoreKit purchase sheet, and
  `await tapAlertButton(at: 0)` for the nth button of an alert or action sheet. Coordinate taps
  (`touch(CGPoint)`) are written for a 393x852 screen and scaled for others; use them only for
  elements without a label.
- **Assertions:** `await assert(after: delay)` checks the screen. Use the delay the scenario really
  needs (`Constants.paywallPresentationDelay`, …). The wait ends early when the screen settles, and
  runs in full when nothing changes, so "nothing should appear" checks keep their strength.
- **Values:** `await assert(value:)` compares a string (an event, a delegate call) with a stored
  reference.
- **Subscribed users:** `await configuration.mockSubscribedUser(productIdentifier:)` buys the product
  and waits for the SDK to see it.
- **State:** the app wipes its own persisted state on every launch, so tests don't depend on each
  other.

## References

### Screen references

Each `assert(after:)` is compared with `Automated UI Testing/__Snapshots__/Screens/Test-N.K.json`
(test N, Kth assertion). A missing reference is recorded on the first run, and the test fails once so
you look at it.

To re-record a test's references after an intended change:

```bash
TEST_RUNNER_SWK_RECORD_SCREENS=1 TESTS="179" ./runTests.sh "UI Tests -swift -automatic"
```

Then read the JSON diff. Check prices, product names and which paywall is shown, not only that the
file changed. If pixel references exist for the test, compare against them with
`swift scripts/compare-screen-references.swift`.

Record locally. Limrun runs read references from the test bundle and can't write them back.

### Recorded network responses

API responses and paywall pages are replayed from `Fixtures/`. After changing a test's paywall or
campaign on the dashboard, record them again:

```bash
TEST_RUNNER_SWK_FIXTURES=record TESTS="179" ./runTests.sh "UI Tests -swift -automatic"
```

Then re-record the screen references, since the paywall changed. `TEST_RUNNER_SWK_FIXTURES=off` goes
to the network for a run. `TEST_RUNNER_SWK_FIXTURES_LOG=<path>` logs every request that wasn't
answered from `Fixtures/`.

## Known SDK issues

If a test fails because of SDK behaviour, not the test, add it to `KnownIssue` in
`Automated UI Testing/Automated_UI_Testing.swift` with:

- the tests and the configurations and languages affected,
- a reason that says what the SDK does wrong,
- a link to the SDK issue that will fix it.

Failures in those tests are then recorded as expected and don't turn the run red. Remove the entry
once the fix ships. Don't use this for a test that's simply flaky; fix the test.

## Before opening a pull request

- The tests you touched pass in all four schemes locally.
- They pass on Limrun: `scripts/limrun-test.sh -t "179"` (repeat with `-s` for the other schemes).
  SuperwallKit releases run there, so a test that only passes locally will block a release.
- New or changed references are committed, and you've read their diffs.
- Don't commit `scripts/pin-superwallkit.sh` changes to the project file, or a `Package.resolved`.
- If the change affects how the suite runs, update the [README](README.md) and `CLAUDE.md`.
