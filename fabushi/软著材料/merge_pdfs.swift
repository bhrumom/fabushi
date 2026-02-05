import Foundation
import PDFKit

let arguments = CommandLine.arguments
guard arguments.count > 3 else {
    print("Usage: swift merge_pdfs.swift <output.pdf> <input1.pdf> <input2.pdf> ...")
    exit(1)
}

let outputPath = arguments[1]
let inputPaths = Array(arguments[2...])

let outputDocument = PDFDocument()
var pageIndex = 0

for path in inputPaths {
    let url = URL(fileURLWithPath: path)
    guard let document = PDFDocument(url: url) else {
        print("Failed to load document at \(path)")
        continue
    }
    
    for i in 0..<document.pageCount {
        if let page = document.page(at: i) {
            outputDocument.insert(page, at: pageIndex)
            pageIndex += 1
        }
    }
}

if outputDocument.write(to: URL(fileURLWithPath: outputPath)) {
    print("Successfully merged \(inputPaths.count) files into \(outputPath)")
    print("Total pages: \(outputDocument.pageCount)")
} else {
    print("Failed to write merged document to \(outputPath)")
    exit(1)
}
