import UIKit

final class SignatureStore {
  private let store: DocumentStore
  init(_ store: DocumentStore) { self.store = store }

  private func file(_ id: String) throws -> URL {
    guard UUID(uuidString: id) != nil else { throw ScannerFailure(code: "invalid_input", message: "Invalid signature identity") }
    return store.root.appendingPathComponent("signatures/\(id).json")
  }

  func list() throws -> [Signature] {
    try store.locked {
      try FileManager.default.contentsOfDirectory(at: store.root.appendingPathComponent("signatures"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.map { try JSONDecoder().decode(Signature.self, from: Data(contentsOf: $0)) }
    }
  }

  func save(_ strokes: [Stroke]) throws -> Signature {
    guard strokes.contains(where: { $0.points.count > 1 }), strokes.allSatisfy({ stroke in
      ["#111111", "#1546A0", "#A01919"].contains(stroke.color) && stroke.width.isFinite && stroke.width > 0 && stroke.width <= 0.1 && stroke.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }
    }) else { throw ScannerFailure(code: "invalid_input", message: "Draw a signature before saving") }
    return try store.locked {
      let size = CGSize(width: 1200, height: 480)
      let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
      let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
        for stroke in strokes {
          guard let first = stroke.points.first else { continue }
          let cg = renderer.cgContext
          let color: UIColor = stroke.color == "#1546A0" ? UIColor(red: 0.08, green: 0.27, blue: 0.63, alpha: 1) : stroke.color == "#A01919" ? UIColor(red: 0.63, green: 0.1, blue: 0.1, alpha: 1) : .black
          cg.setStrokeColor(color.cgColor); cg.setLineWidth(stroke.width*size.width); cg.setLineCap(.round); cg.setLineJoin(.round)
          cg.beginPath(); cg.move(to: CGPoint(x: first.x*size.width, y: first.y*size.height))
          for point in stroke.points.dropFirst() { cg.addLine(to: CGPoint(x: point.x*size.width, y: point.y*size.height)) }; cg.strokePath()
        }
      }
      let id = UUID().uuidString
      let relative = "signatures/\(id).png"
      guard let bytes = image.pngData() else { throw ScannerFailure(code: "processing", message: "Signature rendering failed") }
      try bytes.write(to: store.owned(relative), options: .atomic)
      let signature = Signature(id: id, name: "Signature", imageUri: relative)
      try JSONEncoder().encode(signature).write(to: file(id), options: .atomic)
      return signature
    }
  }

  func rename(_ id: String, name: String) throws {
    try store.locked {
      let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { throw ScannerFailure(code: "invalid_input", message: "Enter a signature name") }
      let url = try file(id)
      var value = try JSONDecoder().decode(Signature.self, from: Data(contentsOf: url)); value.name = name
      try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
  }

  func delete(_ id: String) throws {
    try store.locked {
      let url = try file(id)
      let value = try JSONDecoder().decode(Signature.self, from: Data(contentsOf: url))
      let image = try store.owned(value.imageUri)
      if FileManager.default.fileExists(atPath: image.path) { try FileManager.default.removeItem(at: image) }
      try FileManager.default.removeItem(at: url)
    }
  }

  func outward(_ signature: Signature) throws -> [String: Any] {
    var value = try json(signature); value["imageUri"] = try store.owned(signature.imageUri).absoluteString; return value
  }
}
