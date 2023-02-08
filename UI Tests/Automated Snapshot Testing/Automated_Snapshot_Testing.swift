//
//  Automated_Snapshot_Testing.swift
//  Automated Snapshot Testing
//
//  Created by Bryan Dubno on 2/7/23.
//

import SnapshotTesting
import XCTest

@testable import UI_Tests
final class Automated_Snapshot_Testing: XCTestCase {

  override func setUpWithError() throws {
      // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
      // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testExample() throws {
    let expectation = XCTestExpectation()
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
      let testSuite = SwiftTestSuite()
      testSuite.tests[0].perform()

      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1000)) {
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 10000)
  }

}
