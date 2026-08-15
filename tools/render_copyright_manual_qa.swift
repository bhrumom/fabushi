import Foundation
import PDFKit
import AppKit

let pdfPath = "/Users/gloriachan/Documents/fabushi/output/copyright_registration/发布软件V1.0_操作说明书.pdf"
let outDir = URL(fileURLWithPath: "/tmp/copyright_manual_qa", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let doc = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else {
  fatalError("Cannot open PDF")
}
print("pages=\(doc.pageCount)")
let indexes = [0, 2, 4, 7, 10, 11].filter { $0 < doc.pageCount }
for index in indexes {
  guard let page = doc.page(at: index) else { continue }
  let box = page.bounds(for: .mediaBox)
  let width: CGFloat = 620
  let height = width * box.height / box.width
  let image = page.thumbnail(of: NSSize(width: width, height: height), for: .mediaBox)
  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let jpg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
    fatalError("Cannot render page \(index + 1)")
  }
  let url = outDir.appendingPathComponent(String(format: "page-%02d.jpg", index + 1))
  try jpg.write(to: url)
  print("\(index + 1) \(url.path) \(jpg.count)")
}
