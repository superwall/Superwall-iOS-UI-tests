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

    static let numTests = 2
    static let launchEnvironments: [LaunchEnvironment] = [automatic]
//    static let launchEnvironments: [LaunchEnvironment] = [automatic, advanced, revenueCat]

    static let automatic: LaunchEnvironment = ["configurationType": "automatic"]
    static let advanced: LaunchEnvironment = ["configurationType": "advanced"]
    static let revenueCat: LaunchEnvironment = ["configurationType": "revenueCat"]
  }

  var testNumber: Int = -1
  var launchEnvironment: [String: String] = [:]

  override class var defaultTestSuite: XCTestSuite {
    Communicator.shared.start()

    let testSuite = XCTestSuite(name: NSStringFromClass(self))

    Constants.launchEnvironments.forEach { launchEnvironment in
      Array(stride(from: 0, to: Constants.numTests, by: 1)).map { testNumber in
        return testNumber
      }.forEach { testNumber in
        testInvocations.forEach { invocation in
          let testCase = Automated_UI_Testing(invocation: invocation)
          testCase.testNumber = testNumber
          testCase.launchEnvironment = launchEnvironment
          testSuite.addTest(testCase)
        }
      }
    }

    return testSuite
  }

  func handle(_ action: Communicator.Action) {
    switch action {
      case .launchApp:
        Task {
          await launchApp()
        }
      case .endTest:
        expectation.fulfill()
      case .assert(let testName):
        let image = app.screenshot().image
        let precisionValue: Float = 0.95
        assertSnapshot(matching: image, as: .image(precision: precisionValue), testName: testName)
        return
      case .touch(_):
        return

        //

      case .runTest(_):
        return
    }
  }

  lazy var app: XCUIApplication = {
    let app = XCUIApplication()
    app.launchEnvironment = launchEnvironment
    return app
  }()

  let expectation = XCTestExpectation(description: "Expectation for the run of the test")

  func launchApp() async {
    await MainActor.run(body: {
      app.launch()
      _ = app.wait(for: .runningForeground, timeout: 60)
    })
  }

  func testSDK() async {
    let observer = NotificationCenter.default.addObserver(forName: .receivedResponse, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }

    print("Please start test #\(testNumber) in with \(launchEnvironment.debugDescription)")

    await launchApp()

    Communicator.shared.send(.runTest(number: testNumber))

    wait(for: [expectation], timeout: 1000)

    NotificationCenter.default.removeObserver(observer)
  }

}

//final class Automated_UI_Testing: XCTestCase {
//
//  static let communicator = Communicator.shared
//  static let app = XCUIApplication()
//
//  static let parentAppExpectation: XCTestExpectation = XCTestExpectation(description: "Waiting for parent app to provide test info.")
//
//  override class var defaultTestSuite: XCTestSuite {
//    communicator.start()
//
//    let testSuite = XCTestSuite(name: NSStringFromClass(self))
//
//    app.launch()
//    _ = app.wait(for: .runningForeground, timeout: 60)
//
//    tests = Array(stride(from: 0, to: 5, by: 1)).map { testNumber in
//      let testCase = ParentAppTestCase()
//      testCase.number = testNumber
//      return testCase
//    }
//
//    self.testInvocations
//
//    tests.forEach({ testSuite.addTest($0) })
//
//    return testSuite
//  }
//
//  static var tests: [XCTest] = []
//
//  override init() {
//    super.init()
//
//    NotificationCenter.default.addObserver(forName: .receivedResponse, object: nil, queue: .main) { notification in
//      guard let action = notification.object as? Communicator.Action else { return }
//      Self.handle(action)
//    }
//  }
//
//  override func setUpWithError() throws {
//    // In UI tests it is usually best to stop immediately when a failure occurs.
//    continueAfterFailure = false
//  }
//
//  static func handle(_ action: Communicator.Action) {
//    switch action {
//      case .launchApp:
//        app.launch()
//        _ = app.wait(for: .runningForeground, timeout: 60)
//
//      case .relayNumberOfTests(number: let number):
////        print("Create \(number) tests")
//        return
//
//      case .assert:
//        print("Perform assertion")
//      case .touch(point: let point):
//        print("Touch point: \(point.debugDescription)")
//        return
//
//      // For the parent app only
//      case .runTest(_):
//        return
//    }
//  }
//
//  override func tearDownWithError() throws {
//    // Put teardown code here. This method is called after the invocation of each test method in the class.
//  }
//}
//
//class ParentAppTestCase: XCTestCase {
//  var number: Int = 0
//
//  func testNumber() async {
//    print("STARTING TEST #\(number)")
//
//    await Task.sleep(timeInterval: 1000)
//  }
//}
