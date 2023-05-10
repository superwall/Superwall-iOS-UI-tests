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
  var skip: XCTSkip? = nil

  struct Constants {
    typealias LaunchEnvironment = [String: String]
    static let launchEnvironment = ProcessInfo.processInfo.environment
  }

  override class func setUp() {
    Communicator.shared.start()
  }

  func handle(_ action: Communicator.Action) {
    switch action.invocation {
      case .assert(let testName, let precision, let captureArea):
        // If Xcode 14.1/14.2 bug ever gets fixed, use `simctl` to set a consistent status bar instead (https://www.jessesquires.com/blog/2022/12/14/simctrl-status_bar-broken/)
        let image = captureArea.image(from: app.screenshot().image)
        assertSnapshot(matching: image, as: .image(precision: precision), testName: testName)
        Communicator.shared.completed(action: action)

      case .assertValue(let testName, let value):
        assertSnapshot(matching: value, as: .json, testName: testName)
        Communicator.shared.completed(action: action)

      case .skip(let message):
        skip = XCTSkip(message)
        Communicator.shared.completed(action: action)

      case .touch(let point):
        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let coordinate = normalized.withOffset(CGVector(dx: point.x, dy: point.y))
        coordinate.tap()
        Communicator.shared.completed(action: action)

      case .activateSubscriber(let productIdentifier):
        try! storeKitTestSession.buyProduct(productIdentifier: productIdentifier)
        Communicator.shared.completed(action: action)

      case .relaunchApp:
        app.activate()
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

  private let storeKitTestSession = try! SKTestSession(configurationFileNamed: "Products")

  func clearStoreKitTransactions() {
    storeKitTestSession.resetToDefaultState()
    storeKitTestSession.clearTransactions()
  }

  func performSDKTest(number: Int) async throws {
    // Handle 5 minute timeout
    let timeoutTask = Task {
      await Task.sleep(timeInterval: 300)
      guard Task.isCancelled == false else { return }
      #warning("log failure better")
      XCTFail("Timeout for test #\(number)")
      app.terminate()
    }

    #warning("change to async sequence")
    let observer = NotificationCenter.default.addObserver(forName: .receivedActionRequest, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }

    print("Instructing parent app to start test #\(number) with \(Constants.launchEnvironment["configurationType"]!) in \(Constants.launchEnvironment["language"]!)")

    await launchApp()

    await Communicator.shared.send(.runTest(number: number))

    // Stop timeout
    timeoutTask.cancel()

    // Clean up StoreKit
    clearStoreKitTransactions()

    // Stop listening for action requests
    NotificationCenter.default.removeObserver(observer)

    if let skip {
      throw skip
    }
  }
}
