import XCTest
import UIKit
@testable import PocketScanner

final class DocumentStoreTests: XCTestCase {
  func testUnreadableImportDoesNotHideSavedDocuments() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 40)).image { _ in }
    let draft = try store.createDraft(mode: "photo", uris: [store.stage(image)])
    _ = try store.save(draft.id, expected: draft.revision, name: "Readable")
    let broken = try store.folder(UUID().uuidString)
    try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: broken.appendingPathComponent("document.json"))
    let snapshot = try store.librarySnapshot()
    XCTAssertEqual((snapshot["documents"] as? [[String: Any]])?.count, 1)
    XCTAssertEqual((snapshot["unavailable"] as? [[String: String]])?.count, 1)
  }

  func testDocumentModeKeepsTwoImportedPagesAndRejectsInvalidOrder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 40)).image { _ in }
    let uri = try store.stage(image)
    let draft = try store.createDraft(mode: "document", uris: [uri, uri])
    XCTAssertEqual(draft.mode, "document"); XCTAssertEqual(draft.pages.count, 2)
    XCTAssertThrowsError(try store.reorder(draft.id, expected: draft.revision, ids: [draft.pages[0].id, draft.pages[0].id]))
    let changed = try store.reorder(draft.id, expected: draft.revision, ids: Array(draft.pageIds.reversed()))
    XCTAssertEqual(changed.pageIds, Array(draft.pageIds.reversed()))
    XCTAssertGreaterThan(changed.revision, draft.revision)
  }

  func testSignatureDeletionRetainsDocumentOwnedAppearance() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root), signatures = SignatureStore(store)
    let saved = try signatures.save([Stroke(points: [Point(x: 0.1, y: 0.1), Point(x: 0.8, y: 0.8)], color: "#111111", width: 0.003)])
    let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 40)).image { _ in }
    let draft = try store.createDraft(mode: "photo", uris: [store.stage(image)])
    let placement = Placement(assetId: saved.id, imageUri: try store.owned(saved.imageUri).absoluteString, x: 0.2, y: 0.5, width: 0.4, height: 0.2, radians: 0, mirrored: false)
    let edited = try store.edit(draft.id, pageId: draft.pages[0].id, expected: draft.revision, edit: Edit(filter: "color", signatures: [placement]))
    try signatures.delete(saved.id)
    let ownedAppearance = try store.owned(edited.pages[0].edit.signatures[0].imageUri)
    XCTAssertTrue(FileManager.default.fileExists(atPath: ownedAppearance.path))
    XCTAssertTrue(try signatures.list().isEmpty)
  }

  func testForeignInputsAndBlankNamesAreRejected() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root)
    XCTAssertThrowsError(try store.createDraft(mode: "document", uris: ["file:///etc/passwd"]))
    XCTAssertThrowsError(try store.save(UUID().uuidString, expected: 1, name: "  "))
  }

  func testEditsKeepBaseAndInvalidateRecognition() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 40)).image { _ in }
    let draft = try store.createDraft(mode: "photo", uris: [store.stage(image)])
    let base = try store.owned(draft.pages[0].baseUri)
    let bytes = try Data(contentsOf: base)
    let changed = try store.edit(draft.id, pageId: draft.pages[0].id, expected: draft.revision, edit: Edit(filter: "grayscale"))
    XCTAssertEqual(try Data(contentsOf: base), bytes)
    XCTAssertEqual(changed.pages[0].revision, 2)
    XCTAssertEqual(changed.pages[0].ocr.status, "pending")
    XCTAssertNotEqual(changed.pages[0].imageUri, changed.pages[0].baseUri)
  }

  func testFailedPublicationRetainsSavedRevision() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var failWrites = false
    let store = try DocumentStore(root: root, writeManifest: { data, url in
      if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
      try data.write(to: url, options: .atomic)
    })
    let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { _ in }
    let draft = try store.createDraft(mode: "document", uris: [store.stage(image)])
    let saved = try store.save(draft.id, expected: draft.revision, name: "Keep me")
    failWrites = true
    XCTAssertThrowsError(try store.save(saved.id, expected: saved.revision, name: "Do not publish"))
    XCTAssertEqual(try store.load(saved.id).name, "Keep me")
    XCTAssertEqual(try store.load(saved.id).revision, saved.revision)
  }

  func testCancelledDraftIsAbsentFromLibrary() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
      UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
    }
    let uri = try store.stage(image)
    let draft = try store.createDraft(mode: "document", uris: [uri])
    XCTAssertTrue(try store.list(saved: true).isEmpty)
    try store.discardDraft(draft.id)
    XCTAssertTrue(try store.list(saved: false).isEmpty)
  }

  func testStaleSaveCannotReplaceSavedRevision() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try DocumentStore(root: root)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { _ in }
    let draft = try store.createDraft(mode: "document", uris: [store.stage(image)])
    let saved = try store.save(draft.id, expected: draft.revision, name: "First")
    XCTAssertThrowsError(try store.save(saved.id, expected: draft.revision, name: "Stale"))
    XCTAssertEqual(try store.load(saved.id).name, "First")
  }
}
