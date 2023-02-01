//
//  TestSuitable.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/1/23.
//

import Foundation

@objc protocol TestSuitable {
  var tests: [Test] { get }
}
