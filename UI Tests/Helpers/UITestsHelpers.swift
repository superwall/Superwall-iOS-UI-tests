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
  func mockSubscribedUser(productIdentifier: String) async
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
          return 92
        case .video:
          return 90
        case .transparency:
          return 90
        default:
          fatalError("Undefined precision value")
      }
    }
  }

  func assert(after timeInterval: TimeInterval = 0, precision: PrecisionValue = .default, testName: String = #function, prefix: String = "Swift", captureArea: CaptureArea = .safeArea(captureHomeIndicator: false)) async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }

    let testName = "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))"

    await Communicator.shared.send(.assert(testName: testName, precision: Float(precision.rawValue) / 100.0, captureArea: captureArea))
  }

  func assert(value: String, after timeInterval: TimeInterval = 0, testName: String = #function, prefix: String = "Swift") async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }

    let testName = "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))"

    await Communicator.shared.send(.assertValue(testName: testName, value: value))
  }

  @available(swift, obsoleted: 1.0)
  @objc func assert(after timeInterval: TimeInterval, testName: String, precision: PrecisionValue, captureArea: CaptureAreaObjC = CaptureAreaObjC.safeAreaNoHomeIndicator) async {
    // Transform: "-[UITests_ObjC test0WithCompletionHandler:]" -> "0" OR "-[UITests_ObjC test11WithCompletionHandler:]_block_invoke_2" -> "11"

    let modifiedTestName = testName.components(separatedBy: "WithCompletionHandler:]").first!.components(separatedBy: "UITests_ObjC test").last!

    await assert(after: timeInterval, precision: precision, testName: modifiedTestName, prefix: "ObjC", captureArea: captureArea.transform)
  }

  @available(swift, obsoleted: 1.0)
  @objc func assert(value: String, after timeInterval: TimeInterval, testName: String) async {
    let modifiedTestName = testName.components(separatedBy: "WithCompletionHandler:]").first!.components(separatedBy: "UITests_ObjC test").last!

    await assert(value: value, after: timeInterval, testName: modifiedTestName, prefix: "ObjC")
  }

  #warning("make these async")
  @objc func skip(_ message: String) {
    Task {
      await Communicator.shared.send(.skip(message: message))
    }
  }

  @objc func touch(_ point: CGPoint) {
    Task {
      await Communicator.shared.send(.touch(point: point))
    }
  }

  @objc func relaunch() {
    Task {
      await Communicator.shared.send(.relaunchApp)
    }
  }

  @objc func activateSubscriber(productIdentifier: String) async {
    await Communicator.shared.send(.activateSubscriber(productIdentifier: productIdentifier))
  }
}

// MARK: - UITests Helpers

@objc public extension NSObject {
  private static var stronglyHeldObjects: [AnyObject] = []
  @objc func holdStrongly(_ object: AnyObject) {
    Self.stronglyHeldObjects.append(object)
  }

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
        // For view controllers presented above the paywall view controller
        let presentedViewController = Superwall.shared.presentedViewController?.presentedViewController

        Task {
          await presentedViewController?.dismissAsync()

          DispatchQueue.main.async {
            if Superwall.shared.presentedViewController != nil {
              Superwall.shared.dismiss {
                continuation.resume()
              }
            } else if RootViewController.shared.presentedViewController != nil {
              Task {
                await presentedViewController?.dismissAsync()
                continuation.resume()
              }
            } else {
              continuation.resume()
            }
          }
        }
      }
    }
  }
}

// MARK: - PresentationResult

extension PresentationValueObjc {
  public var description: String {
    switch self {
      case .eventNotFound:
        return "eventNotFound"
      case .noRuleMatch:
        return "noRuleMatch"
      case .paywall:
        return "paywall"
      case .holdout:
        return "holdout"
      case .userIsSubscribed:
        return "userIsSubscribed"
      case .paywallNotAvailable:
        return "paywallNotAvailable"
    }
  }
}

@objc (SWKPresentationValueObjcHelper)
class PresentationValueObjcHelper: NSObject {
  @objc static func description(_ value: PresentationValueObjc) -> String {
    return value.description
  }
}

extension PresentationResult: CustomStringConvertible {
  public var description: String {
    switch self {
      case .eventNotFound:
        return PresentationValueObjc.eventNotFound.description
      case .noRuleMatch:
        return PresentationValueObjc.noRuleMatch.description
      case .paywall(_):
        return PresentationValueObjc.paywall.description
      case .holdout(_):
        return PresentationValueObjc.holdout.description
      case .paywallNotAvailable:
        return PresentationValueObjc.paywallNotAvailable.description
      case .userIsSubscribed:
        return PresentationValueObjc.userIsSubscribed.description
    }
  }
}
