//
//  Automated_UI_Testing.swift
//  Automated UI Testing
//
//  Created by Bryan Dubno on 3/10/23.
//

import XCTest
import SnapshotTesting

class Automated_UI_Testing: XCTestCase {

  struct Constants {
    typealias LaunchEnvironment = [String: String]
    static let launchEnvironment = ProcessInfo.processInfo.environment
  }

  override class func setUp() {
    Communicator.shared.start()
  }

  func handle(_ action: Communicator.Action) {
    switch action {

      case .endTest:
        expectation.fulfill()

      case .assert(let testName, let precision):
        let image = app.screenshot().image
        assertSnapshot(matching: image, as: .image(precision: precision), testName: testName)
        Communicator.shared.send(.finishedAsserting)
        return

      case .skip(let message):
        skip = XCTSkip(message)
        expectation.fulfill()

      case .touch(let point):
        let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let coordinate = normalized.withOffset(CGVector(dx: point.x, dy: point.y))
        coordinate.tap()

      case .relaunchApp:
        app.activate()

      case .runTest(_):
        return
      case .finishedAsserting:
        return
    }
  }

  lazy var app: XCUIApplication = {
    let app = XCUIApplication()
    return app
  }()

  func launchApp() async {
    await MainActor.run(body: {
      app.launchEnvironment = Constants.launchEnvironment
      app.launch()
      _ = app.wait(for: .runningForeground, timeout: 60)
    })
  }

  let expectation = XCTestExpectation(description: "Expectation for the run of the test")
  var skip: XCTSkip? = nil

  func performSDKTest(number: Int) async throws {
    let observer = NotificationCenter.default.addObserver(forName: .receivedResponse, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }

    print("Instructing parent app to start test #\(number) with \(Constants.launchEnvironment["configurationType"]!)")

    await launchApp()

    Communicator.shared.send(.runTest(number: number))

    wait(for: [expectation], timeout: 1000)

    NotificationCenter.default.removeObserver(observer)

    if let skip = skip {
      throw skip
    }
  }
}
