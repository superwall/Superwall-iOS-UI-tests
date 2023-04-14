//
//  StoreKitHelper.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/6/23.
//

import Foundation
import StoreKit

@objc(SWKStoreKitHelper)
public class StoreKitHelper: NSObject {
  @objc public static let shared: StoreKitHelper = StoreKitHelper()

  private(set) var products = [SKProduct]()

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  @objc public var monthlyProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.monthlyProductIdentifier })
  }

  @objc public var annualProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.annualProductIdentifier })
  }

  private lazy var productsRequest: SKProductsRequest = {
    let request = SKProductsRequest(productIdentifiers: [Constants.monthlyProductIdentifier, Constants.annualProductIdentifier])
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

  var mostRecentTransactionState: ((SKPaymentTransactionState) -> Void)?

  @objc public func purchase(product: SKProduct) async -> SKPaymentTransactionState{
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)

    return await withCheckedContinuation { continuation in
      mostRecentTransactionState = { [weak self] state in
        continuation.resume(returning: state)
        self?.mostRecentTransactionState = nil
      }
    }
  }
}

extension StoreKitHelper {
  struct Constants {
    static let monthlyProductIdentifier = "com.ui_tests.custom_monthly"
    static let annualProductIdentifier = "com.ui_tests.custom_annual"
  }
}

extension StoreKitHelper: SKProductsRequestDelegate {
  public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    guard response.products.isEmpty == false else {
      assertionFailure("Failed to receive products in StoreKit helper")
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
      let mostRecentTransactionState = mostRecentTransactionState,
      [.purchasing].contains(transaction.transactionState) == false
    else { return }
    mostRecentTransactionState(transaction.transactionState)
  }
}
