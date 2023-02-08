//
//  SetupHelper.swift
//  UI-Tests
//
//  Created by Bryan Dubno on 1/30/23.
//

import Foundation
import SuperwallKit

class SetupHelper {
  static let shared: SetupHelper = SetupHelper()

  func configure() {
    let options = SuperwallOptions()

    // https://superwall.com/applications/1270
    Superwall.configure(apiKey: "pk_5f6d9ae96b889bc2c36ca0f2368de2c4c3d5f6119aacd3d2", delegate: self, options: options)

    // Begin fetching products for use in other test cases
    StoreKitHelper.shared.fetchCustomProducts()
  }
}

extension SetupHelper: SuperwallDelegate {

}
