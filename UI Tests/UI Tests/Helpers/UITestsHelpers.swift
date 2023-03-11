//
//  UITestsHelpers.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/13/23.
//

import UIKit
import SuperwallKit

// MARK: - UITestsBase

public class UITestsBase: NSObject {}

// MARK: - TestConfiguration

@objc(SWKTestConfiguration)
public protocol TestConfiguration: AnyObject {
  func setup() async
  func tearDown() async
}

// MARK: - UITestsBase

@objc public extension UITestsBase {
  @objc func canRun(test: String = #function) {
    // -[SnapshotTests_ObjC test9] or test9()
    print("[TEST_NAME] \(test)")
  }

  func assert(after timeInterval: TimeInterval, testName: String = #function, prefix: String = "Swift") async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }

    await MainActor.run(body: {
      let testName = "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))"
      Communicator.shared.send(.assert(testName: testName))
    })

    await sleep(timeInterval: 3.0)
  }

  //  func assert(after timeInterval: TimeInterval, testName: String = #function, precision: Bool = true, prefix: String = "Swift") async {
  //    if timeInterval > 0 {
  //      await sleep(timeInterval: timeInterval)
  //    }
  //    await MainActor.run {
  //      #warning("consider removing")
  ////      let precisionValue: Float = precision ? 1.0 : 0.95
  //      let precisionValue: Float = 0.95
  //      assertSnapshot(matching: UIScreen.main.snapshotImage(), as: .image(precision: precisionValue), testName: "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))")
  //    }
  //  }
  //
  //  @available(swift, obsoleted: 1.0)
  //  @objc func assert(after timeInterval: TimeInterval, fulfill expectation: XCTestExpectation?, testName: String, precision: Bool = true) {
  //    Task {
  //      // Transform: "-[SnapshotTests_ObjC test0]_block_invoke" -> "0"
  //      let testName = testName.replacingOccurrences(of: "-[SnapshotTests_ObjC ", with: "").replacingOccurrences(of: "test", with: "").components(separatedBy: "]").first!
  //      await assert(after: timeInterval, testName: testName, precision: precision, prefix: "ObjC")
  //      expectation?.fulfill()
  //    }
  //  }
}

// MARK: - UITestsBase Helpers

@objc public extension UITestsBase {
  @objc func sleep(timeInterval: TimeInterval) async {
    await Self.sleep(timeInterval: timeInterval)
  }

  //  @objc func wait(expectation: XCTestExpectation) {
  //    Self.wait(expectation: expectation)
  //  }

  func dismissViewControllers() async {
    await Self.dismissViewControllers()
  }

  @objc static func sleep(timeInterval: TimeInterval) async {
    await Task.sleep(timeInterval: timeInterval)
  }

  //  @objc static func wait(expectation: XCTestExpectation) {
  //    // swiftlint:disable:next main_thread
  //    _ = XCTWaiter.wait(for: [expectation], timeout: Constants.defaultTimeout)
  //  }

  static func dismissViewControllers() async {
    return await withCheckedContinuation { continuation in
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
        let presentedViewController = Superwall.shared.presentedViewController?.presentedViewController
        Task {
          await presentedViewController?.dismissAsync()
          DispatchQueue.main.async {
            Superwall.shared.dismiss {
              continuation.resume()
            }
          }
        }
      }
    }
  }
}
