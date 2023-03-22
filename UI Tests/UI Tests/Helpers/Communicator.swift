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
    case assert(testName: String, precision: Float, captureArea: CaptureArea)
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

extension UIImage {
  func captureStatusBar(_ captureStatusBar: Bool) -> UIImage {
    return captureStatusBar ? self : withoutStatusBar
  }

  func captureHomeIndicator(_ captureHomeIndicator: Bool) -> UIImage {
    return captureHomeIndicator ? self : withoutHomeIndicator
  }

  func cropped(to frame: CGRect) -> UIImage {
    guard let cgImage = cgImage else {
      fatalError("Error creating `cropped` image")
    }

    let rect = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)

    if let croppedCGImage = cgImage.cropping(to: rect) {
      let image = UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
      return image
    }

    fatalError("Error creating `cropped` image")
  }

  var withoutStatusBar: UIImage {
    guard let cgImage = cgImage else {
      fatalError("Error creating `withoutStatusBar` image")
    }

    let iPhone14ProStatusBarInset = 59.0
    let yOffset = iPhone14ProStatusBarInset * scale
    let rect = CGRect(x: 0, y: Int(yOffset), width: cgImage.width, height: cgImage.height - Int(yOffset))

    if let croppedCGImage = cgImage.cropping(to: rect) {
      let image = UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
      return image
    }

    fatalError("Error creating `withoutStatusBar` image")
  }

  var withoutHomeIndicator: UIImage {
    guard let cgImage = cgImage else {
      fatalError("Error creating `withoutHomeIndicator` image")
    }

    let iPhone14ProHomeIndicatorInset = 34.0
    let yOffset = iPhone14ProHomeIndicatorInset * scale
    let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height - Int(yOffset))

    if let croppedCGImage = cgImage.cropping(to: rect) {
      let image = UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
      return image
    }

    fatalError("Error creating `withoutHomeIndicator` image")
  }
}
