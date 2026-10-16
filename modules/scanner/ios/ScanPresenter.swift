import UIKit
import VisionKit
import AVFoundation

final class ScanPresenter: NSObject, VNDocumentCameraViewControllerDelegate {
  private var completion: ((Result<[String]?, Error>) -> Void)?
  private let store: DocumentStore
  init(store: DocumentStore) { self.store = store }

  func present(from parent: UIViewController, completion: @escaping (Result<[String]?, Error>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard self.completion == nil else { completion(.failure(ScannerFailure(code: "processing", message: "A scanner is already open"))); return }
    guard VNDocumentCameraViewController.isSupported else { completion(.failure(ScannerFailure(code: "unsupported", message: "Document scanning is unavailable"))); return }
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    if status == .denied || status == .restricted { completion(.failure(ScannerFailure(code: "permission", message: "Enable Camera access in Settings"))); return }
    self.completion = completion
    let controller = VNDocumentCameraViewController(); controller.delegate = self
    parent.present(controller, animated: true)
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true); finish(.success(nil))
  }
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true); finish(.failure(error))
  }
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    controller.dismiss(animated: true)
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      do {
        var uris: [String] = []
        for index in 0..<scan.pageCount { uris.append(try autoreleasepool { try store.stage(scan.imageOfPage(at: index), corrected: true) }) }
        DispatchQueue.main.async { self.finish(.success(uris)) }
      } catch { DispatchQueue.main.async { self.finish(.failure(error)) } }
    }
  }
  private func finish(_ result: Result<[String]?, Error>) {
    let callback = completion; completion = nil; callback?(result)
  }
}
