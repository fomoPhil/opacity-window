import AppKit
import CoreGraphics
import Foundation

// OpacityWindow app icon, drawn programmatically so every size is rendered from
// source rather than downsampled. That matters because the checkerboard is the
// one element that cannot survive naive downsampling: below ~64px it needs FEWER
// and CHUNKIER squares to keep reading as "transparency" instead of grey mush.

// MARK: - Palette

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}

let bgTop     = rgb(0x3D, 0x49, 0x6E)   // slate navy, lighter at top
let bgBottom  = rgb(0x15, 0x1B, 0x2D)
let amberHi   = rgb(0xFF, 0xD8, 0x6B)
let amberLo   = rgb(0xEF, 0xA5, 0x14)
let checkLite = rgb(0xFF, 0xFF, 0xFF)
let checkDark = rgb(0xC4, 0xCA, 0xD6)

// MARK: - Squircle

/// Apple's icon silhouette is a superellipse, not a rounded rectangle. Circular
/// corners read subtly "off" next to real Mac icons, so build the real curve.
func squirclePath(in rect: CGRect, n: CGFloat = 5.0, steps: Int = 720) -> CGPath {
    let p = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * CGFloat(sign(ct)) * pow(abs(ct), 2/n)
        let y = cy + b * CGFloat(sign(st)) * pow(abs(st), 2/n)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

func sign(_ v: CGFloat) -> CGFloat { v < 0 ? -1 : 1 }

func roundedPath(_ rect: CGRect, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func linearGradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: colors as CFArray, locations: locations)!
}

// MARK: - Draw

func drawIcon(in ctx: CGContext, size S: CGFloat) {
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Apple's macOS icon grid: the body occupies 824 of a 1024 canvas, leaving
    // transparent margin for the system's own shadow.
    let inset = S * (100.0/1024.0)
    let body  = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)

    // ---- background ----
    ctx.saveGState()
    ctx.addPath(squirclePath(in: body))
    ctx.clip()
    ctx.drawLinearGradient(linearGradient([bgTop, bgBottom], [0, 1]),
                           start: CGPoint(x: body.midX, y: body.maxY),
                           end:   CGPoint(x: body.midX, y: body.minY),
                           options: [])
    ctx.restoreGState()

    // ---- detail level ----
    // Apple simplifies icon artwork as it shrinks rather than shrinking the same
    // drawing. Below ~28px the checkerboard cannot resolve at all, and a white
    // rim eats such a large fraction of the tile that the icon washes out and
    // loses the amber that carries its identity. So small sizes drop detail
    // deliberately and keep the one thing that reads: the warm/cool split.
    enum Detail { case tiny, small, medium, full }
    let detail: Detail = S < 28 ? .tiny : (S < 48 ? .small : (S < 128 ? .medium : .full))

    // ---- the tile ----
    // Proportions carried over from the approved mockup: 71% of body width,
    // 62% of its height, sitting very slightly above centre. Tiny sizes pull the
    // tile in a little so the navy still frames it.
    let widthFactor: CGFloat = detail == .tiny ? 0.66 : 0.71
    let tw = body.width * widthFactor
    let th = body.height * 0.62
    let tile = CGRect(x: body.midX - tw/2,
                      y: body.midY - th/2 + body.height * 0.012,
                      width: tw, height: th)
    let tr = tw * 0.105
    let tilePath = roundedPath(tile, tr)

    // soft shadow, skipped at tiny sizes where it only muddies the edge
    if S >= 64 {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -S*0.012),
                      blur: S*0.030,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.42))
        ctx.addPath(tilePath); ctx.setFillColor(checkLite); ctx.fillPath()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    // checkerboard base. Square count drops as the icon shrinks so the pattern
    // stays legible instead of dissolving into flat grey. At `tiny` it is
    // dropped entirely for a single flat tone: three pixels of checker is noise,
    // not a pattern.
    let cols: Int
    switch detail {
    case .tiny:   cols = 0
    case .small:  cols = 3
    case .medium: cols = 4
    case .full:   cols = 6
    }

    if cols == 0 {
        ctx.setFillColor(rgb(0xD6, 0xDB, 0xE4))
        ctx.fill(tile)
    } else {
        let cell = tile.width / CGFloat(cols)
        ctx.setFillColor(checkLite)
        ctx.fill(tile)
        ctx.setFillColor(checkDark)
        // Centre the grid vertically. Letting it run from the top leaves a lone
        // sliver row at the bottom, which reads as a mistake rather than a pattern.
        let rows = Int(ceil(tile.height / cell)) + 1
        let gridTop = tile.midY + CGFloat(rows) * cell / 2
        for r in 0..<rows {
            for c in 0..<cols where (r + c) % 2 == 1 {
                ctx.fill(CGRect(x: tile.minX + CGFloat(c)*cell,
                                y: gridTop - CGFloat(r+1)*cell,
                                width: cell, height: cell))
            }
        }
    }

    // amber panel dissolving left-to-right, revealing the checkerboard beneath
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.drawLinearGradient(linearGradient([amberHi, amberLo], [0, 1]),
                           start: CGPoint(x: tile.minX, y: tile.maxY),
                           end:   CGPoint(x: tile.maxX * 0.45, y: tile.minY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.setBlendMode(.destinationIn)
    let opaque = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    let clear  = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    // Hold the amber solid across the left third, then dissolve so the
    // checkerboard genuinely owns the right half. Fading too late reads as an
    // amber tile with a stripe, which loses the whole "opacity" idea. Small
    // sizes get a shorter, harder transition, because a long soft gradient
    // spread over five pixels just reads as a smear.
    let stops: [CGFloat]
    switch detail {
    case .tiny:   stops = [0, 0.52, 0.60]
    case .small:  stops = [0, 0.34, 0.66]
    default:      stops = [0, 0.26, 0.70]
    }
    ctx.drawLinearGradient(linearGradient([opaque, opaque, clear], stops),
                           start: CGPoint(x: tile.minX, y: tile.midY),
                           end:   CGPoint(x: tile.maxX, y: tile.midY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.endTransparencyLayer()
    ctx.setBlendMode(.normal)
    ctx.restoreGState()

    // ---- rim ----
    // Omitted entirely at tiny sizes. A 1px white rim around an 11px tile is
    // nearly a fifth of its width, which is what was bleaching the 16px render.
    // The navy body already provides the separation the rim exists to give.
    if detail != .tiny {
        let lw = detail == .small ? 1.0 : max(S * 0.011, 1.5)
        ctx.saveGState()
        ctx.addPath(roundedPath(tile.insetBy(dx: lw/2, dy: lw/2), tr))
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: detail == .small ? 0.75 : 0.95))
        ctx.setLineWidth(lw)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

// MARK: - Export

func render(_ px: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawIcon(in: ctx, size: CGFloat(px))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    rep.size = NSSize(width: px, height: px)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// macOS asset catalogue: 10 entries, 7 distinct pixel sizes.
let entries: [(String, Int, String, String)] = [
    ("icon_16x16.png",       16,  "16x16",   "1x"),
    ("icon_16x16@2x.png",    32,  "16x16",   "2x"),
    ("icon_32x32.png",       32,  "32x32",   "1x"),
    ("icon_32x32@2x.png",    64,  "32x32",   "2x"),
    ("icon_128x128.png",    128,  "128x128", "1x"),
    ("icon_128x128@2x.png", 256,  "128x128", "2x"),
    ("icon_256x256.png",    256,  "256x256", "1x"),
    ("icon_256x256@2x.png", 512,  "256x256", "2x"),
    ("icon_512x512.png",    512,  "512x512", "1x"),
    ("icon_512x512@2x.png", 1024, "512x512", "2x"),
]

for (name, px, _, _) in entries {
    render(px, to: out.appendingPathComponent(name))
    print("  \(name)  \(px)x\(px)")
}

let images = entries.map { name, _, size, scale in
    "    {\n      \"filename\" : \"\(name)\",\n      \"idiom\" : \"mac\",\n      \"scale\" : \"\(scale)\",\n      \"size\" : \"\(size)\"\n    }"
}.joined(separator: ",\n")
let json = "{\n  \"images\" : [\n\(images)\n  ],\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n"
try! json.write(to: out.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("  Contents.json")
