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
  
  // https://superwall.com/applications/1270
  @objc public static let apiKey = "pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2"
  
  @objc public static let configurationType = {
    return ProcessInfo.processInfo.environment["configurationType"]!
  }()
  
  @objc public static let language: Language = {
    return ProcessInfo.processInfo.environment["language"]! == "swift" ? .swift : .objc
  }()
  
  // Time interval constants
  @objc public static let defaultTimeout: TimeInterval = 120.0
  @objc public static let paywallPresentationDelay: TimeInterval = 8.0
  @objc public static let paywallPresentationFailureDelay: TimeInterval = 16.0
}