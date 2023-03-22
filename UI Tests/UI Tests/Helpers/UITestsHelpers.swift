//
//  UITestsHelpers.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/13/23.
//

import UIKit
import SuperwallKit

// MARK: - TestConfiguration

@objc(SWKTestConfiguration)
public protocol TestConfiguration: NSObjectProtocol {
  func setup() async
  func tearDown() async
}

// MARK: - UITests

public extension NSObject {
  @objc(SWKPrecisionValue)
  enum PrecisionValue: Int {
    // The percentage a pixel must match the source pixel to be considered a match. (98-99% mimics the precision of the human eye)
    case `default`

    // Use this value when needing to compare against a screenshot with a video
    case video

    // Use this value when needed to compare against a screenshot that contains elements with some degree of transparency (like a `UIAlertController`)
    case transparency

    public var rawValue: Int {
      switch self {
        case .default:
          return 98
        case .video:
          return 97
        case .transparency:
          return 97
        default:
          fatalError("Undefined precision value")
      }
    }
  }

  func assert(after timeInterval: TimeInterval, precision: PrecisionValue = .default, testName: String = #function, prefix: String = "Swift", captureArea: CaptureArea = .fullScreen) async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }

    await MainActor.run(body: {
      let testName = "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))"
      Communicator.shared.send(.assert(testName: testName, precision: Float(precision.rawValue) / 100.0, captureArea: captureArea))
    })

    await wait(for: .finishedAsserting)
  }

  @available(swift, obsoleted: 1.0)
  @objc func assert(after timeInterval: TimeInterval, testName: String, precision: PrecisionValue, captureArea: CaptureAreaObjC = CaptureAreaObjC.fullScreen) async {
    // Transform: "-[UITests_ObjC test0WithCompletionHandler:]" -> "0" OR "-[UITests_ObjC test11WithCompletionHandler:]_block_invoke_2" -> "11"

    let modifiedTestName = testName.components(separatedBy: "WithCompletionHandler:]").first!.components(separatedBy: "UITests_ObjC test").last!

    await assert(after: timeInterval, precision: precision, testName: modifiedTestName, prefix: "ObjC", captureArea: captureArea.transform)
  }

  @objc func skip(_ message: String) {
    Communicator.shared.send(.skip(message: message))
  }

  @objc func touch(_ point: CGPoint) {
    Communicator.shared.send(.touch(point: point))
  }

  @objc func relaunch() {
    Communicator.shared.send(.relaunchApp)
  }
}

// MARK: - UITests Helpers

@objc public extension NSObject {
  @objc func sleep(timeInterval: TimeInterval) async {
    await Self.sleep(timeInterval: timeInterval)
  }

  func dismissViewControllers() async {
    await Self.dismissViewControllers()
  }

  @objc static func sleep(timeInterval: TimeInterval) async {
    await Task.sleep(timeInterval: timeInterval)
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
