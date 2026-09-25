//
//  ScreenInspector.swift
//  UI Tests
//

import UIKit
import WebKit
import SafariServices
import SuperwallKit

/// Describes what is on screen in device-independent terms: which paywall is
/// presented, whether it finished loading, the text it shows, and any alerts
/// or other controllers above it.
///
/// Unlike a screenshot, this survives a change of device, iOS runtime or
/// rendering engine, and a mismatch produces a readable diff
/// ("'View All Plans' was added") instead of a pixel percentage.
struct ScreenState: Encodable, Equatable {
  struct Layer: Encodable, Equatable {
    var kind: String
    var presentationStyle: String?
    var paywallIdentifier: String?
    var loadingState: String?
    var text: [String]?
    var title: String?
    var message: String?
    var actions: [String]?
  }

  var layers: [Layer]

  /// Pretty, key-sorted JSON so references are stable and diff line-by-line.
  var json: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(self), let string = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return string
  }
}

enum ScreenInspector {
  /// Captures the current screen. Also reports whether anything is still in
  /// motion (presentation transitions, web views loading), which callers use
  /// to decide when the screen has settled. `patient` gives slow pages longer
  /// to report their text; use it for the capture that gets asserted, not for
  /// polling.
  @MainActor
  static func capture(patient: Bool = false) async -> (state: ScreenState, isStable: Bool) {
    var layers: [ScreenState.Layer] = []
    var isStable = true
    var seen = Set<ObjectIdentifier>()

    for (controller, isWindowRoot) in presentedControllers() where seen.insert(ObjectIdentifier(controller)).inserted {
      if controller.isBeingPresented || controller.isBeingDismissed {
        isStable = false
      }
      guard var layer = await layer(for: controller, patient: patient, isStable: &isStable) else {
        continue
      }
      if isWindowRoot {
        // Window roots are hosting containers (ours, Superwall's presentation
        // window, the keyboard); only report them when they show something.
        guard layer.kind == "paywall" || layer.kind == "alert" || !(layer.text ?? []).isEmpty else {
          continue
        }
        layer.presentationStyle = nil
      }
      layers.append(layer)
    }

    return (ScreenState(layers: layers), isStable)
  }

  // MARK: - Layers

  @MainActor
  private static func layer(for controller: UIViewController, patient: Bool, isStable: inout Bool) async -> ScreenState.Layer? {
    if let paywall = controller as? PaywallViewController {
      // A purchase in progress is reported as "ready": when the paywall flips
      // to it depends on StoreKit timing, and the steps after a purchase
      // assert its outcome anyway.
      let loadingState = paywall.loadingState == .loadingPurchase ? "ready" : describe(paywall.loadingState)
      // A purchase or manual spinner is a resting state waiting on the user
      // (e.g. the system purchase sheet); only page loads are in motion.
      if paywall.loadingState == .loadingURL || paywall.loadingState == .unknown {
        isStable = false
      }
      var layer = ScreenState.Layer(
        kind: "paywall",
        presentationStyle: describe(paywall.modalPresentationStyle),
        paywallIdentifier: paywall.info.identifier,
        loadingState: loadingState
      )
      let webViews = paywall.isViewLoaded ? paywall.view.allSubviews(of: WKWebView.self) : []
      if webViews.contains(where: { $0.isLoading }) {
        isStable = false
      }
      var text: [String] = []
      for webView in webViews where !webView.isHidden {
        if let lines = await visibleText(of: webView, timeout: patient ? 10 : 1) {
          text += lines
        } else {
          isStable = false
        }
      }
      layer.text = text
      return layer
    }

    if let alert = controller as? UIAlertController {
      return ScreenState.Layer(
        kind: alert.preferredStyle == .alert ? "alert" : "actionSheet",
        title: alert.title.map(normalize),
        message: alert.message.map(normalize),
        // Sorted: Superwall shuffles survey options on every presentation.
        actions: alert.actions.map { normalize($0.title ?? "") }.sorted()
      )
    }

    if controller is SFSafariViewController {
      return ScreenState.Layer(kind: "safari")
    }

    // The test host's own root screen carries no information.
    if controller is RootViewController {
      return nil
    }

    // Containers (e.g. a navigation controller wrapping a paywall) are
    // described by their visible child.
    if let navigation = controller as? UINavigationController, let top = navigation.topViewController {
      return await layer(for: top, patient: patient, isStable: &isStable)
    }

    let labels = controller.isViewLoaded ? controller.view.allSubviews(of: UILabel.self)
      .filter { !$0.isHidden && $0.alpha > 0 }
      .compactMap { $0.text.map(normalize) }
      .filter { !$0.isEmpty } : []
    return ScreenState.Layer(
      kind: "viewController",
      presentationStyle: describe(controller.modalPresentationStyle),
      text: labels
    )
  }

  /// Every presented controller, bottom to top, across all visible windows.
  /// Paywalls can be presented from their own window, outside the key window's
  /// presentation chain.
  @MainActor
  private static func presentedControllers() -> [(controller: UIViewController, isWindowRoot: Bool)] {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .filter { !$0.isHidden && $0.alpha > 0 }
      .sorted { $0.windowLevel < $1.windowLevel }

    var controllers: [(UIViewController, Bool)] = []
    for window in windows {
      var controller = window.rootViewController
      var isRoot = true
      while let current = controller {
        controllers.append((current, isRoot))
        controller = current.presentedViewController
        isRoot = false
      }
    }
    if Superwall.isInitialized, let paywall = Superwall.shared.presentedViewController {
      controllers.append((paywall, false))
    }
    return controllers
  }

  // MARK: - Text

  /// Returns nil when the page didn't answer in time.
  @MainActor
  private static func visibleText(of webView: WKWebView, timeout: TimeInterval) async -> [String]? {
    // `innerText` only includes rendered text: elements hidden with CSS are
    // excluded, matching what a person would read.
    let script = "document.body ? document.body.innerText : ''"
    // A busy page can take many seconds to run the script; don't let one
    // read stall the whole wait.
    let result: String? = await withCheckedContinuation { continuation in
      var hasResumed = false
      webView.evaluateJavaScript(script) { value, _ in
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(returning: value as? String)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(returning: nil)
      }
    }
    guard let text = result else {
      return nil
    }
    return text
      .components(separatedBy: .newlines)
      .map(normalize)
      .filter { !$0.isEmpty }
  }

  private static let volatilePatterns: [(NSRegularExpression, String)] = {
    let month = "(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\\.?"
    let rules: [(String, String)] = [
      // Dates computed at runtime, e.g. trial end dates.
      // "1 October 2026" first, so "October 20" isn't taken out of it.
      ("\\b\\d{1,2} \(month)(?: \\d{4})?(?!\\d)", "<date>"),
      ("\\b\(month) \\d{1,2}(?:st|nd|rd|th)?(?!\\d)(?:, \\d{4})?", "<date>"),
      ("\\b\\d{1,4}[/.-]\\d{1,2}[/.-]\\d{1,4}\\b", "<date>"),
      // Clocks and countdown timers.
      ("\\b\\d{1,2}:\\d{2}(?::\\d{2})?(?:\\s?[AaPp][Mm])?", "<time>")
    ]
    return rules.map { (try! NSRegularExpression(pattern: $0.0), $0.1) }
  }()

  /// Collapses whitespace and masks values that change from run to run, so
  /// references stay stable and countdowns don't keep the screen "unsettled".
  static func normalize(_ text: String) -> String {
    var result = text
      .replacingOccurrences(of: "\u{00A0}", with: " ")
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    for (regex, replacement) in volatilePatterns {
      result = regex.stringByReplacingMatches(
        in: result,
        range: NSRange(result.startIndex..., in: result),
        withTemplate: replacement
      )
    }
    return result
  }

  // MARK: - Descriptions

  private static func describe(_ state: PaywallLoadingState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .loadingPurchase: return "loadingPurchase"
    case .loadingURL: return "loadingURL"
    case .manualLoading: return "manualLoading"
    case .ready: return "ready"
    @unknown default: return "other"
    }
  }

  private static func describe(_ style: UIModalPresentationStyle) -> String {
    switch style {
    case .fullScreen: return "fullScreen"
    case .pageSheet: return "pageSheet"
    case .formSheet: return "formSheet"
    case .currentContext: return "currentContext"
    case .custom: return "custom"
    case .overFullScreen: return "overFullScreen"
    case .overCurrentContext: return "overCurrentContext"
    case .popover: return "popover"
    case .none: return "none"
    case .automatic: return "automatic"
    @unknown default: return "other"
    }
  }
}

extension UIView {
  func allSubviews<T: UIView>(of type: T.Type) -> [T] {
    var result: [T] = []
    if let view = self as? T {
      result.append(view)
    }
    for subview in subviews {
      result.append(contentsOf: subview.allSubviews(of: type))
    }
    return result
  }
}
