import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: add_ai_badge <images-directory>\n", stderr)
    exit(2)
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let manager = FileManager.default
let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

for (index, file) in files.enumerated() {
    guard let image = NSImage(contentsOf: file),
          let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("跳过：\(file.lastPathComponent)")
        continue
    }

    let width = source.width
    let height = source.height
    guard let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    let shortSide = CGFloat(min(width, height))
    let fontSize = max(13, shortSide * 0.025)
    let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let label = NSAttributedString(string: "AI生成", attributes: attributes)
    let textSize = label.size()
    let horizontalPadding = fontSize * 0.62
    let verticalPadding = fontSize * 0.34
    let badgeWidth = textSize.width + horizontalPadding * 2
    let badgeHeight = textSize.height + verticalPadding * 2
    let margin = max(10, shortSide * 0.018)
    let badgeRect = CGRect(
        x: CGFloat(width) - margin - badgeWidth,
        y: margin,
        width: badgeWidth,
        height: badgeHeight
    )

    context.setFillColor(NSColor.black.withAlphaComponent(0.48).cgColor)
    context.addPath(CGPath(roundedRect: badgeRect, cornerWidth: badgeHeight * 0.35, cornerHeight: badgeHeight * 0.35, transform: nil))
    context.fillPath()

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    label.draw(at: CGPoint(x: badgeRect.minX + horizontalPadding, y: badgeRect.minY + verticalPadding))
    NSGraphicsContext.restoreGraphicsState()

    guard let output = context.makeImage() else { continue }
    let bitmap = NSBitmapImageRep(cgImage: output)
    var data: Data?
    if file.pathExtension.lowercased() == "png" {
        data = bitmap.representation(using: .png, properties: [:])
    } else {
        for quality in stride(from: 0.94, through: 0.48, by: -0.02) {
            guard let candidate = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else { continue }
            data = candidate
            if candidate.count <= 400 * 1024 { break }
        }
    }
    try data?.write(to: file, options: .atomic)
    print("\(index + 1)/\(files.count) \(file.lastPathComponent)")
}

print("AI 标识处理完成：\(files.count) 张")
