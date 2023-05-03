//
//  Testable.swift
//  Automated UI Testing
//
//  Created by Bryan Dubno on 3/12/23.
//

import Foundation

@objc protocol Testable: AnyObject {
  var configuration: TestConfiguration { get }

  func test0() async throws
  func test1() async throws
  func test2() async throws
  func test3() async throws
  func test4() async throws
  func test5() async throws
  func test6() async throws
  func test7() async throws
  func test8() async throws
  func test9() async throws
  func test10() async throws
  func test11() async throws
  func test12() async throws
  func test13() async throws
  func test14() async throws
  func test15() async throws
  func test16() async throws
  func test17() async throws
  func test18() async throws
  func test19() async throws
  func test20() async throws
  func test21() async throws
  func test22() async throws
  func test23() async throws
  func test24() async throws
  func test25() async throws
  func test26() async throws
  func test27() async throws
  func test28() async throws
}

extension RootViewController {
  func performTest(_ testNumber: Int, on testable: Testable) async throws {
    switch testNumber {
    case 0: try await testable.test0()
    case 1: try await testable.test1()
    case 2: try await testable.test2()
    case 3: try await testable.test3()
    case 4: try await testable.test4()
    case 5: try await testable.test5()
    case 6: try await testable.test6()
    case 7: try await testable.test7()
    case 8: try await testable.test8()
    case 9: try await testable.test9()
    case 10: try await testable.test10()
    case 11: try await testable.test11()
    case 12: try await testable.test12()
    case 13: try await testable.test13()
    case 14: try await testable.test14()
    case 15: try await testable.test15()
    case 16: try await testable.test16()
    case 17: try await testable.test17()
    case 18: try await testable.test18()
    case 19: try await testable.test19()
    case 20: try await testable.test20()
    case 21: try await testable.test21()
    case 22: try await testable.test22()
    case 23: try await testable.test23()
    case 24: try await testable.test24()
    case 25: try await testable.test25()
    case 26: try await testable.test26()
    case 27: try await testable.test27()
    case 28: try await testable.test28()
    default:
      fatalError("Test has not been defined above.")
    }
  }
}
