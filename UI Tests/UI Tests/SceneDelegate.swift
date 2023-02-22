//
//  SceneDelegate.swift
//  UI-Tests
//
//  Created by Bryan Dubno on 1/24/23.
//

import UIKit
import SuperwallKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  // for cold launches
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let url = connectionOptions.urlContexts.first?.url {
      handleDeepLink(url: url)
    }

    guard let _ = (scene as? UIWindowScene) else { return }
  }

  // for when your app is already running
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      handleDeepLink(url: url)
    }
  }

  func handleDeepLink(url: URL) {
    let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PlaceholderViewController")
    guard let rootViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
      print("WARNING: Could not find root view controller.")
      return
    }

    rootViewController.present(viewController, animated: true)
  }

}

