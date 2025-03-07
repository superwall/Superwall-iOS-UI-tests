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
    Superwall.shared.register(placement: "present_data")

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
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Calls `reset()`. No first name should be displayed.
  func test2() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Calls `reset()` multiple times. No first name should be displayed.
  func test3() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test3")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video
  /// at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close.
  /// This paywall should have a video playing and should be started from the beginning with a 0 on
  /// the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and
  /// we want to capture the video as quickly as possible.
  func test4() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_video")

    // Dismiss after 4 seconds
    await sleep(timeInterval: 4.0)
    await dismissViewControllers()

    // Present again after 1 second
    await sleep(timeInterval: 1.0)
    Superwall.shared.register(placement: "present_video")

    await assert(after: 2.0, precision: .video)
  }

  /// Show paywall with override products using SK1. Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  func testOptions5() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test5() async throws {
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
  func test7() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 14 ])
    Superwall.shared.register(placement: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Remove those attributes.
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    Superwall.shared.register(placement: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  func test8() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 12 ])
    Superwall.shared.register(placement: "present_and_rule_user")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present regardless of status
  func testOptions9() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test9() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    Superwall.shared.register(placement: "present_always")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  func testOptions10() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test10() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", delegate: delegate) {
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
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": nil ])
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": "Sawyer" ])
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: off
  func test12() async throws {
    Superwall.shared.register(placement: "keep_this_trigger_off")
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: not in the dashboard
  func test13() async throws {
    Superwall.shared.register(placement: "i_just_made_this_up_and_it_dne")
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: not-allowed standard event (paywall_close)
  func test14() async throws {
    // Show a paywall
    Superwall.shared.register(placement: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clusterfucks by Jake™
  func test15() async throws {
    Superwall.shared.register(placement: "present_always")
    Superwall.shared.register(placement: "present_always", params: ["some_param_1": "hello"])
    Superwall.shared.register(placement: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.register(placement: "present_always")
    Superwall.shared.identify(userId: "1111")
    Superwall.shared.register(placement: "present_always")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    let handler = PaywallPresentationHandler()

    var experimentId = ""
    handler.onPresent { info in
      experimentId = info.experiment?.id ?? ""
      Superwall.shared.register(placement: "present_always")
    }
    Superwall.shared.register(placement: "present_always", handler: handler)

    await assert(after: Constants.paywallPresentationDelay)
    await assert(value: experimentId)
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
    Superwall.shared.register(placement: "present_always", handler: handler)

    await assert(after: Constants.paywallPresentationDelay, precision: .transparency)
  }

  /// Clusterfucks by Jake™
  func test17() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.register(placement: "present_data")

    // Assert Jack displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Reset the user identity
    Superwall.shared.reset()

    Superwall.shared.register(placement: "present_data")

    // Assert no name displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Present paywall
    Superwall.shared.register(placement: "present_always")
    Superwall.shared.register(placement: "present_always", params: ["some_param_1": "hello"])
    Superwall.shared.register(placement: "present_always")

    // Assert Present Always paywall displayed.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Open In-App Safari view controller from manually presented paywall
  func test18() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_urls", delegate: delegate) {
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
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    _ = await Superwall.shared.getPresentationResult(forPlacement: "present_and_rule_user")

    // Dismiss any view controllers
    await dismissViewControllers()

    // Show a paywall
    Superwall.shared.register(placement: "present_always")

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
    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Verify that external URLs can be opened in native Safari from paywall
  func test20() async throws {
    // Present paywall with URLs
    Superwall.shared.register(placement: "present_urls")

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
  func testOptions21() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test21() async throws {
    Superwall.shared.register(placement: "present_data")

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
    Superwall.shared.register(placement: "present_data")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Track an event shortly after another one is beginning to present. The session should not be cancelled out.
  func test22() async throws {
    skip("Skipping until we can read didTrackSuperwallEventInfo params")
    return

    // TODO: Maybe clear attributes here? Don't want rules matching

    Superwall.shared.register(placement: "present_data")

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
      Superwall.shared.register(placement: "present_and_rule_user")
    }

    // TODO: Need to read the output of the didTrackSuperwallEventInfo params and check that trigger_session_id, experiment_id, and variant_id isn't nil.
  }

  /// Case: Unsubscribed user, register event without a gating handler
  /// Result: paywall should display
  func test23() async throws {
    // Register event
    Superwall.shared.register(placement: "register_nongated_paywall")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Subscribed user, register event without a gating handler
  /// Result: paywall should NOT display
  func testOptions24() -> TestOptions {
    return TestOptions(
      purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier
    )
  }
  func test24() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    // Register event
    Superwall.shared.register(placement: "register_nongated_paywall")

    // Assert that paywall DOES not appear
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
  /// Result: paywall should display, after user subscribes, don't show another paywall
  func testOptions25() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test25() async throws {
    Superwall.shared.register(placement: "register_nongated_paywall")

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
    Superwall.shared.register(placement: "register_nongated_paywall")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Unsubscribed user, register event with a gating handler
  /// Result: paywall should display, code in gating closure should not execute
  func test26() async throws {
    Superwall.shared.register(placement: "register_gated_paywall") {
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

    Superwall.shared.register(placement: "register_gated_paywall") {
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
    let result = await Superwall.shared.getPresentationResult(forPlacement: "present_data")
    await assert(value: result.description)
  }

  /// Presentation result: `noRuleMatch`
  func test29() async {
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    let result = await Superwall.shared.getPresentationResult(forPlacement: "present_and_rule_user")
    await assert(value: result.description)
  }

  /// Presentation result: `eventNotFound`
  func test30() async {
    let result = await Superwall.shared.getPresentationResult(forPlacement: "some_random_not_found_event")
    await assert(value: result.description)
  }

  /// Presentation result: `holdOut`
  func test31() async {
    let result = await Superwall.shared.getPresentationResult(forPlacement: "holdout")
    await assert(value: result.description)
  }

  // Presentation result: `userIsSubscribed`
  func testOptions32() -> TestOptions {
    return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)
  }
  func test32() async {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    let result = await Superwall.shared.getPresentationResult(forPlacement: "present_data")
    await assert(value: result.description)
  }

  /// Call identify twice with the same ID before presenting a paywall
  func test33() async {
    // Set identity
    Superwall.shared.identify(userId: "test33")
    Superwall.shared.identify(userId: "test33")

    Superwall.shared.register(placement: "present_data")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Call reset while a paywall is displayed should not cause a crash
  func test34() async {
    Superwall.shared.register(placement: "present_data")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)

    // Call reset while it is still on screen
    Superwall.shared.reset()

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Finished purchase with a result type of `purchased`
  func testOptions35() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test35() async {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_data", delegate: delegate) {
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

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_data", delegate: delegate) {
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
  func testOptions37() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test37() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore", delegate: delegate) {
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
  func testOptions38() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test38() async {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_data", delegate: delegate) {
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
  func testOptions39() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test39() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore", delegate: delegate) {
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

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_data", delegate: delegate) {
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

    Superwall.shared.register(placement: event, handler: paywallPresentationHandler) {
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

  /// https://www.notion.so/superwall/No-internet-feature-gating-b383af91a0fc49d9b7402d1cf09ada6a?pvs=4
#warning("change `subscribed` param to product id")
  func executeRegisterFeatureClosureTestWithV4Paywall(subscribed: Bool, gated: Bool, testName: String = #function) async {
    // Mock user as subscribed
    if subscribed {
      // Mock user as subscribed
      await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)
    }

    // Determine gating event
    let event: String = {
      if gated {
        return "register_gated_paywall_v4"
      } else {
        return "register_nongated_paywall_v4"
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

    Superwall.shared.register(placement: event, handler: paywallPresentationHandler) {
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
  func testOptions43() -> TestOptions {
    return TestOptions(allowNetworkRequests: false, purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
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

  /// Verify `app_install` event occurs when the SDK is configured for the first time
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

    // Respond to Superwall placements
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

  /// Verify `session_start` event occurs when the app is opened from a cold start.
  func test54() async throws {
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

  /// Test opening debugger from deeplink and previewing both the free trial and default view.
  func test56() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    let urlString = "exampleapp://?superwall_debug=true&paywall_id=7872&token=sat_eyJhbGciOiJIUzI1NiJ9.eyJzY29wZXMiOlt7InNjb3BlIjoicGF5d2FsbF9wcmV2aWV3IiwiYXBwbGljYXRpb25JZCI6MTI3MH1dLCJpYXQiOjE2ODg2MjgxNTIsImV4cCI6NTA2NTI4Nzg3MiwiYXVkIjoicHduIiwiaXNzIjoicHduIiwic3ViIjoiNzAifQ.J0QNaycFlGY8ZQGBUwrySxkX43iPH2iV646EvJ5TvCg"
    let url = URL(string: urlString)!
    let handled = Superwall.shared.handleDeepLink(url)

    // Create value handler
    let deepLinkEventHolder = ValueDescriptionHolder()
    deepLinkEventHolder.stringValue = "No"

    // Respond to Superwall events
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .deepLink:
        deepLinkEventHolder.intValue += 1
        deepLinkEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Assert that the deep link worked
    await assert(value: "\(handled)", after: Constants.implicitPaywallPresentationDelay)

    // Assert that `.deepLink` was called once
    await assert(value: deepLinkEventHolder.description)

    // Tap the Preview button
    let previewButton = CGPoint(x: 196, y: 775)
    touch(previewButton)

    await sleep(timeInterval: 2)

    // Tap the Free Trial button
    let freeTrialButton = CGPoint(x: 196, y: 665)
    touch(freeTrialButton)

    await assert(after: Constants.paywallPresentationDelay)

    // Tap the close button
    let closeButton = CGPoint(x: 196, y: 91)
    touch(closeButton)

    await sleep(timeInterval: 2)

    // Tap the Preview button
    touch(previewButton)

    await sleep(timeInterval: 2)

    // Tap the default view
    let defaultButton = CGPoint(x: 196, y: 725)
    touch(defaultButton)

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present paywall from implicit trigger: `deepLink_open`.
  func testOptions57() -> TestOptions { return TestOptions(apiKey: Constants.deepLinkOpenAPIKey) }
  func test57() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    let url = URL(string: "exampleapp://mydeepLink?isDeepLink=true")!
    let handled = Superwall.shared.handleDeepLink(url)

    // Create value handler
    let deepLinkEventHolder = ValueDescriptionHolder()
    deepLinkEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .deepLink:
        deepLinkEventHolder.intValue += 1
        deepLinkEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // The deep link will return false here.
    await assert(value: "\(handled)", after: Constants.implicitPaywallPresentationDelay)

    // Assert that `.deepLink` was called once
    await assert(value: deepLinkEventHolder.description)

    // Assert paywall presented.
    await assert()
  }

  /// Present paywall after a `transaction_abandon` event.
  func testOptions58() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      apiKey: Constants.transactionAbandonAPIKey,
      options: options
    )
  }
  func test58() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionAbandonEventHolder = ValueDescriptionHolder()
    transactionAbandonEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionAbandon:
        transactionAbandonEventHolder.intValue += 1
        transactionAbandonEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "campaign_trigger")

    await assert(after: Constants.paywallPresentationDelay)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 750)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    let abandonTransactionButton = CGPoint(x: 359, y: 515)
    touch(abandonTransactionButton)

    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.transactionAbandon` was called once
    await assert(value: transactionAbandonEventHolder.description)
  }

  /// Present paywall after a `paywall_decline` event. The declined paywall has a survey attached to it.
  /// This is answered before `paywall_decline` is called.
  func testOptions59() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      apiKey: Constants.paywallDeclineAPIKey,
      options: options
    )
  }
  func test59() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create paywall decline value handler
    let paywallDeclineEventHolder = ValueDescriptionHolder()
    paywallDeclineEventHolder.stringValue = "No"

    // Create survey response value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallDecline:
        paywallDeclineEventHolder.intValue += 1
        paywallDeclineEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "campaign_trigger")

    await assert(after: Constants.paywallPresentationDelay)

    // Decline the paywall
    let declineButton = CGPoint(x: 358, y: 59)
    touch(declineButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert the next paywall is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.paywallDecline` was called once
    await assert(value: paywallDeclineEventHolder.description)

    // Assert that `.surveyResponse` was called once
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Present paywall after a `transaction_fail` event.
  func testOptions60() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      apiKey: Constants.transactionFailAPIKey,
      options: options
    )
  }
  func test60() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionFailEventHolder = ValueDescriptionHolder()
    transactionFailEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionFail:
        transactionFailEventHolder.intValue += 1
        transactionFailEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    await failTransactions()

    Superwall.shared.register(placement: "campaign_trigger")

    await assert(after: Constants.paywallPresentationDelay)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 750)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button
    let subscribeButton = CGPoint(x: 196, y: 766)
    touch(subscribeButton)

    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.transaction_fail` was called once
    await assert(value: transactionFailEventHolder.description)
  }

  //    - subscription_start
  //    - freeTrial_start
  //    - nonRecurringProduct_purchase
  //    - transaction_start
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

  // TODO: Display paywall with free trial content, make a free trial purchase, force trial to expire. Ensure that free trial content is no longer used. Do this in SK1 and SK2.
  func test61() async throws {
    skip("Need to add mechanism for restart")
    return
    // Expire subscription crashes sometimes, dunno why. The free trial is on the secondary product to test the v3 logic  FYI
    Superwall.shared.register(placement: "present_free_trial")

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
    Superwall.shared.register(placement: "present_free_trial")

    // Assert that paywall appears without free trial content
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Verify that an invalid URL like `#` doesn't crash the app
  func test62() async throws {
    // Present paywall with URLs
    Superwall.shared.register(placement: "present_urls")

    await assert(after: Constants.paywallPresentationDelay)

    // Tap the open # URL button
    let point = CGPoint(x: 330, y: 360)
    touch(point)

    // Verify that nothing happened
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Restore but don't have an active subscription
  func testOptions63() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test63() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Press restore
    let restoreButton = CGPoint(x: 200, y: 232)
    touch(restoreButton)

    // Assert no subscription alert appeared.
    await assert(after: Constants.paywallDelegateResponseDelay)

    // Assert paywall not finished.
    await assert(value: paywallDidFinishResultValueHolder.stringValue)
  }

  /// Choose non-other option from a paywall exit survey that shows 100% of the time. Then open and close the paywall again to make sure survey doesn't show again.
  func test64() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "show_survey_with_other") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Open the paywall again
    Superwall.shared.register(placement: "show_survey_with_other")

    // Wait for paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    touch(closeButton)

    // Assert paywall closed without showing survey.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Choose other option from a paywall exit survey that shows 100% of the time.
  func test65() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "show_survey_with_other") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the other option
    let firstOption = CGPoint(x: 196, y: 790)
    touch(firstOption)

    // Assert that alert controller with textfield has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    await typeText("Test")

    // Tap the submit button
    let submitButton = CGPoint(x: 196, y: 350)
    touch(submitButton)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Close paywall that has a paywall exit survey set to 0%
  func test66() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "zero_percent_survey") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert that paywall has disappeared, no survey, and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that only `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Assert survey is displayed after swiping down to dismiss a paywall.
  func test67() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "modal_paywall_with_survey") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    swipeDown()

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present paywall after a `survey_response` event.
  func testOptions68() -> TestOptions { return TestOptions(apiKey: Constants.surveyResponseAPIKey) }
  func test68() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert that paywall was presented
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that new paywall has appeared.
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let newCloseButton = CGPoint(x: 34, y: 66)
    touch(newCloseButton)

    // Assert paywall closed and feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Assert survey is displayed after swiping down to dismiss a paywall presented by `getPaywall`.
  func test69() async throws {
    // Create Superwall delegate
    let superwallDelegate = Configuration.MockSuperwallDelegate()
    holdStrongly(superwallDelegate)

    // Set delegate
    Superwall.shared.delegate = superwallDelegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    superwallDelegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    // Create Superwall delegate
    let paywallVcDelegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(paywallVcDelegate)

    paywallVcDelegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(
      forPlacement: "modal_paywall_with_survey",
      delegate: paywallVcDelegate
    ) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .pageSheet
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    swipeDown()

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Assert survey is displayed after tapping exit button to dismiss a paywall presented by `getPaywall`.
  func test70() async throws {
    // Create Superwall delegate
    let superwallDelegate = Configuration.MockSuperwallDelegate()
    holdStrongly(superwallDelegate)

    // Set delegate
    Superwall.shared.delegate = superwallDelegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    superwallDelegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    // Create Superwall delegate
    let paywallVcDelegate = Configuration.MockPaywallViewControllerDelegate()
    paywallVcDelegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }
    holdStrongly(paywallVcDelegate)

    if let viewController = try? await Superwall.shared.getPaywall(
      forPlacement: "show_survey_with_other",
      delegate: paywallVcDelegate
    ) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Purchase from paywall that has a survey attached and make sure survey doesn't show.
  func testOptions71() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test71() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "survey_with_purchase_button") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
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

    // Assert the paywall has disappeared and no survey displayed.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` not called.
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Check that calling identify restores the seed value. This is async and dependent on config so needs to sleep after calling identify.
  func test72() async throws {
    // Create value handler
    let seedHolder = ValueDescriptionHolder()
    Superwall.shared.identify(userId: "abc")

    try? await Task.sleep(for: .seconds(7))

    seedHolder.intValue = Superwall.shared.userAttributes["seed"] as? Int ?? -1
    await assert(value: seedHolder.description)

    Superwall.shared.reset()

    Superwall.shared.identify(userId: "abc")

    try? await Task.sleep(for: .seconds(7))

    seedHolder.intValue = Superwall.shared.userAttributes["seed"] as? Int ?? -1
    await assert(value: seedHolder.description)
  }

  /// Present paywall after a `touches_began` event.
  func testOptions73() -> TestOptions { return TestOptions(apiKey: Constants.touchesBeganAPIKey) }
  func test73() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let touchesBeganEventHolder = ValueDescriptionHolder()
    touchesBeganEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .touchesBegan:
        touchesBeganEventHolder.intValue += 1
        touchesBeganEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Wait until config has been retrieved
    await assert(after: Constants.paywallPresentationDelay)

    // Touch the paywall
    let centreOfScreen = CGPoint(x: 197, y: 426)
    touch(centreOfScreen)

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Touch the paywall again
    touch(centreOfScreen)

    // Assert .touchesBegan has been called only once
    await assert(value: touchesBeganEventHolder.description)
  }

  /// Assert a `survey_close` event when closing a survey that has a close button.
  func test74() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyCloseEventHolder = ValueDescriptionHolder()
    surveyCloseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyClose:
        surveyCloseEventHolder.intValue += 1
        surveyCloseEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "survey_with_close_option")

    // Assert the paywall is presented
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 154)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the close option
    let closeOption = CGPoint(x: 196, y: 792)
    touch(closeOption)

    // Assert the paywall has disappeared
    await assert(after: Constants.paywallPresentationDelay)

    // Assert .surveyClose has been called only once
    await assert(value: surveyCloseEventHolder.description)
  }

  /// Present the paywall and purchase. Make sure the transaction, product, and paywallInfo data is passed back to delegate.
  func testOptions75() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test75() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case let .transactionComplete(transaction, product, _, paywallInfo):
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "\(transaction == nil),\(product.productIdentifier),\(paywallInfo.identifier)"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "present_data")

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

    // Assert the paywall has disappeared
    await assert(after: Constants.paywallPresentationDelay)

    // Assert .transactionComplete has been called with transaction details
    await assert(value: transactionCompleteEventHolder.description)
  }

  /// Register event and land in holdout. Register again and present paywall.
  func test76() async throws {
    Superwall.shared.register(placement: "holdout_one_time_occurrence")

    // Assert that no paywall appears (holdout)
    await assert(after: Constants.paywallPresentationDelay)

    Superwall.shared.register(placement: "holdout_one_time_occurrence")

    // Assert that a paywall appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test 5 but using new `PaywallOverrides` init
  /// Show paywall with override products. Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  func test77() async throws {
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// This is the same as test10 but with the new `PaywallOverrides` init
  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  func test78() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present non-gated `paywall_decline` paywall from gated paywall and make sure the feature block isn't called.
  func testOptions79() -> TestOptions { return TestOptions(apiKey: Constants.gatedAPIKey) }
  func test79() async throws {
    // Present the gated paywall.
    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Wait for gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Wait for non-gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    touch(closeButton)

    // Assert the feature block wasn't called.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present non-gated `transaction_abandon` paywall from gated paywall and make sure the feature block isn't called.
  func testOptions80() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      apiKey: Constants.gatedAPIKey,
      options: options
    )
  }
  func test80() async throws {
    // Present the gated paywall.
    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Wait for gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Continue on the paywall
    let continueButton = CGPoint(x: 196, y: 786)
    touch(continueButton)

    await sleep(timeInterval: 2)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 786)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    let abandonTransactionButton = CGPoint(x: 359, y: 515)
    touch(abandonTransactionButton)

    // Wait for non-gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the feature block wasn't called.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Present non-gated `transaction_fail` paywall from gated paywall and make sure the feature block isn't called.
  func testOptions81() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      apiKey: Constants.gatedAPIKey,
      options: options
    )
  }
  func test81() async throws {
    await failTransactions()

    // Present the gated paywall.
    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Wait for gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Continue on the paywall
    let continueButton = CGPoint(x: 196, y: 786)
    touch(continueButton)

    await sleep(timeInterval: 2)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 786)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button
    let subscribeButton = CGPoint(x: 196, y: 766)
    touch(subscribeButton)

    // Wait for non-gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the feature block wasn't called.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Make sure feature block of gated paywall isn't called when `paywall_decline` returns a `noRuleMatch`
  func testOptions82() -> TestOptions { return TestOptions(apiKey: Constants.noRuleMatchGatedAPIKey) }
  func test82() async throws {
    // Present the gated paywall.
    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Wait for gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 56, y: 86)
    touch(closeButton)

    // Make sure no paywall_decline paywall shows and the feature block isn't called.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Finished purchase with a result type of `restored` on v4 paywall (same as test37)
  func testOptions83() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test83() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore_v4", delegate: delegate) {
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
    let restoreButton = CGPoint(x: 196, y: 136)
    touch(restoreButton)

    // Assert paywall result value
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// Finished restore with a result type of `restored` and then swiping the paywall view controller away (does it get called twice?).
  /// Same as test39 but with a v4 paywall
  func testOptions84() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test84() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore_v4", delegate: delegate) {
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
    let restoreButton = CGPoint(x: 196, y: 196)
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

  /// Restore but don't have an active subscription.
  /// Same as test63 but with a v4 paywall.
  func testOptions85() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test85() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore_v4", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Press restore
    let restoreButton = CGPoint(x: 196, y: 136)
    touch(restoreButton)

    // Assert no subscription alert appeared.
    await assert(after: Constants.paywallDelegateResponseDelay)

    // Assert paywall not finished.
    await assert(value: paywallDidFinishResultValueHolder.stringValue)
  }

  /// Case: Unsubscribed user, register event with a gating handler
  /// Result: paywall should display, code in gating closure should not execute
  /// Same as test26 but with v4 paywall
  func test86() async throws {
    Superwall.shared.register(placement: "register_gated_paywall_v4") {
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
  /// Same as test27 but with v4 paywall
  func testOptions87() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test87() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    Superwall.shared.register(placement: "register_gated_paywall_v4") {
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

  /// Case: Unsubscribed user, register event without a gating handler
  /// Result: paywall should display
  /// Same as test23 but with v4 paywall
  func test88() async throws {
    // Register event
    Superwall.shared.register(placement: "register_nongated_paywall_v4")

    // Assert that paywall appears
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Subscribed user, register event without a gating handler
  /// Result: paywall should NOT display
  /// Same as test24 but with v4 paywall.
  func testOptions89() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test89() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    // Register event
    Superwall.shared.register(placement: "register_nongated_paywall_v4")

    // Assert that paywall DOES not appear
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
  /// Result: paywall should display, after user subscribes, don't show another paywall
  /// Same as test25 but with v4 paywall
  func testOptions90() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test90() async throws {
    Superwall.shared.register(placement: "register_nongated_paywall_v4")

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
    Superwall.shared.register(placement: "register_nongated_paywall_v4")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Unable to fetch config, not subscribed, and not gated.
  /// Same as test41 but with v4 paywall
  func testOptions91() -> TestOptions { return TestOptions(allowNetworkRequests: false) }
  func test91() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: false, gated: false)
  }

  /// Unable to fetch config, not subscribed, and gated.
  /// Same as test42 but with v4 paywall
  func testOptions92() -> TestOptions { return TestOptions(allowNetworkRequests: false) }
  func test92() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: false, gated: true)
  }

  /// Unable to fetch config, subscribed, and not gated.
  /// Same as test43 but with v4 paywall
  func testOptions93() -> TestOptions { return TestOptions(allowNetworkRequests: false, purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test93() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: true, gated: false)
  }

  /// Unable to fetch config, subscribed, and gated.
  /// Same as test44 but with v4 paywall
  func testOptions94() -> TestOptions { return TestOptions(allowNetworkRequests: false, purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test94() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: true, gated: true)
  }

  /// Fetched config, not subscribed, and not gated.
  /// Same as test45 but with v4 paywall
  func test95() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: false, gated: false)
  }

  /// Fetched config, not subscribed, and gated.
  /// Same as test46 but with v4 paywall
  func test96() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: false, gated: true)
  }

  /// Fetched config, subscribed, and not gated.
  /// Same as test47 but with v4 paywall
  func testOptions97() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test97() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: true, gated: false)
  }

  /// Fetched config, subscribed, and gated.
  /// Same as test48 but with v4 paywall 
  func testOptions98() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test98() async throws {
    await executeRegisterFeatureClosureTestWithV4Paywall(subscribed: true, gated: true)
  }

  /// Present regardless of status
  /// Same as test9 but with v4 paywall
  func testOptions99() -> TestOptions { return TestOptions(purchasedProductIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier) }
  func test99() async throws {
    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    Superwall.shared.register(placement: "present_always_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Test trigger: not-allowed standard event (paywall_close)
  /// Same as test14 but with v4 paywall
  func test100() async throws {
    // Show a paywall
    Superwall.shared.register(placement: "present_always_v4")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Assert that no paywall is displayed as a result of the Superwall-owned `paywall_close` standard event.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clusterfucks by Jake™
  /// Same as test15 but with v4 paywall
  func test101() async throws {
    Superwall.shared.register(placement: "present_always_v4")
    Superwall.shared.register(placement: "present_always_v4", params: ["some_param_1": "hello"])
    Superwall.shared.register(placement: "present_always_v4")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.register(placement: "present_always_v4")
    Superwall.shared.identify(userId: "1111")
    Superwall.shared.register(placement: "present_always_v4")

    // Assert that paywall was displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    let handler = PaywallPresentationHandler()

    var experimentId = ""
    handler.onPresent { info in
      experimentId = info.experiment?.id ?? ""
      Superwall.shared.register(placement: "present_always_v4")
    }
    Superwall.shared.register(placement: "present_always_v4", handler: handler)

    await assert(after: Constants.paywallPresentationDelay)
    await assert(value: experimentId)
  }

  /// Present an alert on Superwall.presentedViewController from the onPresent callback
  /// Same as test16 but with v4 paywall
  func test102() async throws {
    let handler = PaywallPresentationHandler()
    handler.onPresent { _ in
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)

        Superwall.shared.presentedViewController?.present(alertController, animated: false)
      }
    }
    Superwall.shared.register(placement: "present_always_v4", handler: handler)

    await assert(after: Constants.paywallPresentationDelay, precision: .transparency)
  }

  /// Uses the identify function. Should see the name 'Jack' in the paywall.
  /// Same as test0 but with v4 paywall
  func test103() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Uses the identify function. Should see the name 'Kate' in the paywall.
  /// Same as test1 but with v4 paywall
  func test104() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test1a")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Set new identity
    Superwall.shared.identify(userId: "test1b")
    Superwall.shared.setUserAttributes([ "first_name": "Kate" ])
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Calls `reset()`. No first name should be displayed.
  /// Same as test2 but with v4 paywall
  func test105() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Calls `reset()` multiple times. No first name should be displayed.
  /// Same as test3 but with v4 paywall
  func test106() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test3")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clear a specific user attribute.
  /// Same as test11 but with v4 paywall
  func test107() async throws {
    Superwall.shared.setUserAttributes([ "first_name": "Claire" ])
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

      // TODO: THIS FAILS, DOESN'T CLEAR
    Superwall.shared.setUserAttributes([ "first_name": nil ])
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    Superwall.shared.setUserAttributes([ "first_name": "Sawyer" ])
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Clusterfucks by Jake™
  /// Same as test17 but with v4 paywall
  func test108() async throws {
    Superwall.shared.identify(userId: "test0")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
    Superwall.shared.register(placement: "present_data_v4")

    // Assert Jack displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Set identity
    Superwall.shared.identify(userId: "test2")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    // Reset the user identity
    Superwall.shared.reset()

    Superwall.shared.register(placement: "present_data_v4")

    // Assert no name displayed.
    await assert(after: Constants.paywallPresentationDelay)

    await dismissViewControllers()

    // Present paywall
    Superwall.shared.register(placement: "present_always_v4")
    Superwall.shared.register(placement: "present_always_v4", params: ["some_param_1": "hello"])
    Superwall.shared.register(placement: "present_always_v4")

    // Assert Present Always paywall displayed.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Assert a `survey_close` event when closing a survey that has a close button.
  /// Same as test74 but with v4 paywall
  func test109() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyCloseEventHolder = ValueDescriptionHolder()
    surveyCloseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyClose:
        surveyCloseEventHolder.intValue += 1
        surveyCloseEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "survey_with_close_option_v4")

    // Assert the paywall is presented
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 196, y: 820)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the close option
    let closeOption = CGPoint(x: 196, y: 792)
    touch(closeOption)

    // Assert the paywall has disappeared
    await assert(after: Constants.paywallPresentationDelay)

    // Assert .surveyClose has been called only once
    await assert(value: surveyCloseEventHolder.description)
  }

  /// Purchase from paywall that has a survey attached and make sure survey doesn't show.
  /// Same as test71 but with v4 paywall
  func testOptions110() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test110() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "survey_with_purchase_button_v4") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
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

    // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env).
    // For some reason, the tapping of OK gets called twice and dismisses both the purchase alert and the feature alert so it won't appear in screenshots.
    let okButton = CGPoint(x: 196, y: 495)
    touch(okButton)

    // Assert the paywall has disappeared and no survey displayed.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` not called.
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Assert survey is displayed after swiping down to dismiss a paywall.
  /// Same as test67 but with v4 paywall
  func test111() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "modal_paywall_with_survey_v4") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    swipeDown()

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Assert survey is displayed after swiping down to dismiss a paywall presented by `getPaywall`.
  /// Same as test69 but with v4 paywall
  func test112() async throws {
    // Create Superwall delegate
    let superwallDelegate = Configuration.MockSuperwallDelegate()
    holdStrongly(superwallDelegate)

    // Set delegate
    Superwall.shared.delegate = superwallDelegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    superwallDelegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    // Create Superwall delegate
    let paywallVcDelegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(paywallVcDelegate)

    paywallVcDelegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(
      forPlacement: "modal_paywall_with_survey_v4",
      delegate: paywallVcDelegate
    ) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .pageSheet
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    swipeDown()

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Close paywall that has a paywall exit survey set to 0%
  /// Same as test66 but with v4 paywall
  func test113() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "zero_percent_survey_v4") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert that paywall has disappeared, no survey, and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that only `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Choose non-other option from a paywall exit survey that shows 100% of the time. Then open and close the paywall again to make sure survey doesn't show again.
  /// Same as test64 but with v4 paywall
  func test114() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "show_survey_with_other_v4") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Open the paywall again
    Superwall.shared.register(placement: "show_survey_with_other_v4")

    // Wait for paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    touch(closeButton)

    // Assert paywall closed without showing survey.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Choose other option from a paywall exit survey that shows 100% of the time.
  /// Same as test65 but with v4 paywall
  func test115() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    Superwall.shared.register(placement: "show_survey_with_other_v4") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the other option
    let firstOption = CGPoint(x: 196, y: 790)
    touch(firstOption)

    // Assert that alert controller with textfield has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    await typeText("Test")

    // Tap the submit button
    let submitButton = CGPoint(x: 196, y: 350)
    touch(submitButton)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Assert survey is displayed after tapping exit button to dismiss a paywall presented by `getPaywall`.
  /// Same as test70 but with v4 paywall
  func test116() async throws {
    // Create Superwall delegate
    let superwallDelegate = Configuration.MockSuperwallDelegate()
    holdStrongly(superwallDelegate)

    // Set delegate
    Superwall.shared.delegate = superwallDelegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    superwallDelegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallClose:
        surveyResponseEventHolder.intValue += 1
      default:
        return
      }
    }

    // Create Superwall delegate
    let paywallVcDelegate = Configuration.MockPaywallViewControllerDelegate()
    paywallVcDelegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }
    holdStrongly(paywallVcDelegate)

    if let viewController = try? await Superwall.shared.getPaywall(
      forPlacement: "show_survey_with_other_v4",
      delegate: paywallVcDelegate
    ) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert the paywall has displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert that paywall has disappeared and the feature block called.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` and `.paywallClose` was called
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Clusterfucks by Jake™
  /// Same as test19 but with v4 paywalls.
  func test117() async throws {
    // Set identity
    Superwall.shared.identify(userId: "test19a")
    Superwall.shared.setUserAttributes([ "first_name": "Jack" ])

    Superwall.shared.reset()
    Superwall.shared.reset()
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    _ = await Superwall.shared.getPresentationResult(forPlacement: "present_and_rule_user_v4")

    // Dismiss any view controllers
    await dismissViewControllers()

    // Show a paywall
    Superwall.shared.register(placement: "present_always_v4")

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
    Superwall.shared.register(placement: "present_data_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Adds a user attribute to verify rule on `present_and_rule_user` presents: user.should_display == true and user.some_value > 12. Then remove those attributes and make sure it's not presented.
  /// Same as test7 but with v4 paywalls
  func test118() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 14 ])
    Superwall.shared.register(placement: "present_and_rule_user_v4")

    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Remove those attributes.
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    Superwall.shared.register(placement: "present_and_rule_user_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Adds a user attribute to verify rule on `present_and_rule_user` DOES NOT present: user.should_display == true and user.some_value > 12
  /// Same as test8 but with v4 paywall
  func test119() async throws {
    Superwall.shared.identify(userId: "test7")
    Superwall.shared.setUserAttributes([ "first_name": "Charlie", "should_display": true, "some_value": 12 ])
    Superwall.shared.register(placement: "present_and_rule_user_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Presentation result: `noRuleMatch`
  /// Same as test29 but with v4 paywall
  func test120() async {
    Superwall.shared.setUserAttributes([ "should_display": nil, "some_value": nil ])
    let result = await Superwall.shared.getPresentationResult(forPlacement: "present_and_rule_user_v4")
    await assert(value: result.description)
  }

  /// Open In-App Safari view controller from manually presented paywall
  /// Same as test18 but with v4 paywall
  func test121() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_urls_v4", delegate: delegate) {
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

  /// Verify that external URLs can be opened in native Safari from paywall
  /// Same as test20 but with v4 paywall
  func test122() async throws {
    // Present paywall with URLs
    Superwall.shared.register(placement: "present_urls_v4")

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

  /// Verify that an invalid URL like `#` doesn't crash the app
  /// Same as test62 but with v4 paywall
  func test123() async throws {
    // Present paywall with URLs
    Superwall.shared.register(placement: "present_urls_v4")

    await assert(after: Constants.paywallPresentationDelay)

    // Tap the open # URL button
    let point = CGPoint(x: 330, y: 360)
    touch(point)

    // Verify that nothing happened
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Show paywall with override products. Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  /// Same as test5 but with v4 paywall
  func testOptions124() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test124() async throws {
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(
      productsByName: [
        "primary": StoreProduct(sk1Product: primary),
        "secondary": StoreProduct(sk1Product: secondary)
      ]
    )

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// Same as test6 but with v4 paywall
  func test125() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products_v4")

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  /// Same as test10 but with v4 paywall
  func testOptions126() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test126() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(
      productsByName: [
        "primary": StoreProduct(sk1Product: primary),
        "secondary": StoreProduct(sk1Product: secondary)
      ]
    )

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Show paywall with override products. Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  /// Same as test77 but with v4 paywall
  func testOptions127() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test127() async throws {
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// This is the same as test10 but with the new `PaywallOverrides` init
  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  /// Same as test78 but with v4 paywall
  func testOptions128() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test128() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// This paywall will open with a video playing that shows a 0 in the video at t0 and a 2 in the video
  /// at t2. It will close after 4 seconds. A new paywall will be presented 1 second after close.
  /// This paywall should have a video playing and should be started from the beginning with a 0 on
  /// the screen. Only a presentation delay of 1 sec as the paywall should already be loaded and
  /// we want to capture the video as quickly as possible.
  /// Same as test4 but with v4 paywall
  func test129() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_video_v4")

    // Dismiss after 4 seconds
    await sleep(timeInterval: 4.0)
    await dismissViewControllers()

    // Present again after 1 second
    await sleep(timeInterval: 1.0)
    Superwall.shared.register(placement: "present_video_v4")

    await assert(after: 2.0, precision: .video)
  }

  /// Purchase a product without a paywall.
  func testOptions130() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test130() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. In the advanced configuration we assume the purchase is "
           + "within the purchase controller so the delegate won't get called and "
           + "the result will not return."
      )
      return
    }
    guard let product = StoreKitHelper.shared.sk1MonthlyProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"
    let subscriptionStartEventHolder = ValueDescriptionHolder()
    subscriptionStartEventHolder.stringValue = "No"
    let purchaseResultValueHolder = ValueDescriptionHolder()
    purchaseResultValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionComplete:
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "Yes"
      case .subscriptionStart:
        subscriptionStartEventHolder.intValue += 1
        subscriptionStartEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Task {
      let result = await Superwall.shared.purchase(product)
      switch result {
      case .purchased:
        purchaseResultValueHolder.intValue += 1
        purchaseResultValueHolder.stringValue = "Yes"
      default:
        break
      }
    }

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

    await assert(value: purchaseResultValueHolder.description, after: Constants.paywallPresentationDelay)
    await assert(value: transactionCompleteEventHolder.description)
  }

  /// Cancel purchase of product without a paywall.
  func testOptions131() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test131() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. In the advanced configuration we assume the purchase is "
           + "within the purchase controller so the delegate won't get called and "
           + "the result will not return."
      )
      return
    }
    guard let product = StoreKitHelper.shared.sk1MonthlyProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionAbandonEventHolder = ValueDescriptionHolder()
    transactionAbandonEventHolder.stringValue = "No"
    let cancelledResultValueHolder = ValueDescriptionHolder()
    cancelledResultValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionAbandon:
        transactionAbandonEventHolder.intValue += 1
        transactionAbandonEventHolder.stringValue = "Yes"
      default:
        return
      }
    }


    Task {
      let result = await Superwall.shared.purchase(product)
      switch result {
      case .cancelled:
        cancelledResultValueHolder.intValue += 1
        cancelledResultValueHolder.stringValue = "Yes"
      default:
        break
      }
    }

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Abandon the transaction
    let abandonTransactionButton = CGPoint(x: 359, y: 20)
    touch(abandonTransactionButton)

    await assert(value: cancelledResultValueHolder.description, after: Constants.paywallPresentationDelay)
    await assert(value: transactionAbandonEventHolder.description)
  }

  /// Restore purchases with automatic config.
  func testOptions132() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test132() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. The restore performs differently in the advanced configuration.")
      return
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreCompleteEventHolder = ValueDescriptionHolder()
    restoreCompleteEventHolder.stringValue = "No"
    let restoredResultValueHolder = ValueDescriptionHolder()
    restoredResultValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreComplete:
        restoreCompleteEventHolder.intValue += 1
        restoreCompleteEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      restoredResultValueHolder.intValue += 1
      restoredResultValueHolder.stringValue = "Yes"
    default:
      break
    }

    await assert(value: restoredResultValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreCompleteEventHolder.description)
  }

  /// Failed restore of purchases under automatic configuration.
  func testOptions133() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test133() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. The restore performs differently in the advanced configuration.")
      return
    }
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreFailEventHolder = ValueDescriptionHolder()
    restoreFailEventHolder.stringValue = "No"
    let restoredValueHolder = ValueDescriptionHolder()
    restoredValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreFail:
        restoreFailEventHolder.intValue += 1
        restoreFailEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // User is not subscribed

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      // Result is still restored even though alert shows. This is because
      // the user is unsubscribed but result is restored.
      restoredValueHolder.intValue += 1
      restoredValueHolder.stringValue = "Yes"
    default:
      break
    }

    // Assert alert shows.
    await assert(after: Constants.paywallPresentationDelay)

    await assert(value: restoredValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreFailEventHolder.description)
  }

  /// Failed restore of purchases.
  func testOptions134() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test134() async throws {
    if configuration is Configuration.Automatic {
      skip("Skipping test. The restore performs differently in the automatic configuration.")
      return
    }
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreFailEventHolder = ValueDescriptionHolder()
    restoreFailEventHolder.stringValue = "No"
    let restoredValueHolder = ValueDescriptionHolder()
    restoredValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreFail:
        restoreFailEventHolder.intValue += 1
        restoreFailEventHolder.stringValue = "Yes"
      default:
        return
      }
    }


    // User is not subscribed

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      // Result is still restored even though alert shows. This is because
      // the user is unsubscribed but result is restored.
      restoredValueHolder.intValue += 1
      restoredValueHolder.stringValue = "Yes"
    default:
      break
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    await assert(value: restoredValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreFailEventHolder.description)
  }

  /// Restored result from purchase without a paywall.
  func test135() async throws {
    skip("Simulator sometimes returns purchased instead of restored so hard to use. Would need SK1 and SK2 versions of this")
//    guard let product = StoreKitHelper.shared.monthlyProduct else {
//      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
//    }
//
//    let delegate = Configuration.MockSuperwallDelegate()
//    holdStrongly(delegate)
//
//    // Set delegate
//    Superwall.shared.delegate = delegate
//
//    // Create value handler
//    let transactionRestoreEventHolder = ValueDescriptionHolder()
//    transactionRestoreEventHolder.stringValue = "No"
//
//    // Respond to Superwall events
//    delegate.handleSuperwallEvent { eventInfo in
//      switch eventInfo.event {
//      case .transactionRestore:
//        print("**** RESTOREDDDD")
//        transactionRestoreEventHolder.intValue += 1
//        transactionRestoreEventHolder.stringValue = "Yes"
//      default:
//        return
//      }
//    }
//
//    // Mock user as subscribed
//    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customMonthlyProductIdentifier)
//
//    Task {
//      let _ = await Superwall.shared.purchase(product)
//
//      // Not checking this because in the simulator it can sometime be purchased
////      switch result {
////      case .restored:
////        restoredResultValueHolder.intValue += 1
////        restoredResultValueHolder.stringValue = "Yes"
////      default:
////        break
////      }
//    }
//
//    // Assert that the 'currently subscribed to product' alert is displayed.
//    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 0), size: .init(width: 393, height: 390))))
//
//    // Tap the OK button
//    let okButton = CGPoint(x: 261, y: 526)
//    touch(okButton)
//
//    await sleep(timeInterval: Constants.paywallPresentationDelay)
//
//    await assert(value: transactionRestoreEventHolder.description)
  }

  /// Restore purchases with advanced config.
  func testOptions136() -> TestOptions {
    let options = SuperwallOptions()
    options.storeKitVersion = .storeKit1
    return TestOptions(
      options: options
    )
  }
  func test136() async throws {
    if configuration is Configuration.Automatic {
      skip("Skipping test. The restore performs differently in the automatic configuration.")
      return
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreCompleteEventHolder = ValueDescriptionHolder()
    restoreCompleteEventHolder.stringValue = "No"
    let restoredResultValueHolder = ValueDescriptionHolder()
    restoredResultValueHolder.stringValue = "No"

    // Respond to Superwall placements, these shouldn't be called
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreComplete:
        restoreCompleteEventHolder.intValue += 1
        restoreCompleteEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      restoredResultValueHolder.intValue += 1
      restoredResultValueHolder.stringValue = "Yes"
    default:
      break
    }

    await assert(value: restoredResultValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreCompleteEventHolder.description)
  }

  /// Superwall purchases with observer mode enabled.
  func testOptions137() -> TestOptions {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test137() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case let .transactionComplete(transaction, product, _, paywallInfo):
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "\(transaction == nil),\(product.productIdentifier),\(paywallInfo.identifier)"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "present_data")

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

    // Assert the paywall has disappeared
    await assert(after: Constants.paywallPresentationDelay)

    // Assert .transactionComplete has been called with transaction details
    await assert(value: transactionCompleteEventHolder.description)

    Superwall.shared.register(placement: "campaign_trigger")

    // Make sure paywall isn't presented
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Native SK1 purchase with observer mode enabled.
  func testOptions138() -> TestOptions {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    options.storeKitVersion = .storeKit1
    return TestOptions(options: options)
  }
  func test138() async throws {
    guard let product = StoreKitHelper.shared.sk1MonthlyProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case let .transactionComplete(transaction, product, _, paywallInfo):
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "\(transaction == nil),\(product.productIdentifier),\(paywallInfo.identifier)"
      default:
        return
      }
    }

    Task {
      let product = StoreProduct(sk1Product: product)
      let result = await StoreKitHelper.shared.purchase(product: product)

      if configuration is Configuration.Advanced,
        result == .purchased {
        Superwall.shared.subscriptionStatus = .active([.init(id: "default")])
      }
    }

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

    // Assert .transactionComplete has been called with transaction details
    await assert(value: transactionCompleteEventHolder.description, after: 8)

    Superwall.shared.register(placement: "campaign_trigger")

    // Make sure paywall isn't presented
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Native SK2 purchase with observer mode enabled.
  func testOptions139() -> TestOptions {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    return TestOptions(options: options)
  }
  func test139() async throws {
    if #unavailable(iOS 17.2) {
      skip(
        "Skipping test. Observer mode for SK2 can only run on iOS 17.2 simulators or later otherwise it won't work. "
        + "This test should be run on iOS 18.1 with iPhone 16 Pro"
      )
      return
    }
    guard let product = await StoreKitHelper.shared.getSk2MonthlyProduct() else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case let .transactionComplete(transaction, product, type, paywallInfo):
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "\(transaction == nil),\(product.productIdentifier),\(type.description),\(paywallInfo.identifier)"
      default:
        return
      }
    }

    Task {
      let product = StoreProduct(sk2Product: product)
      _ = await StoreKitHelper.shared.purchase(product: product)
    }

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button (set for iPhone 16 Pro on iOS 18.1)
    let subscribeButton = CGPoint(x: 201, y: 810)
    touch(subscribeButton)

    // Wait for subscribe to occur
    await sleep(timeInterval: Constants.paywallPresentationDelay)

    // Tap the OK button once subscription has been confirmed (coming from Apple in Sandbox env)
    let okButton = CGPoint(x: 196, y: 495)
    touch(okButton)

    // Assert .transactionComplete has been called with transaction details
    await assert(value: transactionCompleteEventHolder.description, after: 8)

    Superwall.shared.register(placement: "campaign_trigger")

    // Make sure paywall isn't presented
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test 5 but using SK2. Show paywall with override products using SK2.
  /// Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  func test140() async throws {
    guard let primary = await StoreKitHelper.shared.getSk2MonthlyProduct(), let secondary = await StoreKitHelper.shared.getSk2AnnualProduct() else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk2Product: primary),
      "secondary": StoreProduct(sk2Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test10 but with SK2. Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  func test141() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test21 but using SK2. Present the paywall and purchase; then make sure
  /// the paywall doesn't get presented again after the purchase
  func test142() async throws {
    Superwall.shared.register(placement: "present_data")

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
    Superwall.shared.register(placement: "present_data")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test25 but with SK2. Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
  /// Result: paywall should display, after user subscribes, don't show another paywall
  func test143() async throws {
    Superwall.shared.register(placement: "register_nongated_paywall")

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
    Superwall.shared.register(placement: "register_nongated_paywall")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test35 but with SK2. Finished purchase with a result type of `purchased`
  func test144() async {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_data", delegate: delegate) {
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

  /// Same as test37 but with SK2. Finished purchase with a result type of `restored`
  func test145() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    // Sleeping because there seems to be a delay between mocking and entitlements setting.
    await sleep(timeInterval: 3)

    // Press restore
    let restoreButton = CGPoint(x: 200, y: 232)
    touch(restoreButton)

    // Assert paywall result value
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// Same as test38 but with SK2. Finished purchase with a result type of `purchased` and then swiping the paywall view controller away
  func test146() async {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_data", delegate: delegate) {
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

  /// Same as test39 but with SK2. Finished restore with a result type of `restore`.
  func test147() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore", delegate: delegate) {
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

  /// Same as test58 but with SK2. Present paywall after a `transaction_abandon` event.
  func testOptions148() -> TestOptions {
    return TestOptions(
      apiKey: Constants.transactionAbandonAPIKey
    )
  }
  func test148() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionAbandonEventHolder = ValueDescriptionHolder()
    transactionAbandonEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionAbandon:
        transactionAbandonEventHolder.intValue += 1
        transactionAbandonEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "campaign_trigger")

    await assert(after: Constants.paywallPresentationDelay)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 750)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    let abandonTransactionButton = CGPoint(x: 359, y: 515)
    touch(abandonTransactionButton)

    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.transactionAbandon` was called once
    await assert(value: transactionAbandonEventHolder.description)
  }

  /// Same as test59 but with SK2. Present paywall after a `paywall_decline` event. The declined paywall has a survey attached to it.
  /// This is answered before `paywall_decline` is called.
  func testOptions149() -> TestOptions {
    return TestOptions(
      apiKey: Constants.paywallDeclineAPIKey
    )
  }
  func test149() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create paywall decline value handler
    let paywallDeclineEventHolder = ValueDescriptionHolder()
    paywallDeclineEventHolder.stringValue = "No"

    // Create survey response value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      case .paywallDecline:
        paywallDeclineEventHolder.intValue += 1
        paywallDeclineEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "campaign_trigger")

    await assert(after: Constants.paywallPresentationDelay)

    // Decline the paywall
    let declineButton = CGPoint(x: 358, y: 59)
    touch(declineButton)

    // Assert the survey is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Tap the first option
    let firstOption = CGPoint(x: 196, y: 733)
    touch(firstOption)

    // Assert the next paywall is displayed
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.paywallDecline` was called once
    await assert(value: paywallDeclineEventHolder.description)

    // Assert that `.surveyResponse` was called once
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Same as test60 but with SK2. Present paywall after a `transaction_fail` event.
  func testOptions150() -> TestOptions { return TestOptions(apiKey: Constants.transactionFailAPIKey) }
  func test150() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionFailEventHolder = ValueDescriptionHolder()
    transactionFailEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionFail:
        transactionFailEventHolder.intValue += 1
        transactionFailEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    await failTransactions()

    Superwall.shared.register(placement: "campaign_trigger")

    await assert(after: Constants.paywallPresentationDelay)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 750)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button
    let subscribeButton = CGPoint(x: 196, y: 766)
    touch(subscribeButton)

    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.transaction_fail` was called once
    await assert(value: transactionFailEventHolder.description)
  }

  /// Same as test63 but with SK2. Restore but don't have an active subscription
  func test151() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Press restore
    let restoreButton = CGPoint(x: 200, y: 232)
    touch(restoreButton)

    // Assert no subscription alert appeared.
    await assert(after: Constants.paywallDelegateResponseDelay)

    // Assert paywall not finished.
    await assert(value: paywallDidFinishResultValueHolder.stringValue)
  }

  /// Same as test71 but with SK2. Purchase from paywall that has a survey attached and make sure survey doesn't show.
  func test152() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "survey_with_purchase_button") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
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
    // TODO: Note that sometimes this dismisses everything but sometimes doesn't causing test to be flakey.
    let okButton = CGPoint(x: 196, y: 495)
    touch(okButton)

    // Assert the paywall has disappeared and no survey displayed.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` not called.
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Same as test75 but with SK2. Present the paywall and purchase. Make sure the transaction, product, and paywallInfo data is passed back to delegate.
  func test153() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case let .transactionComplete(transaction, product, _, paywallInfo):
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "\(transaction == nil),\(product.productIdentifier),\(paywallInfo.identifier)"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "present_data")

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

    // Assert the paywall has disappeared
    await assert(after: Constants.paywallPresentationDelay)

    // Assert .transactionComplete has been called with transaction details
    await assert(value: transactionCompleteEventHolder.description)
  }

  /// Same as test80 but with SK2. Present non-gated `transaction_abandon` paywall from gated paywall and make sure the feature block isn't called.
  func testOptions154() -> TestOptions { return TestOptions(apiKey: Constants.gatedAPIKey) }
  func test154() async throws {
    // Present the gated paywall.
    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Wait for gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Continue on the paywall
    let continueButton = CGPoint(x: 196, y: 786)
    touch(continueButton)

    await sleep(timeInterval: 2)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 786)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    let abandonTransactionButton = CGPoint(x: 359, y: 515)
    touch(abandonTransactionButton)

    // Wait for non-gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the feature block wasn't called.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test81 but with SK2. Present non-gated `transaction_fail` paywall from gated paywall and make sure the feature block isn't called.
  func testOptions155() -> TestOptions { return TestOptions(apiKey: Constants.gatedAPIKey) }
  func test155() async throws {
    await failTransactions()

    // Present the gated paywall.
    Superwall.shared.register(placement: "campaign_trigger") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Wait for gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Continue on the paywall
    let continueButton = CGPoint(x: 196, y: 786)
    touch(continueButton)

    await sleep(timeInterval: 2)

    // Purchase on the paywall
    let purchaseButton = CGPoint(x: 196, y: 786)
    touch(purchaseButton)

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Tap the Subscribe button
    let subscribeButton = CGPoint(x: 196, y: 766)
    touch(subscribeButton)

    // Wait for non-gated paywall to show
    await assert(after: Constants.paywallPresentationDelay)

    // Close the paywall
    let closeButton = CGPoint(x: 356, y: 86)
    touch(closeButton)

    // Assert the feature block wasn't called.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test83 but with SK2. Finished purchase with a result type of `restored` on v4 paywall (same as test37)
  func test156() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore_v4", delegate: delegate) {
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
    let restoreButton = CGPoint(x: 196, y: 136)
    touch(restoreButton)

    // Assert paywall result value
    await assert(value: paywallDidFinishResultValueHolder.stringValue, after: Constants.paywallDelegateResponseDelay)
  }

  /// Same as test84 but with SK2. Finished restore with a result type of `restored` and then swiping the paywall view controller away (does it get called twice?).
  /// Same as test39 but with a v4 paywall
  func test157() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore_v4", delegate: delegate) {
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
    let restoreButton = CGPoint(x: 196, y: 196)
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

  /// Same as test85 but with SK2. Restore but don't have an active subscription.
  /// Same as test63 but with a v4 paywall.
  func test158() async throws {
    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    let paywallDidFinishResultValueHolder = ValueDescriptionHolder()
    delegate.paywallViewControllerDidFinish { _, result, shouldDismiss in
      paywallDidFinishResultValueHolder.stringValue = result.description
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "restore_v4", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert paywall presented.
    await assert(after: Constants.paywallPresentationDelay)

    // Press restore
    let restoreButton = CGPoint(x: 196, y: 136)
    touch(restoreButton)

    // Assert no subscription alert appeared.
    await assert(after: Constants.paywallDelegateResponseDelay)

    // Assert paywall not finished.
    await assert(value: paywallDidFinishResultValueHolder.stringValue)
  }

  /// Same as test90 but with SK2. Case: Unsubscribed user, register event without a gating handler, user subscribes, after dismiss register another event without a gating handler
  /// Result: paywall should display, after user subscribes, don't show another paywall
  /// Same as test25 but with v4 paywall
  func test159() async throws {
    Superwall.shared.register(placement: "register_nongated_paywall_v4")

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
    Superwall.shared.register(placement: "register_nongated_paywall_v4")

    // Ensure the paywall doesn't present.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test110 but with SK2. Purchase from paywall that has a survey attached and make sure survey doesn't show.
  /// Same as test71 but with v4 paywall
  func test160() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let surveyResponseEventHolder = ValueDescriptionHolder()
    surveyResponseEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .surveyResponse:
        surveyResponseEventHolder.intValue += 1
        surveyResponseEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "survey_with_purchase_button_v4") {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: "Alert", message: "This is an alert message", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        RootViewController.shared.present(alertController, animated: false)
      }
    }

    // Assert the paywall has displayed
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

    // Assert the paywall has disappeared and no survey displayed.
    // Note: Alert disappears due to Xcode overtapping for some weird reason.
    await assert(after: Constants.paywallPresentationDelay)

    // Assert that `.surveyResponse` not called.
    await assert(value: surveyResponseEventHolder.description)
  }

  /// Same as test124 but with SK2. Show paywall with override products. Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  /// Same as test5 but with v4 paywall
  func test161() async throws {
    guard
      let primary = await StoreKitHelper.shared.getSk2MonthlyProduct(),
      let secondary = await StoreKitHelper.shared.getSk2AnnualProduct()
    else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(
      productsByName: [
        "primary": StoreProduct(sk2Product: primary),
        "secondary": StoreProduct(sk2Product: secondary)
      ]
    )

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test126 but with SK2. Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  /// Same as test10 but with v4 paywall
  func test162() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard
      let primary = await StoreKitHelper.shared.getSk2MonthlyProduct(),
      let secondary = await StoreKitHelper.shared.getSk2AnnualProduct()
    else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(
      productsByName: [
        "primary": StoreProduct(sk2Product: primary),
        "secondary": StoreProduct(sk2Product: secondary)
      ]
    )

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Sane as test127 but with SK2. Show paywall with override products. Paywall should appear with 2 products: 1 monthly at
  /// $12.99 and 1 annual at $99.99.
  /// Same as test77 but with v4 paywall
  func test163() async throws {
    guard
      let primary = await StoreKitHelper.shared.getSk2MonthlyProduct(),
      let secondary = await StoreKitHelper.shared.getSk2AnnualProduct()
    else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk2Product: primary),
      "secondary": StoreProduct(sk2Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, result, shouldDismiss in
      DispatchQueue.main.async {
        if shouldDismiss {
          viewController.dismiss(animated: false)
        }
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test128 but with SK2. This is the same as test10 but with the new `PaywallOverrides` init
  /// Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.
  /// After dismiss, paywall should be presented again with override products: 1 monthly at $12.99
  /// and 1 annual at $99.99. After dismiss, paywall should be presented again with no override products.
  /// After dismiss, paywall should be presented one last time with no override products.
  /// Same as test78 but with v4 paywall
  func test164() async throws {
    // Present the paywall.
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Create override products
    guard let primary = StoreKitHelper.shared.sk1MonthlyProduct, let secondary = StoreKitHelper.shared.sk1AnnualProduct else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let paywallOverrides = PaywallOverrides(productsByName: [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary)
    ])

    let delegate = Configuration.MockPaywallViewControllerDelegate()
    holdStrongly(delegate)

    delegate.paywallViewControllerDidFinish { viewController, _, shouldDismiss in
      DispatchQueue.main.async {
        viewController.dismiss(animated: false)
      }
    }

    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", paywallOverrides: paywallOverrides, delegate: delegate) {
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
    Superwall.shared.register(placement: "present_products_v4")

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    // Dismiss any view controllers
    await dismissViewControllers()

    // Present manually again, but with no overrides
    if let viewController = try? await Superwall.shared.getPaywall(forPlacement: "present_products_v4", delegate: delegate) {
      DispatchQueue.main.async {
        viewController.modalPresentationStyle = .fullScreen
        RootViewController.shared.present(viewController, animated: true)
      }
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)
  }

  /// Same as test130 but with SK2. Purchase a product without a paywall.
  func test165() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. In the advanced configuration we assume the purchase is "
           + "within the purchase controller so the delegate won't get called and "
           + "the result will not return."
      )
      return
    }
    guard let product = await StoreKitHelper.shared.getSk2MonthlyProduct() else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"
    let subscriptionStartEventHolder = ValueDescriptionHolder()
    subscriptionStartEventHolder.stringValue = "No"
    let purchaseResultValueHolder = ValueDescriptionHolder()
    purchaseResultValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionComplete:
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "Yes"
      case .subscriptionStart:
        subscriptionStartEventHolder.intValue += 1
        subscriptionStartEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    Task {
      let result = await Superwall.shared.purchase(product)
      switch result {
      case .purchased:
        purchaseResultValueHolder.intValue += 1
        purchaseResultValueHolder.stringValue = "Yes"
      default:
        break
      }
    }

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

    await assert(value: purchaseResultValueHolder.description, after: Constants.paywallPresentationDelay)
    await assert(value: transactionCompleteEventHolder.description)
  }

  /// Same as test131 but with SK2. Cancel purchase of product without a paywall.
  func test166() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. In the advanced configuration we assume the purchase is "
           + "within the purchase controller so the delegate won't get called and "
           + "the result will not return."
      )
      return
    }
    guard let product = await StoreKitHelper.shared.getSk2MonthlyProduct() else {
      fatalError("WARNING: Unable to fetch custom products. These are needed for testing.")
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionAbandonEventHolder = ValueDescriptionHolder()
    transactionAbandonEventHolder.stringValue = "No"
    let cancelledResultValueHolder = ValueDescriptionHolder()
    cancelledResultValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .transactionAbandon:
        transactionAbandonEventHolder.intValue += 1
        transactionAbandonEventHolder.stringValue = "Yes"
      default:
        return
      }
    }


    Task {
      let result = await Superwall.shared.purchase(product)
      switch result {
      case .cancelled:
        cancelledResultValueHolder.intValue += 1
        cancelledResultValueHolder.stringValue = "Yes"
      default:
        break
      }
    }

    // Assert that the system paywall sheet is displayed but don't capture the loading indicator at the top
    await assert(after: Constants.paywallPresentationDelay, captureArea: .custom(frame: .init(origin: .init(x: 0, y: 488), size: .init(width: 393, height: 300))))

    // Abandon the transaction
    let abandonTransactionButton = CGPoint(x: 359, y: 20)
    touch(abandonTransactionButton)

    await assert(value: cancelledResultValueHolder.description, after: Constants.paywallPresentationDelay)
    await assert(value: transactionAbandonEventHolder.description)
  }

  /// Same as test132 but with SK2. Restore purchases with automatic config.
  func test167() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. The restore performs differently in the advanced configuration.")
      return
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreCompleteEventHolder = ValueDescriptionHolder()
    restoreCompleteEventHolder.stringValue = "No"
    let restoredResultValueHolder = ValueDescriptionHolder()
    restoredResultValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreComplete:
        restoreCompleteEventHolder.intValue += 1
        restoreCompleteEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      restoredResultValueHolder.intValue += 1
      restoredResultValueHolder.stringValue = "Yes"
    default:
      break
    }

    await assert(value: restoredResultValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreCompleteEventHolder.description)
  }

  /// Same as test133 but with SK2. Failed restore of purchases under automatic configuration.
  func test168() async throws {
    if configuration is Configuration.Advanced {
      skip("Skipping test. The restore performs differently in the advanced configuration.")
      return
    }
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreFailEventHolder = ValueDescriptionHolder()
    restoreFailEventHolder.stringValue = "No"
    let restoredValueHolder = ValueDescriptionHolder()
    restoredValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreFail:
        restoreFailEventHolder.intValue += 1
        restoreFailEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // User is not subscribed

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      restoredValueHolder.intValue += 1
      restoredValueHolder.stringValue = "Yes"
    default:
      break
    }

    // Assert alert shows.
    await assert(after: Constants.paywallPresentationDelay)

    await assert(value: restoredValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreFailEventHolder.description)
  }

  /// Same as test134 but with SK2. Failed restore of purchases.
  func test169() async throws {
    if configuration is Configuration.Automatic {
      skip("Skipping test. The restore performs differently in the automatic configuration.")
      return
    }
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreFailEventHolder = ValueDescriptionHolder()
    restoreFailEventHolder.stringValue = "No"
    let restoredValueHolder = ValueDescriptionHolder()
    restoredValueHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreFail:
        restoreFailEventHolder.intValue += 1
        restoreFailEventHolder.stringValue = "Yes"
      default:
        return
      }
    }


    // User is not subscribed

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      // Result is still restored even though alert shows. This is because
      // the user is unsubscribed but result is restored.
      restoredValueHolder.intValue += 1
      restoredValueHolder.stringValue = "Yes"
    default:
      break
    }

    // Assert original products.
    await assert(after: Constants.paywallPresentationDelay)

    await assert(value: restoredValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreFailEventHolder.description)
  }

  /// Same as test136 but with SK2. Restore purchases with advanced config.
  func test170() async throws {
    if configuration is Configuration.Automatic {
      skip("Skipping test. The restore performs differently in the automatic configuration.")
      return
    }

    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let restoreStartEventHolder = ValueDescriptionHolder()
    restoreStartEventHolder.stringValue = "No"
    let restoreCompleteEventHolder = ValueDescriptionHolder()
    restoreCompleteEventHolder.stringValue = "No"
    let restoredResultValueHolder = ValueDescriptionHolder()
    restoredResultValueHolder.stringValue = "No"

    // Respond to Superwall placements, these shouldn't be called
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case .restoreStart:
        restoreStartEventHolder.intValue += 1
        restoreStartEventHolder.stringValue = "Yes"
      case .restoreComplete:
        restoreCompleteEventHolder.intValue += 1
        restoreCompleteEventHolder.stringValue = "Yes"
      default:
        return
      }
    }

    // Mock user as subscribed
    await configuration.mockSubscribedUser(productIdentifier: StoreKitHelper.Constants.customAnnualProductIdentifier)

    await sleep(timeInterval: 15)

    let result = await Superwall.shared.restorePurchases()
    switch result {
    case .restored:
      restoredResultValueHolder.intValue += 1
      restoredResultValueHolder.stringValue = "Yes"
    default:
      break
    }

    await assert(value: restoredResultValueHolder.description)
    await assert(value: restoreStartEventHolder.description)
    await assert(value: restoreCompleteEventHolder.description)
  }

  /// Same as test137 but with SK2. Superwall purchases with observer mode enabled.
  func testOptions171() -> TestOptions {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    return TestOptions(options: options)
  }
  func test171() async throws {
    // Create Superwall delegate
    let delegate = Configuration.MockSuperwallDelegate()
    holdStrongly(delegate)

    // Set delegate
    Superwall.shared.delegate = delegate

    // Create value handler
    let transactionCompleteEventHolder = ValueDescriptionHolder()
    transactionCompleteEventHolder.stringValue = "No"

    // Respond to Superwall placements
    delegate.handleSuperwallEvent { eventInfo in
      switch eventInfo.event {
      case let .transactionComplete(transaction, product, _, paywallInfo):
        transactionCompleteEventHolder.intValue += 1
        transactionCompleteEventHolder.stringValue = "\(transaction == nil),\(product.productIdentifier),\(paywallInfo.identifier)"
      default:
        return
      }
    }

    Superwall.shared.register(placement: "present_data")

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

    // Assert the paywall has disappeared
    await assert(after: Constants.paywallPresentationDelay)

    // Assert .transactionComplete has been called with transaction details
    await assert(value: transactionCompleteEventHolder.description)

    Superwall.shared.register(placement: "campaign_trigger")

    // Make sure paywall isn't presented
    await assert(after: Constants.paywallPresentationDelay)
  }

  // TODO: The loading of the paywall doesn't always match up. Need to disable animations.
//  /// Assert exit/refresh shows up if paywall.js isn't installed on page. Tap close button.
//  func test73() async throws {
//    Superwall.shared.register(placement: "no_paywalljs")
//
//    // Assert infinite loading
//    await assert(after: Constants.paywallPresentationDelay)
//
//    // Tap the close button
//    let closeButton = CGPoint(x: 43, y: 103)
//    touch(closeButton)
//
//    // Assert that the paywall has disappeared
//    await assert(after: Constants.paywallPresentationDelay)
//  }

  /// Assert localized paywall presented for given locale
//  func testOptions74() -> TestOptions {
//    let options = SuperwallOptions()
//    options.localeIdentifier = "es"
//    return TestOptions(options: options)
//  }
// TODO: Currently there's an issue where it doesn't seem to substitute data on the paywall
//  func test74() async throws {
//    Superwall.shared.register(placement: "present_localized")
//
//    // Assert infinite loading
//    await assert(after: Constants.paywallPresentationDelay)
//  }

  // Deep Link (closes paywall, then opens Placeholder view controller
  // Test: not calling dismiss on main thread
  // Test whatever logic comes out of new track API
  //  22. Infinite loading
  //      1. make sure refresh button loads it again from a fresh start
  //      2. test this for modal + normal presentation + on nil + on another view controller
  // Test custom actions
  // Test localization based on system settings (-AppleLocale fr_FR)
  // Test localized paywall when available and unavailable using Superwall options
  // Swipe to dismiss a modal view and make sure new tracks function afterwards
}
