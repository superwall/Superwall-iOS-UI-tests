//
//  Configuration_Swift.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/6/23.
//

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
  }
}

// MARK: - Advanced configuration

extension Configuration {
  class Advanced: NSObject, TestConfiguration {
    private(set) var mockPurchaseController: MockPurchaseController!

    func setup() async {
      // Using this approach over using the class setup() function because it's not async
      guard State.hasConfigured == false else { return }
      State.hasConfigured = true

      mockPurchaseController = MockPurchaseController()

      Superwall.configure(apiKey: Constants.apiKey, purchaseController: mockPurchaseController)

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

      // Reset the mock purchases controller
      mockPurchaseController.reset()

      // Reset identity and user data
      Superwall.shared.reset()
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

// MARK: - MockPurchaseController

import StoreKit

class MockPurchaseController: PurchaseController {
  private struct Constants {
    static let defaultPurchaseResult: PurchaseResult = .cancelled
    static let defaultRestorePurchasesResult: Bool = false
  }

  var purchaseResult: PurchaseResult = Constants.defaultPurchaseResult
  var restorePurchasesResult: Bool = Constants.defaultRestorePurchasesResult

  func purchase(product: SKProduct) async -> PurchaseResult {
    return purchaseResult
  }

  func restorePurchases() async -> Bool {
    return restorePurchasesResult
  }

  func reset() {
    purchaseResult = Constants.defaultPurchaseResult
    restorePurchasesResult = Constants.defaultRestorePurchasesResult
  }
}
