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
  // The runner's SKTestSession hands its configuration to storekitd
  // asynchronously; until it lands, product requests come back empty.
  private let maxRetries = 20

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

  // An SKProductsRequest can only be started once, so each attempt gets a new one.
  private var productsRequest: SKProductsRequest?

  private func startProductsRequest() {
    let request = SKProductsRequest(productIdentifiers: [Constants.customMonthlyProductIdentifier, Constants.customAnnualProductIdentifier])
    request.delegate = self
    productsRequest = request
    request.start()
  }

  // Resumes the pending fetch at most once. Only touched on the main queue.
  private var mostRecentFetch: (() -> Void)?

  private func finishFetch() {
    DispatchQueue.main.async {
      self.mostRecentFetch?()
      self.mostRecentFetch = nil
    }
  }

  @objc public func fetchCustomProducts() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.main.async {
        self.retryCount = 0
        // Store the continuation before starting the request: the delegate can
        // respond on another thread before `start()` even returns.
        self.mostRecentFetch = { continuation.resume() }
        self.startProductsRequest()

        // StoreKit can silently never answer; never let that hang a test.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
          guard let self, self.mostRecentFetch != nil else { return }
          print("❌ StoreKit products request timed out.")
          self.mostRecentFetch?()
          self.mostRecentFetch = nil
        }
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
          self?.startProductsRequest()
        }
        return  // Return but continuation will be resumed by retry
      }

      // Failed after all retries - still need to resume continuation
      print("❌ Failed to receive products in StoreKit helper after \(maxRetries) retries.")

      // Resume continuation even on failure so test doesn't hang
      finishFetch()
      return
    }

    // Success - reset retry counter and store products
    retryCount = 0
    let loadedProducts = response.products
    print("✅ StoreKit products loaded successfully: \(loadedProducts.map { $0.productIdentifier })")
    DispatchQueue.main.async {
      self.products = loadedProducts
    }
    finishFetch()
  }

  public func request(_ request: SKRequest, didFailWithError error: Error) {
    print("❌ StoreKit request failed with error: \(error.localizedDescription)")

    // Retry on error as well
    if retryCount < maxRetries {
      retryCount += 1
      print("⚠️ Retrying StoreKit request... (attempt \(retryCount)/\(maxRetries))")

      // Don't return here - the retry will call delegate method again
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.startProductsRequest()
      }
      return  // Return but continuation will be resumed by retry
    }

    // Failed after all retries - still need to resume continuation
    print("❌ Failed after \(maxRetries) retries: \(error.localizedDescription)")

    // Resume continuation even on failure so test doesn't hang
    finishFetch()
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
