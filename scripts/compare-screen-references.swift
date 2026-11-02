#!/usr/bin/env swift
//
// Cross-checks the JSON screen references against the older PNG references,
// which were reviewed by eye when they were recorded.
//
// For every `__Snapshots__/Screens/<name>.json` with a matching
// `__Snapshots__/Automated_UI_Testing/<name>.png`, the PNG is OCR'd with
// Vision and its words are compared with the text in the JSON. Assertions
// whose words disagree are listed for a human to review: either the new
// reference captured the wrong screen, or the paywall changed on the
// dashboard since the PNG was recorded.
//
// Usage: swift scripts/compare-screen-references.swift [min-overlap=0.8]
//

import Foundation
import Vision
import AppKit

let root = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
  .appendingPathComponent("Automated UI Testing/__Snapshots__")
let screens = root.appendingPathComponent("Screens")
let pngs = root.appendingPathComponent("Automated_UI_Testing")
let threshold = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 0.8

func words(in text: String) -> Set<String> {
  let tokens = text.lowercased()
    .components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { $0.count >= 3 }
  return Set(tokens)
}

func collectText(_ object: Any) -> [String] {
  switch object {
  case let string as String:
    return [string]
  case let array as [Any]:
    return array.flatMap(collectText)
  case let dictionary as [String: Any]:
    // Only on-screen text, not identifiers or states.
    return ["text", "title", "message", "actions", "buttons"]
      .compactMap { dictionary[$0] }
      .flatMap(collectText)
      + dictionary.values.filter { $0 is [Any] || $0 is [String: Any] }.flatMap(collectText)
  default:
    return []
  }
}

func ocr(_ url: URL) -> String {
  guard
    let image = NSImage(contentsOf: url),
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
  else {
    return ""
  }
  let request = VNRecognizeTextRequest()
  request.recognitionLevel = .accurate
  request.usesLanguageCorrection = false
  try? VNImageRequestHandler(cgImage: cgImage).perform([request])
  return (request.results ?? [])
    .compactMap { $0.topCandidates(1).first?.string }
    .joined(separator: "\n")
}

let references = ((try? FileManager.default.contentsOfDirectory(at: screens, includingPropertiesForKeys: nil)) ?? [])
  .filter { $0.pathExtension == "json" }
  .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

var flagged: [(String, Double, Set<String>, Set<String>)] = []
var compared = 0
var withoutPNG: [String] = []

for reference in references {
  let name = reference.deletingPathExtension().lastPathComponent
  let png = pngs.appendingPathComponent("\(name).png")
  guard FileManager.default.fileExists(atPath: png.path) else {
    withoutPNG.append(name)
    continue
  }
  guard
    let data = try? Data(contentsOf: reference),
    let json = try? JSONSerialization.jsonObject(with: data)
  else {
    continue
  }
  compared += 1

  // The PNG only shows what fits on screen, so measure how much of what the
  // PNG shows is present in the JSON, not the other way around.
  let expected = words(in: ocr(png))
  let actual = words(in: collectText(json).joined(separator: " "))
  let overlap = expected.isEmpty ? (actual.isEmpty ? 1 : 0) : Double(expected.intersection(actual).count) / Double(expected.count)
  if overlap < threshold {
    flagged.append((name, overlap, expected.subtracting(actual), actual.subtracting(expected)))
  }
}

print("Compared \(compared) screen references with their PNGs; \(flagged.count) below \(Int(threshold * 100))% word overlap.\n")
for (name, overlap, missing, extra) in flagged {
  print("\(name): \(Int(overlap * 100))% of the PNG's words are in the JSON")
  if !missing.isEmpty {
    print("  only in PNG:  \(missing.sorted().prefix(15).joined(separator: ", "))")
  }
  if !extra.isEmpty {
    print("  only in JSON: \(extra.sorted().prefix(15).joined(separator: ", "))")
  }
}
if !withoutPNG.isEmpty {
  print("\nNo PNG to compare against: \(withoutPNG.joined(separator: ", "))")
}
