//
//  AppDelegate.swift
//  UI Tests-Swift
//
//  Created by Bryan Dubno on 1/24/23.
//

import UIKit
import Security

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Wipe all persisted state before anything touches storage, giving each
    // test fresh-install conditions without the springboard delete dance.
    AppStateWiper.wipeIfRequested()

    // Answer Superwall API requests and serve paywall pages from recordings
    // (see Fixtures).
    Fixtures.installURLSessionHook()
    Communicator.shared.configureServer = { server, port in
      Fixtures.installWebRoute(on: server, port: port)
    }
    Communicator.shared.start(httpConfiguration: Constants.httpConfiguration)

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

// MARK: - AppStateWiper

/// Restores fresh-install conditions when the test runner passes
/// `SWK_WIPE_STATE=1`. This replaces the per-test springboard app deletion,
/// which cost ~10s per test and was the main source of flaky crashes.
private enum AppStateWiper {
  static func wipeIfRequested() {
    guard ProcessInfo.processInfo.environment["SWK_WIPE_STATE"] == "1" else {
      return
    }

    wipePreferences()
    wipeContainerFiles()
    wipeKeychain()
    wipeReceipt()
  }

  /// Removes every preferences domain through UserDefaults so cfprefsd's
  /// cache stays consistent (raw-deleting the plists would not).
  private static func wipePreferences() {
    let fileManager = FileManager.default
    guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
      return
    }

    let preferences = library.appendingPathComponent("Preferences")
    let plists = (try? fileManager.contentsOfDirectory(at: preferences, includingPropertiesForKeys: nil)) ?? []
    var domains = Set(plists.filter { $0.pathExtension == "plist" }.map { $0.deletingPathExtension().lastPathComponent })
    if let bundleId = Bundle.main.bundleIdentifier {
      domains.insert(bundleId)
    }

    for domain in domains {
      UserDefaults.standard.removePersistentDomain(forName: domain)
    }
  }

  private static func wipeContainerFiles() {
    let fileManager = FileManager.default

    var directories: [URL] = [.documentDirectory, .cachesDirectory, .applicationSupportDirectory]
      .compactMap { fileManager.urls(for: $0, in: .userDomainMask).first }
    directories.append(URL(fileURLWithPath: NSTemporaryDirectory()))

    // Library, except Preferences (handled above via UserDefaults) and
    // Caches (already included, so this avoids double traversal).
    if let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
      let librarySubdirectories = (try? fileManager.contentsOfDirectory(at: library, includingPropertiesForKeys: nil)) ?? []
      directories.append(contentsOf: librarySubdirectories.filter {
        !["Preferences", "Caches"].contains($0.lastPathComponent)
      })
    }

    for directory in directories {
      let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
      for item in contents {
        try? fileManager.removeItem(at: item)
      }
    }
  }

  private static func wipeKeychain() {
    let itemClasses: [CFString] = [
      kSecClassGenericPassword,
      kSecClassInternetPassword,
      kSecClassCertificate,
      kSecClassKey,
      kSecClassIdentity
    ]

    for itemClass in itemClasses {
      let query: [CFString: Any] = [
        kSecClass: itemClass,
        kSecAttrSynchronizable: kSecAttrSynchronizableAny
      ]
      SecItemDelete(query as CFDictionary)
    }
  }

  /// Removes any App Store receipt left over from a previous test's
  /// StoreKit test session.
  private static func wipeReceipt() {
    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
      return
    }
    try? FileManager.default.removeItem(at: receiptURL.deletingLastPathComponent())
  }
}

