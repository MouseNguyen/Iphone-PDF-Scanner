import QuickLook

final class PDFPreview: NSObject, QLPreviewControllerDataSource {
  let url: URL
  init(url: URL) { self.url = url }
  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
}
