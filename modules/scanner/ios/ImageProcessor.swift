import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImageProcessor {
  static let context = CIContext(options: [.cacheIntermediates: false])

  static func oriented(_ image: UIImage) -> UIImage {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
  }

  static func validate(_ edit: Edit) throws {
    guard ["auto", "color", "grayscale", "bw"].contains(edit.filter), (0...3).contains(edit.quarterTurns) else { throw ScannerFailure(code: "invalid_input", message: "Unsupported adjustment") }
    if let points = edit.corners {
      guard points.count == 4, points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else { throw ScannerFailure(code: "invalid_input", message: "Invalid crop corners") }
      for index in 0..<4 {
        let a = points[index], b = points[(index + 1) % 4], c = points[(index + 2) % 4]
        guard (b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x) > 0.0001 else { throw ScannerFailure(code: "invalid_input", message: "Crop corners must form a non-crossing rectangle") }
      }
    }
    for p in edit.signatures {
      guard [p.x,p.y,p.width,p.height,p.radians].allSatisfy(\.isFinite), p.width > 0, p.height > 0, p.width <= 1, p.height <= 1, p.x >= 0, p.y >= 0, p.x + p.width <= 1.001, p.y + p.height <= 1.001 else { throw ScannerFailure(code: "invalid_input", message: "Signature must fit within the page") }
    }
  }

  static func render(base: URL, edit: Edit, alreadyCorrected: Bool = false, resolve: (String) throws -> URL) throws -> UIImage {
    try validate(edit)
    guard let source = UIImage(contentsOfFile: base.path), var image = CIImage(image: source) else { throw ScannerFailure(code: "processing", message: "Image cannot be opened") }
    if let points = edit.corners {
      let filter = CIFilter.perspectiveCorrection(); filter.inputImage = image
      func corner(_ index: Int) -> CGPoint { CGPoint(x: points[index].x * image.extent.width, y: (1-points[index].y) * image.extent.height) }
      filter.topLeft = corner(0); filter.topRight = corner(1); filter.bottomRight = corner(2); filter.bottomLeft = corner(3)
      guard let result = filter.outputImage else { throw ScannerFailure(code: "processing", message: "Crop failed") }; image = result
    }
    for _ in 0..<edit.quarterTurns { image = image.oriented(.right) }
    if edit.filter == "auto" && !alreadyCorrected {
      for filter in image.autoAdjustmentFilters(options: [.enhance: true]) {
        filter.setValue(image, forKey: kCIInputImageKey)
        if let output = filter.outputImage { image = output }
      }
    }
    if edit.filter == "grayscale" || edit.filter == "bw" {
      let filter = CIFilter.colorControls(); filter.inputImage = image; filter.saturation = 0
      filter.contrast = edit.filter == "bw" ? 2.2 : 1
      guard let output = filter.outputImage else { throw ScannerFailure(code: "processing", message: "Filter failed") }; image = output
      if edit.filter == "bw" {
        let threshold = CIFilter.colorThreshold(); threshold.inputImage = image; threshold.threshold = 0.55
        guard let output = threshold.outputImage else { throw ScannerFailure(code: "processing", message: "Black and white conversion failed") }; image = output
      }
    }
    guard let cg = context.createCGImage(image, from: image.extent) else { throw ScannerFailure(code: "processing", message: "Image rendering failed") }
    let result = UIImage(cgImage: cg)
    guard !edit.signatures.isEmpty else { return result }
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    let signatures = try edit.signatures.map { placement -> UIImage in
      guard let image = UIImage(contentsOfFile: try resolve(placement.imageUri).path) else { throw ScannerFailure(code: "storage", message: "A signature image is unavailable") }
      return image
    }
    return UIGraphicsImageRenderer(size: result.size, format: format).image { renderer in
      result.draw(at: .zero)
      for (placement, signature) in zip(edit.signatures, signatures) {
        let rect = CGRect(x: placement.x * result.size.width, y: placement.y * result.size.height, width: placement.width * result.size.width, height: placement.height * result.size.height)
        let cg = renderer.cgContext
        cg.saveGState(); cg.translateBy(x: rect.midX, y: rect.midY); cg.rotate(by: placement.radians)
        if placement.mirrored { cg.scaleBy(x: -1, y: 1) }
        signature.draw(in: AVFit(signature.size, in: CGRect(x: -rect.width/2, y: -rect.height/2, width: rect.width, height: rect.height))); cg.restoreGState()
      }
    }
  }

  static func compose(front: URL, back: URL) throws -> UIImage {
    guard let a = UIImage(contentsOfFile: front.path), let b = UIImage(contentsOfFile: back.path) else { throw ScannerFailure(code: "invalid_input", message: "Both ID sides are required") }
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 1240, height: 1754), format: format).image { renderer in
      UIColor.white.setFill(); renderer.fill(CGRect(x: 0, y: 0, width: 1240, height: 1754))
      for (image, y) in [(a, CGFloat(100)), (b, CGFloat(927))] {
        let rect = AVFit(image.size, in: CGRect(x: 100, y: y, width: 1040, height: 727)); image.draw(in: rect)
      }
    }
  }
}

func AVFit(_ size: CGSize, in bounds: CGRect) -> CGRect {
  let scale = min(bounds.width / size.width, bounds.height / size.height)
  let width = size.width * scale, height = size.height * scale
  return CGRect(x: bounds.midX-width/2, y: bounds.midY-height/2, width: width, height: height)
}
