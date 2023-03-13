//
//  Communicator.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/10/23.
//

import UIKit
import Swifter

class Communicator {
  static let shared: Communicator = Communicator()

#warning("separate out into parent and runner actions")
  enum Action: Codable, Equatable {
    // Test app tells the parent
    case runTest(number: Int)
    case finishedAsserting

    // Parent tells the test app
    case relaunchApp
    case endTest
    case assert(testName: String, precision: Float)
    case skip(message: String)
    case touch(point: CGPoint)

    static func == (lhs: Action, rhs: Action) -> Bool {
      switch (lhs, rhs) {
        case (.runTest, .runTest):
          return true
        case (.finishedAsserting, .finishedAsserting):
          return true
        case (.relaunchApp, .relaunchApp):
          return true
        case (.endTest, .endTest):
          return true
        case (.assert, .assert):
          return true
        case (.touch, .touch):
          return true
        default:
          return false
      }
    }
  }

  private struct Constants {
    static let runnerBundlePath = "Automated UI Testing-Runner.app"
    static let isRunner: Bool = Bundle.main.bundlePath.contains(Constants.runnerBundlePath)
    static let sourceConfiguration: Configuration = {
      return isRunner ? runnerConfiguration : parentConfiguration
    }()
    static let destinationConfiguration: Configuration = {
      return isRunner ? parentConfiguration : runnerConfiguration
    }()

    static let runnerConfiguration = Configuration(serverPath: "/toRunner", port: 8090)
    static let parentConfiguration = Configuration(serverPath: "/toParent", port: 8091)
  }

  struct Configuration {
    let serverPath: String
    let port: in_port_t

    func urlRequest(with action: Action) -> URLRequest? {
      let url = URL(string: "http://localhost:\(port)\(serverPath)")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = action.data

      return request
    }
  }

  private let server = HttpServer()

  func start() {
    server[Constants.sourceConfiguration.serverPath] = { request in
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .receivedResponse, object: request.bodyData.decodedAction())
      }

      return HttpResponse.accepted
    }

    do {
      try server.start(Constants.sourceConfiguration.port, forceIPv4: true)
      print("Server has started ( port = \(try server.port()) ).")
    } catch {
      print("Server start error: \(error)")
    }
  }
  
  func send(_ action: Action) {
    if let urlRequest = Constants.destinationConfiguration.urlRequest(with: action) {
      let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
        if let data = data, let stringResponse = String(data: data, encoding: .utf8) {
          print(stringResponse)
        } else if let error = error {
          print("Error: \(error.localizedDescription)")
        }
      }
      task.resume()
    } else {
      print("Invalid URL")
    }
  }

  // MARK: - NotificationCenter

  func wait(for action: Communicator.Action) async {
    await Waiter().wait(for: action)
  }

  private class Waiter {
    func wait(for action: Action) async {
      let notifications = NotificationCenter.default.notifications(named: .receivedResponse)
      for await notification in notifications {
        guard let _ = notification.object as? Communicator.Action else { return }
        return
      }
    }
  }
}

extension NSNotification.Name {
  static let receivedResponse = NSNotification.Name("receivedResponse")
}

// MARK: - Extensions

extension NSObject {
  func wait(for action: Communicator.Action) async {
    await Communicator.shared.wait(for: action)
  }
}

extension Data {
  func decodedAction() -> Communicator.Action? {
    guard let decodedData = try? JSONDecoder().decode(Communicator.Action.self, from: self) else {
      print("Unable to build object from data")
      return nil
    }

    return decodedData
  }
}

extension Communicator.Action {
  var data: Data? {
    let encodedData = try? JSONEncoder().encode(self)

    guard let encodedData = encodedData else {
      print("Unable to encode object")
      return nil
    }

    return encodedData
  }
}

extension HttpRequest {
  var bodyData: Data {
    get {
      return body.data
    }
    set {
      body = newValue.bytes
    }
  }
}
