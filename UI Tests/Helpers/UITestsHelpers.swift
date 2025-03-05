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

@objc(SWKTestOptions)
@objcMembers
public class TestOptions: NSObject {
  static let defaultOptions: TestOptions = TestOptions()

  // Prevents network requests to mimic poor network connectivity
  let allowNetworkRequests: Bool

  // Whether or not setup() should automatically configure the SDK, or the test itself will handle it
  let automaticallyConfigure: Bool

  // Starts a test after a receipt has been generated for this particular product identifier
  let purchasedProductIdentifier: String?

  // API for the Superwall account. Modified for use of implicit triggers like `app_open`
  let apiKey: String

  let options: SuperwallOptions

  init(
    allowNetworkRequests: Bool = true,
    automaticallyConfigure: Bool = true,
    purchasedProductIdentifier: String? = nil,
    apiKey: String = Constants.defaultAPIKey,
    options: SuperwallOptions = .init()
  ) {
    self.allowNetworkRequests = allowNetworkRequests
    self.automaticallyConfigure = automaticallyConfigure
    self.purchasedProductIdentifier = purchasedProductIdentifier
    self.apiKey = apiKey

    // TODO: REmove when merging to main
    options.networkEnvironment = .developer

    // So we don't have to wait for a minute before it completely fails.
    options.maxConfigRetryCount = 0
    self.options = options
    super.init()
  }

  static func testOptions(allowNetworkRequests: Bool) -> TestOptions {
    return TestOptions(allowNetworkRequests: allowNetworkRequests)
  }

  static func testOptions(purchasedProductIdentifier: String) -> TestOptions {
    return TestOptions(purchasedProductIdentifier: purchasedProductIdentifier)
  }

  static func testOptions(allowNetworkRequests: Bool, purchasedProductIdentifier: String) -> TestOptions {
    return TestOptions(allowNetworkRequests: allowNetworkRequests, purchasedProductIdentifier: purchasedProductIdentifier)
  }

  static func testOptions(allowNetworkRequests: Bool, automaticallyConfigure: Bool) -> TestOptions {
    return TestOptions(allowNetworkRequests: allowNetworkRequests, automaticallyConfigure: automaticallyConfigure)
  }

  static func testOptions(automaticallyConfigure: Bool) -> TestOptions {
    return TestOptions(automaticallyConfigure: automaticallyConfigure)
  }

  static func testOptions(apiKey: String) -> TestOptions {
    return TestOptions(apiKey: apiKey)
  }

  static func testOptions(options: SuperwallOptions) -> TestOptions {
    return TestOptions(options: options)
  }

  static func testOptions(
    allowNetworkRequests: Bool,
    automaticallyConfigure: Bool,
    apiKey: String,
    options: SuperwallOptions
  ) -> TestOptions {
    return TestOptions(
      allowNetworkRequests: allowNetworkRequests,
      automaticallyConfigure: automaticallyConfigure,
      apiKey: apiKey,
      options: options
    )
  }
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

  func assert(after timeInterval: TimeInterval = 0, precision: PrecisionValue = .default, testName: String = #function, prefix: String = "Test", captureArea: CaptureArea = .safeArea(captureHomeIndicator: false)) async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }

    let testName = "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))"

    await Communicator.shared.send(.assert(testName: testName, precision: Float(precision.rawValue) / 100.0, captureArea: captureArea))
  }

  func assert(value: @autoclosure () -> String, after timeInterval: TimeInterval = 0, testName: String = #function, prefix: String = "Test") async {
    if timeInterval > 0 {
      await sleep(timeInterval: timeInterval)
    }

    let testName = "\(prefix)-\(testName.replacingOccurrences(of: "test", with: ""))"

    await Communicator.shared.send(.assertValue(testName: testName, value: value()))
  }

  @available(swift, obsoleted: 1.0)
  @objc func assert(after timeInterval: TimeInterval, testName: String, precision: PrecisionValue, captureArea: CaptureAreaObjC = CaptureAreaObjC.safeAreaNoHomeIndicator) async {
    // Transform: "-[UITests_ObjC test0WithCompletionHandler:]" -> "0" OR "-[UITests_ObjC test11WithCompletionHandler:]_block_invoke_2" -> "11"

    let modifiedTestName = testName.components(separatedBy: "WithCompletionHandler:]").first!.components(separatedBy: "UITests_ObjC test").last!

    await assert(after: timeInterval, precision: precision, testName: modifiedTestName, captureArea: captureArea.transform)
  }

  @available(swift, obsoleted: 1.0)
  @objc func assert(value: String, testName: String) async {
    let modifiedTestName = testName.components(separatedBy: "WithCompletionHandler:]").first!.components(separatedBy: "UITests_ObjC test").last!

    await assert(value: value, testName: modifiedTestName)
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

  @objc func swipeDown() {
    Task {
      await Communicator.shared.send(.swipeDown)
    }
  }

  @objc func typeText(_ text: String) async {
    await Communicator.shared.send(.type(text: text))
  }

  @objc func failTransactions() async {
    await Communicator.shared.send(.failTransactions)
  }

  @objc func relaunch() async {
    await Communicator.shared.send(.relaunchApp)
  }

  @objc func springboard() async {
    await Communicator.shared.send(.springboard)
  }

  @objc func activateSubscription(productIdentifier: String) async {
    await Communicator.shared.send(.activateSubscription(productIdentifier: productIdentifier))
  }

  @objc func expireSubscription(productIdentifier: String) async {
    await Communicator.shared.send(.expireSubscription(productIdentifier: productIdentifier))
  }

  @objc func log(_ message: String) {
    print(message)
    Task {
      await Communicator.shared.send(.log(message))
    }
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

@objc(SWKValueDescriptionHolder)
class ValueDescriptionHolder: NSObject {
  @objc var stringValue: String = "Value description not set"
  @objc var intValue: Int = 0

  override var description: String {
    return "\(stringValue)-\(intValue)"
  }
}

// MARK: - PresentationResult

@objc(SWKPresentationValueObjcHelper)
class PresentationValueObjcHelper: NSObject {
  @objc static func description(_ value: PresentationValueObjc) -> String {
    return value.description
  }
}

extension PresentationValueObjc {
  public var description: String {
    switch self {
    case .placementNotFound:
      return "eventNotFound"
    case .noAudienceMatch:
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

extension PresentationResult: CustomStringConvertible {
  public var description: String {
    switch self {
    case .placementNotFound:
      return PresentationValueObjc.placementNotFound.description
    case .noAudienceMatch:
      return PresentationValueObjc.noAudienceMatch.description
    case .paywall(_):
      return PresentationValueObjc.paywall.description
    case .holdout(_):
      return PresentationValueObjc.holdout.description
    case .paywallNotAvailable:
      return PresentationValueObjc.paywallNotAvailable.description
    }
  }
}

// MARK: - PaywallResult

@objc (SWKPaywallResultValueObjcHelper)
class PaywallResultValueObjcHelper: NSObject {
  @objc static func description(_ value: PaywallResultObjc) -> String {
    return value.description
  }
}

extension PaywallResultObjc {
  public var description: String {
    switch self {
      case .purchased:
        return "purchased"
      case .declined:
        return "declined"
      case .restored:
        return "restored"
    }
  }
}

extension PaywallResult: CustomStringConvertible {
  public var description: String {
    switch self {
      case .purchased(_):
        return PaywallResultObjc.purchased.description
      case .declined:
        return PaywallResultObjc.declined.description
      case .restored:
        return PaywallResultObjc.restored.description
    }
  }
}
