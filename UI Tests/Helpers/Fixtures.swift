//
//  Fixtures.swift
//  UI Tests
//

import Foundation
import ObjectiveC
import CryptoKit
import Swifter

/// Serves the Superwall API and paywall web content from recordings, so tests
/// don't wait on the network and don't depend on the backend or dashboard.
///
/// `SWK_FIXTURES` picks the mode:
/// - `replay` (the default when there are recordings): answer from
///   recordings, and fall back to the network for anything that wasn't
///   recorded.
/// - `record`: go to the network and save every response into
///   `SWK_FIXTURES_DIR` (the repo's `Fixtures` folder; the simulator can write
///   to the host's file system).
/// - `off` (the default without recordings): go to the network, as before.
///
/// API requests are answered by `FixtureURLProtocol`. Paywall pages are loaded
/// by WebKit in another process, out of reach of `URLProtocol`, so paywall URLs
/// in API responses are rewritten to the app's own HTTP server
/// (`/web/<host>/<path>`), which answers from recordings in the same way.
enum Fixtures {
  enum Mode: String {
    case replay
    case record
    case off
  }

  static let mode: Mode = {
    let value = ProcessInfo.processInfo.environment["SWK_FIXTURES"] ?? ""
    if let mode = Mode(rawValue: value) {
      return mode
    }
    // Without recordings, replaying would only add a hop to every request.
    let hasRecordings = [sourceDirectory, bundledDirectory].contains { directory in
      guard let directory else { return false }
      return FileManager.default.fileExists(atPath: directory.path)
    }
    return hasRecordings ? .replay : .off
  }()

  /// Where recordings are written, and read first when it's set. Otherwise
  /// they're read from the copy bundled with the app, which is what remote
  /// runners have.
  static let sourceDirectory: URL? = {
    guard let path = ProcessInfo.processInfo.environment["SWK_FIXTURES_DIR"], !path.isEmpty else {
      return nil
    }
    return URL(fileURLWithPath: path, isDirectory: true)
  }()

  static let bundledDirectory = Bundle.main.url(forResource: "Fixtures", withExtension: nil)

  /// Requests that only report something to the backend. Their responses
  /// don't affect the app, so they're answered immediately without a
  /// recording, and never sent.
  static let fireAndForgetPaths: Set<String> = [
    "events",
    "session_events",
    "confirm_assignments",
    "apple-search-ads/token",
    "api/match"
  ]

  /// Requests whose responses depend on what the app sends, such as the
  /// purchases in a redemption request, or on who the user is (a user's
  /// entitlements and experiment assignments are their own). A recording would answer with the
  /// state at the time it was made (e.g. "not subscribed" after a purchase),
  /// so these always go to the network.
  static let livePathSuffixes = [
    "/redeem",
    "/entitlements",
    "/assignments",
    "/checkout/session/poll-redemption-result",
    "/app-store/intro-eligibility/jws"
  ]

  static func isLivePath(_ path: String) -> Bool {
    return livePathSuffixes.contains { path.hasSuffix($0) }
  }

  /// Hosts whose requests go through the fixtures.
  static func isFixtureHost(_ host: String) -> Bool {
    return ["superwall.me", "superwall.com", "superwall.app", "superwall.dev"].contains { host.hasSuffix($0) }
  }

  static var webServerPort: UInt16 = 0

  /// Logs to the console, and to `SWK_FIXTURES_LOG` when it's set (the app's
  /// console isn't visible when the test runner launches it).
  static func log(_ format: String, _ arguments: CVarArg...) {
    let message = "[Fixtures] " + String(format: format, arguments: arguments)
    NSLog("%@", message)
    guard let path = ProcessInfo.processInfo.environment["SWK_FIXTURES_LOG"] else { return }
    logQueue.async {
      guard let data = (message + "\n").data(using: .utf8) else { return }
      if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
      } else {
        FileManager.default.createFile(atPath: path, contents: data)
      }
    }
  }

  private static let logQueue = DispatchQueue(label: "com.superwall.ui-tests.fixtures-log")

  // MARK: - Storage

  struct Recording: Codable {
    let status: Int
    let contentType: String?
    let body: Data
  }

  /// The file a request's recording lives in: readable and stable across
  /// runs. Volatile parts of the request (headers other than the API key,
  /// POST bodies) are left out so repeated runs map to the same file.
  static func relativePath(for url: URL, method: String, apiKey: String?) -> String {
    let host = url.host ?? "unknown"
    var path = url.path
    if path.isEmpty || path == "/" {
      path = "/index"
    }
    let query = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
      .filter { !volatileQueryItems.contains($0.name) }
      .sorted { $0.name < $1.name }
      .map { "\($0.name)=\($0.value ?? "")" }
      .joined(separator: "&")
    let identity = [method, query, apiKey ?? ""].joined(separator: "|")
    let digest = SHA256.hash(data: Data(identity.utf8))
      .prefix(6)
      .map { String(format: "%02x", $0) }
      .joined()
    let safePath = path
      .split(separator: "/")
      .map { segment -> String in
        // Anonymous users are identified by a device ID or alias
        // (`$SuperwallDevice:<id>`, `$SuperwallAlias:<id>`) that's different
        // on every simulator.
        if segment.hasPrefix("$Superwall"), let colon = segment.firstIndex(of: ":") {
          return String(segment[..<colon])
        }
        return segment.replacingOccurrences(of: "..", with: "_")
      }
      .joined(separator: "/")
    return "\(host)/\(safePath)~\(method.lowercased())-\(digest).json.gz"
  }

  /// Query items that differ between runs of the same test, such as the
  /// device ID a fresh install generates or a cache-busting timestamp.
  static let volatileQueryItems: Set<String> = ["deviceId", "device_id", "ts"]

  static func load(_ relativePath: String) -> Recording? {
    for directory in [sourceDirectory, bundledDirectory].compactMap({ $0 }) {
      let url = directory.appendingPathComponent(relativePath)
      if let data = try? Data(contentsOf: url),
        let json = try? data.gunzipped(),
        let recording = try? JSONDecoder().decode(Recording.self, from: json) {
        return recording
      }
    }
    return nil
  }

  /// Large images and videos are recorded as "not found": they'd make up most
  /// of the recordings' size, and the screen assertions compare text, not
  /// pixels. Answering them at once, rather than fetching them on replay,
  /// keeps pages from sitting in their loading state while they download.
  static let largestRecordedMedia = 256 * 1024

  static func isLargeMedia(_ recording: Recording) -> Bool {
    guard recording.body.count > largestRecordedMedia else { return false }
    guard let contentType = recording.contentType, !contentType.isEmpty else { return true }
    return ["image/", "video/", "audio/", "application/octet-stream"].contains { contentType.hasPrefix($0) }
  }

  static func save(_ recording: Recording, at relativePath: String) {
    let recording = isLargeMedia(recording)
      ? Recording(status: 404, contentType: nil, body: Data())
      : recording
    guard let directory = sourceDirectory else {
      Fixtures.log("SWK_FIXTURES=record needs SWK_FIXTURES_DIR; not saving %@", relativePath)
      return
    }
    let url = directory.appendingPathComponent(relativePath)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      // Gzipped: config responses are several megabytes of JSON each.
      try encoder.encode(recording).gzipped().write(to: url, options: .atomic)
    } catch {
      Fixtures.log("Couldn't save %@: %@", relativePath, "\(error)")
    }
  }

  /// A session that bypasses the fixtures, for fetching from the network.
  static let liveSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    isCreatingLiveSession = true
    defer { isCreatingLiveSession = false }
    return URLSession(configuration: configuration)
  }()

  private static var isCreatingLiveSession = false

  /// Puts `FixtureURLProtocol` first in every session the app creates. The
  /// SDK builds its own session from `.default`, which doesn't see
  /// `URLProtocol.registerClass`, so the protocol has to go into the session's
  /// configuration.
  static func installURLSessionHook() {
    Fixtures.log("mode %@, directory %@", mode.rawValue, sourceDirectory?.path ?? "bundled")
    guard mode != .off else { return }
    swizzleClassMethod(
      NSSelectorFromString("sessionWithConfiguration:"),
      with: #selector(URLSession.swk_session(configuration:))
    )
    swizzleClassMethod(
      NSSelectorFromString("sessionWithConfiguration:delegate:delegateQueue:"),
      with: #selector(URLSession.swk_session(configuration:delegate:delegateQueue:))
    )
  }

  private static func swizzleClassMethod(_ original: Selector, with replacement: Selector) {
    guard let originalMethod = class_getClassMethod(URLSession.self, original),
      let replacementMethod = class_getClassMethod(URLSession.self, replacement) else {
      Fixtures.log("Couldn't hook %@", NSStringFromSelector(original))
      return
    }
    method_exchangeImplementations(originalMethod, replacementMethod)
  }

  fileprivate static func addFixtureProtocol(to configuration: URLSessionConfiguration) {
    guard !isCreatingLiveSession else { return }
    let existing = (configuration.protocolClasses ?? []).filter { $0 != FixtureURLProtocol.self }
    configuration.protocolClasses = [FixtureURLProtocol.self] + existing
  }

  static func fetchLive(_ request: URLRequest) async -> Recording? {
    var request = request
    // Keeps `FixtureURLProtocol` from answering this request itself.
    request.setValue("1", forHTTPHeaderField: FixtureURLProtocol.handledKey)
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await liveSession.data(for: request)
    } catch {
      log("Fetching %@ failed: %@", request.url?.absoluteString ?? "", "\(error)")
      return nil
    }
    guard let http = response as? HTTPURLResponse else {
      return nil
    }
    return Recording(
      status: http.statusCode,
      contentType: http.value(forHTTPHeaderField: "Content-Type"),
      body: data
    )
  }

  // MARK: - Rewriting

  /// Points paywall web content at the app's server by rewriting every
  /// `https://` URL on a fixture host in a JSON response. Only the web view
  /// loads these (API calls go through `URLProtocol` either way).
  static func rewritingWebURLs(in body: Data, contentType: String?) -> Data {
    guard mode != .off, webServerPort != 0,
      contentType?.contains("json") ?? true,
      var text = String(data: body, encoding: .utf8) else {
      return body
    }
    text = rewriteAbsoluteURLs(in: text, escapedSlashes: true)
    text = rewriteAbsoluteURLs(in: text, escapedSlashes: false)
    return Data(text.utf8)
  }

  /// Rewrites absolute `https://` URLs for web content hosts in HTML and CSS,
  /// so assets the page references are served from recordings too.
  static func rewritingPageURLs(in body: Data, contentType: String?) -> Data {
    guard let contentType,
      contentType.contains("html") || contentType.contains("css"),
      let text = String(data: body, encoding: .utf8) else {
      return body
    }
    return Data(rewriteAbsoluteURLs(in: text, escapedSlashes: false).utf8)
  }

  private static func rewriteAbsoluteURLs(in text: String, escapedSlashes: Bool) -> String {
    let slash = escapedSlashes ? "\\/" : "/"
    let prefix = "https:\(slash)\(slash)"
    let local = "http:\(slash)\(slash)127.0.0.1:\(webServerPort)\(slash)web\(slash)"
    var result = ""
    var remainder = Substring(text)
    while let range = remainder.range(of: prefix) {
      result += remainder[..<range.lowerBound]
      let afterScheme = remainder[range.upperBound...]
      let hostEnd = afterScheme.firstIndex { $0 == "/" || $0 == "\\" || $0 == "\"" || $0 == "'" || $0 == ")" || $0 == " " }
        ?? afterScheme.endIndex
      let host = String(afterScheme[..<hostEnd])
      if isWebContentHost(host) {
        result += local + host
      } else {
        result += prefix + host
      }
      remainder = afterScheme[hostEnd...]
    }
    result += remainder
    return result
  }

  /// Hosts serving paywall pages and their assets: everything except the
  /// Superwall API, which goes through `FixtureURLProtocol` instead.
  static func isWebContentHost(_ host: String) -> Bool {
    guard !host.isEmpty, !host.hasPrefix("127.0.0.1"), !host.hasPrefix("localhost") else {
      return false
    }
    return !isAPIHost(host)
  }

  static func isAPIHost(_ host: String) -> Bool {
    guard isFixtureHost(host) else { return false }
    let apiPrefixes = ["api.", "collector.", "enrichment-api.", "subscriptions-api.", "mmp.", "web2app."]
    return apiPrefixes.contains { host.hasPrefix($0) }
  }

  // MARK: - Web server

  /// Adds the `/web/<host>/<path>` route to the app's HTTP server.
  static func installWebRoute(on server: HttpServer, port: UInt16) {
    guard mode != .off else { return }
    webServerPort = port
    // Swifter's router has no catch-all for the rest of a path, so this runs
    // as middleware, ahead of the routes.
    server.middleware.append { request in
      guard let (host, path) = webTarget(of: request) else {
        return nil
      }
      var components = URLComponents()
      components.scheme = "https"
      components.host = host
      components.percentEncodedPath = path
      if !request.queryParams.isEmpty {
        components.queryItems = request.queryParams.map { URLQueryItem(name: $0.0, value: $0.1) }
      }
      guard let url = components.url else {
        return HttpResponse.badRequest(nil)
      }
      let recording = webRecording(for: url)
      guard let recording else {
        return HttpResponse.notFound
      }
      let body = rewritingPageURLs(in: recording.body, contentType: recording.contentType)
      var headers = ["Access-Control-Allow-Origin": "*"]
      if let contentType = recording.contentType {
        headers["Content-Type"] = contentType
      }
      return HttpResponse.raw(recording.status, "OK", headers) { writer in
        try? writer.write(body)
      }
    }
  }

  /// The host and path a request to the app's server stands for, or nil if
  /// it isn't for web content.
  ///
  /// Requests under `/web/<host>/` say so directly. Pages also load things by
  /// root-relative paths (`/runtime/app.js`), including from scripts, which
  /// resolve against the app's server instead; those are matched to their
  /// host through the page that asked for them (`Referer`).
  private static func webTarget(of request: HttpRequest) -> (host: String, path: String)? {
    let routePrefix = "/web/"
    let requestPath = String(request.path.split(separator: "?", maxSplits: 1).first ?? "")
    if requestPath.hasPrefix(routePrefix) {
      let rest = requestPath.dropFirst(routePrefix.count)
      let host = String(rest.prefix { $0 != "/" })
      guard !host.isEmpty else { return nil }
      let path = String(rest.dropFirst(host.count))
      return (host, path.isEmpty ? "/" : path)
    }
    guard let referer = request.headers["referer"],
      let range = referer.range(of: routePrefix) else {
      return nil
    }
    let host = String(referer[range.upperBound...].prefix { $0 != "/" && $0 != "?" })
    guard !host.isEmpty else { return nil }
    return (host, requestPath.isEmpty ? "/" : requestPath)
  }

  /// Swifter runs handlers on its own threads, so waiting here is fine.
  private static func webRecording(for url: URL) -> Recording? {
    let relativePath = self.relativePath(for: url, method: "GET", apiKey: nil)
    if mode == .replay, let recording = load(relativePath) {
      return recording
    }
    log("web %@ from the network (%@)", url.absoluteString, mode.rawValue)
    let semaphore = DispatchSemaphore(value: 0)
    var fetched: Recording?
    Task.detached {
      fetched = await fetchLive(URLRequest(url: url))
      semaphore.signal()
    }
    semaphore.wait()
    if mode == .record, let fetched, fetched.status < 400 {
      save(fetched, at: relativePath)
    }
    return fetched
  }
}

extension URLSession {
  // After swizzling these run in place of the originals, and calling them
  // calls the originals.
  @objc class func swk_session(configuration: URLSessionConfiguration) -> URLSession {
    Fixtures.addFixtureProtocol(to: configuration)
    return swk_session(configuration: configuration)
  }

  @objc class func swk_session(
    configuration: URLSessionConfiguration,
    delegate: URLSessionDelegate?,
    delegateQueue: OperationQueue?
  ) -> URLSession {
    Fixtures.addFixtureProtocol(to: configuration)
    return swk_session(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
  }
}

// MARK: - FixtureURLProtocol

/// Answers Superwall API requests from recordings (see ``Fixtures``).
final class FixtureURLProtocol: URLProtocol {
  static let handledKey = "X-SWK-Fixture-Handled"

  private var loadTask: Task<Void, Never>?

  override class func canInit(with request: URLRequest) -> Bool {
    // Tests that simulate being offline (`allowNetworkRequests: false`) have
    // their requests broken by `NetworkConnectivityEvaluator`; recordings
    // mustn't answer them either.
    guard Constants.currentTestOptions.allowNetworkRequests,
      Fixtures.mode != .off,
      let host = request.url?.host,
      Fixtures.isFixtureHost(host),
      request.value(forHTTPHeaderField: handledKey) == nil else {
      return false
    }
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    let request = self.request
    loadTask = Task { [weak self] in
      let recording = await Self.recording(for: request)
      guard let self, !Task.isCancelled else { return }
      guard let recording, let url = request.url else {
        self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        return
      }
      var headers: [String: String] = [:]
      if let contentType = recording.contentType {
        headers["Content-Type"] = contentType
      }
      let body = Fixtures.rewritingWebURLs(in: recording.body, contentType: recording.contentType)
      let response = HTTPURLResponse(url: url, statusCode: recording.status, httpVersion: "HTTP/1.1", headerFields: headers)!
      self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      self.client?.urlProtocol(self, didLoad: body)
      self.client?.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {
    loadTask?.cancel()
  }

  private static func recording(for request: URLRequest) async -> Fixtures.Recording? {
    guard let url = request.url else { return nil }
    let method = request.httpMethod ?? "GET"
    // Paths look like `/api/v1/events`.
    let apiPath = url.path.split(separator: "/").dropFirst(2).joined(separator: "/")
    let isFireAndForget = method == "POST"
      && (Fixtures.fireAndForgetPaths.contains(apiPath) || Fixtures.fireAndForgetPaths.contains(String(url.path.dropFirst())))
    if isFireAndForget, Fixtures.mode == .replay {
      return Fixtures.Recording(status: 200, contentType: "application/json", body: Data("{}".utf8))
    }

    let apiKey = request.value(forHTTPHeaderField: "Authorization")
    let relativePath = Fixtures.relativePath(for: url, method: method, apiKey: apiKey)
    let isLive = Fixtures.isLivePath(url.path)
    if Fixtures.mode == .replay, !isLive, let recording = Fixtures.load(relativePath) {
      Fixtures.log("%@ %@ from a recording", method, url.absoluteString)
      return recording
    }
    if isLive {
      Fixtures.log("%@ %@ live", method, url.absoluteString)
    }
    if !isLive {
      Fixtures.log("%@ %@ from the network (%@)", method, url.absoluteString, Fixtures.mode.rawValue)
    }

    var liveRequest = request
    if liveRequest.httpBody == nil, let stream = request.httpBodyStream {
      liveRequest.httpBody = Data(reading: stream)
    }
    let recording = await Fixtures.fetchLive(liveRequest)
    if Fixtures.mode == .record, !isFireAndForget, !isLive, let recording, recording.status < 400 {
      Fixtures.save(recording, at: relativePath)
    }
    return recording
  }
}

private extension Data {
  init(reading stream: InputStream) {
    self.init()
    stream.open()
    defer { stream.close() }
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let read = stream.read(buffer, maxLength: bufferSize)
      if read <= 0 { break }
      append(buffer, count: read)
    }
  }
}
