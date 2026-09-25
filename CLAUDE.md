# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive iOS UI testing framework for the Superwall SDK. The project contains both an iOS app and automated UI tests that validate the SDK's functionality across different configurations and scenarios.

## Key Components

### Main App Structure
- **UI Tests.app**: Main iOS application target that integrates SuperwallKit
- **Automated UI Testing.xctest**: XCTest bundle containing automated UI tests
- **RootViewController**: Main controller that orchestrates test execution via the `Testable` protocol
- **Communicator**: HTTP-based communication system between the app and test runner using port-based IPC

### Test Architecture
- **UITests_Swift.swift**: Contains 170+ numbered test functions (test0, test1, etc.) that test various SDK scenarios
- **UITests_ObjC.m**: Objective-C equivalent tests for cross-language compatibility
- **Automated_UI_Testing.swift**: Base test class that handles app lifecycle, StoreKit sessions, and UI interactions
- **Tests.swift**: Auto-generated file containing individual test classes for each test number
- **Testable.swift**: Auto-generated protocol defining test methods and options

### Code Generation System
The project uses a build script that auto-generates test infrastructure:
- Scans UITests_Swift.swift for test functions to determine the highest test number
- Generates Testable.swift protocol with all test methods
- Generates Tests.swift with individual test classes for each test
- Located in Xcode build phase "Autogenerate functions"

### Network Interceptor Library
Custom network interception system in `Libraries/NetworkInterceptor/`:
- Intercepts and redirects HTTP requests for testing
- Supports request sniffing, redirection, and evaluation
- Includes Slack integration for test notifications

### Configuration System
- **Configuration_Swift.swift** & **Configuration_ObjC.m**: Test configuration management
- **Constants.swift**: Global constants and environment setup
- **TestOptions**: Per-test configuration including StoreKit settings and SDK options

## Common Commands

### Running Tests
```bash
# Run all test schemes
./runTests.sh

# Run specific scheme
xcodebuild test -scheme "UI Tests -swift -automatic" -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'

# Run on Limrun cloud simulators, sharded (needs `npm i -g lim` and LIM_API_KEY).
# Tests that need StoreKit (products, prices, purchases) are skipped there: StoreKit's local
# test environment isn't available to XCUITest-launched apps under `lim xcode test`.
scripts/limrun-test.sh -n 8
```

Screen references are recorded on iPhone 18 Pro / iOS 27 (the iOS 16.4 runtime the old PNGs came from
doesn't run on macOS 27 hosts). Taps target elements by accessibility label where possible:
- `await tap("Purchase Primary")`: paywall content, alerts, anything labelled (ObjC: `tapElement:`).
- `await tapSystemElement("Subscribe")` / `("dismiss")`: the StoreKit purchase sheet only.
- `await tapAlertButton(at: 0)`: nth button of the alert or action sheet on screen (survey options).
The runner waits up to 15s for the element. Remaining `touch(CGPoint)` calls (unlabelled close icons,
"tap anywhere") are written for 393x852 and mapped for other sizes (`TouchMapping`).

### Test environment
- Paywall preloading is off (`TestOptions`): preloading gives every paywall in the account its own
  WebKit process and starves the machine when simulators run in parallel.
- `SKTestSession` only takes effect for an app that has been launched once, so the runner launches the
  app once per process before creating the first session (`registerAppIfNeeded`).
- `SWK_SDK_DEBUG=1` turns on SuperwallKit debug logging.

### Known SDK issues
Tests failing because of SDK behaviour (not the test) are listed in `KnownIssue` in
`Automated_UI_Testing.swift`, with the reason and the configurations affected. Their failures are
recorded as expected failures (`XCTExpectFailure`, non-strict), so a run only goes red on something new;
the reason shows in the results. Remove an entry once the SDK is fixed. Currently: 9/99 (a "present
always" paywall is closed as restored for a subscribed user) and 134/169 (no `restoreStart` from a
programmatic restore with a purchase controller).

### Recorded network responses (`Fixtures/`)
Superwall API responses and paywall pages (HTML, CSS, JS, fonts) are recorded in `Fixtures/`
(gzipped) and replayed by the app (`UI Tests/Helpers/Fixtures.swift`), so tests don't depend on the
dev backend or the dashboard. API requests are answered by `FixtureURLProtocol`, hooked into every
`URLSession`; paywall URLs are rewritten to the app's own HTTP server (`/web/<host>/<path>`), since
WebKit loads pages out of `URLProtocol`'s reach. Anything not recorded falls back to the network.
- Replay is the default whenever `Fixtures/` exists. In replay mode the adaptive wait's ceiling is
  capped at 6s (nothing waits on the network), which mostly speeds up "nothing should appear" tests.
- Re-record after changing a test's paywall or campaign on the dashboard:
  `TEST_RUNNER_SWK_FIXTURES=record TESTS="12" ./runTests.sh` (or everything without `TESTS`).
- `TEST_RUNNER_SWK_FIXTURES=off` goes to the network as before.
- `TEST_RUNNER_SWK_FIXTURES_LOG=<path>` logs every request that went to the network.
- The "Bundle fixtures" build phase copies `Fixtures/` into the app for remote runners.

### Assertions
`assert(after:)` waits until the screen has changed and settled (`AdaptiveWait`), falling back to the
full delay when nothing changes, so negative tests keep their strength. It then verifies the screen
according to `SWK_ASSERT_MODE`:
- `screen` (default): a JSON description of the screen from `ScreenInspector` (paywall identifier,
  loading state, visible web text, alerts, other presented controllers) is compared with
  `__Snapshots__/Screens/<Test-N.K>.json`. Device- and runtime-independent; runs on Limrun.
- `pixel`: the old screenshot comparison against PNGs recorded on iPhone 14 Pro / iOS 16.4. Local only.
- `both`: both.

Missing screen references are recorded on the first run (the test fails once so you review them).
Re-record everything with `TEST_RUNNER_SWK_RECORD_SCREENS=1 xcodebuild test ...`, then check new
references against the reviewed PNGs with `swift scripts/compare-screen-references.swift`.
The "Bundle snapshot references" build phase copies all JSON references into the test bundle so
remote runners can read them. `SWK_ADAPTIVE_WAIT=0` restores fixed sleeps.

### Available Test Schemes
- **UI Tests -swift -automatic**: Swift tests with automatic configuration
- **UI Tests -swift -advanced**: Swift tests with advanced configuration
- **UI Tests -objc -automatic**: Objective-C tests with automatic configuration
- **UI Tests -objc -advanced**: Objective-C tests with advanced configuration
- **UI Tests -demo**: Demo configuration

### Build Commands
```bash
# Build main app
xcodebuild build -scheme "UI Tests" -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'

# Build tests
xcodebuild build-for-testing -scheme "Automated UI Testing" -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

## Development Workflow

### Adding New Tests
1. Add test method to `UITests_Swift.swift` with sequential numbering (e.g., `test172`)
2. Optionally add corresponding method to `UITests_ObjC.m`
3. Add test options method if needed (e.g., `testOptions172`)
4. Build project to trigger auto-generation of supporting files

### Test Structure
Tests follow this pattern:
```swift
func test{N}() async throws {
    // Setup SDK configuration
    Superwall.shared.identify(userId: "test{N}")
    
    // Perform actions
    Superwall.shared.register(placement: "placement_name")
    
    // Assert results
    await assert(after: Constants.paywallPresentationDelay)
}
```

### Test Communication
- Tests communicate via HTTP between app and test runner
- Ports are derived from the simulator's UDID (shared by the app and runner on one simulator), so concurrent test sessions on one Mac don't collide
- Supports assertions, screenshots, StoreKit operations, and app lifecycle events

## Dependencies

### Swift Package Manager
- **SuperwallKit**: Main SDK being tested (develop branch)
- **swift-snapshot-testing**: For screenshot comparisons
- **swifter**: HTTP server for test communication

### Built-in Libraries
- **NetworkInterceptor**: Custom network interception
- **GzipSwift**: Gzip compression utilities
- **URLRequest-cURL**: cURL conversion utilities

## Important Notes

- Tests run in isolated simulator environments with fresh app installs
- StoreKit testing uses sandbox configuration with `Products.storekit`
- Screen references (JSON) live in `__Snapshots__/Screens`; legacy pixel references (PNG) and value references in `__Snapshots__/Automated_UI_Testing`
- Tests support both StoreKit 1 and StoreKit 2 configurations
- The system handles parallel test execution with unique port allocation
- All test infrastructure is auto-generated based on test method scanning

## Test Debugging

### Common Issues
- Port conflicts: Ensure simulators are properly isolated
- StoreKit failures: Check sandbox configuration and product setup
- Network timeouts: Verify HTTP communication between app and test runner
- Screen differences: the failure shows a line diff; if the paywall changed on the dashboard, re-record with `SWK_RECORD_SCREENS=1`

### Test Execution Flow
1. Test runner launches app with environment variables
2. App configures SDK and starts HTTP server
3. Test runner sends `runTest` command with test number
4. App executes test method and communicates results back
5. Test runner handles assertions and captures screenshots
6. App terminates after test completion