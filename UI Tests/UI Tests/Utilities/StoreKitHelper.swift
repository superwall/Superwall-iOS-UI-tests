//
//  StoreKitHelper.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/6/23.
//

import Foundation
import StoreKit

class StoreKitHelper: NSObject {
  static let shared: StoreKitHelper = StoreKitHelper()

  private(set) var products = [SKProduct]()

  var monthlyProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.monthlyProductIdentifier })
  }

  var annualProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.annualProductIdentifier })
  }

  private lazy var productsRequest: SKProductsRequest = {
    let request = SKProductsRequest(productIdentifiers: [Constants.monthlyProductIdentifier, Constants.annualProductIdentifier])
    request.delegate = self
    return request
  }()

  func fetchCustomProducts() {
    productsRequest.start()
  }
}

extension StoreKitHelper {
  struct Constants {
    static let monthlyProductIdentifier = "com.ui_tests.custom_monthly"
    static let annualProductIdentifier = "com.ui_tests.custom_annual"
  }
}

extension StoreKitHelper: SKProductsRequestDelegate {
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
      if !response.products.isEmpty {
         products = response.products
      }
  }
}
