//
//  SwiftTestSuite.swift
//  UI-Tests
//
//  Created by Bryan Dubno on 1/30/23.
//

import Foundation
import SuperwallKit

class SwiftTestSuite: TestSuitable {
  let tests: [Test] = {
    [
      // 1
      Test(
        title: "Identify User 1",
        body: "Uses the identify function. Should see the name 'Jack' in the paywall.",
        perform: {

        }
      ),

      // 2
      Test(
        title: "Identify User 2 without calling reset",
        body: "Uses the identify function. Should see the name 'Kate' in the paywall.",
        perform: {

        }
      ),




      // 6
      Test(
        title: "Video restarts on trigger, after it is already loaded",
        body: "This paywall will open with a video playing. It will close after 3 seconds. A new paywall will be presented 1 second after close. This paywall should have a video playing and should be started from the beginning.",
        perform: {
          // Present the paywall.
          Superwall.shared.track(event: "present_video")

          Task {
            // Dismiss after 3 seconds
            await DispatchQueue.main.after(deadline: .now() + .seconds(3))
            await Superwall.shared.dismiss()

            // Present again after 1 second
            await DispatchQueue.main.after(deadline: .now() + .seconds(1))
            Superwall.shared.track(event: "present_video")
          }

        }
      ),

      // 7
      Test(
        title: "Show paywall with custom products",
        body: "Paywall should appear with 2 products: 1 monthly at $4.99 and 1 annual at $29.99.",
        perform: {
          Superwall.shared.track(event: "present_products")
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

extension DispatchQueue {
  func after(deadline: DispatchTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = []) async {
    return await withCheckedContinuation { continuation in
      asyncAfter(deadline: deadline, qos: qos, flags: flags) {
        continuation.resume(returning: ())
      }
    }
  }
}
