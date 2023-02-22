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
}

extension StoreKitHelper {
  struct Constants {
    static let monthlyProductIdentifier = "com.ui_tests.custom_monthly"
    static let annualProductIdentifier = "com.ui_tests.custom_annual"
  }
}

extension StoreKitHelper: SKProductsRequestDelegate {
  public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    if !response.products.isEmpty {
      products = response.products
      mostRecentFetch?()
    }
  }
}
