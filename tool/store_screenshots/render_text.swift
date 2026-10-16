// Mağaza görsellerindeki başlığı macOS'un metin motoruyla çizer. Arapça gibi
// harfleri birleşen ve sağdan sola yazılan dillerde Pillow'un yalın çizimi
// yetmez; CoreText bunu doğru yapar.
//
//   swift render_text.swift <çıktı.png> <genişlik> <punto> <rtl:0|1> <satır1> [satır2 ...]
//
// Çıktı saydam bir PNG'dir; compose.py onu görselin üstüne yapıştırır.
import AppKit

let args = CommandLine.arguments
guard args.count >= 6 else {
    FileHandle.standardError.write("kullanım: çıktı genişlik punto rtl satırlar...\n".data(using: .utf8)!)
    exit(1)
}
let out = args[1]
let width = CGFloat(Double(args[2]) ?? 900)
let size = CGFloat(Double(args[3]) ?? 80)
let rtl = args[4] == "1"
let text = args[5...].joined(separator: "\n")

let font = NSFont(name: rtl ? "SFArabic-Bold" : "Roboto-Bold", size: size)
    ?? NSFont.systemFont(ofSize: size, weight: .bold)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = rtl ? .right : .left
paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
paragraph.lineHeightMultiple = 1.05
let attributed = NSAttributedString(string: text, attributes: [
    .font: font,
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
])
let bounds = attributed.boundingRect(
    with: NSSize(width: width, height: 2000),
    options: [.usesLineFragmentOrigin, .usesFontLeading])
let height = ceil(bounds.height)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
attributed.draw(with: NSRect(x: 0, y: 0, width: width, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading])
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
// Pillow, satırların gerçekte kapladığı genişliği bilsin diye yazdırılır.
print(Int(ceil(bounds.width)), Int(height))
