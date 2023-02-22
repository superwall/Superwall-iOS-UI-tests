//
//  SnapshotTests-Swift.swift
//  Automated Snapshot Testing
//
//  Created by Bryan Dubno on 2/13/23.
//

import XCTest
import SuperwallKit

final class SnapshotTests_Swift: XCTestCase {
  let delegate: MockDelegate = MockDelegate()

  private static var hasConfigured: Bool = false

  override func setUp() async throws {
    guard Self.hasConfigured == false else { return }
    Self.hasConfigured = true

    let options = SuperwallOptions()

    // https://superwall.com/applications/1270
    Superwall.configure(apiKey: "pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2", options: options)
    Superwall.shared.delegate = MockDelegate()

    // Set status
    Superwall.shared.subscriptionStatus = .inactive

    // Begin fetching products for use in other test cases
    await StoreKitHelper.shared.fetchCustomProducts()
  }

  override func tearDown() async throws {
    // Reset status
    Superwall.shared.subscriptionStatus = .inactive

    // Dismiss any view controllers
    await dismissViewControllers()

    // Remove delegate observers
    delegate.removeObservers()
  }

  // Uses the identify function. Should see the name 'Jack' in the paywall.
  func test0() async {
    try? await Superwall.shared.identify(userId: "test0")
    await Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Uses the identify function. Should see the name 'Kate' in the paywall.
  func test1() async {
    // Set identity
    try? await Superwall.shared.identify(userId: "test1a")
    await Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Set new identity
    try? await Superwall.shared.identify(userId: "test1b")
    await Superwall.shared.setUserAttributes([ "first_name": "Kate" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Calls `reset()`. No first name should be displayed.
  func test2() async {
    // Set identity
    try? await Superwall.shared.identify(userId: "test2")
    await Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    await Superwall.shared.reset()
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Calls `reset()` multiple times. No first name should be displayed.
  func test3() async {
    // Set identity
    try? await Superwall.shared.identify(userId: "test3")
    await Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    await Superwall.shared.reset()
    await Superwall.shared.reset()
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning with a 0 on the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and we want to capture the video as quickly as possible.
  func test4() async {
    // Present the paywall.
    Superwall.shared.track(event: "present_video")

    // Dismiss after 4 seconds
    await sleep(timeInterval: 4.0)
    Superwall.shared.dismiss()

    // Present again after 1 second
    await sleep(timeInterval: 1.0)
    Superwall.shared.track(event: "present_video")

    await assert(after: 2.0, precision: false)
  }

  // Show paywall with override products. Paywall should appear with 2 products: 1 monthly at $12.99 and 1 annual at $99.99.
  func test5() async {
    guard let primary = StoreKitHelper.shared.monthlyProduct, let secondary = StoreKitHelper.shared.annualProduct else {
      XCTAssert(false, "WARNING: Unable to fetch custom products. These are needed for testing.")
      return
    }

    let products = PaywallProducts(primary: StoreProduct(sk1Product: primary), secondary: StoreProduct(sk1Product: secondary))
    let paywallOverrides = PaywallOverrides(products: products)

    Superwall.shared.track(event: "present_products", paywallOverrides: paywallOverrides)

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  func test6() async {
    // Present the paywall.
    Superwall.shared.track(event: "present_products")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12
  func test7() async {
    try? await Superwall.shared.identify(userId: "test7")
    await Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 14 ])
    Superwall.shared.track(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  func test8() async {
    try? await Superwall.shared.identify(userId: "test7")
    await Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 12 ])
    Superwall.shared.track(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Present regardless of status
  func test9() async {
    Superwall.shared.subscriptionStatus = .active
    Superwall.shared.track(event: "present_always")

    await assert(after: Constants.paywallPresentationDelay)
  }


#warning("TODO")
// Open URLs in Safari, In-App, and Deep Link (closes paywall, then opens Placeholder view controller
// Superwall.shared.track(event: "present_urls")
// Test: present paywall, then present with overrides, the present original again

}

// MARK: - Constants

extension SnapshotTests_Swift {
  struct Constants {
    static let paywallPresentationDelay: TimeInterval = 8.0
  }
}

// MARK: - Constants

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


////      // 13
////      Test(
////        title: "Open URLs",
////        body: "Open URLs in Safari, In-App, and Deep Link (closes paywall, then opens Placeholder view controller)",
////        perform: { invokeAssertion in
////          Superwall.shared.track(event: "present_urls")
////        }
////      ),
//
////      // Uncomment, Right-click > Create Code Snippet to add to Xcode as a code snippet. Choose a "Completion" for easy additions.
////      // <#Test Number#>
////      Test(
////        title: <#T##String#>,
////        body: <#T##String#>,
////        perform: <#T##() -> Void#>
////      ),
//
//    ]
//
//
//  }()
//}
