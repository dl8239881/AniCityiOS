import UIKit

enum Palette {
    static let night = UIColor(red: 0.04, green: 0.02, blue: 0.09, alpha: 1)
    static let pink = UIColor(red: 1.0, green: 0.22, blue: 0.62, alpha: 1)
    static let blue = UIColor(red: 0.25, green: 0.62, blue: 1.0, alpha: 1)
    static let blonde = UIColor(red: 0.96, green: 0.82, blue: 0.45, alpha: 1)
    static let skin = UIColor(red: 1.0, green: 0.84, blue: 0.74, alpha: 1)
    static let dress = UIColor(red: 0.07, green: 0.05, blue: 0.08, alpha: 1)
    static let eye = UIColor(red: 0.18, green: 0.55, blue: 1.0, alpha: 1)
    static let lipstick = UIColor(red: 0.35, green: 0.08, blue: 0.18, alpha: 1)
    static let asphalt = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
    static let sidewalk = UIColor(red: 0.28, green: 0.27, blue: 0.30, alpha: 1)
    static let concrete = UIColor(red: 0.34, green: 0.33, blue: 0.36, alpha: 1)
    static let lace = UIColor(red: 0.55, green: 0.42, blue: 0.52, alpha: 1)

    static func rgb(_ r: Float, _ g: Float, _ b: Float) -> UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
    }

    static func sky(at time: Float) -> UIColor {
        let stops: [(Float, Float, Float, Float)] = [
            (0.00, 0.03, 0.015, 0.07),
            (0.20, 0.08, 0.04, 0.14),
            (0.30, 0.85, 0.38, 0.32),
            (0.42, 0.45, 0.70, 0.95),
            (0.62, 0.42, 0.66, 0.92),
            (0.74, 0.90, 0.32, 0.42),
            (0.84, 0.10, 0.04, 0.16),
            (1.00, 0.03, 0.015, 0.07)
        ]
        let t = time - floor(time)
        var index = 0
        while index < stops.count - 2 && t > stops[index + 1].0 {
            index += 1
        }
        let a = stops[index]
        let b = stops[index + 1]
        let span = max(0.0001, b.0 - a.0)
        let u = clamp((t - a.0) / span, 0, 1)
        return rgb(lerp(a.1, b.1, u), lerp(a.2, b.2, u), lerp(a.3, b.3, u))
    }

    /// 0 at noon-ish day, 1 in the middle of the night.
    static func nightAmount(at time: Float) -> Float {
        let t = time - floor(time)
        let day = sin((t - 0.25) * 2 * Float.pi)
        return clamp(1 - max(0, day) * 1.4, 0, 1)
    }
}
