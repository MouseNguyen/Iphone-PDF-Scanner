import Foundation
import UIKit

final class DocumentStore {
  let root: URL
  private let lock = NSRecursiveLock()
  private let cancellationLock = NSLock()
  private var generations: [String: Int] = [:]
  private let fm = FileManager.default
  private let writeManifest: (Data, URL) throws -> Void

  init(root: URL? = nil, writeManifest: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) throws {
    self.writeManifest = writeManifest
    self.root = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("PocketScanner", isDirectory: true)
    for name in ["documents", "staging", "signatures"] {
      try fm.createDirectory(at: self.root.appendingPathComponent(name), withIntermediateDirectories: true)
    }
  }

  func locked<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock(); defer { lock.unlock() }; return try body()
  }

  func folder(_ id: String) throws -> URL {
    guard UUID(uuidString: id) != nil else { throw ScannerFailure(code: "invalid_input", message: "Invalid document identity") }
    return root.appendingPathComponent("documents/\(id)", isDirectory: true)
  }

  func owned(_ relative: String) throws -> URL {
    let url = root.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
    guard url.path.hasPrefix(root.standardizedFileURL.resolvingSymlinksInPath().path + "/") else {
      throw ScannerFailure(code: "invalid_input", message: "File is outside scanner storage")
    }
    return url
  }

  func input(_ uri: String) throws -> URL {
    guard let url = URL(string: uri), url.isFileURL else { throw ScannerFailure(code: "invalid_input", message: "Expected a local image") }
    let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
    let allowed = [root, fm.urls(for: .cachesDirectory, in: .userDomainMask)[0], URL(fileURLWithPath: NSTemporaryDirectory())]
    guard allowed.contains(where: { resolved.path.hasPrefix($0.standardizedFileURL.resolvingSymlinksInPath().path + "/") }), fm.fileExists(atPath: resolved.path) else {
      throw ScannerFailure(code: "invalid_input", message: "Image is unavailable or not app-owned")
    }
    return resolved
  }

  func stage(_ image: UIImage, corrected: Bool = false) throws -> String {
    guard let data = image.jpegData(compressionQuality: 0.95) else { throw ScannerFailure(code: "processing", message: "Image could not be encoded") }
    let url = root.appendingPathComponent("staging/\(corrected ? "scan-" : "image-")\(UUID().uuidString).jpg")
    try data.write(to: url, options: .atomic)
    return url.absoluteString
  }

  private func makePage(_ uri: String, documentId: String, mode: String) throws -> Page {
    let source = try input(uri)
    let id = UUID().uuidString
    let relative = "documents/\(documentId)/\(id)-base.jpg"
    guard let image = UIImage(contentsOfFile: source.path) else { throw ScannerFailure(code: "invalid_input", message: "Selected file is not a readable image") }
    let normalized = ImageProcessor.oriented(image)
    guard let bytes = normalized.jpegData(compressionQuality: 0.95) else { throw ScannerFailure(code: "processing", message: "Image encoding failed") }
    try bytes.write(to: owned(relative), options: .atomic)
    let corrected = source.lastPathComponent.hasPrefix("scan-")
    let edit = Edit(filter: mode == "photo" ? "color" : "auto")
    var output = relative
    if mode != "photo" && !corrected {
      let processed = try ImageProcessor.render(base: owned(relative), edit: edit, alreadyCorrected: false, resolve: owned)
      output = "documents/\(documentId)/\(id)-initial.jpg"
      guard let data = processed.jpegData(compressionQuality: 0.95) else { throw ScannerFailure(code: "processing", message: "Image cleanup failed") }
      try data.write(to: owned(output), options: .atomic)
    }
    return Page(id: id, baseUri: relative, imageUri: output, edit: edit, ocr: OCR(revision: 1), nativeCorrected: corrected)
  }

  func createDraft(mode: String, uris: [String]) throws -> Document {
    try locked {
      guard ["document", "id", "photo"].contains(mode), !uris.isEmpty else { throw ScannerFailure(code: "invalid_input", message: "Choose a mode and at least one image") }
      let id = UUID().uuidString
      let directory = try folder(id)
      try fm.createDirectory(at: directory, withIntermediateDirectories: true)
      do {
        var pages: [Page] = []
        for uri in uris { pages.append(try autoreleasepool { try makePage(uri, documentId: id, mode: mode) }) }
        let now = ISO8601DateFormatter().string(from: Date())
        let doc = Document(id: id, name: "Scan \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))", mode: mode, createdAt: now, updatedAt: now, pageIds: pages.map(\.id), pages: pages)
        try publish(doc)
        return doc
      } catch {
        // Unpublished files remain owned and recoverable; no saved entry is exposed.
        throw error
      }
    }
  }

  func load(_ id: String) throws -> Document {
    try locked {
      let doc = try JSONDecoder().decode(Document.self, from: Data(contentsOf: folder(id).appendingPathComponent("document.json")))
      guard doc.schemaVersion == 1, doc.id == id, Set(doc.pageIds).count == doc.pageIds.count, doc.pageIds == doc.pages.map(\.id), !doc.pages.isEmpty else {
        throw ScannerFailure(code: "invalid_input", message: "Unsupported or damaged document metadata")
      }
      for page in doc.pages {
        for path in [page.baseUri, page.imageUri] {
          guard fm.fileExists(atPath: try owned(path).path) else { throw ScannerFailure(code: "storage", message: "A document image is missing") }
        }
      }
      return doc
    }
  }

  func list(saved: Bool) throws -> [Document] {
    try locked {
      let folders = try fm.contentsOfDirectory(at: root.appendingPathComponent("documents"), includingPropertiesForKeys: nil)
      return try folders.filter { fm.fileExists(atPath: $0.appendingPathComponent("document.json").path) }.map { try load($0.lastPathComponent) }.filter { $0.saved == saved }.sorted { $0.updatedAt > $1.updatedAt }
    }
  }

  func librarySnapshot() throws -> [String: Any] {
    try locked {
      var saved: [[String: Any]] = [], drafts: [[String: Any]] = [], unavailable: [[String: String]] = []
      let directories = try fm.contentsOfDirectory(at: root.appendingPathComponent("documents"), includingPropertiesForKeys: nil)
      for directory in directories {
        let id = directory.lastPathComponent
        guard UUID(uuidString: id) != nil else { continue }
        do {
          let doc = try load(id), value = try outward(doc)
          if doc.saved { saved.append(value) } else { drafts.append(value) }
        } catch {
          unavailable.append(["id": id, "reason": "This document or interrupted import could not be opened. Its files are retained. \(error.localizedDescription)"])
        }
      }
      return ["documents": saved, "drafts": drafts, "unavailable": unavailable]
    }
  }

  func publish(_ doc: Document) throws {
    let data = try JSONEncoder().encode(doc)
    try writeManifest(data, folder(doc.id).appendingPathComponent("document.json"))
  }

  func update(_ id: String, expected: Int, _ transform: (inout Document) throws -> Void) throws -> Document {
    try locked {
      var doc = try load(id)
      guard doc.revision == expected else { throw ScannerFailure(code: "stale_revision", message: "Document changed; reload and retry") }
      try transform(&doc)
      doc.revision += 1
      doc.updatedAt = ISO8601DateFormatter().string(from: Date())
      try publish(doc)
      return doc
    }
  }

  func save(_ id: String, expected: Int, name: String) throws -> Document {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw ScannerFailure(code: "invalid_input", message: "Enter a document name") }
    return try update(id, expected: expected) { $0.name = name; $0.saved = true }
  }

  func discardDraft(_ id: String) throws {
    try locked {
      guard try !load(id).saved else { throw ScannerFailure(code: "invalid_input", message: "Saved documents require confirmed deletion") }
      try fm.removeItem(at: folder(id))
    }
  }

  func delete(_ ids: [String]) throws {
    try locked { for id in ids { try fm.removeItem(at: folder(id)) } }
  }

  func outward(_ doc: Document) throws -> [String: Any] {
    var value = try json(doc)
    value["pages"] = try doc.pages.map { try outward($0) }
    if let sources = doc.idSourcePages { value["idSourcePages"] = try sources.map { try outward($0) } }
    return value
  }

  func outward(_ page: Page) throws -> [String: Any] {
    var value = try json(page)
    value["baseUri"] = try owned(page.baseUri).absoluteString
    value["imageUri"] = try owned(page.imageUri).absoluteString
    var edit = try json(page.edit)
    edit["signatures"] = try page.edit.signatures.map { placement -> [String: Any] in
      var result = try json(placement); result["imageUri"] = try owned(placement.imageUri).absoluteString; return result
    }
    value["edit"] = edit
    return value
  }

  func edit(_ id: String, pageId: String, expected: Int, edit: Edit) throws -> Document {
    try update(id, expected: expected) { doc in
      guard let index = doc.pages.firstIndex(where: { $0.id == pageId }) else { throw ScannerFailure(code: "invalid_input", message: "Page not found") }
      var recipe = edit
      try ImageProcessor.validate(recipe)
      for index in recipe.signatures.indices {
        let source = try input(recipe.signatures[index].imageUri)
        let relative = "documents/\(id)/signature-\(UUID().uuidString).png"
        try fm.copyItem(at: source, to: owned(relative))
        recipe.signatures[index].imageUri = relative
      }
      let page = doc.pages[index]
      let relative = "documents/\(id)/\(pageId)-\(UUID().uuidString).jpg"
      let image = try ImageProcessor.render(base: owned(page.baseUri), edit: recipe, alreadyCorrected: page.nativeCorrected ?? false, resolve: owned)
      guard let bytes = image.jpegData(compressionQuality: 0.95) else { throw ScannerFailure(code: "processing", message: "Edited image could not be encoded") }
      try bytes.write(to: owned(relative), options: .atomic)
      doc.pages[index].imageUri = relative
      doc.pages[index].edit = recipe
      doc.pages[index].revision += 1
      doc.pages[index].ocr = OCR(revision: doc.pages[index].revision)
    }
  }

  func reorder(_ id: String, expected: Int, ids: [String]) throws -> Document {
    try update(id, expected: expected) { doc in
      guard ids.count == doc.pages.count, Set(ids) == Set(doc.pageIds) else { throw ScannerFailure(code: "invalid_input", message: "Invalid page order") }
      let lookup = Dictionary(uniqueKeysWithValues: doc.pages.map { ($0.id, $0) })
      doc.pages = try ids.map { pageId in
        guard let page = lookup[pageId] else { throw ScannerFailure(code: "invalid_input", message: "Unknown page") }; return page
      }
      doc.pageIds = ids
    }
  }

  func removePage(_ id: String, expected: Int, pageId: String) throws -> Document {
    try update(id, expected: expected) { doc in
      guard doc.pages.count > 1, doc.pageIds.contains(pageId) else { throw ScannerFailure(code: "invalid_input", message: "Keep at least one page or delete the document") }
      doc.pages.removeAll { $0.id == pageId }; doc.pageIds = doc.pages.map(\.id)
    }
  }

  func append(_ id: String, expected: Int, uris: [String], replace: String?) throws -> Document {
    try update(id, expected: expected) { doc in
      guard !uris.isEmpty else { throw ScannerFailure(code: "invalid_input", message: "No images selected") }
      var pages: [Page] = []
      for uri in uris { pages.append(try autoreleasepool { try makePage(uri, documentId: id, mode: doc.mode) }) }
      if let replace = replace {
        guard let index = doc.pages.firstIndex(where: { $0.id == replace }) else { throw ScannerFailure(code: "invalid_input", message: "Page to retake no longer exists") }
        doc.pages.replaceSubrange(index...index, with: pages)
      } else { doc.pages.append(contentsOf: pages) }
      doc.pageIds = doc.pages.map(\.id)
    }
  }

  func composeID(_ id: String, expected: Int) throws -> Document {
    try update(id, expected: expected) { doc in
      guard doc.mode == "id", doc.pages.count == 2 else { throw ScannerFailure(code: "invalid_input", message: "Review both ID sides before composing") }
      let image = try ImageProcessor.compose(front: owned(doc.pages[0].imageUri), back: owned(doc.pages[1].imageUri))
      let uri = try stage(image, corrected: true)
      let page = try makePage(uri, documentId: id, mode: "id")
      doc.idSourcePages = doc.pages; doc.pages = [page]; doc.pageIds = [page.id]
    }
  }

  func restoreIDSides(_ id: String, expected: Int) throws -> Document {
    try update(id, expected: expected) { doc in
      guard let sources = doc.idSourcePages, sources.count == 2 else { throw ScannerFailure(code: "invalid_input", message: "No retained ID sides") }
      doc.pages = sources; doc.pageIds = sources.map(\.id); doc.idSourcePages = nil
    }
  }

  func preferences(_ value: [String: Any]? = nil) throws -> [String: Any] {
    try locked {
      let url = root.appendingPathComponent("library-preferences.json")
      if let value = value {
        guard let grid = value["grid"] as? Bool, let sort = value["sort"] as? String, let category = value["category"] as? String, ["name", "date"].contains(sort), ["all", "document", "id", "photo"].contains(category) else { throw ScannerFailure(code: "invalid_input", message: "Invalid library preference") }
        let normalized: [String: Any] = ["grid": grid, "sort": sort, "category": category]
        try JSONSerialization.data(withJSONObject: normalized).write(to: url, options: .atomic)
        return normalized
      }
      if fm.fileExists(atPath: url.path), let stored = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] { return stored }
      return ["grid": false, "sort": "date", "category": "all"]
    }
  }

  func generation(_ id: String) -> Int { cancellationLock.lock(); defer { cancellationLock.unlock() }; return generations[id, default: 0] }
  func cancel(_ id: String) { cancellationLock.lock(); defer { cancellationLock.unlock() }; generations[id, default: 0] += 1 }
  func check(_ id: String, generation: Int) throws {
    guard self.generation(id) == generation else { throw ScannerFailure(code: "cancelled", message: "Processing cancelled; images retained") }
  }
}
