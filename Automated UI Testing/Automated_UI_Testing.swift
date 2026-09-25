//
//  Automated_UI_Testing.swift
//  Automated UI Testing
//
//  Created by Bryan Dubno on 3/10/23.
//

import XCTest
import SnapshotTesting
import StoreKitTest

class Automated_UI_Testing: XCTestCase {
  lazy var app: XCUIApplication = {
    let app = XCUIApplication()
    return app
  }()
  var assertionData: AssertionData!

  struct Constants {
    typealias LaunchEnvironment = [String: String]
    static let launchEnvironment = {
      return ProcessInfo.processInfo.environment
    }()
    static let snapshotsPathComponent: String = {
      return BuildHelpers.Constants.isCIEnvironment ? "CI_Snapshots" : "Snapshots"
    }()

    static let httpConfiguration = {
      return Communicator.HTTPConfiguration(processInfo: ProcessInfo.processInfo)
    }()
  }

  override class func setUp() {
    Communicator.shared.start(httpConfiguration: Constants.httpConfiguration)
  }

  /// With `SWK_FAILURE_LOG=<path>`, every failure is also appended to that
  /// file as it happens: parallel runs don't print failure messages, and a
  /// run that has to be killed never finishes its result bundle.
  override func record(_ issue: XCTIssue) {
    if let path = ProcessInfo.processInfo.environment["SWK_FAILURE_LOG"] {
      let line = "\(name): \(issue.compactDescription.replacingOccurrences(of: "\n", with: " ⏎ "))\n"
      if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
      } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
      }
    }
    // Failures from a known SDK issue are recorded as expected failures, so
    // a run only fails on something new. This has to happen here, on the
    // thread recording the failure: an expectation registered elsewhere
    // doesn't cover failures recorded from other threads.
    if let testNumber = assertionData?.testNumber,
      let knownIssue = KnownIssue.affecting(testNumber: testNumber) {
      XCTExpectFailure(knownIssue, strict: false) {
        recordUnchecked(issue)
      }
      return
    }
    super.record(issue)
  }

  private func recordUnchecked(_ issue: XCTIssue) {
    super.record(issue)
  }

  func handle(_ action: Communicator.Action) {
    switch action.invocation {
      case .relaunchApp:
        app.activate()
        Communicator.shared.completed(action: action)

      case .type(let text):
        // Newer iOS versions don't focus an alert's text field automatically.
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 5), !(field.value(forKey: "hasKeyboardFocus") as? Bool ?? false) {
          field.tap()
        }
        app.typeText(text)
        Communicator.shared.completed(action: action)

      case .springboard:
        XCUIDevice.shared.press(.home)
        Communicator.shared.completed(action: action)

      case .assert(let testName, let precision, let captureArea):
        // If Xcode 14.1/14.2 bug ever gets fixed, use `simctl` to set a consistent status bar instead (https://www.jessesquires.com/blog/2022/12/14/simctrl-status_bar-broken/)
        let image = captureArea.image(from: app.screenshot().image)
        // In "both" mode the screen half of this assertion already took the slot.
        if ProcessInfo.processInfo.environment["SWK_ASSERT_MODE"] != "both" {
          assertionData.assertionCount += 1
        }
        if let failure = verifySnapshot(matching: image, as: .image(precision: precision), named: "\(assertionData.assertionCount)", snapshotDirectory: ReferenceStore.snapshotDirectory, testName: testName) {
          XCTFail(failure)
        }
        Communicator.shared.completed(action: action)

      case .assertValue(let testName, let value):
        assertionData.assertionCount += 1
        if let failure = verifySnapshot(matching: value, as: .json, named: "\(assertionData.assertionCount)", snapshotDirectory: ReferenceStore.snapshotDirectory, testName: testName) {
          XCTFail(failure)
        }
        Communicator.shared.completed(action: action)

      case .assertScreen(let testName, let screen):
        assertionData.assertionCount += 1
        // Same naming as swift-snapshot-testing, e.g. "Test-0.1", so screen and
        // pixel references for an assertion sit side by side.
        let baseName = testName
          .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
          .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
        let name = "\(baseName).\(assertionData.assertionCount)"
        if let failure = ReferenceStore.verifyScreen(describeScreen(appScreen: screen), named: name) {
          XCTFail(failure)
        }
        Communicator.shared.completed(action: action)

      case .skip(let message):
        assertionData.skip = XCTSkip(message)
        Communicator.shared.completed(action: action)

      case .fail(let message):
        assertionData.failure = XCTIssue(type: .assertionFailure, compactDescription: message)
        Communicator.shared.completed(action: action)

      case .tapElement(let label, let index, let systemOnly):
        // The purchase sheet's hosts are slow to query, so they come last.
        let roots = systemOnly ? storeKitSheets + [springboard] : [app, springboard, safariViewService] + storeKitSheets
        // System UI differs between iOS versions (e.g. with failing transactions
        // iOS 27 fails without showing the purchase sheet), so those taps are
        // best-effort; the screen assertions record whether a sheet appeared.
        if let found = ElementFinder.find(label: label, index: index, in: roots, timeout: systemOnly ? 12 : 15) {
          let point = ElementFinder.settled(label: label, index: index, in: roots, from: found)
          tapScreen(point, in: app)
        } else if systemOnly {
          print("System element \"\(label)\" didn't appear; skipping the tap.")
        } else {
          let visible = roots
            .map { "\($0.description): " + ElementFinder.visibleLabels(in: $0).joined(separator: ", ") }
            .joined(separator: " | ")
          assertionData.failure = XCTIssue(
            type: .assertionFailure,
            compactDescription: "No element labelled \"\(label)\" (index \(index)) appeared. Visible labels: \(visible)"
          )
        }
        Communicator.shared.completed(action: action)

      case .tapAlertButton(let index):
        if let point = ElementFinder.alertButton(at: index, in: [app, springboard], timeout: 15) {
          tapScreen(point, in: app)
        } else {
          assertionData.failure = XCTIssue(
            type: .assertionFailure,
            compactDescription: "No alert or action sheet with a button at index \(index) appeared."
          )
        }
        Communicator.shared.completed(action: action)

      case .touch(let point):
        TouchRecorder.record(point, testNumber: assertionData.testNumber, app: app, springboard: springboard)
        let point = TouchMapping.map(point, toScreenOfSize: app.frame.size)
        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let coordinate = normalized.withOffset(CGVector(dx: point.x, dy: point.y))
        // A short press rather than a tap: web content sometimes drops the
        // instantaneous touch XCUITest synthesizes for `tap()`.
        coordinate.press(forDuration: 0.1)
        Communicator.shared.completed(action: action)

      case .swipeDown:
        app.swipeDown(velocity: XCUIGestureVelocity.fast)
        Communicator.shared.completed(action: action)

      case .failTransactions:
        storeKitTestSession.failTransactionsEnabled = true
        Communicator.shared.completed(action: action)

      case .activateSubscription(let productIdentifier):
        // The synchronous `buyProduct(productIdentifier:)` fails on iOS 27
        // (SKServiceErrorDomain error 2); the async API works.
        let session = storeKitTestSession!
        // Buying a subscription that's already active throws with the async
        // API (the old one ignored it); tests can activate the same one twice.
        if session.allTransactions().contains(where: { $0.productIdentifier == productIdentifier }) {
          Communicator.shared.completed(action: action)
          break
        }
        Task { @MainActor in
          do {
            if #available(iOS 17.0, *) {
              _ = try await session.buyProduct(identifier: productIdentifier)
            } else {
              try session.buyProduct(productIdentifier: productIdentifier)
            }
            // This purchase is test setup, but iOS confirms it with a "You're
            // all set." alert that may or may not still be up when the test
            // asserts. Dismiss it, as a user would.
            if let ok = ElementFinder.find(label: "OK", index: 0, in: [springboard], timeout: 4) {
              tapScreen(ok, in: self.app)
            }
          } catch {
            self.assertionData.failure = XCTIssue(type: .uncaughtException, compactDescription: "Unable to purchase product with SKTestSession: \(error.localizedDescription)")
          }
          Communicator.shared.completed(action: action)
        }

      case .expireSubscription(let productIdentifier):
        do {
          try storeKitTestSession.expireSubscription(productIdentifier: productIdentifier)
        } catch {
          assertionData.failure = XCTIssue(type: .uncaughtException, compactDescription: "Unable to expire product with SKTestSession: \(error.localizedDescription)")
        }
        Communicator.shared.completed(action: action)

      case .disableAutoRenew(let productIdentifier):
        do {
          // Get the transaction for the product and disable auto-renew
          if let transaction = storeKitTestSession.allTransactions().first(where: { $0.productIdentifier == productIdentifier }) {
            try storeKitTestSession.disableAutoRenewForTransaction(identifier: transaction.identifier)
          }
        } catch {
          assertionData.failure = XCTIssue(type: .uncaughtException, compactDescription: "Unable to disable auto-renew for product with SKTestSession: \(error.localizedDescription)")
        }
        Communicator.shared.completed(action: action)

      case .log(let message):
        print(message)
        Communicator.shared.completed(action: action)

      case .runTest(_):
        return
      case .completed(_):
        return
    }
  }

  @MainActor
  func launchApp() {
    var environment = Constants.launchEnvironment
    // Have the app wipe its own persisted state on launch, giving fresh-install
    // conditions without deleting the app via springboard.
    environment["SWK_WIPE_STATE"] = environment["SWK_WIPE_STATE"] ?? "1"
    // Locally the app reads and records fixtures in the checkout; remote
    // runners use the copy bundled with the app.
    if environment["SWK_FIXTURES_DIR"] == nil, let fixtures = ReferenceStore.fixturesSourceDirectory {
      environment["SWK_FIXTURES_DIR"] = fixtures.path
    }
    app.launchEnvironment = environment
    app.launchArguments.append("SUPERWALL_UI_TESTS")
    app.launch()
    _ = app.wait(for: .runningForeground, timeout: 60)
  }

  @MainActor
  func terminateApp() {
    // Limrun terminates the app itself after the last test and ends the run
    // with an error ("found nothing to terminate") if it's already gone. The
    // next test's launch restarts it anyway.
    guard !KnownIssue.isLimrun else { return }
    guard app.state != .notRunning else { return }
    app.terminate()
  }

  private var storeKitTestSession: SKTestSession!

  private static var hasRegisteredApp = false

  /// storekitd rejects a test configuration for an app that has never been
  /// launched ("Unable to get entitlements", -10814), and an app that talks
  /// to StoreKit before a configuration lands stays on the real store for its
  /// whole lifetime. Launch it once per runner so it's registered.
  @MainActor
  func registerAppIfNeeded() {
    guard !Self.hasRegisteredApp else { return }
    app.launchEnvironment = Constants.launchEnvironment
    app.launch()
    terminateApp()
    Self.hasRegisteredApp = true
  }

  func setupStoreKitSession() throws {
    storeKitTestSession = try SKTestSession(configurationFileNamed: "Products")
    storeKitTestSession.resetToDefaultState()
    storeKitTestSession.clearTransactions()
  }

  func performSDKTest(number: Int) async throws {
    // Store assertion data
    assertionData = AssertionData(testNumber: number)
    // Tests that can't work where they're running are skipped up front, with
    // the reason (see KnownIssue.skipReason).
    if let skipReason = KnownIssue.skipReason(testNumber: number) {
      throw XCTSkip(skipReason)
    }


    #warning("change to async sequence")
    let observer = NotificationCenter.default.addObserver(forName: .receivedActionRequest, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }

    // Must setup store kit session before app launch. The app wipes its own
    // persisted state on launch (SWK_WIPE_STATE), so nothing stays cached
    // between tests.
    await registerAppIfNeeded()
    do {
      try setupStoreKitSession()
    } catch {
      NotificationCenter.default.removeObserver(observer)
      XCTFail("Unable to create StoreKit test session: \(error)")
      return
    }

    print("Instructing parent app to start test #\(number) with \(Constants.launchEnvironment["configurationType"]!) in \(Constants.launchEnvironment["language"]!)")

    await launchApp()

    // If the app process dies mid-test, no completion will ever arrive over
    // HTTP. Fail fast instead of hanging until the suite timeout.
    let watchdog = Task { @MainActor [app] in
      while !Task.isCancelled {
        await Task.sleep(timeInterval: 2.0)
        if app.state == .notRunning {
          self.assertionData.failure = XCTIssue(
            type: .uncaughtException,
            compactDescription: "App process terminated unexpectedly during test #\(number)"
          )
          Communicator.shared.abortPendingActions()
          return
        }
      }
    }

    await Communicator.shared.send(.runTest(number: number))

    watchdog.cancel()

    // Stop listening for action requests
    NotificationCenter.default.removeObserver(observer)

    if let failure = assertionData.failure {
      XCTFail(failure.compactDescription)
    }
    else if let skip = assertionData.skip {
      throw skip
    }
    
    // Terminate app after test
    await terminateApp()
  }
}

struct AssertionData {
  var testNumber = 0
  var skip: XCTSkip? = nil
  var failure: XCTIssue? = nil
  /// One counter across screen, pixel and value assertions, so every
  /// assertion keeps the reference number it had when all of them went
  /// through swift-snapshot-testing (e.g. Test-35.1.png, Test-35.2.png,
  /// Test-35.3.json).
  var assertionCount = 0
}

let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

/// System UI drawn outside the app that hosts the StoreKit purchase sheet:
/// ServicesPaymentAngel on iOS 27, the StoreKit UI services on earlier runtimes.
/// Tests tap its buttons; it isn't part of screen descriptions because
/// whether it's up yet at a given moment depends on StoreKit timing.
let storeKitSheets = [
  XCUIApplication(bundleIdentifier: "com.apple.ServicesPaymentAngel"),
  XCUIApplication(bundleIdentifier: "com.apple.StoreKitUISceneService"),
  XCUIApplication(bundleIdentifier: "com.apple.ios.StoreKitUIService")
]

/// In-app Safari (SFSafariViewController) is drawn by this service, so its
/// controls, like "Done", aren't in the app's own element tree.
let safariViewService = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")

/// Finds on-screen elements by accessibility label. Web content in paywalls
/// is exposed to XCUITest, so paywall buttons and text are found this way too.
enum ElementFinder {
  // Everything here works on snapshots rather than XCUIElementQuery: queries
  // against system processes (SpringBoard, the purchase sheet's host) time
  // out or hit processes that just went away, and XCUITest reports that as a
  // test failure. A failed snapshot just throws, and we try again.

  /// Visible element frames with this label or identifier, top to bottom.
  static func frames(label: String, in root: XCUIApplication) -> [CGRect] {
    guard let snapshot = snapshotIfRunning(root) else { return [] }
    let screen = snapshot.frame
    var found: [CGRect] = []
    func walk(_ node: XCUIElementSnapshot) {
      if (node.label == label || node.identifier == label),
         node.frame.width > 0, node.frame.height > 0, node.frame.intersects(screen) {
        found.append(node.frame)
      }
      node.children.forEach(walk)
    }
    walk(snapshot)
    return sorted(found)
  }

  /// The center of the `index`th element with this label, in screen points.
  static func find(label: String, index: Int, in roots: [XCUIApplication], timeout: TimeInterval) -> CGPoint? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      for root in roots {
        let found = frames(label: label, in: root)
        if found.indices.contains(index) {
          return CGPoint(x: found[index].midX, y: found[index].midY)
        }
      }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    return nil
  }

  /// The center of the `index`th button, top to bottom, of the first alert or
  /// action sheet on screen.
  /// Re-finds an element until two finds a moment apart agree on where it is.
  /// Sheets and alerts slide in, and a tap on a button that's still moving is
  /// dropped (the purchase sheet's "Subscribe" in particular).
  static func settled(label: String, index: Int, in roots: [XCUIApplication], from point: CGPoint) -> CGPoint {
    var point = point
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
      Thread.sleep(forTimeInterval: 0.3)
      guard let next = find(label: label, index: index, in: roots, timeout: 1) else {
        return point
      }
      if abs(next.x - point.x) < 1 && abs(next.y - point.y) < 1 {
        return next
      }
      point = next
    }
    return point
  }

  static func alertButton(at index: Int, in roots: [XCUIApplication], timeout: TimeInterval) -> CGPoint? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      for root in roots {
        guard let snapshot = snapshotIfRunning(root) else { continue }
        var container: XCUIElementSnapshot?
        func findContainer(_ node: XCUIElementSnapshot) {
          if container == nil, node.elementType == .alert || node.elementType == .sheet {
            container = node
          }
          node.children.forEach(findContainer)
        }
        findContainer(snapshot)
        guard let container else { continue }
        var buttons: [CGRect] = []
        func walk(_ node: XCUIElementSnapshot) {
          if node.elementType == .button, node.frame.width > 0, node.frame.height > 0 {
            buttons.append(node.frame)
          }
          node.children.forEach(walk)
        }
        walk(container)
        let ordered = sorted(buttons)
        if ordered.indices.contains(index) {
          return CGPoint(x: ordered[index].midX, y: ordered[index].midY)
        }
      }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    return nil
  }

  /// Alerts drawn by `root`, as title plus button labels.
  static func alerts(in root: XCUIApplication) -> [[String: Any]] {
    guard let snapshot = snapshotIfRunning(root) else { return [] }
    var result: [[String: Any]] = []
    func buttons(_ node: XCUIElementSnapshot) -> [String] {
      (node.elementType == .button && !node.label.isEmpty ? [node.label] : []) + node.children.flatMap(buttons)
    }
    func walk(_ node: XCUIElementSnapshot) {
      if node.elementType == .alert {
        result.append(["title": node.label, "buttons": buttons(node)])
      } else {
        node.children.forEach(walk)
      }
    }
    walk(snapshot)
    return result
  }

  static func visibleLabels(in root: XCUIApplication) -> [String] {
    guard let snapshot = snapshotIfRunning(root) else { return [] }
    var labels: [String] = []
    func walk(_ node: XCUIElementSnapshot) {
      if !node.label.isEmpty { labels.append(node.label) }
      node.children.forEach(walk)
    }
    walk(snapshot)
    return labels
  }

  /// Snapshotting a process that isn't running makes XCUITest retry for
  /// about 90 seconds, so check first.
  static func snapshotIfRunning(_ root: XCUIApplication) -> XCUIElementSnapshot? {
    guard root.state != .notRunning else { return nil }
    return try? root.snapshot()
  }

  private static func sorted(_ frames: [CGRect]) -> [CGRect] {
    frames.sorted { $0.minY != $1.minY ? $0.minY < $1.minY : $0.minX < $1.minX }
  }
}

/// Taps a point in screen coordinates. The app spans the screen, so this
/// also reaches system UI drawn over it, like the purchase sheet.
func tapScreen(_ point: CGPoint, in app: XCUIApplication) {
  // A short press rather than a tap: web content sometimes drops the
  // instantaneous touch XCUITest synthesizes for `tap()` (see `.touch`).
  app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
    .withOffset(CGVector(dx: point.x, dy: point.y))
    .press(forDuration: 0.1)
}

/// With `SWK_TOUCH_LOG=<path>`, records which element sits under every
/// coordinate `touch`, one JSON line per touch. Used to convert coordinate
/// taps into `tap("label")` calls; run it on a 393x852 screen so the points
/// land exactly where they were written for.
enum TouchRecorder {
  private static let path = ProcessInfo.processInfo.environment["SWK_TOUCH_LOG"]

  static func record(_ point: CGPoint, testNumber: Int, app: XCUIApplication, springboard: XCUIApplication) {
    guard let path else { return }

    var entry: [String: Any] = ["test": testNumber, "x": point.x, "y": point.y]
    let roots = storeKitSheets.map { ("storeKitSheet", $0) } + [("springboard", springboard), ("app", app)]
    for (source, root) in roots {
      guard let snapshot = ElementFinder.snapshotIfRunning(root) else { continue }
      var best: XCUIElementSnapshot?
      func walk(_ node: XCUIElementSnapshot) {
        let frame = node.frame
        if frame.contains(point), !node.label.isEmpty, frame.width < 390 || frame.height < 800 {
          if best == nil || frame.width * frame.height <= best!.frame.width * best!.frame.height {
            best = node
          }
        }
        node.children.forEach(walk)
      }
      walk(snapshot)
      if best == nil, source == "app" {
        // Nothing under the point: note what's nearby, to help pick a label.
        var nearby: [(CGFloat, String)] = []
        func near(_ node: XCUIElementSnapshot) {
          let distance = hypot(node.frame.midX - point.x, node.frame.midY - point.y)
          if distance < 80, node.frame.width < 390, node.frame.width > 0 {
            nearby.append((distance, "'\(node.label)' id='\(node.identifier)' [\(node.elementType.rawValue)] \(NSCoder.string(for: node.frame))"))
          }
          node.children.forEach(near)
        }
        near(snapshot)
        entry["nearby"] = nearby.sorted { $0.0 < $1.0 }.prefix(6).map(\.1)
      }
      if let best {
        let siblings = ElementFinder.frames(label: best.label, in: root)
        let index = siblings.firstIndex(of: best.frame) ?? 0
        entry["label"] = best.label
        entry["index"] = index
        entry["type"] = best.elementType.rawValue
        entry["frame"] = NSCoder.string(for: best.frame)
        entry["source"] = source
        break
      }
    }

    guard
      let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]),
      let line = String(data: data, encoding: .utf8)
    else { return }
    let url = URL(fileURLWithPath: path)
    if let handle = try? FileHandle(forWritingTo: url) {
      handle.seekToEndOfFile()
      handle.write(Data((line + "\n").utf8))
      try? handle.close()
    } else {
      try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
  }
}

extension Automated_UI_Testing {
  /// Adds what only the runner can see to the app's own description of its
  /// screen: which app is in front (tests that open Safari or go to the home
  /// screen) and system alerts drawn by SpringBoard.
  func describeScreen(appScreen: String) -> String {
    var description: [String: Any] = [:]

    let appState = (try? JSONSerialization.jsonObject(with: Data(appScreen.utf8))) ?? [:]
    let foreground: String
    if app.state == .runningForeground {
      foreground = "app"
      description["app"] = appState
    } else if XCUIApplication(bundleIdentifier: "com.apple.mobilesafari").state == .runningForeground {
      foreground = "safari"
    } else {
      foreground = "springboard"
    }
    description["foreground"] = foreground

    let systemAlerts = ElementFinder.alerts(in: springboard)
    if !systemAlerts.isEmpty {
      description["systemAlerts"] = systemAlerts
    }

    return ReferenceStore.canonicalJSON(description)
  }
}

/// SDK behaviour that currently makes tests fail, by test number and the
/// configurations it affects. Each entry should point at the SDK issue that
/// will fix it; remove it when that lands.
enum KnownIssue {
  private struct Issue {
    let tests: Set<Int>
    let configurationTypes: Set<String>
    let languages: Set<String>
    let reason: String
  }

  private static let issues: [Issue] = [
    Issue(
      tests: [9, 99],
      configurationTypes: ["automatic", "advanced"],
      languages: ["swift", "objc"],
      reason: "SDK: for a subscribed user, the \"present always\" paywall's page starts a restore "
        + "as it opens, and the SDK closes the paywall as restored (restore_complete, then paywall_close)."
    ),
    Issue(
      tests: [134, 169],
      configurationTypes: ["advanced"],
      languages: ["swift", "objc"],
      reason: "SDK: restorePurchases() called from code with a purchase controller no longer sends restoreStart."
    )
  ]

  /// Tests that need StoreKit's local test environment (products, prices,
  /// purchases). On Limrun it isn't available to apps that XCUITest launches:
  /// storekitd reports the app "is not using StoreKit Testing in Xcode" and
  /// asks Apple's sandbox, which has none of our test products.
  ///
  /// These are the tests that failed in a full Limrun run of the Swift
  /// automatic scheme (all for this reason: missing prices and templated
  /// product text, purchases that never happen, or tests stopping because no
  /// products loaded). Tests that don't involve products pass there. Re-derive
  /// the list once Limrun supports StoreKit testing for XCUITest-launched apps.
  private static let storeKitTests: Set<Int> = [
    4, 5, 6, 7, 9, 10, 21, 24, 25, 27, 32, 35, 37, 38, 39, 43,
    44, 45, 47, 48, 58, 60, 63, 69, 71, 75, 77, 78, 79, 80, 81, 83,
    84, 85, 86, 87, 88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 99, 103,
    104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 124,
    125, 126, 127, 128, 129, 130, 131, 132, 133, 137, 138, 139, 140, 141, 142, 143,
    144, 145, 146, 147, 148, 149, 150, 152, 153, 154, 155, 156, 157, 159, 160, 161,
    162, 163, 164, 165, 166, 167, 171, 172, 173, 174, 175, 176, 177, 178
  ]

  /// Limrun runs the test products from its own file area on the simulator.
  static let isLimrun = Bundle(for: Automated_UI_Testing.self).bundlePath.contains("/limulator-files/")

  /// Why a test can't run where it's running, if so. Skipped rather than run
  /// as an expected failure: Limrun's results drop or fail tests with
  /// expected failures, and there's no point spending a simulator on them.
  static func skipReason(testNumber: Int) -> String? {
    if isLimrun, storeKitTests.contains(testNumber) {
      return "Limrun: StoreKit's local test environment isn't available to apps launched by XCUITest in "
        + "`lim xcode test`, so products don't load and purchases don't happen."
    }
    return nil
  }

  static func affecting(testNumber: Int) -> String? {
    let environment = ProcessInfo.processInfo.environment
    let configurationType = environment["configurationType"] ?? ""
    let language = environment["language"] ?? ""
    return issues.first {
      $0.tests.contains(testNumber)
        && $0.configurationTypes.contains(configurationType)
        && $0.languages.contains(language)
    }?.reason
  }
}

/// Reads and writes assertion references.
///
/// Locally, references live next to this file in `__Snapshots__`. On remote
/// runners (e.g. Limrun) the simulator can't see the source checkout, so the
/// "Bundle snapshot references" build phase copies every JSON reference into
/// the test bundle and they're read from there instead. PNG references are
/// not bundled; pixel mode is local-only.
enum ReferenceStore {
  private static let sourceDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("__Snapshots__")

  private static let bundledDirectory = Bundle(for: Automated_UI_Testing.self)
    .resourceURL?
    .appendingPathComponent("SnapshotReferences")

  static let root: URL = {
    if FileManager.default.fileExists(atPath: sourceDirectory.path) {
      return sourceDirectory
    }
    return bundledDirectory ?? sourceDirectory
  }()

  /// The checkout's `Fixtures` folder (see the app's `Fixtures.swift`), when
  /// the checkout is on this machine.
  static let fixturesSourceDirectory: URL? = {
    let checkout = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    guard FileManager.default.fileExists(atPath: checkout.appendingPathComponent("runTests.sh").path) else {
      return nil
    }
    return checkout.appendingPathComponent("Fixtures")
  }()

  static var isWritable: Bool {
    return root == sourceDirectory
  }

  /// Directory for swift-snapshot-testing's pixel and value references.
  static var snapshotDirectory: String {
    return root.appendingPathComponent("Automated_UI_Testing").path
  }

  private static var screensDirectory: URL {
    return root.appendingPathComponent("Screens")
  }

  /// With `SWK_RECORD_SCREENS=1`, references are (re)written and the
  /// assertion passes.
  private static let isRecording = ProcessInfo.processInfo.environment["SWK_RECORD_SCREENS"] == "1"

  /// Returns a failure message, or nil when the screen matches its reference.
  static func verifyScreen(_ screen: String, named name: String) -> String? {
    let url = screensDirectory.appendingPathComponent("\(name).json")
    let reference = try? String(contentsOf: url, encoding: .utf8)

    if reference == screen {
      return nil
    }

    if isWritable && (isRecording || reference == nil) {
      try? FileManager.default.createDirectory(at: screensDirectory, withIntermediateDirectories: true)
      try? screen.write(to: url, atomically: true, encoding: .utf8)
      if isRecording {
        return nil
      }
      return "No screen reference existed for \(name). Recorded one at \(url.path); check it and re-run.\n\(screen)"
    }

    guard let reference else {
      return "No screen reference for \(name) and this runner can't write one. Actual screen:\n\(screen)"
    }
    return "Screen does not match reference \(name) (set SWK_RECORD_SCREENS=1 to re-record):\n"
      + lineDiff(expected: reference, actual: screen)
  }

  static func canonicalJSON(_ object: Any) -> String {
    guard
      let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
      let string = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return string
  }

  /// A minimal line diff: `-` lines only in the reference, `+` lines only on
  /// screen. Enough to read a screen description at a glance.
  private static func lineDiff(expected: String, actual: String) -> String {
    let old = expected.components(separatedBy: "\n")
    let new = actual.components(separatedBy: "\n")
    let lcs = longestCommonSubsequence(old, new)
    var output: [String] = []
    var i = 0, j = 0
    for line in lcs {
      while old[i] != line { output.append("- " + old[i]); i += 1 }
      while new[j] != line { output.append("+ " + new[j]); j += 1 }
      output.append("  " + line)
      i += 1; j += 1
    }
    output += old[i...].map { "- " + $0 }
    output += new[j...].map { "+ " + $0 }
    return output.joined(separator: "\n")
  }

  private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
    var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in stride(from: a.count - 1, through: 0, by: -1) {
      for j in stride(from: b.count - 1, through: 0, by: -1) {
        table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
      }
    }
    var result: [String] = []
    var i = 0, j = 0
    while i < a.count && j < b.count {
      if a[i] == b[j] {
        result.append(a[i]); i += 1; j += 1
      } else if table[i + 1][j] >= table[i][j + 1] {
        i += 1
      } else {
        j += 1
      }
    }
    return result
  }
}

/// Test taps are written in points for the iPhone 14 Pro (393×852). On other
/// screen sizes, controls near the top keep their distance from the top and
/// controls in the lower half (where paywalls put their buttons) keep their
/// distance from the bottom. Horizontal positions scale with the width.
enum TouchMapping {
  static let referenceSize = CGSize(width: 393, height: 852)

  static func map(_ point: CGPoint, toScreenOfSize size: CGSize) -> CGPoint {
    guard size != referenceSize, size.width > 0, size.height > 0 else {
      return point
    }
    let x = point.x * size.width / referenceSize.width
    let y = point.y < referenceSize.height / 2
      ? point.y
      : size.height - (referenceSize.height - point.y)
    return CGPoint(x: x, y: y)
  }
}
