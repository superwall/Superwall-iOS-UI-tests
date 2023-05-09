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

// MARK: - UIImage

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
