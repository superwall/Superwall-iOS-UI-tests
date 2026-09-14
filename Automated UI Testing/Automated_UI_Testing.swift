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
    static let httpConfiguration = {
      return Communicator.HTTPConfiguration(processInfo: ProcessInfo.processInfo)
    }()
  }

  override class func setUp() {
    // Set by `scripts/run-tests.py run --record`, which overwrites the stored
    // images instead of comparing against them. Every recorded test fails by
    // design, so a recording run is expected to come back red.
    isRecording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    Communicator.shared.start(httpConfiguration: Constants.httpConfiguration)
  }

  func handle(_ action: Communicator.Action) {
    switch action.invocation {
      case .relaunchApp:
        app.activate()
        Communicator.shared.completed(action: action)

      case .type(let text):
        app.typeText(text)
        Communicator.shared.completed(action: action)

      case .springboard:
        XCUIDevice.shared.press(.home)
        Communicator.shared.completed(action: action)

      case .assert(let testName, let precision, let perceptualPrecision, let captureArea):
        // If Xcode 14.1/14.2 bug ever gets fixed, use `simctl` to set a consistent status bar instead (https://www.jessesquires.com/blog/2022/12/14/simctrl-status_bar-broken/)
        let image = captureArea.image(from: app.screenshot().image)
        assertSnapshot(matching: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), testName: testName)
        Communicator.shared.completed(action: action)

      case .assertValue(let testName, let value):
        assertSnapshot(matching: value, as: .json, testName: testName)
        Communicator.shared.completed(action: action)

      case .skip(let message):
        assertionData.skip = XCTSkip(message)
        Communicator.shared.completed(action: action)

      case .fail(let message):
        assertionData.failure = XCTIssue(type: .assertionFailure, compactDescription: message)
        Communicator.shared.completed(action: action)

      case .touch(let point):
        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let coordinate = normalized.withOffset(CGVector(dx: point.x, dy: point.y))
        coordinate.tap()
        Communicator.shared.completed(action: action)

      case .swipeDown:
        app.swipeDown(velocity: XCUIGestureVelocity.fast)
        Communicator.shared.completed(action: action)

      case .failTransactions:
        storeKitTestSession.failTransactionsEnabled = true
        Communicator.shared.completed(action: action)

      case .activateSubscription(let productIdentifier):
        do {
          try storeKitTestSession.buyProduct(productIdentifier: productIdentifier)
        } catch {
          assertionData.failure = XCTIssue(type: .uncaughtException, compactDescription: "Unable to purchase product with SKTestSession: \(error.localizedDescription)")
        }
        Communicator.shared.completed(action: action)

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
    app.launchEnvironment = Constants.launchEnvironment
    app.launchArguments.append("SUPERWALL_UI_TESTS")
    app.launch()

    if app.wait(for: .runningForeground, timeout: 60) == false {
      XCTFail("The app did not reach the foreground within 60 seconds.")
    }
  }

  @MainActor
  func terminateApp() {
    app.terminate()
  }

  private var storeKitTestSession: SKTestSession!

  func setupStoreKitSession() {
    storeKitTestSession = try! SKTestSession(configurationFileNamed: "Products")
    storeKitTestSession.resetToDefaultState()
    storeKitTestSession.clearTransactions()
  }

  @MainActor
  func deleteApp() async {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let icon = springboard.icons["UI Tests"]
    guard icon.waitForExistence(timeout: 10) else {
      print("No app to delete. This is likely a first install.")
      return
    }

    icon.press(forDuration: 1.1)

    // Each step is asked for on Springboard itself rather than through the
    // view that happens to hold it. The wording has stayed put across
    // releases; the nesting has not, and a query that spells the nesting out
    // matches nothing the moment it changes.
    for label in ["Remove App", "Delete App", "Delete"] {
      let button = springboard.buttons[label]
      guard button.waitForExistence(timeout: 10) else {
        XCTFail("Could not delete the app: no \"\(label)\" button appeared.")
        return
      }
      button.tap()
    }

    // The next test installs the app again, and it has to be gone before the
    // StoreKit session is set up, or the app starts with no products.
    let disappeared = icon.waitForNonExistence(timeout: 20)
    if disappeared == false {
      XCTFail("The app is still on the home screen after deleting it.")
    }
  }

  func performSDKTest(number: Int) async throws {
    // Store assertion data
    assertionData = AssertionData()

    #warning("change to async sequence")
    let observer = NotificationCenter.default.addObserver(forName: .receivedActionRequest, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }

    // Reset app to avoid anything cached.
    await deleteApp()

    // Must setup store kit session before app is install
    setupStoreKitSession()

    print("Instructing parent app to start test #\(number) with \(Constants.launchEnvironment["configurationType"]!) in \(Constants.launchEnvironment["language"]!)")

    await launchApp()

    let reported = await runTest(number: number)

    // Stop listening for action requests
    NotificationCenter.default.removeObserver(observer)

    if reported == false {
      XCTFail("Test #\(number) never reported back. The app has most likely stopped running; check its output above.")
    }

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

private extension Automated_UI_Testing {
  /// Runs the test in the app, returning false if the app never answered.
  ///
  /// The app has a timeout of its own and reports a failure when it fires, so
  /// this only comes into play when the app has stopped running altogether.
  /// Without it the runner waits on an answer that can no longer arrive.
  func runTest(number: Int) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        await Communicator.shared.send(.runTest(number: number))
        return true
      }
      group.addTask {
        await Task.sleep(timeInterval: 420)
        return false
      }

      let reported = await group.next() ?? false
      group.cancelAll()
      return reported
    }
  }
}

struct AssertionData {
  var skip: XCTSkip? = nil
  var failure: XCTIssue? = nil
}
