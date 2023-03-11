//
//  RootViewController.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/14/23.
//

import UIKit
import SuperwallKit

class RootViewController: UIViewController {

  static private(set) var shared: RootViewController!
  let communicator = Communicator.shared

  override func viewDidLoad() {
    super.viewDidLoad()

    RootViewController.shared = self
    
    NotificationCenter.default.addObserver(forName: .receivedResponse, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }
  }

  func handle(_ action: Communicator.Action) {
    switch action {
      case .runTest(number: let testNumber):
        Task {
          await runTest(testNumber)
        }
      default:
        return
    }
  }

  func runTest(_ testNumber: Int) async {
    print("Ok, I'm running test #\(testNumber)")

    let testCase = UITests_Swift()
    try? await testCase.setUp()

    let test = testCase.tests[testNumber]
    await test()

    try? await testCase.tearDown()

    Communicator.shared.send(.endTest)
  }

  func getMethodNames() -> [String] {
    // Get the class whose methods you want to collect
    let testClass = UITests_Swift.self

    // Get a Mirror instance of the class
    let mirror = Mirror(reflecting: testClass.init())

    // Create an array to store the method names
    var methodNames: [String] = []

    // Loop through the Mirror's children and add each method name to the array
    for child in mirror.children {
      if let methodName = child.label, child.value is () -> () {
        methodNames.append(methodName)
      }
    }

    return methodNames
  }
}
