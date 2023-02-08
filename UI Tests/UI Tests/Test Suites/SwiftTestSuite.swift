//
//  SwiftTestSuite.swift
//  UI-Tests
//
//  Created by Bryan Dubno on 1/30/23.
//

import UIKit
import SuperwallKit

class SwiftTestSuite: TestSuitable {
  let tests: [Test] = {
    [
      Test(
        title: "Identify User 1",
        body: "Uses the identify function. Should see the name 'Jack' in the paywall.",
        perform: {
//          let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PlaceholderViewController")
//          guard let rootViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
//            print("WARNING: Could not find root view controller.")
//            return
//          }
//
//          rootViewController.present(viewController, animated: true)

          try? Superwall.shared.identify(userId: "123")
          Superwall.shared.setUserAttributes([ "first_name": "Jack" ])
          Superwall.shared.track(event: "present_data")
        }
      ),

      Test(
        title: "Identify User 2 without calling reset",
        body: "Uses the identify function. Should see the name 'Kate' in the paywall.",
        perform: {
          try? Superwall.shared.identify(userId: "456")
          Superwall.shared.setUserAttributes([ "first_name": "Kate" ])
          Superwall.shared.track(event: "present_data")
        }
      ),

      Test(
        title: "Reset user",
        body: "Calls `reset()`. No first name should be displayed",
        perform: {
          Superwall.shared.reset()
          Superwall.shared.track(event: "present_data")
        }
      ),

      Test(
        title: "Reset user again",
        body: "Calls `reset()` again. No first name should be displayed",
        perform: {
          Superwall.shared.reset()
          Superwall.shared.track(event: "present_data")
        }
      ),

      Test(
        title: "Video restarts on trigger, after it is already loaded",
        body: "This paywall will open with a video playing. It will close after 3 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning.",
        perform: {
          // Present the paywall.
          Superwall.shared.track(event: "present_video")

          Task {
            // Dismiss after 3 seconds
            await Task.sleep(timeInterval: 3.0)
            await Superwall.shared.dismiss()

            // Present again after 1 second
            await Task.sleep(timeInterval: 1.0)
            Superwall.shared.track(event: "present_video")
          }

        }
      ),

      Test(
        title: "Show paywall with override products",
        body: "Paywall should appear with 2 products: 1 monthly at $12.99 and 1 annual at $99.99.",
        perform: {
          #warning("CURRENTLY A BUG IN B4")
          guard let primary = StoreKitHelper.shared.monthlyProduct, let secondary = StoreKitHelper.shared.annualProduct else {
            print("WARNING: Unable to fetch custom products.")
            return
          }

          let products = PaywallProducts(primary: StoreProduct(sk1Product: primary), secondary: StoreProduct(sk1Product: secondary))
          let paywallOverrides = PaywallOverrides(products: products)

          Superwall.shared.track(event: "present_products", paywallOverrides: paywallOverrides)
        }
      ),

      Test(
        title: "Show paywall with products",
        body: "Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.",
        perform: {
          Superwall.shared.track(event: "present_products")
        }
      ),

      // 8
//      Test(
//        title: "Change user name ",
//        body: <#T##String#>,
//        perform: <#T##() -> Void#>
//      ),

      // 9
//      Test(
//        title: <#T##String#>,
//        body: <#T##String#>,
//        perform: <#T##() -> Void#>
//      ),

      // 13
      Test(
        title: "Open URLs",
        body: "Open URLs in Safari, In-App, and Deep Link (closes paywall, then opens Placeholder view controller)",
        perform: {
          Superwall.shared.track(event: "present_urls")
        }
      ),

//      // Uncomment, Right-click > Create Code Snippet to add to Xcode as a code snippet. Choose a "Completion" for easy additions.
//      // <#Test Number#>
//      Test(
//        title: <#T##String#>,
//        body: <#T##String#>,
//        perform: <#T##() -> Void#>
//      ),

    ]


  }()
}

extension Task where Success == Never, Failure == Never {
  public static func sleep(timeInterval: TimeInterval) async {
    let nanoseconds = UInt64(timeInterval * 1_000_000_000)
    try? await sleep(nanoseconds: nanoseconds)
  }
}
