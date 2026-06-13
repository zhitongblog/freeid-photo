import Foundation

/// Minimal sRGB → CIELAB conversion + ΔE color difference, used to check whether a
/// detected background color is close enough to a spec's required color.
///
/// Uses ΔE*ab (CIE76): Euclidean distance in Lab space. It is simpler than CIEDE2000
/// and accurate enough for "is this background near white / light grey / light blue",
/// which is all the spec needs. Swap in CIEDE2000 later if a spec demands tighter
/// chroma discrimination — the call site (`SpecValidator`) only depends on `deltaE`.
public enum ColorMath {

    public struct RGB: Equatable { public let r, g, b: Double } // each 0..1
    public struct Lab: Equatable { public let L, a, b: Double }

    /// Parse "#RRGGBB" (or "RRGGBB"). Returns nil on malformed input.
    public static func rgb(fromHex hex: String) -> RGB? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return RGB(
            r: Double((v >> 16) & 0xFF) / 255.0,
            g: Double((v >> 8) & 0xFF) / 255.0,
            b: Double(v & 0xFF) / 255.0
        )
    }

    /// sRGB (gamma-encoded, 0..1) → CIELAB, D65 white point.
    public static func lab(from c: RGB) -> Lab {
        func linear(_ u: Double) -> Double {
            u <= 0.04045 ? u / 12.92 : pow((u + 0.055) / 1.055, 2.4)
        }
        let r = linear(c.r), g = linear(c.g), b = linear(c.b)
        // linear sRGB → XYZ (D65)
        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
        // normalize by D65 reference white
        let xn = x / 0.95047, yn = y / 1.0, zn = z / 1.08883
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t) + (16.0 / 116.0)
        }
        let fx = f(xn), fy = f(yn), fz = f(zn)
        return Lab(L: (116 * fy) - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    /// ΔE*ab (CIE76) between two hex colors. Returns .infinity if either is malformed.
    public static func deltaE(_ hexA: String, _ hexB: String) -> Double {
        guard let a = rgb(fromHex: hexA), let b = rgb(fromHex: hexB) else { return .infinity }
        let la = lab(from: a), lb = lab(from: b)
        let dL = la.L - lb.L, da = la.a - lb.a, db = la.b - lb.b
        return (dL * dL + da * da + db * db).squareRoot()
    }
}
