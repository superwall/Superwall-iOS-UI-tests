//
//  Communicator.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/10/23.
//

import UIKit
import Swifter

public class Communicator {
  static var shared: Communicator = Communicator()
  private(set) var httpConfiguration: HTTPConfiguration? = nil

  public struct HTTPConfiguration {
    let runnerPort: UInt16
    let parentPort: UInt16

    public init(processInfo: ProcessInfo) {
      self.runnerPort = Utility.port(environment: ProcessInfo.processInfo.environment, indexType: .runnerPort)
      self.parentPort = Utility.port(environment: ProcessInfo.processInfo.environment, indexType: .parentPort)
    }

    struct Utility {
      enum IndexType {
          case runnerPort
          case parentPort
      }

      static func port(environment: [String: String], indexType: IndexType) -> UInt16 {
        func parseCloneNumber() -> Int {
          // e.g. CoreSimulator 917 - Device: Clone 2 of iPhone 14 Pro
          guard let simulatorString = environment["SIMULATOR_VERSION_INFO"] else {
            // Treat a missing value like a non-parallel run rather than crashing.
            return 999
          }

          // Define a regular expression to find the number after 'Clone'
          do {
            let regex = try NSRegularExpression(pattern: "Clone (\\d+)", options: [])

            guard let match = regex.firstMatch(in: simulatorString, options: [], range: NSRange(location: 0, length: simulatorString.utf16.count)) else {
              // If it can't match "Clone", it means it's just opened one simulator and not running in parallel.
              return 999
            }

            let range = match.range(at: 1)
            guard let swiftRange = Range(range, in: simulatorString),
                let cloneNumber = Int(simulatorString[swiftRange]) else {
              fatalError("Unable to determine port to use")
            }

            return cloneNumber
          } catch {
            fatalError("Unable to determine port to use: \(error.localizedDescription)")
          }
        }

        // Ports are derived from the simulator's UDID, which the runner and the
        // app share. Clone numbers aren't unique on a host: two concurrent test
        // sessions both have a "Clone 1", and their messages would cross.
        if let udid = environment["SIMULATOR_UDID"] {
          return port(at: stableIndex(for: udid), type: indexType)
        }
        return port(at: parseCloneNumber(), type: indexType)
      }

      /// FNV-1a, so the value is the same in every process (Swift's `hashValue`
      /// is seeded per process). Kept below 7000 so the runner range
      /// (49152...) and the parent range (...65535) never overlap.
      static func stableIndex(for string: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
          hash ^= UInt64(byte)
          hash = hash &* 0x100000001b3
        }
        return Int(hash % 7000)
      }

      static func port(at index: Int, type: IndexType) -> UInt16 {
          let startIndex = 49152
          let endIndex = 65535
          let value: Int
          switch type {
          case .runnerPort:
              value = startIndex + index
          case .parentPort:
              value = endIndex - index
          }
          if value >= startIndex, value <= endIndex {
              return UInt16(value)
          } else {
              fatalError("Unable to find a port to use")
          }
      }
    }
  }

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
      case type(text: String)
      case springboard
      case assert(testName: String, precision: Float, captureArea: CaptureArea)
      case assertScreen(testName: String, screen: String)
      case assertValue(testName: String, value: String)
      case skip(message: String)
      case fail(message: String)
      case touch(point: CGPoint)
      case tapElement(label: String, index: Int, systemOnly: Bool)
      case tapAlertButton(index: Int)
      case swipeDown
      case failTransactions
      case activateSubscription(productIdentifier: String)
      case expireSubscription(productIdentifier: String)
      case disableAutoRenew(productIdentifier: String)
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
  }

  private lazy var sourceConfiguration: Configuration = {
    return Constants.isRunner ? runnerConfiguration : parentConfiguration
  }()
  private lazy var destinationConfiguration: Configuration = {
    return Constants.isRunner ? parentConfiguration : runnerConfiguration
  }()

  private lazy var runnerConfiguration = {
    guard let httpConfiguration = httpConfiguration else {
      fatalError("Communicator must be configured with an identifier and port before being used.")
    }

    return Configuration(serverPath: "/toRunner", port: httpConfiguration.runnerPort)
  }()

  private lazy var parentConfiguration = {
    guard let httpConfiguration = httpConfiguration else {
      fatalError("Communicator must be configured with an identifier and port before being used.")
    }

    return Configuration(serverPath: "/toParent", port: httpConfiguration.parentPort)
  }()

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

  /// Called with the server and its port before it starts, to add routes.
  var configureServer: ((HttpServer, UInt16) -> Void)?
  private let operationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  let sendSerialQueue = DispatchQueue(label: "com.ui-tests.Communicator.sendSerialQueue")

  // Provide a unique identifier and parent to share between runner and parent to avoid crossing wires in a parellelized environment.
  func start(httpConfiguration: HTTPConfiguration) {
    self.httpConfiguration = httpConfiguration

    server[sourceConfiguration.serverPath] = { [weak self] request in
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

    configureServer?(server, sourceConfiguration.port)

    // A previous process can hold the port for a moment after termination,
    // so retry before giving up rather than crashing on the first attempt.
    var attempts = 0
    while true {
      do {
        // Swifter defaults to `.background` QoS, which recent simulator hosts
        // throttle so hard that requests can take minutes to be handled.
        try server.start(sourceConfiguration.port, forceIPv4: true, priority: .userInitiated)
        print("Server has started ( port = \(try server.port()) ).")
        break
      } catch {
        attempts += 1
        guard attempts < 20 else {
          fatalError("Server start error: \(error) for port \(sourceConfiguration.port)")
        }
        print("Server start failed (attempt \(attempts)) for port \(sourceConfiguration.port): \(error). Retrying...")
        server.stop()
        Thread.sleep(forTimeInterval: 0.5)
      }
    }
  }

  private func handleCompletionAction(_ action: Communicator.Action) {
    sendSerialQueue.async {
      guard let completionHandler = self.completionHandlers[action.identifier] else {
        print("Warning: No completion handler found for action identifier: \(action.identifier)")
        return
      }

      // Remove the completion handler immediately to prevent double-calling
      self.completionHandlers.removeValue(forKey: action.identifier)

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

      if let urlRequest = destinationConfiguration.urlRequest(with: action) {
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

  // Complete action locally without sending over HTTP (for use in test runner when app has been terminated)
  func completedLocally(action: Communicator.Action) {
    handleCompletionAction(action)
  }

  /// Waits until every action sent so far has been completed by the other
  /// side, or `timeout` elapses.
  func waitForPendingActions(timeout: TimeInterval = 40) async {
    // Fire-and-forget senders hop through a `Task` and this queue before
    // their action is registered; give them a moment to get there.
    try? await Task.sleep(nanoseconds: 200_000_000)
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
      let pending = sendSerialQueue.sync { completionHandlers.count }
      if pending == 0 {
        return
      }
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
  }

  // Resumes every pending `send` continuation. Used by the test runner when
  // the app process dies and no completion will ever arrive over HTTP.
  func abortPendingActions() {
    sendSerialQueue.async {
      let handlers = self.completionHandlers
      self.completionHandlers.removeAll()
      for (identifier, handler) in handlers {
        DispatchQueue.main.async {
          handler(Action(.fail(message: "Aborted action \(identifier): app process is no longer running")))
        }
      }
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
