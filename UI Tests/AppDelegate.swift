//
//  AppDelegate.swift
//  UI Tests-Swift
//
//  Created by Bryan Dubno on 1/24/23.
//

import UIKit
import UXCam

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Configure recordings
    configureUXCam()

    // Override point for customization after application launch.
    Communicator.shared.start()

    let requestRedirectors: [RequestRedirector] = [
      RequestRedirector(requestEvaluator: NetworkConnectivityEvaluator(), redirectableRequestHandler: MalformRequestRedirector())
    ]

    let networkConfig = NetworkInterceptorConfig(requestRedirectors: requestRedirectors)
    NetworkInterceptor.shared.setup(config: networkConfig)
    NetworkInterceptor.shared.startRecording()
    
    return true
  }

  func configureUXCam() {
//    let configuration = UXCamConfiguration(appKey: "8e6x26usp1g3tpb")
//    configuration.enableNetworkLogging = true
//    configuration.enableMultiSessionRecord = false
//
//    UXCam.setUserIdentity("iOS-UI-test")
//    UXCam.optIntoSchematicRecordings()
//    UXCam.start(with: configuration)
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

}

