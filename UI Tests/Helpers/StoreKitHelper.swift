//
//  StoreKitHelper.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/6/23.
//

import Foundation
import StoreKit
import SuperwallKit

@objc(SWKStoreKitHelper)
public class StoreKitHelper: NSObject {
  @objc(sharedInstance)
  public static let shared: StoreKitHelper = StoreKitHelper()

  private(set) var products = [SKProduct]()

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  @objc public var monthlyProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.customMonthlyProductIdentifier })
  }

  @objc public var annualProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.customAnnualProductIdentifier })
  }

  private lazy var productsRequest: SKProductsRequest = {
    let request = SKProductsRequest(productIdentifiers: [Constants.customMonthlyProductIdentifier, Constants.customAnnualProductIdentifier])
    request.delegate = self
    return request
  }()

  var mostRecentFetch: (() -> Void)?

  @objc public func fetchCustomProducts() async {
    productsRequest.start()
    return await withCheckedContinuation { continuation in
      mostRecentFetch = { [weak self] in
        continuation.resume()
        self?.mostRecentFetch = nil
      }
    }
  }

  @objc(mostRecentPurchaseResult)
  var mostRecentPurchaseResultObjc: ((PurchaseResultObjc, Error?) -> Void)?
  var mostRecentPurchaseResult: ((PurchaseResult) -> Void)?

  @available(swift, obsoleted: 1.0)
  @objc public func purchase(product: SKProduct) async -> (PurchaseResultObjc, Error?) {
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)

    return await withCheckedContinuation { continuation in
      mostRecentPurchaseResultObjc = { [weak self] result, error in
        continuation.resume(returning: (result, error))
        self?.mostRecentPurchaseResultObjc = nil
      }
    }
  }

  public func purchase(product: SKProduct) async -> PurchaseResult {
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)

    return await withCheckedContinuation { continuation in
      mostRecentPurchaseResult = { [weak self] state in
        continuation.resume(returning: state)
        self?.mostRecentPurchaseResult = nil
      }
    }
  }
}

extension StoreKitHelper {
  @objc(SWKStoreKitHelperConstants)
  class Constants: NSObject {
    @objc static let customMonthlyProductIdentifier = "com.ui_tests.custom_monthly"
    @objc static let customAnnualProductIdentifier = "com.ui_tests.custom_annual"
    @objc static let freeTrialProductIdentifier = "com.ui_tests.free_trial_annual"
  }
}

extension StoreKitHelper: SKProductsRequestDelegate {
  public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    guard response.products.isEmpty == false else {
      assertionFailure("Failed to receive products in StoreKit helper. Make sure Automated UI Testing has been setup with an `SKTestSession` instance *before* the app has been installed.")
      return
    }

    products = response.products
    mostRecentFetch?()
  }

  public func request(_ request: SKRequest, didFailWithError error: Error) {
    assertionFailure("Failed to receive products in StoreKit helper")
  }
}

extension StoreKitHelper: SKPaymentTransactionObserver {
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    guard
      let transaction = transactions.first,
      [.purchasing, .restored].contains(transaction.transactionState) == false
    else { return }

    switch transaction.transactionState {
    case .purchased:
      mostRecentPurchaseResultObjc?(.purchased, nil)
      mostRecentPurchaseResult?(.purchased)
    case .deferred:
      mostRecentPurchaseResultObjc?(.pending, nil)
      mostRecentPurchaseResult?(.pending)
    case .failed:
      if let error = transaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .paymentCancelled,
            .overlayCancelled:
            mostRecentPurchaseResultObjc?(.cancelled, nil)
            mostRecentPurchaseResult?(.cancelled)
            return
          default:
            break
          }

          if #available(iOS 14, *) {
            switch error.code {
            case .overlayTimeout:
              mostRecentPurchaseResultObjc?(.cancelled, nil)
              mostRecentPurchaseResult?(.cancelled)
            default:
              break
            }
          }
        }
        mostRecentPurchaseResultObjc?(.failed, error)
        mostRecentPurchaseResult?(.failed(error))
      }
    default:
      break
    }
  }
}
