//
//  UITests_Swift.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/13/23.
//

import UIKit
import SuperwallKit

final class UITests_Swift: NSObject, Testable {
  /// Uses the identify function. Should see the name 'Jack' in the paywall.
  func test0() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Uses the identify function. Should see the name 'Kate' in the paywall.
  func test1() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test1a")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Set new identity
    Superwall.shared.identify(userId: "test1b")
    Superwall.shared.setUserAttributes([ "first_name": "Kate" ])
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Calls `reset()`. No first name should be displayed.
  func test2() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Calls `reset()` multiple times. No first name should be displayed.
  func test3() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test3")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning with a 0 on the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and we want to capture the video as quickly as possible.
  func test4() async throws {
    // Present the paywall.
    Superwall.shared.register(event: "present_video")

    // Dismiss after 4 seconds
    await sleep(timeInterval: 4.0)
    await dismissViewControllers()

    // Present again after 1 second
    await sleep(timeInterval: 1.0)
    Superwall.shared.register(event: "present_video")

    await assert(after: 2.0, precision: .video)
  }

  /// Show paywall with override products. Paywall should appear with 2 products: 1 monthly at $12.99 and 1 annual at $99.99.
  func test5() async throws {
    guard let primary = StoreKitHelper.shared.monthlyProduct, let secondary = StoreKitHelper.shared.annualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let products = PaywallProducts(primary: StoreProduct(sk1Product: primary), secondary: StoreProduct(sk1Product: secondary))
    let paywallOverrides = PaywallOverrides(products: products)

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  func test6() async throws {
    // Present the paywall.
    Superwall.shared.register(event: "present_products")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
  func test7() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 14 ])
    Superwall.shared.register(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Remove those attributes.
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    Superwall.shared.register(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  func test8() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 12 ])
    Superwall.shared.register(event: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present regardless of status
  func testOptions9() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test9() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    Superwall.shared.register(event: "present_always")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99. After dismiss, paywall should be presented again with override products: 1 monthly at $12.99 and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products. After dismiss, paywall should be presented one last time with no override products.
  func test10() async throws {
    // Present the paywall.
    Superwall.shared.register(event: "present_products")

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

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert override products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present the paywall.
    Superwall.shared.register(event: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_products", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clear a specific user attribute.
  func test11() async throws {
    Superwall.shared.setUserAttributes([ "first_name": "Claire" ])
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": nil ])
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": "Sawyer" ])
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: off
  func test12() async throws {
    Superwall.shared.register(event: "keep_this_trigger_off")
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: not in the dashboard
  func test13() async throws {
    Superwall.shared.register(event: "i_just_made_this_up_and_it_dne")
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: not-allowed standard event (paywall_close)
  func test14() async throws {
    // Show a paywall
    Superwall.shared.register(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clusterfucks by Jake™
  func test15() async throws {
    Superwall.shared.register(event: "present_always")
    Superwall.shared.register(event: "present_always", params: ["some_param_1": "hello"])
    Superwall.shared.register(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.register(event: "present_always")
    Superwall.shared.identify(userId: "1111")
    Superwall.shared.register(event: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    let handler = PaywallPresentationHandler()
    handler.onPresent { _ in
      Superwall.shared.register(event: "present_always")
    }
    Superwall.shared.register(event: "present_always", handler: handler)

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present an alert on Superwall.presentedViewController from the onPresent callback
  func test16() async throws {
    let handler = PaywallPresentationHandler()
    handler.onPresent { _ in
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        
        Superwall.shared.presentedViewController?.present(alertController, animated: false)
      }
    }
    Superwall.shared.register(event: "present_always", handler: handler)

    await assert(after: Constants.paywallPresentationDelay, precision: .transparency)
  }

  /// Clusterfucks by Jake™
  func test17() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.register(event: "present_data")

    // Assert Jack displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Reset the user identity
    Superwall.shared.reset()

    Superwall.shared.register(event: "present_data")

    // Assert no name displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Present paywall
    Superwall.shared.register(event: "present_always")
    Superwall.shared.register(event: "present_always", params: ["some_param_1": "hello"])
    Superwall.shared.register(event: "present_always")

    // Assert Present Always paywall displayed.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Open In-App Safari view controller from manually presented paywall
  func test18() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_urls", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Position of the perform button to open a URL in Safari
    let point = CGPoint(x: 330, y: 212)
    touch(point)

    // Verify that In-App Safari has opened
    await assert(after: Constants.paywallPresentationDelay)

    // Press the done button to go back
    let donePoint = CGPoint(x: 30, y: 70)
    touch(donePoint)

    // Verify that the paywall appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clusterfucks by Jake™
  func test19() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test19a")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    _ = await Superwall.shared.getPresentationResult(forEvent: "present_and_rule_user")

    // Dismiss any view controllers
    await dismissViewControllers()

    // Show a paywall
    Superwall.shared.register(event: "present_always")

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
    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Verify that external URLs can be opened in native Safari from paywall
  func test20() async throws {
    // Present paywall with URLs
    Superwall.shared.register(event: "present_urls")

    await assert(after: Constants.paywallPresentationDelay)

    // Position of the perform button to open a URL in Safari
    let point = CGPoint(x: 330, y: 136)
    touch(point)

    // Verify that Safari has opened.
    await assert(after: Constants.paywallPresentationDelay, captureArea: .safari)

    // Relaunch the parent app.
    await relaunch()

    // Ensure nothing has changed.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present the paywall and purchase; then make sure the paywall doesn't get presented again after the purchase
  func test21() async throws {
    Superwall.shared.register(event: "present_data")

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
    Superwall.shared.register(event: "present_data")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Track an event shortly after another one is beginning to present. The session should not be cancelled out.
  func test22() async throws {
    skip("Skipping until we can read didTrackSuperwallEventInfo params")
    return

    // TODO: Maybe clear attributes here? Don't want rules matching

    Superwall.shared.register(event: "present_data")

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
      Superwall.shared.register(event: "present_and_rule_user")
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
  func testOptions24() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test24() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

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
    let purchaseButton = CGPoint(x: 196, y: 748)
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

    // Assert that alert does not appear
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 352, y: 65)
    touch(closeButton)

    // Assert that nothing else appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Subscribed user, register event with a gating handler
  /// Result: paywall should NOT display, code in gating closure should execute
  func testOptions27() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test27() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    Superwall.shared.register(event: "register_gated_paywall") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert that alert controller appears appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Presentation result: `paywall`
  func test28() async {
    let result = await Superwall.shared.getPresentationResult(forEvent: "present_data")
    await assert(value: result.description)
  }

  /// Presentation result: `noRuleMatch`
  func test29() async {
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    let result = await Superwall.shared.getPresentationResult(forEvent: "present_and_rule_user")
    await assert(value: result.description)
  }

  /// Presentation result: `eventNotFound`
  func test30() async {
    let result = await Superwall.shared.getPresentationResult(forEvent: "some_random_not_found_event")
    await assert(value: result.description)
  }

  /// Presentation result: `holdOut`
  func test31() async {
    let result = await Superwall.shared.getPresentationResult(forEvent: "holdout")
    await assert(value: result.description)
  }

  // Presentation result: `userIsSubscribed`
  func testOptions32() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test32() async {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    let result = await Superwall.shared.getPresentationResult(forEvent: "present_data")
    await assert(value: result.description)
  }

  /// Call identify twice with the same ID before presenting a paywall
  func test33() async {
    // Set identity
    Superwall.shared.identify(userId: "test33")
    Superwall.shared.identify(userId: "test33")

    Superwall.shared.register(event: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Call reset while a paywall is displayed should not cause a crash
  func test34() async {
    Superwall.shared.register(event: "present_data")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)

    // Call reset while it is still on screen
    Superwall.shared.reset()

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Finished purchase with a result type of `purchased`
  func test35() async {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_data", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
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

    // Assert paywall didFinish result value ("purchased")
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// Finished purchase with a result type of `declined`
  func test36() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_data", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 346, y: 54)
    touch(closeButton)

    // Assert paywall result value ("declined")
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// Finished purchase with a result type of `restored`
  func test37() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "restore", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    // Press restore
    let restoreButton = CGPoint(x: 200, y: 232)
    touch(restoreButton)

    // Assert paywall result value
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// Finished purchase with a result type of `purchased` and then swiping the paywall view controller away
  func test38() async {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_data", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .pageSheet
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
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

    // Assert paywall result value ("purchased")
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)

    // Modify the paywall result value
    paywallDidFinishResultValueHolder.stringValue = "empty value"

    // Swipe the paywall down to dismiss
    swipeDown()

    // Assert the paywall was dismissed (and waits to see if the delegate got called again)
    await assert(after: Constants.paywallPresentationDelay)

    // Assert paywall result value ("empty value")
    await assert(value: paywallDidFinishResultValueHolder.stringValue)
  }

  /// Finished restore with a result type of `restored` and then swiping the paywall view controller away (does it get called twice?)
  func test39() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "restore", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .pageSheet
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    // Press restore
    let restoreButton = CGPoint(x: 214, y: 292)
    touch(restoreButton)

    // Assert paywall finished result value ("restored")
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)

    // Modify the paywall result value
    paywallDidFinishResultValueHolder.stringValue = "empty value"

    // Swipe the paywall down to dismiss
    swipeDown()

    // Assert the paywall was dismissed (and waits to see if the delegate got called again)
    await assert(after: Constants.paywallPresentationDelay)

    // Assert paywall result value ("empty value")
    await assert(value: paywallDidFinishResultValueHolder.stringValue)
  }

  /// Paywall disappeared with a result type of `declined` by swiping the paywall view controller away
  func test40() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forEvent: "present_data", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .pageSheet
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Swipe the paywall down to dismiss
    swipeDown()

    // Assert the paywall was dismissed
    await assert(after: Constants.paywallPresentationDelay)

    // Assert paywall result value ("declined")
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// https://www.notion.so/superwall/No-internet-feature-gating-b383af91a0fc49d9b7402d1cf09ada6a?pvs=4
  #warning("change `subscribed` param to product id")
  func executeRegisterFeatureClosureTest(subscribed: Bool, gated: Bool, testName: String = #function) async {
    // Mock user as subscribed
    if subscribed {
      // Mock user as subscribed
      await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)
    }

    // Determine gating event
    let event: String = {
      if gated {
        return "register_gated_paywall"
      } else {
        return "register_nongated_paywall"
      }
    }()

    // Create paywall presentation handler
    let errorHandlerHolder = ValueDescriptionHolder()
    errorHandlerHolder.stringValue = "No"

    let paywallPresentationHandler = PaywallPresentationHandler()
    paywallPresentationHandler.onError { error in
      errorHandlerHolder.intValue += 1
      errorHandlerHolder.stringValue = "Yes"
    }

    // Keep a reference to the value
    let featureClosureHolder = ValueDescriptionHolder()
    featureClosureHolder.stringValue = "No"

    Superwall.shared.register(event: event, handler: paywallPresentationHandler) {
      DispatchQueue.main.async {
        featureClosureHolder.intValue += 1
        featureClosureHolder.stringValue = "Yes"
      }
    }

    // Assert paywall visibility
    await assert(after: Constants.paywallPresentationDelay, testName: testName)

    // Assert error handler execution
    await assert(value: errorHandlerHolder.description, after: Constants.paywallPresentationDelay, testName: testName)

    // Assert feature closure execution
    await assert(value: featureClosureHolder.description, after: Constants.paywallPresentationDelay, testName: testName)
  }

  /// Unable to fetch config, not subscribed, and not gated.
  func testOptions41() -> TestOptions { return TestOptions(allowNetworkRequests: false) }
  func test41() async throws {
    await executeRegisterFeatureClosureTest(subscribed: false, gated: false)
  }

  /// Unable to fetch config, not subscribed, and gated.
  func testOptions42() -> TestOptions { return TestOptions(allowNetworkRequests: false) }
  func test42() async throws {
    await executeRegisterFeatureClosureTest(subscribed: false, gated: true)
  }

  /// Unable to fetch config, subscribed, and not gated.
  func testOptions43() -> TestOptions { return TestOptions(allowNetworkRequests: false, purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test43() async throws {
    await executeRegisterFeatureClosureTest(subscribed: true, gated: false)
  }

  /// Unable to fetch config, subscribed, and gated.
  func testOptions44() -> TestOptions { return TestOptions(allowNetworkRequests: false, purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test44() async throws {
    await executeRegisterFeatureClosureTest(subscribed: true, gated: true)
  }

  /// Fetched config, not subscribed, and not gated.
  func test45() async throws {
    await executeRegisterFeatureClosureTest(subscribed: false, gated: false)
  }

  /// Fetched config, not subscribed, and gated.
  func test46() async throws {
    await executeRegisterFeatureClosureTest(subscribed: false, gated: true)
  }

  /// Fetched config, subscribed, and not gated.
  func testOptions47() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test47() async throws {
    await executeRegisterFeatureClosureTest(subscribed: true, gated: false)
  }

  /// Fetched config, subscribed, and gated.
  func testOptions48() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test48() async throws {
    await executeRegisterFeatureClosureTest(subscribed: true, gated: true)
  }

  /// Present paywall from implicit trigger: `app_launch`.
  func testOptions49() -> TestOptions { return TestOptions(apiKey: Constants.appLaunchAPIKey) }
  func test49() async throws {
    // Assert paywall presented.
    await assert(after: Constants.implicitPaywallPresentationDelay)
  }

  /// Present paywall from implicit trigger: `session_start`.
  func testOptions50() -> TestOptions { return TestOptions(apiKey: Constants.sessionStartAPIKey) }
  func test50() async throws {
    // Assert paywall presented.
    await assert(after: Constants.implicitPaywallPresentationDelay)
  }

  /// Present paywall from implicit trigger: `app_install`.
  func testOptions51() -> TestOptions { return TestOptions(apiKey: Constants.appInstallAPIKey) }
  func test51() async throws {
    // Assert paywall presented.
    await assert(after: Constants.implicitPaywallPresentationDelay)
  }

  /// Verify `app_install` event occurs when the SDK is configured for the first time, and directly after calling Superwall.shared.reset()
  #warning("Is this supposed to work after reset? Ask Yusuf")
  func test52() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let appInstallEventHolder = ValueDescriptionHolder()
    appInstallEventHolder.stringValue = "No"

    // Respond to Superwall events
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
        case .appInstall:
          appInstallEventHolder.intValue += 1
          appInstallEventHolder.stringValue = "Yes"
        default:
          return
      }
    }

    // Close and reopen app after 3 seconds
    await springboard()
    await sleep(timeInterval: 3)
    await relaunch()

    // Assert that `.appInstall` was called once
    await assert(value: appInstallEventHolder.description, after: Constants.implicitPaywallPresentationDelay)
  }

  /// Verify `app_launch` event occurs whenever app is launched from a cold start
  func test53() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let appLaunchEventHolder = ValueDescriptionHolder()
    appLaunchEventHolder.stringValue = "No"

    // Respond to Superwall events
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
        case .appLaunch:
          appLaunchEventHolder.intValue += 1
          appLaunchEventHolder.stringValue = "Yes"
        default:
          return
      }
    }

    // Close and reopen app
    await springboard()
    await relaunch()

    // Assert that `.appLaunch` was called once
    await assert(value: appLaunchEventHolder.description, after: Constants.implicitPaywallPresentationDelay)
  }

  /// Verify `session_start` event occurs when the app is opened either from a cold start, or after at least 30 seconds since last `app_close`.
  func test54() async throws {
    skip("Fixed in another branch")
    return

    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let sessionStartEventHolder = ValueDescriptionHolder()
    sessionStartEventHolder.stringValue = "No"

    // Respond to Superwall events
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
        case .sessionStart:
          sessionStartEventHolder.intValue += 1
          sessionStartEventHolder.stringValue = "Yes"
        default:
          return
      }
    }

    // Assert that `.sessionStart` was called once
    await assert(value: sessionStartEventHolder.description, after: Constants.implicitPaywallPresentationDelay)
  }

  /// Verify `app_close` anytime the app leaves the foreground and `app_open` anytime the app enters the foreground
  func test55() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let appOpenEventHolder = ValueDescriptionHolder()
    appOpenEventHolder.stringValue = "No"

    // Create value handler
    let appCloseEventHolder = ValueDescriptionHolder()
    appCloseEventHolder.stringValue = "No"

    // Respond to Superwall events
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .appClose:
        appCloseEventHolder.intValue += 1
        appCloseEventHolder.stringValue = "Yes"
      case .appOpen:
        appOpenEventHolder.intValue += 1
        appOpenEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Close app
    await springboard()

    // Assert that `.appClose` was called once
    await assert(value: appCloseEventHolder.description, after: Constants.implicitPaywallPresentationDelay)

     // Re-open app
     await relaunch()

    // Assert that `.appOpen` was called once
    await assert(value: appOpenEventHolder.description, after: Constants.implicitPaywallPresentationDelay)
  }


  func test56() async throws {
    skip("Implement")
    return

    //    - subscription_start
    //    - freeTrial_start
    //    - nonRecurringProduct_purchase
    //    - transaction_start
    //    - transaction_abandon
    //    - transaction_fail
    //    - transaction_restore
    //    - transaction_complete
    //    - paywall_close
    //    - paywall_open
    //    - paywallWebviewLoad_start
    //    - paywallWebviewLoad_fail
    //    - paywallWebviewLoad_timeout
    //    - paywallWebviewLoad_complete
    //    - trigger_fire
    //    - paywallResponseLoad_start
    //    - paywallResponseLoad_fail
    //    - paywallResponseLoad_complete
    //    - paywallResponseLoad_notFound
    //    - paywallProductsLoad_start
    //    - paywallProductsLoad_fail
    //    - paywallProductsLoad_complete
    //    - user_attributes
    //    - subscriptionStatus_didChange
    //    - paywallPresentationRequest
    //    - deepLink_open

  }

  // Display paywall with free trial content, make a free trial purchase, force trial to expire. Ensure that free trial content is no longer used
  func test57() async throws {
    skip("Need to add mechanism for restart")
    return

    Superwall.shared.register(event: "present_free_trial")

    // Assert that paywall appears with free trial content
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

    // Expire subscription
    await expireSubscription(productIdentifier: StoreKitHelper.Constants.freeTrialProductIdentifier)

    #warning("need to restart before continuing here")

    // Try to present paywall again
    Superwall.shared.register(event: "present_free_trial")

    // Assert that paywall appears without free trial content
    await assert(after: Constants.paywallPresentationDelay)
  }


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
