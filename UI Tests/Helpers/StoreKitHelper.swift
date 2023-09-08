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
//    guard response.products.isEmpty == false else {
//      assertionFailure("Failed to receive products in StoreKit helper. Make sure Automated UI Testing has been setup with an `SKTestSession` instance *before* the app has been installed.")
//      return
//    }

    let product1 = CustomSKProduct(
        localizedDescription: "",
        localizedTitle: "",
        price: NSDecimalNumber(decimal: Decimal(99.99)),
        priceLocale: Locale(identifier: ""),
        productIdentifier: "com.ui_tests.custom_annual",
        isDownloadable: false,
        isFamilyShareable: false,
        downloadContentLengths: [],
        contentVersion: "",
        downloadContentVersion: "",  // This value wasn't provided in the debug info, so a placeholder is used
        subscriptionGroupIdentifier: "4F31BE19",
        discounts: []
    )

    let product2 = CustomSKProduct(
        localizedDescription: "",
        localizedTitle: "",
        price: NSDecimalNumber(decimal: Decimal(12.99)),
        priceLocale: Locale(identifier: ""),
        productIdentifier: "com.ui_tests.custom_monthly",
        isDownloadable: false,
        isFamilyShareable: false,
        downloadContentLengths: [],
        contentVersion: "",
        downloadContentVersion: "",
        subscriptionGroupIdentifier: "4F31BE19",
        discounts: []
    )

//    products = response.products
    products = [product1, product2]
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

class CustomSKProduct: SKProduct {
    private var _localizedDescription: String
    private var _localizedTitle: String
    private var _price: NSDecimalNumber
    private var _priceLocale: Locale
    private var _productIdentifier: String
    private var _isDownloadable: Bool
    private var _isFamilyShareable: Bool
    private var _downloadContentLengths: [NSNumber]
    private var _contentVersion: String
    private var _downloadContentVersion: String
    private var _subscriptionPeriod: SKProductSubscriptionPeriod?
    private var _introductoryPrice: SKProductDiscount?
    private var _subscriptionGroupIdentifier: String?
    private var _discounts: [SKProductDiscount]

    init(
        localizedDescription: String,
        localizedTitle: String,
        price: NSDecimalNumber,
        priceLocale: Locale,
        productIdentifier: String,
        isDownloadable: Bool = false,
        isFamilyShareable: Bool = false,
        downloadContentLengths: [NSNumber] = [],
        contentVersion: String,
        downloadContentVersion: String,
        subscriptionPeriod: SKProductSubscriptionPeriod? = nil,
        introductoryPrice: SKProductDiscount? = nil,
        subscriptionGroupIdentifier: String? = nil,
        discounts: [SKProductDiscount] = []
    ) {
        self._localizedDescription = localizedDescription
        self._localizedTitle = localizedTitle
        self._price = price
        self._priceLocale = priceLocale
        self._productIdentifier = productIdentifier
        self._isDownloadable = isDownloadable
        self._isFamilyShareable = isFamilyShareable
        self._downloadContentLengths = downloadContentLengths
        self._contentVersion = contentVersion
        self._downloadContentVersion = downloadContentVersion
        self._subscriptionPeriod = subscriptionPeriod
        self._introductoryPrice = introductoryPrice
        self._subscriptionGroupIdentifier = subscriptionGroupIdentifier
        self._discounts = discounts
    }

    override var localizedDescription: String { _localizedDescription }
    override var localizedTitle: String { _localizedTitle }
    override var price: NSDecimalNumber { _price }
    override var priceLocale: Locale { _priceLocale }
    override var productIdentifier: String { _productIdentifier }
    override var isDownloadable: Bool { _isDownloadable }
    override var isFamilyShareable: Bool { _isFamilyShareable }
    override var downloadContentLengths: [NSNumber] { _downloadContentLengths }
    override var contentVersion: String { _contentVersion }
    override var downloadContentVersion: String { _downloadContentVersion }
    override var subscriptionPeriod: SKProductSubscriptionPeriod? { _subscriptionPeriod }
    override var introductoryPrice: SKProductDiscount? { _introductoryPrice }
    override var subscriptionGroupIdentifier: String? { _subscriptionGroupIdentifier }
    override var discounts: [SKProductDiscount] { _discounts }
}
