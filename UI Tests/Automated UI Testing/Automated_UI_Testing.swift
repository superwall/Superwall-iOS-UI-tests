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
  let expectation = XCTestExpectation(description: "Expectation for the run of the test")
  var skip: XCTSkip? = nil

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

      case .assert(let testName, let precision, let captureStatusBar, let captureHomeIndicator):
        // If Xcode 14.1/14.2 bug ever gets fixed, use `simctl` to set a consistent status bar instead (https://www.jessesquires.com/blog/2022/12/14/simctrl-status_bar-broken/)
        let image = app.screenshot().image.captureStatusBar(captureStatusBar).captureHomeIndicator(captureHomeIndicator)
        assertSnapshot(matching: image, as: .image(perceptualPrecision: precision), testName: testName)
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

  @MainActor
  func launchApp() {
    app.launchEnvironment = Constants.launchEnvironment
    app.launch()
    _ = app.wait(for: .runningForeground, timeout: 60)
  }

  func performSDKTest(number: Int) async throws {
    let observer = NotificationCenter.default.addObserver(forName: .receivedResponse, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }

    print("Instructing parent app to start test #\(number) with \(Constants.launchEnvironment["configurationType"]!)")

    await launchApp()

    let session = try? SKTestSession(configurationFileNamed: "Products")
    session?.resetToDefaultState()
    session?.clearTransactions()

    Communicator.shared.send(.runTest(number: number))

    wait(for: [expectation], timeout: 1000)

    NotificationCenter.default.removeObserver(observer)

    if let skip {
      throw skip
    }
  }
}

extension UIImage {
  func captureStatusBar(_ captureStatusBar: Bool) -> UIImage {
    return captureStatusBar ? self : withoutStatusBar
  }

  func captureHomeIndicator(_ captureHomeIndicator: Bool) -> UIImage {
    return captureHomeIndicator ? self : withoutHomeIndicator
  }

  var withoutStatusBar: UIImage {
    guard let cgImage = cgImage else {
      fatalError("Error creating `withoutStatusBar` image")
    }

    let iPhone14ProStatusBarInset = 59.0
    let yOffset = iPhone14ProStatusBarInset * scale
    let rect = CGRect(x: 0, y: Int(yOffset), width: cgImage.width, height: cgImage.height - Int(yOffset))

    if let croppedCGImage = cgImage.cropping(to: rect) {
      let image = UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
      return image
    }

    fatalError("Error creating `withoutStatusBar` image")
  }

  var withoutHomeIndicator: UIImage {
    guard let cgImage = cgImage else {
      fatalError("Error creating `withoutHomeIndicator` image")
    }

    let iPhone14ProHomeIndicatorInset = 34.0
    let yOffset = iPhone14ProHomeIndicatorInset * scale
    let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height - Int(yOffset))

    if let croppedCGImage = cgImage.cropping(to: rect) {
      let image = UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
      return image
    }

    fatalError("Error creating `withoutHomeIndicator` image")
  }
}
