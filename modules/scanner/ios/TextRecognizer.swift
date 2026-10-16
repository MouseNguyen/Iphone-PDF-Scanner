import Foundation
import Vision
import UIKit

enum TextRecognizer {
  static func languages() throws -> [String] {
    let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
    return try request.supportedRecognitionLanguages()
  }

  static func recognize(store: DocumentStore, id: String, pageId: String, expected: Int) throws -> Page {
    let generation = store.generation(id)
    let doc = try store.load(id)
    guard let page = doc.pages.first(where: { $0.id == pageId }), page.revision == expected else { throw ScannerFailure(code: "stale_revision", message: "Page changed before recognition") }
    let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
    var ocr = OCR(revision: expected)
    do {
      let handler = VNImageRequestHandler(url: try store.owned(page.imageUri), options: [:])
      try handler.perform([request])
      ocr.status = "ready"; ocr.languages = request.recognitionLanguages; ocr.apiRevision = request.revision
      ocr.lines = (request.results ?? []).compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        return OCRLine(text: candidate.string, bounds: Bounds(x: box.minX, y: 1-box.maxY, width: box.width, height: box.height), confidence: Double(candidate.confidence))
      }
    } catch {
      ocr.status = "failed"; ocr.errorCode = "processing"
    }
    return try store.locked {
      try store.check(id, generation: generation)
      var latest = try store.load(id)
      guard let index = latest.pages.firstIndex(where: { $0.id == pageId }), latest.pages[index].revision == expected else { throw ScannerFailure(code: "stale_revision", message: "Newer page retained; old recognition ignored") }
      latest.pages[index].ocr = ocr
      // OCR publication changes export contents even when page pixels are unchanged.
      latest.revision += 1
      try store.publish(latest)
      return latest.pages[index]
    }
  }
}
