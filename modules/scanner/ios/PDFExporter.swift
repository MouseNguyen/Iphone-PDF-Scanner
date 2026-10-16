import UIKit
import CoreText

enum PDFExporter {
  static func export(store: DocumentStore, id: String, expected: Int, allowImageOnly: Bool) throws -> [String: Any] {
    let generation = store.generation(id)
    let doc = try store.load(id)
    guard doc.revision == expected else { throw ScannerFailure(code: "stale_revision", message: "Reload the document before exporting") }
    let missing = doc.pages.filter { $0.ocr.status != "ready" || $0.ocr.revision != $0.revision }.map(\.id)
    guard missing.isEmpty || allowImageOnly else { throw ScannerFailure(code: "processing", message: "Some pages are not searchable. Retry recognition or explicitly choose image-only export.") }
    let url = try store.folder(id).appendingPathComponent("export-\(expected)-\(UUID().uuidString).pdf")
    let staging = url.appendingPathExtension("partial")
    defer { try? FileManager.default.removeItem(at: staging) }
    let pageBounds = CGRect(x: 0, y: 0, width: 595.276, height: 841.89)
    let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
    try renderer.writePDF(to: staging) { context in
      for page in doc.pages {
        autoreleasepool {
          context.beginPage()
          guard let imageURL = try? store.owned(page.imageUri), let image = UIImage(contentsOfFile: imageURL.path) else { return }
          let rect = AVFit(image.size, in: pageBounds)
          image.draw(in: rect)
          guard !missing.contains(page.id) else { return }
          let cg = context.cgContext
          for line in page.ocr.lines where !line.text.isEmpty {
            let b = line.bounds
            let target = CGRect(x: rect.minX + b.x*rect.width, y: rect.minY + b.y*rect.height, width: b.width*rect.width, height: b.height*rect.height)
            guard target.width > 0, target.height > 0 else { continue }
            let font = CTFontCreateWithName("Helvetica" as CFString, max(1, target.height*0.85), nil)
            let text = NSAttributedString(string: line.text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            let ctLine = CTLineCreateWithAttributedString(text)
            let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
            guard width > 0 else { continue }
            cg.saveGState()
            cg.translateBy(x: target.minX, y: target.maxY)
            cg.scaleBy(x: target.width / width, y: -1)
            cg.textMatrix = .identity; cg.textPosition = .zero; cg.setTextDrawingMode(.invisible)
            CTLineDraw(ctLine, cg); cg.restoreGState()
          }
        }
      }
    }
    try store.check(id, generation: generation)
    return try store.locked {
      guard try store.load(id).revision == expected else { throw ScannerFailure(code: "stale_revision", message: "Document changed during export; retry") }
      // Validate every snapshot input before publishing; failed reads never become a valid export.
      for page in doc.pages {
        guard UIImage(contentsOfFile: try store.owned(page.imageUri).path) != nil else { throw ScannerFailure(code: "storage", message: "A page is unavailable") }
      }
      try FileManager.default.moveItem(at: staging, to: url)
      return ["uri": url.absoluteString, "revision": expected, "imageOnlyPageIds": missing]
    }
  }
}
