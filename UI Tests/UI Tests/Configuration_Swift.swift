//
//  Configuration_Swift.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/6/23.
//

import StoreKit
import StoreKitTest
import SuperwallKit

struct Configuration {
  struct State {
    static var hasConfigured: Bool = false
  }
}

// MARK: - Automatic configuration

extension Configuration {
  class Automatic: NSObject, TestConfiguration {
    func setup() async {
      // Using this approach over using the class setup() function because it's not async
      guard State.hasConfigured == false else { return }
      State.hasConfigured = true

      Superwall.configure(apiKey: Constants.apiKey)

      // Begin fetching products for use in other test cases
      await StoreKitHelper.shared.fetchCustomProducts()
    }

    func tearDown() async {
      // Dismiss any view controllers
      await dismissViewControllers()

      // Reset identity and user data
      Superwall.shared.reset()
    }

    func mockSubscribedUser(productIdentifier: String) async {
      activateSubscriber(productIdentifier: productIdentifier)
    }
  }
}

// MARK: - Advanced configuration

extension Configuration {
  class Advanced: NSObject, TestConfiguration {
    private(set) var purchaseController: AdvancedPurchaseController!

    func setup() async {
      // Using this approach over using the class setup() function because it's not async
      guard State.hasConfigured == false else { return }
      State.hasConfigured = true

      purchaseController = AdvancedPurchaseController()

      Superwall.configure(apiKey: Constants.apiKey, purchaseController: purchaseController)

      // Set status
      Superwall.shared.subscriptionStatus = .inactive

      // Begin fetching products for use in other test cases
      await StoreKitHelper.shared.fetchCustomProducts()
    }

    func tearDown() async {
      // Reset status
      Superwall.shared.subscriptionStatus = .inactive

      // Dismiss any view controllers
      await NSObject.dismissViewControllers()

      // Reset identity and user data
      Superwall.shared.reset()
    }

#warning("add to objc")
    func mockSubscribedUser(productIdentifier: String) async {
      Superwall.shared.subscriptionStatus = .active
    }
  }

  #warning("add to objc")
  class AdvancedPurchaseController: PurchaseController {
    func purchase(product: SKProduct) async -> PurchaseResult {
      let transactionState = await StoreKitHelper.shared.purchase(product: product)
      switch transactionState {
        case .purchased, .restored:
          Superwall.shared.subscriptionStatus = .active
          return .purchased
        case .failed:
          return .failed(NSError() as Error)
        default:
          return .cancelled
      }
    }

    func restorePurchases() async -> RestorationResult {
      return .restored
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

// MARK: - UITests_Swift convenience

extension UITests_Swift {
  var configuration: TestConfiguration {
    return Self.configuration
  }

  static let configuration: TestConfiguration = {
    switch Constants.configurationType {
      case "automatic":
        return Configuration.Automatic()
      case "advanced":
        return Configuration.Advanced()
      default:
        fatalError("Could not find Swift test configuration type")
    }
  }()
}
