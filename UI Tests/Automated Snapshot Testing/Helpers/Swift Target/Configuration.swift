//
//  Configuration.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/6/23.
//

import XCTest
import SuperwallKit

extension SnapshotTests_Swift {
  var configuration: TestConfiguration {
    return Self.configuration
  }

  static let configuration: TestConfiguration = {
    switch Constants.configurationType {
      case "automatic":
        return Configuration.Automatic()
      default:
        fatalError("Could not find Swift test configuration type")
    }
  }()
}

struct Configuration {
  struct State {
    static var hasConfigured: Bool = false
  }
}

// MARK: - Automatic configuration

extension Configuration {
  class Automatic: TestConfiguration {
    func setup() async {
      // Using this approach over using the class setup() function because it's not async
      guard State.hasConfigured == false else { return }
      State.hasConfigured = true

      Superwall.configure(apiKey: Constants.apiKey, options: SuperwallOptions())

      // Begin fetching products for use in other test cases
      await StoreKitHelper.shared.fetchCustomProducts()
    }

    func tearDown() async {
      // Dismiss any view controllers
      await XCTestCase.dismissViewControllers()
    }
  }
}

// MARK: - Purchase controller configuration

extension Configuration {
  class PurchaseController: TestConfiguration {
    func setup() async {
      Superwall.configure(apiKey: Constants.apiKey, options: SuperwallOptions())

      // Set status
      Superwall.shared.subscriptionStatus = .inactive

      // Begin fetching products for use in other test cases
      await StoreKitHelper.shared.fetchCustomProducts()
    }

    func tearDown() async {
      // Reset status
      Superwall.shared.subscriptionStatus = .inactive

      // Dismiss any view controllers
      await XCTestCase.dismissViewControllers()

      // Remove delegate observers
//      delegate.removeObservers()
    }
  }
}

// MARK: - Mocks

class MockDelegate: SuperwallDelegate {
  var observers: [(SuperwallEventInfo) -> Void] = []

  public func addObserver(_ observer: @escaping (SuperwallEventInfo) -> Void) {
    observers.append(observer)
  }

  public func removeObservers() {
    observers.removeAll()
  }

  public func didTrackSuperwallEventInfo(_ info: SuperwallEventInfo) {
    observers.forEach({ $0(info) })
  }
}
