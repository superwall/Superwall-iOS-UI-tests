//
//  Constants.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/7/23.
//

import Foundation

@objc(SWKConstants)
public class Constants: NSObject {
  @objc public static var currentTestOptions: TestOptions = .defaultOptions

  @objc public enum Language: Int, CustomStringConvertible {
    case swift
    case objc
    
    public var description: String {
      switch self {
        case .swift:
          return "Swift"
        case .objc:
          return "Objective-C"
      }
    }
  }

  // Default UI test API key.
  // https://superwall.com/applications/1270
  @objc public static let defaultAPIKey: String = "pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2"

  // Contains a campaign with an `app_launch` trigger
  // https://superwall.com/applications/1768/
  @objc public static let appLaunchAPIKey: String = "pk_fb295f846b075fae6619eebb43d126ecddd1e3b18e7028b8"

  // Contains a campaign with a `session_start` trigger.
  // https://superwall.com/applications/1769/
  @objc public static let sessionStartAPIKey: String = "pk_6c881299e2f8db59f697646e399397be76432fa0968ca254"

  // Contains a campaign with a `app_install` trigger.
  // https://superwall.com/applications/1770/
  @objc public static let appInstallAPIKey: String = "pk_8db958db59cc8460969659822351d5e177d8d65cb295cff2"

  // Contains a campaign with a `deepLink_open` trigger.
  // https://superwall.com/applications/1817/
  @objc public static let deepLinkOpenAPIKey: String =
  "pk_3faea4c721179218a245475ea9d378d1ecb9bf059411a0c0"

  // Contains a campaign with a `transaction_fail` trigger.
  // https://superwall.com/applications/1818/
  @objc public static let transactionAbandonAPIKey: String =
  "pk_9c99186b023ae795e0189cf9cdcd3e2d2d174289e0800d66"

  // Contains a campaign with a `paywall_decline` trigger.
  // https://superwall.com/applications/1819/
  @objc public static let paywallDeclineAPIKey: String =
  "pk_a1071d541642719e2dc854da9ec717ec967b8908854ede74"

  // Contains a campaign with a `transaction_fail` trigger.
  // https://superwall.com/applications/1820/
  @objc public static let transactionFailAPIKey: String =
  "pk_b6cd945401435766da627080a3fbe349adb2dcd69ab767f3"

  // Contains a campaign with a `transaction_fail` trigger.
  // https://superwall.com/applications/1965/
  @objc public static let surveyResponseAPIKey: String =
  "pk_3698d9fe123f1e4aa8014ceca111096ca06fd68d31d9e662"

  // Contains a campaign with a `touches_began` trigger.
  // https://superwall.com/applications/2098/
  @objc public static let touchesBeganAPIKey: String =
  "pk_decd38c6de66a726af2b5e786897ce7ef4aaf0c0959bd061"

  // Contains a campaign with a `paywall_decline`,
  // `transaction_abandon`, and `transaction_fail` trigger.
  // https://superwall.com/applications/3843/
  @objc public static let gatedAPIKey: String =
  "pk_8d769657b3cc26993439cfb4b065bdfb01cc7ddf8982a708"

  // Contains a campaign with a `paywall_decline` trigger.
  // https://superwall.com/applications/3861/
  @objc public static let noRuleMatchGatedAPIKey: String =
  "pk_22d152e6b039c39c7e1a1e5d0bb3921e4fdd578411c80612"

  @objc public static let configurationType = {
    return ProcessInfo.processInfo.environment["configurationType"]!
  }()
  
  @objc public static let language: Language = {
    return ProcessInfo.processInfo.environment["language"]! == "swift" ? .swift : .objc
  }()

  public static let httpConfiguration: Communicator.HTTPConfiguration = {
    return .init(processInfo: ProcessInfo.processInfo)
  }()
  
  // Time interval constants
  @objc public static let paywallPresentationDelay: TimeInterval = 12.0 * CIDelayMultiplier
  @objc public static let implicitPaywallPresentationDelay: TimeInterval = 12.0 * CIDelayMultiplier
  @objc public static let paywallPresentationFailureDelay: TimeInterval = 16.0 * CIDelayMultiplier
  @objc public static let paywallDelegateResponseDelay: TimeInterval = 12.0 * CIDelayMultiplier

  private static let CIDelayMultiplier: TimeInterval = BuildHelpers.Constants.isCIEnvironment ? 1.5 : 1.0
}
