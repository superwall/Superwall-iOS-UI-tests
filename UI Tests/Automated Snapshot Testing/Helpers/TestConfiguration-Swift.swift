//
//  Configurations-Swift.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/6/23.
//

import XCTest
import SuperwallKit

protocol TestConfiguration {
  func setup() async
  func tearDown() async
}

struct Configuration {
  struct Constants {
    // https://superwall.com/applications/1270
    static let apiKey = "pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2"
  }

  struct State {
    static var hasConfigured: Bool = false
  }
}

extension Configuration {
  struct Automatic: TestConfiguration {
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

extension Configuration {
  struct PurchaseController: TestConfiguration {
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
