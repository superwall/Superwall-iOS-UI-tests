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

  override func viewDidLoad() {
    super.viewDidLoad()
    RootViewController.shared = self
  }

}
