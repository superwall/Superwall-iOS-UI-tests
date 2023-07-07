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
    static let launchEnvironment = ProcessInfo.processInfo.environment
    static let isCIEnvironment: Bool = {
      return launchEnvironment["xcode_cloud_ci"] != nil ? true : false
    }()
    static let snapshotsPathComponent: String = {
      return isCIEnvironment ? "CI_Snapshots" : "Snapshots"
    }()
  }

  override class func setUp() {
    Communicator.shared.start()
  }

  func handle(_ action: Communicator.Action) {
    switch action.invocation {
      case .relaunchApp:
        app.activate()
        Communicator.shared.completed(action: action)

      case .springboard:
        XCUIDevice.shared.press(.home)
        Communicator.shared.completed(action: action)

      case .assert(let testName, let precision, let captureArea):
        // If Xcode 14.1/14.2 bug ever gets fixed, use `simctl` to set a consistent status bar instead (https://www.jessesquires.com/blog/2022/12/14/simctrl-status_bar-broken/)
        let image = captureArea.image(from: app.screenshot().image)
        assertSnapshot(matching: image, as: .image(precision: precision), testName: testName)
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

      case .activateSubscription(let productIdentifier):
        try! storeKitTestSession.buyProduct(productIdentifier: productIdentifier)
        Communicator.shared.completed(action: action)

      case .expireSubscription(let productIdentifier):
        try! storeKitTestSession.expireSubscription(productIdentifier: productIdentifier)
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
    app.launch()
    _ = app.wait(for: .runningForeground, timeout: 60)
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
    guard icon.exists else {
      print("No app to delete. This is likely a first install.")
      return
    }

    icon.press(forDuration: 1.1);

    springboard.collectionViews.buttons["Remove App"].tap()

    await Task.sleep(timeInterval: 2.0)

    springboard.alerts["Remove “UI Tests”?"].scrollViews.otherElements.buttons["Delete App"].tap()

    await Task.sleep(timeInterval: 2.0)

    springboard.alerts["Delete “UI Tests”?"].scrollViews.otherElements.buttons["Delete"].tap()

    await Task.sleep(timeInterval: 2.0)
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

    await Communicator.shared.send(.runTest(number: number))

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
  var skip: XCTSkip? = nil
  var failure: XCTIssue? = nil
}
