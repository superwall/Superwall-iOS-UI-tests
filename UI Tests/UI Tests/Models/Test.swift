//
//  Test.swift
//  UI-Tests
//
//  Created by Bryan Dubno on 1/24/23.
//

import Foundation

@objc(SWKTest)
class Test: NSObject {
  var title: String
  var body: String
  var perform: () -> ()

  init(title: String, body: String, perform: @escaping () -> Void) {
    self.title = title
    self.body = body
    self.perform = perform
  }
}
