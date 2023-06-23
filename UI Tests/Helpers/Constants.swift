//
//  Constants.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/7/23.
//

import Foundation

@objc(SWKConstants)
public class Constants: NSObject {
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

  @objc public enum App: Int {
    case `default`
    case appLaunch
    case sessionStart
    case appInstall
  }
  @objc public static var app: App = .default

  @objc public static func apiKey(forApp app: App) -> String {
    switch app {
    case .default:
      // https://superwall.com/applications/1270
      return "pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2"
    case .appLaunch:
      // https://superwall.com/applications/1768/
      return "pk_fb295f846b075fae6619eebb43d126ecddd1e3b18e7028b8"
    case .sessionStart:
      // https://superwall.com/applications/1769/
      return "pk_6c881299e2f8db59f697646e399397be76432fa0968ca254"
    case .appInstall:
      // https://superwall.com/applications/1770/
      return "pk_8db958db59cc8460969659822351d5e177d8d65cb295cff2"
    }
  }
  
  @objc public static let configurationType = {
    return ProcessInfo.processInfo.environment["configurationType"]!
  }()
  
  @objc public static let language: Language = {
    return ProcessInfo.processInfo.environment["language"]! == "swift" ? .swift : .objc
  }()
  
  // Time interval constants
  @objc public static let defaultTimeout: TimeInterval = 120.0
  @objc public static let paywallPresentationDelay: TimeInterval = 8.0
  @objc public static let implicitPaywallPresentationDelay: TimeInterval = 12.0
  @objc public static let paywallPresentationFailureDelay: TimeInterval = 16.0
  @objc public static let paywallDelegateResponseDelay: TimeInterval = 12.0
}
