import ExpoModulesCore
import UIKit
import QuickLook

public final class ScannerModule: Module {
  private var storage: DocumentStore?
  private var presenter: ScanPresenter?
  private let initializationLock = NSLock()
  private var preview: PDFPreview?
  private func store() throws -> DocumentStore {
    initializationLock.lock(); defer { initializationLock.unlock() }
    if let storage = storage { return storage }
    let result = try DocumentStore(); storage = result; return result
  }

  public func definition() -> ModuleDefinition {
    Name("PocketScanner")
    AsyncFunction("librarySnapshot") { () -> [String: Any] in try self.store().librarySnapshot() }
    AsyncFunction("listDocuments") { () -> [[String: Any]] in let s = try self.store(); return try s.list(saved: true).map(s.outward) }
    AsyncFunction("listDrafts") { () -> [[String: Any]] in let s = try self.store(); return try s.list(saved: false).map(s.outward) }
    AsyncFunction("libraryPreferences") { () -> [String: Any] in try self.store().preferences() }
    AsyncFunction("setLibraryPreferences") { (value: [String: Any]) in _ = try self.store().preferences(value) }
    AsyncFunction("composeIDDocument") { (id: String, expected: Int) -> [String: Any] in let s = try self.store(); return try s.outward(s.composeID(id, expected: expected)) }
    AsyncFunction("restoreIDSides") { (id: String, expected: Int) -> [String: Any] in let s = try self.store(); return try s.outward(s.restoreIDSides(id, expected: expected)) }
    AsyncFunction("loadDocument") { (id: String) -> [String: Any] in let s = try self.store(); return try s.outward(s.load(id)) }
    AsyncFunction("createDraft") { (mode: String, uris: [String]) -> [String: Any] in let s = try self.store(); return try s.outward(s.createDraft(mode: mode, uris: uris)) }
    AsyncFunction("saveDocument") { (id: String, expected: Int, name: String) -> [String: Any] in let s = try self.store(); return try s.outward(s.save(id, expected: expected, name: name)) }
    AsyncFunction("renameDocument") { (id: String, expected: Int, name: String) -> [String: Any] in let s = try self.store(); return try s.outward(s.save(id, expected: expected, name: name)) }
    AsyncFunction("discardDraft") { (id: String) in try self.store().discardDraft(id) }
    AsyncFunction("deleteDocuments") { (ids: [String]) in try self.store().delete(ids) }
    AsyncFunction("cancelProcessing") { (id: String) in try self.store().cancel(id) }
    AsyncFunction("recognitionLanguages") { () -> [String] in try TextRecognizer.languages() }
    AsyncFunction("recognizePage") { (id: String, pageId: String, expected: Int) -> [String: Any] in let s = try self.store(); return try s.outward(TextRecognizer.recognize(store: s, id: id, pageId: pageId, expected: expected)) }
    AsyncFunction("exportPDF") { (id: String, expected: Int, allowImageOnly: Bool) -> [String: Any] in try PDFExporter.export(store: self.store(), id: id, expected: expected, allowImageOnly: allowImageOnly) }
    AsyncFunction("previewPDF") { (uri: String) in
      let url = try self.store().input(uri)
      guard url.pathExtension == "pdf", let parent = self.appContext?.utilities?.currentViewController() else { throw ScannerFailure(code: "unsupported", message: "PDF preview is unavailable") }
      let preview = PDFPreview(url: url); self.preview = preview
      let controller = QLPreviewController(); controller.dataSource = preview
      parent.present(controller, animated: true)
    }.runOnQueue(.main)
    AsyncFunction("shareImages") { (uris: [String]) in
      let s = try self.store()
      guard !uris.isEmpty, let parent = self.appContext?.utilities?.currentViewController() else { throw ScannerFailure(code: "unsupported", message: "No images or active screen for sharing") }
      let urls = try uris.map { try s.input($0) }
      let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
      controller.popoverPresentationController?.sourceView = parent.view
      parent.present(controller, animated: true)
    }.runOnQueue(.main)
    AsyncFunction("editPage") { (id: String, pageId: String, expected: Int, edit: [String: Any]) -> [String: Any] in let s = try self.store(); return try s.outward(s.edit(id, pageId: pageId, expected: expected, edit: decode(edit, as: Edit.self))) }
    AsyncFunction("reorderPages") { (id: String, expected: Int, ids: [String]) -> [String: Any] in let s = try self.store(); return try s.outward(s.reorder(id, expected: expected, ids: ids)) }
    AsyncFunction("removePage") { (id: String, expected: Int, pageId: String) -> [String: Any] in let s = try self.store(); return try s.outward(s.removePage(id, expected: expected, pageId: pageId)) }
    AsyncFunction("appendPages") { (id: String, expected: Int, uris: [String], replace: String?) -> [String: Any] in let s = try self.store(); return try s.outward(s.append(id, expected: expected, uris: uris, replace: replace)) }
    AsyncFunction("composeID") { (front: String, back: String) -> String in let s = try self.store(); return try s.stage(ImageProcessor.compose(front: s.input(front), back: s.input(back))) }
    AsyncFunction("saveSignature") { (strokes: [[String: Any]]) -> [String: Any] in let signatures = try SignatureStore(self.store()); return try signatures.outward(signatures.save(decode(strokes, as: [Stroke].self))) }
    AsyncFunction("listSignatures") { () -> [[String: Any]] in let signatures = try SignatureStore(self.store()); return try signatures.list().map(signatures.outward) }
    AsyncFunction("renameSignature") { (id: String, name: String) in try SignatureStore(self.store()).rename(id, name: name) }
    AsyncFunction("deleteSignature") { (id: String) in try SignatureStore(self.store()).delete(id) }
    AsyncFunction("scanDocument") { (promise: Promise) in
      do {
        let s = try self.store()
        guard let parent = self.appContext?.utilities?.currentViewController() else { throw ScannerFailure(code: "unsupported", message: "No active iPhone screen") }
        if self.presenter == nil { self.presenter = ScanPresenter(store: s) }
        self.presenter?.present(from: parent) { result in
          switch result {
          case .success(let uris):
            if let uris = uris { promise.resolve(["status": "captured", "imageUris": uris] as [String: Any]) }
            else { promise.resolve(["status": "cancelled"]) }
          case .failure(let error): promise.reject("processing", error.localizedDescription)
          }
        }
      } catch { promise.reject("processing", error.localizedDescription) }
    }.runOnQueue(.main)
  }
}
