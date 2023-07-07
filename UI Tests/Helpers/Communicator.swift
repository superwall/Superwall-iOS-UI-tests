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

  struct Action: Codable, Equatable {
    let identifier: String
    let invocation: Action.Invocation

    init(_ invocation: Communicator.Action.Invocation) {
      self.identifier = NSUUID().uuidString
      self.invocation = invocation
    }

#warning("separate out into parent and runner invocations")
    indirect enum Invocation: Codable {
      // Test app tells the parent
      case runTest(number: Int)

      // Parent tells the test app
      case relaunchApp
      case springboard
      case assert(testName: String, precision: Float, captureArea: CaptureArea)
      case assertValue(testName: String, value: String)
      case skip(message: String)
      case fail(message: String)
      case touch(point: CGPoint)
      case swipeDown
      case failTransactions
      case activateSubscription(productIdentifier: String)
      case expireSubscription(productIdentifier: String)
      case log(_ message: String)
      case completed(action: Action)
    }

    static func == (lhs: Action, rhs: Action) -> Bool {
      return lhs.identifier == rhs.identifier
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
  private let operationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  let sendSerialQueue = DispatchQueue(label: "com.ui-tests.Communicator.sendSerialQueue")

  func start() {
    server[Constants.sourceConfiguration.serverPath] = { [weak self] request in

      func handle(_ request: HttpRequest) {
        let action = request.bodyData.decodedAction()
        switch action?.invocation {
          case .completed(let action):
            guard let self = self else { return }
            self.handleCompletionAction(action)
          default:
            NotificationCenter.default.post(name: .receivedActionRequest, object: action)
        }
      }

      handle(request)
      return HttpResponse.accepted
    }

    do {
      try server.start(Constants.sourceConfiguration.port, forceIPv4: true)
      print("Server has started ( port = \(try server.port()) ).")
    } catch {
      print("Server start error: \(error)")
    }
  }

  private func handleCompletionAction(_ action: Communicator.Action) {
    sendSerialQueue.async {
      guard let completionHandler = self.completionHandlers[action.identifier] else {
        fatalError("There should have been a completion handler for this identifier")
      }

      DispatchQueue.main.async {
        let action = action
        completionHandler(action)
      }
    }
  }

  private var completionHandlers: [String: (Communicator.Action) -> Void] = [:]
  
  @discardableResult func send(_ invocation: Communicator.Action.Invocation) async -> Communicator.Action {
    return await withCheckedContinuation { continuation in
      send(invocation) { result in
        continuation.resume(returning: result)
      }
    }
  }

  private func send(_ invocation: Communicator.Action.Invocation, completion: @escaping (Communicator.Action) -> Void) {
    sendSerialQueue.async { [weak self] in
      guard let self = self else { return }

      let action = Communicator.Action(invocation)
      completionHandlers[action.identifier] = completion

      if let urlRequest = Constants.destinationConfiguration.urlRequest(with: action) {
        let operation = BlockOperation {
          let semaphore = DispatchSemaphore(value: 0)

          let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            if let data = data, let stringResponse = String(data: data, encoding: .utf8) {
              print(stringResponse)
            } else if let error = error {
              print("Error: \(error.localizedDescription)")
            }
            semaphore.signal()
          }
          task.resume()

          semaphore.wait()
        }
        operationQueue.addOperation(operation)
      } else {
        print("Invalid URL")
      }
    }
  }

  func completed(action: Communicator.Action) {
    Task {
      await Communicator.shared.send(.completed(action: action))
    }
  }
}

extension NSNotification.Name {
  static let receivedActionRequest = NSNotification.Name("receivedActionRequest")
}

public enum CaptureArea: Codable {
  case fullScreen
  case safeArea(captureStatusBar: Bool = true, captureHomeIndicator: Bool = true)
  case safari // consistent frame for grabbing external Safari content
  case custom(frame: CGRect)

  func image(from image: UIImage) -> UIImage {
    switch self {
      case .fullScreen:
        return image
      case .safeArea(captureStatusBar: let captureStatusBar, captureHomeIndicator: let captureHomeIndicator):
        return image.captureStatusBar(captureStatusBar).captureHomeIndicator(captureHomeIndicator)
      case .safari:
        return image.captureStatusBar(false).cropped(to: .init(origin: .zero, size: .init(width: 393, height: 655)))
      case .custom(frame: let frame):
        return image.cropped(to: frame)
    }
  }
}

@objc(SWKCaptureArea)
public class CaptureAreaObjC: NSObject {
  @objc public static let safeAreaNoHomeIndicator: CaptureAreaObjC = CaptureAreaObjC(.safeArea(captureHomeIndicator: false))
  @objc public static let fullScreen: CaptureAreaObjC = CaptureAreaObjC(.fullScreen)
  @objc public static let safari: CaptureAreaObjC = CaptureAreaObjC(.safari)

  let transform: CaptureArea

  public init(_ captureArea: CaptureArea) {
    self.transform = captureArea
    super.init()
  }

  @objc public convenience init(captureStatusBar: Bool, captureHomeIndicator: Bool) {
    self.init(.safeArea(captureStatusBar: captureStatusBar, captureHomeIndicator: captureHomeIndicator))
  }

  @objc public convenience init(frame: CGRect) {
    self.init(.custom(frame: frame))
  }

  @objc public static func custom(frame: CGRect) -> CaptureAreaObjC {
    return CaptureAreaObjC(.custom(frame: frame))
  }
}

// MARK: - Extensions

extension NSObject {
  func send(for invocation: Communicator.Action.Invocation) async -> Communicator.Action {
    await Communicator.shared.send(invocation)
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
