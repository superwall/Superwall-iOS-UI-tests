//
//  UITests_Swift.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/13/23.
//

import UIKit
import SuperwallKit

final class UITests_Swift: NSObject, Testable {

  // Uses the identify function. Should see the name 'Jack' in the paywall.
  func test0() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Uses the identify function. Should see the name 'Kate' in the paywall.
  func test1() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test1a")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Set new identity
    Superwall.shared.identify(userId: "test1b")
    Superwall.shared.setUserAttributes([ "first_name": "Kate" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Calls `reset()`. No first name should be displayed.
  func test2() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Calls `reset()` multiple times. No first name should be displayed.
  func test3() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test3")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning with a 0 on the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and we want to capture the video as quickly as possible.
  func test4() async throws {
    // Present the paywall.
    Superwall.shared.track(event: "present_video")

    // Dismiss after 4 seconds
    await sleep(timeInterval: 4.0)
    await dismissViewControllers()

    // Present again after 1 second
    await sleep(timeInterval: 1.0)
    Superwall.shared.track(event: "present_video")

    await assert(after: 2.0, precision: .video, captureArea: .safeArea(captureHomeIndicator: false))
  }

  // Show paywall with override products. Paywall should appear with 2 products: 1 monthly at $12.99 and 1 annual at $99.99.
  func test5() async throws {
    guard let primary = StoreKitHelper.shared.monthlyProduct, let secondary = StoreKitHelper.shared.annualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let products = PaywallProducts(primary: StoreProduct(sk1Product: primary), secondary: StoreProduct(sk1Product: secondary))
    let paywallOverrides = PaywallOverrides(products: products)

    Superwall.shared.track(event: "present_products", paywallOverrides: paywallOverrides)

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  func test6() async throws {
    // Present the paywall.
    Superwall.shared.track(event: "present_products")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
#warning("File a ticket if not fixed in latest")
  func test7() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 14 ])
    Superwall.shared.track(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Remove those attributes.
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    Superwall.shared.track(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  func test8() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 12 ])
    Superwall.shared.track(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Present regardless of status
  #warning("not a valid test (shouldn't be setting without a PC")
  func test9() async throws {
//    canRun()

    skip("Rework test")
    return

    Superwall.shared.subscriptionStatus = .active
    Superwall.shared.track(event: "present_always")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
#warning("https://linear.app/superwall/issue/SW-1633/check-paywall-overrides-work")
  func test10() async throws {
    // Present the paywall.
    Superwall.shared.track(event: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.monthlyProduct, let secondary = StoreKitHelper.shared.annualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let products = PaywallProducts(primary: StoreProduct(sk1Product: primary), secondary: StoreProduct(sk1Product: secondary))
    let paywallOverrides = PaywallOverrides(products: products)

    Superwall.shared.track(event: "present_products", paywallOverrides: paywallOverrides)

    // Assert override products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present the paywall.
    Superwall.shared.track(event: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  // Clear a specific user attribute.
  func test11() async throws {
    Superwall.shared.setUserAttributes([ "first_name": "Claire" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": nil ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": "Sawyer" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Test trigger: off
  func test12() async throws {
    Superwall.shared.track(event: "keep_this_trigger_off")
    await assert(after: Constants.paywallPresentationDelay)
  }

  // Test trigger: not in the dashboard
  func test13() async throws {
    Superwall.shared.track(event: "i_just_made_this_up_and_it_dne")
    await assert(after: Constants.paywallPresentationDelay)
  }

  // Test trigger: not-allowed standard event (paywall_close)
  func test14() async throws {
    // Show a paywall
    Superwall.shared.track(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
    await assert(after: Constants.paywallPresentationDelay)
  }

  // Clusterfucks by Jake™
  func test15() async throws {
    Superwall.shared.track(event: "present_always")
    Superwall.shared.track(event: "present_always", params: ["some_param_1": "hello"])
    Superwall.shared.track(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.track(event: "present_always")
    Superwall.shared.identify(userId: "1111")
    Superwall.shared.track(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.track(event: "present_always") { state in
      switch state {
        case .presented(_):
          Superwall.shared.track(event: "present_always")
        default:
          return
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  // Present an alert on Superwall.presentedViewController from the onPresent callback
  func test16() async throws {
    Superwall.shared.track(event: "present_always") { state in
      switch state {
        case .presented(_):
          DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(action)
            Superwall.shared.presentedViewController?.present(alertController, animated: false)
          }
        default:
          return
      }
    }

    await assert(after: Constants.paywallPresentationDelay, precision: .transparency)
  }

  // Clusterfucks by Jake™
  func test17() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.track(event: "present_data")

    // Assert Jack displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Reset the user identity
    Superwall.shared.reset()

    Superwall.shared.track(event: "present_data")

    // Assert no name displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Present paywall
    Superwall.shared.track(event: "present_always")
    Superwall.shared.track(event: "present_always", params: ["some_param_1": "hello"])
    Superwall.shared.track(event: "present_always")

    // Assert Present Always paywall displayed.
    await assert(after: Constants.paywallPresentationDelay)
  }

  func test18() async throws {
    skip("Skipping this test for now")
    return
  }

  // Clusterfucks by Jake™
  func test19() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test19a")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    _ = await Superwall.shared.getPresentationResult(forEvent: "present_and_rule_user")

    // Dismiss any view controllers
    await dismissViewControllers()

    // Show a paywall
    Superwall.shared.track(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Set identity
    Superwall.shared.identify(userId: "test19b")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Set new identity
    Superwall.shared.identify(userId: "test19c")
    Superwall.shared.setUserAttributes([ "first_name": "Kate" ])
    Superwall.shared.track(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  func test20() async throws {
    // Present paywall with URLs
    Superwall.shared.track(event: "present_urls")

    await assert(after: Constants.paywallPresentationDelay)

    // Position of the perform button to open a URL in Safari
    let point = CGPoint(x: 358, y: 177)
    touch(point)

    // Verify that Safari has opened.
    await assert(after: Constants.paywallPresentationDelay, captureArea: .safari)

    // Relaunch the parent app.
    relaunch()

    // Ensure nothing has changed.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present the paywall and purchase; then make sure the paywall doesn't get presented again after the purchase
  func test21() async throws {
    Superwall.shared.track(event: "present_data")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 750)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button
    let subscribeButton = CGPoint(x: 196, y: 766)
    touch(subscribeButton)

    // Wait for subscribe to occur
    await sleep(timeInterval: Constants.paywallPresentationDelay)

    // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
    let okButton = CGPoint(x: 196, y: 495)
    touch(okButton)

    // Try to present paywall again
    Superwall.shared.track(event: "present_data")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Track an event shortly after another one is beginning to present. The session should not be cancelled out.
  func test22() async throws {
    skip("Skipping until we can read didTrackSuperwallEventInfo params")

    // TODO: Maybe clear attributes here? Don't want rules matching

    Superwall.shared.track(event: "present_data")

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
      Superwall.shared.track(event: "present_and_rule_user")
    }

    // TODO: Need to read the output of the didTrackSuperwallEventInfo params and check that trigger_session_id, experiment_id, and variant_id isn't nil.
  }

  /// Case: Unsubscribed user, register event without a gating handler
  /// Result: paywall should display
  func test23() async throws {
    // Register event
    Superwall.shared.register(event: "register_nongated_paywall")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Subscribed user, register event without a gating handler
  /// Result: paywall should NOT display
  func test24() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.annualProductIdentifier)

    // Register event
    Superwall.shared.register(event: "register_nongated_paywall")

    // Assert that paywall DOES not appear
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
  /// Result: paywall should display, after user subscribes, don't show another paywall
  func test25() async throws {
    Superwall.shared.register(event: "register_nongated_paywall")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 684)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button
    let subscribeButton = CGPoint(x: 196, y: 766)
    touch(subscribeButton)

    // Wait for subscribe to occur
    await sleep(timeInterval: Constants.paywallPresentationDelay)

    // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
    let okButton = CGPoint(x: 196, y: 495)
    touch(okButton)

    // Wait for dismiss
    await sleep(timeInterval: Constants.paywallPresentationDelay)

    // Try to present paywall again
    Superwall.shared.register(event: "register_nongated_paywall")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Unsubscribed user, register event with a gating handler
  /// Result: paywall should display, code in gating closure should not execute
  func test26() async throws {
    Superwall.shared.register(event: "register_gated_paywall") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let purchaseButton = CGPoint(x: 352, y: 65)
    touch(purchaseButton)

    // Assert that nothing else appars appears
    await assert(after: Constants.paywallPresentationDelay, captureArea: .safeArea(captureHomeIndicator: false))
  }

  /// Case: Subscribed user, register event with a gating handler
  /// Result: paywall should NOT display, code in gating closure should execute
  func test27() async throws {
    // Mock user as `subscribed`
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.annualProductIdentifier)

    Superwall.shared.register(event: "register_gated_paywall") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert that alert controller appears appears
    await assert(after: Constants.paywallPresentationDelay, captureArea: .safeArea(captureHomeIndicator: false))
  }

  #warning("change all to remove home indicator")

  /// Case: Airplane Mode
  /// Lifecycle handler

#warning("rewrite the below using UI assertions")

//  // MARK: - Get Track Result
//
//  func test_getPresentationResult_paywall() async throws {
//    let result = await Superwall.shared.getPresentationResult(forEvent: "present_data")
//    switch result {
//    case .paywall:
//      break
//    default:
//      XCTFail()
//    }
//  }
//
//  func test_getPresentationResult_eventNotFound() async throws {
//    let result = await Superwall.shared.getPresentationResult(forEvent: "a_random_madeup_event")
//    XCTAssertEqual(result, .eventNotFound)
//  }
//
//  func test_getPresentationResult_noRuleMatch() async throws {
//    let result = await Superwall.shared.getPresentationResult(forEvent: "present_and_rule_user")
//    XCTAssertEqual(result, .noRuleMatch)
//  }
//
//  func test_getPresentationResult_paywallNotAvailable() async throws {
//    let result = await Superwall.shared.getPresentationResult(forEvent: "incorrect_product_identifier")
//    XCTAssertEqual(result, .paywallNotAvailable)
//  }
//
//  func test_getPresentationResult_holdout() async throws {
//    let result = await Superwall.shared.getPresentationResult(forEvent: "holdout")
//    switch result {
//    case .holdout:
//      break
//    default:
//      XCTFail()
//    }
//  }

  // Missing the final case `userIsSubscribed`. This can be done when we are able to manually
  // set the subscription status using the purchaseController.

  // Make sure exit / refresh shows up if paywall.js isn’t installed on page
  //  func test17() async throws {
  //    Superwall.shared.track(event: "no_paywalljs")
  //    await assert(after: Constants.paywallPresentationFailureDelay)
  //  }

#warning("TODO: Might need to move to Waldo")
  // Open URLs in Safari, In-App, and Deep Link (closes paywall, then opens Placeholder view controller
  // Superwall.shared.track(event: "present_urls")
  // Test: not calling dismiss on main thread
  // Test whatever logic comes out of new track API
  //  22. Infinite loading
  //      1. make sure exit / refresh shows up if paywall.js isn’t installed on page
  //      2. make sure exit closes out for sure
  //      3. make sure refresh loads it again from a fresh start
  //      4. test this for modal + normal presentation + on nil + on another view controller
  // Test custom actions
  // Test localization based on system settings (-AppleLocale fr_FR)
  // Test localized paywall when available and unavailable using Superwall options
  // Swipe to dismiss a modal view and make sure new tracks function afterwards
}
