//
//  Extensions.swift
//  UI Tests
//
//  Created by Bryan Dubno on 3/10/23.
//

import UIKit

// MARK: - Task

extension Task where Success == Never, Failure == Never {
  public static func sleep(timeInterval: TimeInterval) async {
    let nanoseconds = UInt64(timeInterval * 1_000_000_000)
    try? await sleep(nanoseconds: nanoseconds)
  }
}

// MARK: - Array

extension Array where Element == UInt8 {
  var data: Data {
    return Data(self)
  }
}

// MARK: - Data

extension Data {
  var string: String {
    return String(bytes: self, encoding: .utf8)!
  }

  var bytes: [UInt8] {
    return [UInt8](self)
  }
}

// MARK: - String

private extension String {
  var data: Data {
    let data = data(using: .utf8)!
    return data
  }
}

// MARK: - UIViewController

extension UIViewController {
  func dismissAsync() async {
    return await withCheckedContinuation { continuation in
      DispatchQueue.main.async { [weak self] in
        self?.dismiss(animated: true) {
          continuation.resume()
        }
      }
    }
  }
}

// MARK: - UIScreen

extension UIScreen {
  func snapshotImage() -> UIImage {
    let view = snapshotView(afterScreenUpdates: true)
    let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
    let image = renderer.image { ctx in
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
    return image
  }
}
