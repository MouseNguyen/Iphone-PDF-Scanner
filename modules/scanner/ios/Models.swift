import Foundation
import UIKit

struct ScannerFailure: LocalizedError {
  let code: String
  let message: String
  var errorDescription: String? { "\(code): \(message)" }
}

struct Point: Codable { var x: Double; var y: Double }
struct Bounds: Codable { var x: Double; var y: Double; var width: Double; var height: Double }
struct Placement: Codable {
  var assetId: String; var imageUri: String
  var x: Double; var y: Double; var width: Double; var height: Double
  var radians: Double; var mirrored: Bool
}
struct Edit: Codable {
  var filter: String = "auto"
  var quarterTurns: Int = 0
  var corners: [Point]? = nil
  var signatures: [Placement] = []
}
struct OCRLine: Codable { var text: String; var bounds: Bounds; var confidence: Double }
struct OCR: Codable {
  var status = "pending"
  var revision: Int
  var lines: [OCRLine] = []
  var languages: [String] = []
  var apiRevision: Int? = nil
  var errorCode: String? = nil
}
struct Page: Codable {
  var id: String; var revision: Int = 1
  var baseUri: String; var imageUri: String
  var edit: Edit; var ocr: OCR
  var nativeCorrected: Bool? = nil
}
struct Document: Codable {
  var schemaVersion = 1
  var id: String; var revision: Int = 1; var name: String; var mode: String
  var createdAt: String; var updatedAt: String
  var pageIds: [String]; var pages: [Page]; var saved = false
  var idSourcePages: [Page]? = nil
}
struct Signature: Codable { var id: String; var name: String; var imageUri: String }
struct Stroke: Codable { var points: [Point]; var color: String; var width: Double }

func decode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
  try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
}

func json<T: Encodable>(_ value: T) throws -> [String: Any] {
  guard let result = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] else {
    throw ScannerFailure(code: "processing", message: "Invalid native result")
  }
  return result
}
