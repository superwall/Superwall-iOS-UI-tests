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

extension Configuration {
  class MockSuperwallDelegate: SuperwallDelegate {
    private var handleSuperwallEvent: ((SuperwallEventInfo) -> Void)?

    func handleSuperwallEvent(_ handler: @escaping ((SuperwallEventInfo) -> Void)) {
      handleSuperwallEvent = handler
    }

    func handleSuperwallPlacement(withInfo placementInfo: SuperwallEventInfo) {
      handleSuperwallEvent?(placementInfo)
    }
  }

  class MockPaywallViewControllerDelegate: PaywallViewControllerDelegate {
    func paywall(_ paywall: PaywallViewController, loadingStateDidChange loadingState: PaywallLoadingState) {
    }
    
    private var paywallViewControllerDidFinish: ((PaywallViewController, PaywallResult, Bool) -> Void)?

    func paywallViewControllerDidFinish(_ handler: @escaping ((PaywallViewController, PaywallResult, Bool) -> Void)) {
      paywallViewControllerDidFinish = handler
    }

    func paywall(_ paywall: PaywallViewController, didFinishWith result: PaywallResult, shouldDismiss: Bool) {
      paywallViewControllerDidFinish?(paywall, result, shouldDismiss)
    }
  }
}

// MARK: - Automatic configuration

extension Configuration {
  class Automatic: NSObject, TestConfiguration {
    func setup() async {
      // Using this approach over using the class setup() function because it's not async
      #warning("can probably remove these checks now")
      guard State.hasConfigured == false else { return }
      State.hasConfigured = true

      // Begin fetching products for use in other test cases
      await StoreKitHelper.shared.fetchCustomProducts()

      Superwall.configure(
        apiKey: Constants.currentTestOptions.apiKey,
        options: Constants.currentTestOptions.options
      )
    }

    func tearDown() async {
      // Reset identity and user data
      Superwall.shared.reset()
    }

    func mockSubscribedUser(productIdentifier: String) async {
      await activateSubscription(productIdentifier: productIdentifier)
    }
  }
}

// MARK: - Advanced configuration

extension Configuration {
  class Advanced: NSObject, TestConfiguration {
    let purchaseController: AdvancedPurchaseController = AdvancedPurchaseController()

    func setup() async {
      // Using this approach over using the class setup() function because it's not async
      guard State.hasConfigured == false else { return }
      State.hasConfigured = true

      // Begin fetching products for use in other test cases
      await StoreKitHelper.shared.fetchCustomProducts()

      Superwall.configure(
        apiKey: Constants.currentTestOptions.apiKey,
        purchaseController: purchaseController,
        options: Constants.currentTestOptions.options
      )

      // Set status
      Superwall.shared.subscriptionStatus = .inactive
    }

    func tearDown() async {
      // Reset status
      Superwall.shared.subscriptionStatus = .inactive

      // Reset identity and user data
      Superwall.shared.reset()
    }

    func mockSubscribedUser(productIdentifier: String) async {
      await activateSubscription(productIdentifier: productIdentifier)
      Superwall.shared.subscriptionStatus = .active([Entitlement(id: "default")])
    }
  }

  class AdvancedPurchaseController: PurchaseController {
    func purchase(product: StoreProduct) async -> PurchaseResult {
      let purchaseResult = await StoreKitHelper.shared.purchase(product: product)

      switch purchaseResult {
        case .purchased:
        Superwall.shared.subscriptionStatus = .active([Entitlement(id: "default")])
          fallthrough
        default:
          return purchaseResult
      }
    }

    func restorePurchases() async -> RestorationResult {
      return .restored
    }
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
