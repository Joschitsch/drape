//
//  CategoryGlyph.swift
//  drape
//
//  Hand-drawn category outlines for the "museum canvas" placeholder, ported
//  from the design prototype's SVG glyphs (drape-ui.jsx `GLYPHS`). Each glyph
//  is authored in a 48×48 coordinate space and scaled to fit its frame.
//

import SwiftUI

/// A stroked outline of a garment category, drawn in a 48×48 viewBox and scaled
/// to fit. Render with `.stroke` (it is an open/!filled silhouette).
struct CategoryGlyph: Shape {
    let category: GarmentCategory

    func path(in rect: CGRect) -> Path {
        // Uniform scale to fit the 48×48 authoring space, centered.
        let s = min(rect.width, rect.height) / 48
        let t = CGAffineTransform(translationX: rect.midX - 24 * s, y: rect.midY - 24 * s)
            .scaledBy(x: s, y: s)

        switch category {
        case .accessory:
            // circle + stem + base bar
            var p = Path()
            p.addEllipse(in: CGRect(x: 24 - 9, y: 20 - 9, width: 18, height: 18))
            p.move(to: CGPoint(x: 24, y: 29)); p.addLine(to: CGPoint(x: 24, y: 37))
            p.move(to: CGPoint(x: 19, y: 37)); p.addLine(to: CGPoint(x: 29, y: 37))
            return p.applying(t)
        default:
            return SVGPath.parse(Self.data(for: category)).applying(t)
        }
    }

    /// SVG `d` strings lifted verbatim from the design.
    private static func data(for category: GarmentCategory) -> String {
        switch category {
        case .top:       "M17 9l-9 6 3 6 4-2.5V39h18V18.5l4 2.5 3-6-9-6-4 3.5h-6L17 9z"
        case .bottom:    "M15 8h18l1 32h-8l-2-20-2 20h-8L15 8z"
        case .dress:     "M18 8l-3 3 4 4-6 22h26l-6-22 4-4-3-3-4 3h-6l-4-3z"
        case .footwear:  "M9 18c3 0 4 2 6 5l9 1c4 0 9 2 13 4 3 1.5 2 6-2 6H10c-1.5 0-2-1-2-2.5L9 18z"
        case .outerwear: "M16 8l-8 7 3 7 3-2v19h20V20l3 2 3-7-8-7-4 4-3-4h-2l-3 4-4-4zM24 12v28"
        case .accessory: ""
        }
    }
}

/// Minimal SVG path parser supporting the command subset used by the glyphs:
/// M/m L/l H/h V/v C/c Z/z.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var nums = ""
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: Character = " "
        var args: [CGFloat] = []

        func flushNumber() {
            if !nums.isEmpty, let v = Double(nums) { args.append(CGFloat(v)) }
            nums = ""
        }
        func run() {
            flushNumber()
            switch command {
            case "M", "L", "C": // absolute, consume in pairs/sextuples
                consume(absolute: true)
            case "m", "l", "c":
                consume(absolute: false)
            case "H": for x in args { current.x = x; path.addLine(to: current) }
            case "h": for dx in args { current.x += dx; path.addLine(to: current) }
            case "V": for y in args { current.y = y; path.addLine(to: current) }
            case "v": for dy in args { current.y += dy; path.addLine(to: current) }
            case "Z", "z": path.closeSubpath(); current = start
            default: break
            }
            args = []
        }
        func consume(absolute: Bool) {
            let stride = command.lowercased() == "c" ? 6 : 2
            var i = 0
            while i + stride <= args.count {
                if command.lowercased() == "c" {
                    let c1 = pt(args[i], args[i+1], absolute)
                    let c2 = pt(args[i+2], args[i+3], absolute)
                    let to = pt(args[i+4], args[i+5], absolute)
                    path.addCurve(to: to, control1: c1, control2: c2)
                    current = to
                } else {
                    let to = pt(args[i], args[i+1], absolute)
                    if command == "M" || command == "m" {
                        path.move(to: to); start = to
                        // subsequent pairs after a moveto are implicit linetos
                        command = (command == "M") ? "L" : "l"
                    } else {
                        path.addLine(to: to)
                    }
                    current = to
                }
                i += stride
            }
        }
        func pt(_ a: CGFloat, _ b: CGFloat, _ absolute: Bool) -> CGPoint {
            absolute ? CGPoint(x: a, y: b) : CGPoint(x: current.x + a, y: current.y + b)
        }

        for ch in d {
            if ch.isLetter {
                run()
                command = ch
            } else if ch == "-" {
                // start of a new (negative) number
                if !nums.isEmpty { flushNumber() }
                nums = "-"
            } else if ch == "." {
                // a second dot starts a new number (e.g. "3.5.2")
                if nums.contains(".") { flushNumber() }
                nums.append(ch)
            } else if ch == " " || ch == "," {
                flushNumber()
            } else {
                nums.append(ch)
            }
        }
        run()
        return path
    }
}
