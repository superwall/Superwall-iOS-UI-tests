//
//  AdaptiveWait.swift
//  UI Tests
//

import Foundation
import SuperwallKit

/// Replaces the long fixed sleeps before assertions with a wait that returns
/// as soon as the screen has changed and then settled: presentations finished,
/// paywalls loaded, and their visible text unchanged for a moment.
///
/// Safety property: when no change is observed at all (e.g. tests asserting
/// that a paywall does NOT present), the full original delay elapses, so
/// negative assertions keep their original strength. The worst case is always
/// the old behavior.
///
/// Set `SWK_ADAPTIVE_WAIT=0` to restore plain fixed sleeps everywhere.
enum AdaptiveWait {
  /// Delays below this are intentional, precisely-timed sleeps
  /// (e.g. video-frame captures) and are never shortened.
  static let minimumEligibleDelay: TimeInterval = 8.0

  private static let pollInterval: TimeInterval = 0.2

  static var isEnabled: Bool {
    return ProcessInfo.processInfo.environment["SWK_ADAPTIVE_WAIT"] != "0"
  }

  /// How long the screen must stay unchanged. Tests usually tap right after
  /// an assertion, and a paywall that just finished loading may not have
  /// attached its click handlers yet, so this is longer than the content
  /// itself needs. Pixel assertions also wait out CSS animations.
  private static var settleDuration: TimeInterval {
    return AssertMode.current.comparesPixels ? 2.5 : 2.0
  }

  /// Never return before this, so fire-and-forget runner round-trips
  /// (`touch`, `swipeDown`) land and start their UI change first.
  private static var minimumWait: TimeInterval {
    return AssertMode.current.comparesPixels ? 3.5 : 3.0
  }

  /// When the deadline arrives while something is visibly still happening
  /// (a paywall mid-load, a presentation mid-animation), keep waiting up to
  /// this much longer. A loaded machine or slow network shouldn't turn into a
  /// screenshot of a spinner.
  private static let loadingGracePeriod: TimeInterval = 30

  /// An optional ceiling for the wait in replay mode (`Fixtures`), from
  /// `SWK_REPLAY_TIMEOUT_CAP=<seconds>`. Off by default: the full delay also
  /// covers actions whose effect arrives late on a loaded machine (a tap
  /// that's processed seconds after it was sent), not just the network.
  private static let replayTimeoutCap: TimeInterval? = {
    return ProcessInfo.processInfo.environment["SWK_REPLAY_TIMEOUT_CAP"].flatMap(TimeInterval.init)
  }()

  static func effectiveTimeout(_ timeout: TimeInterval) -> TimeInterval {
    guard Fixtures.mode == .replay, let replayTimeoutCap else { return timeout }
    return min(timeout, replayTimeoutCap)
  }

  /// When the last assertion finished; presentation outcomes before it belong
  /// to earlier steps of the test.
  @MainActor static var lastAssertion = Date.distantPast

  /// How long the screen must stay unchanged after the SDK reports that a
  /// presentation request ended without a paywall.
  private static let noPaywallGrace: TimeInterval = 2.0

  /// How long the screen must keep matching the expected reference before the
  /// wait ends early. A screen can pass through the expected state on its way
  /// somewhere else (a paywall the SDK closes straight away), and a test that
  /// stopped at the first frame would miss that.
  private static let matchHoldDuration: TimeInterval = 0.4

  /// Waits until the screen has changed and settled, or `timeout` elapses.
  /// With `expected` (the app part of the reference the next assertion is
  /// compared with, see `ScreenReference`), it returns as soon as the screen
  /// matches it and stays matching, unless the screen already matched when
  /// the wait began: that's a "nothing should change" assertion, which keeps
  /// the full wait.
  @MainActor
  static func sleep(upTo timeout: TimeInterval, expected: NSDictionary? = nil) async {
    let timeout = effectiveTimeout(timeout)
    let start = Date()
    var previous = await ScreenInspector.capture().state
    var lastChange: Date?
    var isStable = true
    let expected = expected.flatMap { ScreenReference.matches(previous, $0) ? nil : $0 }
    var matchingSince: Date?

    while true {
      let elapsed = Date().timeIntervalSince(start)
      let isLoadingAtDeadline = lastChange != nil && !isStable
      if elapsed >= timeout && !(isLoadingAtDeadline && elapsed < timeout + loadingGracePeriod) {
        return
      }

      await Task.sleep(timeInterval: pollInterval)
      let capture = await ScreenInspector.capture()
      isStable = capture.isStable

      if capture.state != previous {
        lastChange = Date()
      }
      previous = capture.state

      if let expected {
        if capture.isStable && ScreenReference.matches(capture.state, expected) {
          let since = matchingSince ?? Date()
          matchingSince = since
          if Date().timeIntervalSince(since) >= matchHoldDuration {
            return
          }
        } else {
          matchingSince = nil
        }
      }

      // Without an observed change we can't tell "not yet" from "never",
      // unless the SDK said it decided not to show a paywall. Otherwise wait
      // out the full delay, exactly as the fixed sleep did.
      guard let lastChange else {
        if let decided = PresentationObserver.resolvedWithoutPaywall(since: lastAssertion),
           Date().timeIntervalSince(decided) >= noPaywallGrace,
           Date().timeIntervalSince(start) >= minimumWait {
          return
        }
        continue
      }

      let hasSettled = Date().timeIntervalSince(lastChange) >= settleDuration
      let pastMinimum = Date().timeIntervalSince(start) >= minimumWait
      if hasSettled && pastMinimum && isStable {
        return
      }
    }
  }
}

extension AdaptiveWait {
  /// Waits until the app's screen has stayed the same for `quiet` seconds, or
  /// `timeout` elapses. Used before element taps: an element behind a paywall
  /// that is still animating away is already in the tree, and a tap on it
  /// would land on the paywall.
  @MainActor
  static func settle(quiet: TimeInterval = 1.0, upTo timeout: TimeInterval = 5) async {
    guard isEnabled else { return }
    let start = Date()
    var previous = await ScreenInspector.capture().state
    var lastChange = start

    while Date().timeIntervalSince(start) < timeout {
      await Task.sleep(timeInterval: pollInterval)
      let capture = await ScreenInspector.capture()
      if capture.state != previous || !capture.isStable {
        lastChange = Date()
      }
      previous = capture.state
      if Date().timeIntervalSince(lastChange) >= quiet {
        return
      }
    }
  }

  /// Waits for a value (usually one a delegate callback writes) to change and
  /// then stay the same for a moment, or for `timeout` to elapse. As with the
  /// screen wait, a value that never changes waits out the full delay, so
  /// "this callback shouldn't fire" assertions keep their strength.
  static func wait(for value: () -> String, upTo timeout: TimeInterval) async {
    let start = Date()
    var previous = value()
    var lastChange: Date?

    while Date().timeIntervalSince(start) < timeout {
      await Task.sleep(timeInterval: 0.1)
      let current = value()
      if current != previous {
        lastChange = Date()
        previous = current
      }
      if let lastChange, Date().timeIntervalSince(lastChange) >= 1.0 {
        return
      }
    }
  }
}

/// The screen references the runner compares assertions with, bundled into
/// the app ("Bundle fixtures" build phase) so `AdaptiveWait` can stop waiting
/// once the screen is the one the next assertion expects.
///
/// The runner numbers a test's assertions in order (`Test-4.1`, `Test-4.2`,
/// ...), counting screen, pixel and value assertions alike, so the app keeps
/// the same count. It's per process, and the app is relaunched for every test.
enum ScreenReference {
  @MainActor private static var assertionCount = 0

  private static let directory = Bundle.main.resourceURL?.appendingPathComponent("ScreenReferences")

  /// Recording overwrites references, so the old ones can't end a wait.
  private static let isRecording = ProcessInfo.processInfo.environment["SWK_RECORD_SCREENS"] == "1"

  /// Counts an assertion the runner will number; returns its number.
  @MainActor
  static func nextAssertion() -> Int {
    assertionCount += 1
    return assertionCount
  }

  /// The app part of reference `<testName>.<number>`, or nil when there's
  /// nothing the app alone can match: no reference, recording, or a screen
  /// with Safari, the home screen or a system alert in front (only the runner
  /// sees those).
  static func expectedApp(testName: String, number: Int) -> NSDictionary? {
    guard !isRecording, let directory else { return nil }
    // Same naming as the runner's (`ReferenceStore.verifyScreen`).
    let baseName = testName
      .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
      .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
    let url = directory.appendingPathComponent("\(baseName).\(number).json")
    guard
      let data = try? Data(contentsOf: url),
      let reference = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary,
      reference["foreground"] as? String == "app",
      reference["systemAlerts"] == nil
    else {
      return nil
    }
    return reference["app"] as? NSDictionary
  }

  static func matches(_ state: ScreenState, _ expected: NSDictionary) -> Bool {
    guard let object = try? JSONSerialization.jsonObject(with: Data(state.json.utf8)) as? NSDictionary else {
      return false
    }
    return object.isEqual(expected)
  }
}

/// Records presentation outcomes the SDK reports to its delegate. Every
/// delegate the tests install is one of the mock delegates, which forward
/// here, and setup installs one by default, so this sees every outcome
/// without changing what the tests themselves observe.
@objc(SWKPresentationObserver)
final class PresentationObserver: NSObject {
  @MainActor private static var lastWithoutPaywall: Date?
  @MainActor private static var lastPresented: Date?

  @objc(recordEventInfo:)
  static func record(_ info: SuperwallEventInfo) {
    let now = Date()
    Task { @MainActor in
      switch info.event {
      case .paywallPresentationRequest(let status, _):
        if status == .presentation {
          lastPresented = now
        } else {
          lastWithoutPaywall = now
        }
      case .paywallOpen:
        lastPresented = now
      default:
        break
      }
    }
  }

  /// When a presentation request since `date` ended without a paywall, with
  /// nothing presented after it; nil otherwise.
  @MainActor
  static func resolvedWithoutPaywall(since date: Date) -> Date? {
    guard let decided = lastWithoutPaywall, decided >= date else { return nil }
    if let presented = lastPresented, presented >= decided { return nil }
    return decided
  }
}

/// How `assert(after:)` verifies the screen, from `SWK_ASSERT_MODE`:
/// - `screen` (default): compare a JSON description of the screen.
/// - `pixel`: compare a screenshot against a PNG reference. The references
///   were recorded on an iPhone 14 Pro running iOS 16.4.
/// - `both`: do both.
enum AssertMode: String {
  case screen
  case pixel
  case both

  static let current: AssertMode = {
    let value = ProcessInfo.processInfo.environment["SWK_ASSERT_MODE"] ?? ""
    return AssertMode(rawValue: value) ?? .screen
  }()

  var comparesScreen: Bool { self != .pixel }
  var comparesPixels: Bool { self != .screen }
}

