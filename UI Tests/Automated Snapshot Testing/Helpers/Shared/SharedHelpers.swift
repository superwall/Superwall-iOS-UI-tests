//
//  SharedHelpers.swift
//  Automated Snapshot Testing
//
//  Created by Bryan Dubno on 2/13/23.
//

import UIKit
import XCTest
import SnapshotTesting
import SuperwallKit

@testable import UI_Tests

// MARK: - TestConfiguration

@objc(SWKTestConfiguration)
public protocol TestConfiguration: AnyObject {
  func setup() async
  func tearDown() async
}

// MARK: - XCTestCase

@objc public extension XCTestCase {
  @objc func canRun(test: String = #function) {
    // -[SnapshotTests_ObjC test9] or test9()
    print("[TEST_NAME] \(test)")
  }

  func assert(after timeInterval: TimeInterval, testName: String = #function, precision: Bool = true, prefix: String = "Swift") async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }
    await MainActor.run {
      #warning("consider removing")
//      let precisionValue: Float = precision ? 1.0 : 0.95
      let precisionValue: Float = 0.95
      assertSnapshot(matching: UIScreen.main.snapshotImage(), as: .image(precision: precisionValue), testName: "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))")
    }
  }

  @available(swift, obsoleted: 1.0)
  @objc func assert(after timeInterval: TimeInterval, fulfill expectation: XCTestExpectation?, testName: String, precision: Bool = true) {
    Task {
      // Transform: "-[SnapshotTests_ObjC test0]_block_invoke" -> "0"
      let testName = testName.replacingOccurrences(of: "-[SnapshotTests_ObjC ", with: "").replacingOccurrences(of: "test", with: "").components(separatedBy: "]").first!
      await assert(after: timeInterval, testName: testName, precision: precision, prefix: "ObjC")
      expectation?.fulfill()
    }
  }
}

// MARK: - XCTestCase Helpers

@objc public extension XCTestCase {
  @objc func sleep(timeInterval: TimeInterval) async {
    await Self.sleep(timeInterval: timeInterval)
  }

  @objc func wait(expectation: XCTestExpectation) {
    Self.wait(expectation: expectation)
  }

  func dismissViewControllers() async {
    await Self.dismissViewControllers()
  }

  @objc static func sleep(timeInterval: TimeInterval) async {
    await Task.sleep(timeInterval: timeInterval)
  }

  @objc static func wait(expectation: XCTestExpectation) {
    // swiftlint:disable:next main_thread
    _ = XCTWaiter.wait(for: [expectation], timeout: Constants.defaultTimeout)
  }

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

// MARK: - UIViewController

extension UIViewController {
  func dismissAsync() async {
    return await withCheckedContinuation { continuation in
      DispatchQueue.main.async { [weak self] in
        self?.dismiss(animated: true) {
          continuation.resume()
        }
      }
    }
  }
}

// MARK: - Task

extension Task where Success == Never, Failure == Never {
  public static func sleep(timeInterval: TimeInterval) async {
    let nanoseconds = UInt64(timeInterval * 1_000_000_000)
    try? await sleep(nanoseconds: nanoseconds)
  }
}

// MARK: - UIScreen

extension UIScreen {
  func snapshotImage() -> UIImage {
    let view = snapshotView(afterScreenUpdates: true)
    let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
    let image = renderer.image { ctx in
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
    return image
  }
}
