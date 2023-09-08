//
//  AppDelegate.swift
//  UI Tests-Swift
//
//  Created by Bryan Dubno on 1/24/23.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Override point for customization after application launch.
    Communicator.shared.start(channelID: Constants.channelID)

    let requestRedirectors: [RequestRedirector] = [
      RequestRedirector(requestEvaluator: NetworkConnectivityEvaluator(), redirectableRequestHandler: MalformRequestRedirector())
    ]

    let networkConfig = NetworkInterceptorConfig(requestRedirectors: requestRedirectors)
    NetworkInterceptor.shared.setup(config: networkConfig)
    NetworkInterceptor.shared.startRecording()
    
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

}

