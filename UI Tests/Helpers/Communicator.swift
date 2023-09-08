//
//  Communicator.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/10/23.
//

import UIKit
import Ably

public class Communicator {
  static var shared: Communicator = Communicator()

  private let client = ARTRealtime(key: "mkEeaA.wdohKg:_F9sKcGiWzpOZZE9LYFq_NCD8La84aBFZC7QLhy_HWU")
  private lazy var channel = {
    return client.channels.get("automated-ui-testing")
  }()

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
  }

  private let operationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  let sendSerialQueue = DispatchQueue(label: "com.ui-tests.Communicator.sendSerialQueue")

  private var channelID: String!

  private lazy var channelPublishID: String = {
    if Constants.isRunner {
      return channelID + "-" + "runner"
    } else {
      return channelID + "-" + "parent"
    }
  }()

  private lazy var channelSubscribeID: String = {
    if Constants.isRunner {
      return channelID + "-" + "parent"
    } else {
      return channelID + "-" + "runner"
    }
  }()

  // There might be an issue that causes messages to sometimes be returned multiple times
  let receivedActionIdentifiers: NSMutableSet = NSMutableSet(array: [])

  func start(channelID: String) {
    self.channelID = channelID

    client.connection.on { stateChange in
        switch stateChange.current {
        case .connected:
            print("Connect to Ably client!")
        case .failed:
            fatalError("Server start error: \(String(describing: stateChange.reason))")
        default:
            break
        }
    }

    channel.subscribe(channelSubscribeID) { [weak self] message in
      guard let self else { return }

      guard let action = (message.data as? Data)?.decodedAction() else { return }

      guard receivedActionIdentifiers.contains(action.identifier) == false else {
        print("[COMPLETION] 3a. Already received: \(action.identifier)")
        return
      }

      receivedActionIdentifiers.add(action.identifier)

      print("[COMPLETION] 3. Received action: \(action.identifier)")

      switch action.invocation {
        case .completed(let completedAction):
          print("[COMPLETION] 4. calling handleCompletionAction for: \(completedAction.identifier) from parent action: \(action.identifier)")
          handleCompletionAction(completedAction)
        default:
          NotificationCenter.default.post(name: .receivedActionRequest, object: action)
      }
    }
  }

  private func handleCompletionAction(_ action: Communicator.Action) {
    sendSerialQueue.async { [weak self] in
      guard let self else { return }

      guard let completionHandler = completionHandlers[action.identifier] else {
        fatalError("There should have been a completion handler for \(action.identifier)")
      }

      print("[COMPLETION] 5. Removing completion handler: \(action.identifier)")

      completionHandlers.removeValue(forKey: action.identifier)

      DispatchQueue.main.async {
        print("[COMPLETION] 6. calling completionHandler for: \(action.identifier)")

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

      print("[COMPLETION] 1. Added completion handler for \(action.identifier)")

      completionHandlers[action.identifier] = completion

      print("[COMPLETION] 2. Completion handlers \(completionHandlers.keys)")

      let operation = BlockOperation { [weak self] in
        guard let self else { return }
        let semaphore = DispatchSemaphore(value: 0)
        sendSerialQueue.async { [weak self] in
          guard let self = self else { return }
          channel.publish(channelPublishID, data: action.data!) { _ in
            semaphore.signal()
          }
        }
        semaphore.wait()
      }
      operationQueue.addOperation(operation)
    }
  }

  let completedActionIdentifiers: NSMutableSet = NSMutableSet(array: [])

  func completed(action: Communicator.Action) {
    Task {
      print("[COMPLETION] Calling completed for action: \(action.identifier)")
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
