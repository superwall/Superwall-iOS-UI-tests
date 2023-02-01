//
//  TestListViewController.swift
//  UI-Tests
//
//  Created by Bryan Dubno on 1/24/23.
//

import UIKit

class TestListViewController: UIViewController {

  @IBOutlet var tableView: UITableView!
  let testSuite = SwiftTestSuite() // can sub in objc suite too

  override func viewDidLoad() {
    super.viewDidLoad()
  }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension TestListViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return testSuite.tests.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let test = testSuite.tests[indexPath.row]

    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    cell.contentConfiguration = test.contentConfiguration(for: cell)

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let test = testSuite.tests[indexPath.row]
    test.perform()
  }
}

// MARK: - Test

extension Test {
  func contentConfiguration(for cell: UITableViewCell) -> UIListContentConfiguration {
    var configuration = cell.defaultContentConfiguration()
    configuration.text = title
    configuration.secondaryText = body
    return configuration
  }
}
