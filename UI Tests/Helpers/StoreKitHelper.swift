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
  private var retryCount = 0
  private let maxRetries = 3

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  @objc public var sk1MonthlyProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.customMonthlyProductIdentifier })
  }

  @objc public var sk1AnnualProduct: SKProduct? {
    return products.first(where: { $0.productIdentifier == Constants.customAnnualProductIdentifier })
  }

  public func getSk2MonthlyProduct() async -> StoreKit.Product? {
    return try? await StoreKit.Product.products(for: [Constants.customMonthlyProductIdentifier]).first
  }

  public func getSk2AnnualProduct() async -> StoreKit.Product? {
    return try? await StoreKit.Product.products(for: [Constants.customAnnualProductIdentifier]).first
  }

  private lazy var productsRequest: SKProductsRequest = {
    let request = SKProductsRequest(productIdentifiers: [Constants.customMonthlyProductIdentifier, Constants.customAnnualProductIdentifier])
    request.delegate = self
    return request
  }()

  var mostRecentFetch: (() -> Void)?

  @objc public func fetchCustomProducts() async {
    retryCount = 0  // Reset retry counter for each new fetch attempt
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


  public func purchase(product: StoreProduct) async -> PurchaseResult {
    if let product = product.sk1Product {
      let payment = SKPayment(product: product)
      SKPaymentQueue.default().add(payment)

      return await withCheckedContinuation { continuation in
        mostRecentPurchaseResult = { [weak self] state in
          continuation.resume(returning: state)
          self?.mostRecentPurchaseResult = nil
        }
      }
    } else if let product = product.sk2Product {
      do {
        let result = try await product.purchase()
        switch result {
        case .pending:
          return .pending
        case .success(let verificationResult):
          switch verificationResult {
          case .verified:
            return .purchased
          case .unverified(_, let error):
            return .failed(error)
          }
        case .userCancelled:
          return .cancelled
        @unknown default:
          return .cancelled
        }
      } catch {
        return .failed(error)
      }
    }
    return .cancelled
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
      // Retry if we haven't exceeded max retries
      if retryCount < maxRetries {
        retryCount += 1
        print("⚠️ StoreKit products empty, retrying... (attempt \(retryCount)/\(maxRetries))")

        // Wait a bit before retrying to give SKTestSession time to initialize
        // Don't return here - the retry will call this delegate method again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
          self?.productsRequest.start()
        }
        return  // Return but continuation will be resumed by retry
      }

      // Failed after all retries - still need to resume continuation
      print("❌ Failed to receive products in StoreKit helper after \(maxRetries) retries.")
      assertionFailure("Failed to receive products in StoreKit helper after \(maxRetries) retries. Make sure Automated UI Testing has been setup with an `SKTestSession` instance *before* the app has been installed.")

      // Resume continuation even on failure so test doesn't hang
      mostRecentFetch?()
      return
    }

    // Success - reset retry counter and store products
    retryCount = 0
    products = response.products
    print("✅ StoreKit products loaded successfully: \(response.products.map { $0.productIdentifier })")
    mostRecentFetch?()
  }

  public func request(_ request: SKRequest, didFailWithError error: Error) {
    print("❌ StoreKit request failed with error: \(error.localizedDescription)")

    // Retry on error as well
    if retryCount < maxRetries {
      retryCount += 1
      print("⚠️ Retrying StoreKit request... (attempt \(retryCount)/\(maxRetries))")

      // Don't return here - the retry will call delegate method again
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.productsRequest.start()
      }
      return  // Return but continuation will be resumed by retry
    }

    // Failed after all retries - still need to resume continuation
    print("❌ Failed after \(maxRetries) retries: \(error.localizedDescription)")
    assertionFailure("Failed to receive products in StoreKit helper after \(maxRetries) retries: \(error.localizedDescription)")

    // Resume continuation even on failure so test doesn't hang
    mostRecentFetch?()
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
