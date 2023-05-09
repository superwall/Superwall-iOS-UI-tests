//
//  RootViewController.swift
//  UI Tests
//
//  Created by Bryan Dubno on 2/14/23.
//

import UIKit
import SuperwallKit

@objc(SWKRootViewController)
class RootViewController: UIViewController {
  @objc(sharedInstance)
  static var shared: RootViewController!

  let communicator = Communicator.shared

  override func viewDidLoad() {
    super.viewDidLoad()

    RootViewController.shared = self
    
    NotificationCenter.default.addObserver(forName: .receivedActionRequest, object: nil, queue: .main) { [weak self] notification in
      guard let action = notification.object as? Communicator.Action else { return }
      self?.handle(action)
    }
  }

  func handle(_ action: Communicator.Action) {
    switch action.invocation {
      case .runTest(number: let testNumber):
        Task {
          await runTest(testNumber, from: action)
        }
      default:
        return
    }
  }

  func runTest(_ testNumber: Int, from action: Communicator.Action) async {
    print("Instructed to run test #\(testNumber) with \(Constants.configurationType) mode in \(Constants.language.description)")

    // Create the test case instance depending on language.
    let testCase: Testable = Constants.language == .swift ? UITests_Swift() : (UITests_ObjC() as! Testable)
    let configuration = testCase.configuration

    await configuration.setup()

    try? await performTest(testNumber, on: testCase)

    await configuration.tearDown()

    Communicator.shared.completed(action: action)
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return [.bottom]
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }
}

