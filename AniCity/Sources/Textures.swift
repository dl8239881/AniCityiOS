import UIKit
import SceneKit

enum Art {
    static let windows = makeWindows()
    static let graffiti = makeGraffiti()
    static let lace = makeLace()
    static let blob = makeBlob()
    static let brick = makeBrick()

    static func material(color: UIColor, emission: UIColor? = nil, emissionIntensity: CGFloat = 0, lit: Bool = true, doubleSided: Bool = false) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = lit ? .blinn : .constant
        material.specular.contents = UIColor(white: lit ? 0.25 : 0, alpha: 1)
        material.shininess = lit ? 0.35 : 0
        if let emission {
            material.emission.contents = emission
            material.emission.intensity = emissionIntensity
        }
        material.isDoubleSided = doubleSided
        return material
    }

    static func textured(_ image: UIImage, emission: UIImage? = nil, intensity: CGFloat = 0.2, lit: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.lightingModel = lit ? .blinn : .constant
        material.specular.contents = UIColor(white: 0.08, alpha: 1)
        if let emission {
            material.emission.contents = emission
            material.emission.intensity = intensity
        }
        material.isDoubleSided = false
        return material
    }

    static func sign(_ text: String, width: CGFloat, height: CGFloat, background: UIColor, foreground: UIColor) -> SCNNode {
        let image = label(text, width: 512, height: 160, background: background, foreground: foreground, fontSize: 64)
        let plane = SCNPlane(width: width, height: height)
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.emission.contents = image
        material.emission.intensity = 0.85
        material.lightingModel = .constant
        material.isDoubleSided = false
        plane.materials = [material]
        return SCNNode(geometry: plane)
    }

    static func label(_ text: String, width: Int, height: Int, background: UIColor, foreground: UIColor, fontSize: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { _ in
            background.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let shadow: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: Palette.blue,
                .paragraphStyle: style
            ]
            let fill: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: foreground,
                .paragraphStyle: style
            ]
            let string = NSString(string: text)
            let bounds = CGRect(x: 8, y: (CGFloat(height) - fontSize) * 0.5 - 2, width: CGFloat(width - 16), height: fontSize + 8)
            string.draw(in: bounds.offsetBy(dx: 3, dy: 2), withAttributes: shadow)
            string.draw(in: bounds, withAttributes: fill)
        }
    }

    private static func makeWindows() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 128), format: format)
        return renderer.image { ctx in
            UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 128))
            for row in 0..<8 {
                for col in 0..<3 {
                    let lit = (row * 3 + col) % 4 != 0
                    let neon = (row + col) % 5 == 0
                    let color: UIColor
                    if !lit {
                        color = UIColor(white: 0.02, alpha: 1)
                    } else if neon {
                        color = Palette.pink
                    } else if (row + col) % 2 == 0 {
                        color = UIColor(red: 1, green: 0.82, blue: 0.45, alpha: 1)
                    } else {
                        color = Palette.blue
                    }
                    color.setFill()
                    let rect = CGRect(x: 8 + col * 18, y: 8 + row * 15, width: 12, height: 9)
                    ctx.fill(rect)
                }
            }
        }
    }

    private static func makeGraffiti() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
        return renderer.image { ctx in
            func drawWord(_ text: String, size: CGFloat, color: UIColor, at point: CGPoint) {
                let style = NSMutableParagraphStyle()
                style.alignment = .left
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: size),
                    .foregroundColor: color,
                    .paragraphStyle: style
                ]
                NSString(string: text).draw(at: point, withAttributes: attrs)
            }
            UIColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            UIColor(white: 0.16, alpha: 1).setFill()
            for i in 0..<8 {
                ctx.fill(CGRect(x: 0, y: CGFloat(i) * 32, width: 256, height: 2))
            }
            drawWord("REBEL", size: 54, color: Palette.pink, at: CGPoint(x: 16, y: 28))
            drawWord("ANI", size: 50, color: Palette.blue, at: CGPoint(x: 36, y: 108))
            drawWord("HOOD", size: 42, color: UIColor(red: 0.72, green: 0.22, blue: 1, alpha: 1), at: CGPoint(x: 18, y: 176))
        }
    }

    private static func makeLace() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format)
        return renderer.image { ctx in
            UIColor(red: 0.05, green: 0.04, blue: 0.06, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            ctx.cgContext.setStrokeColor(UIColor(red: 0.55, green: 0.40, blue: 0.52, alpha: 1).cgColor)
            ctx.cgContext.setLineWidth(1.5)
            for y in stride(from: 8, to: 128, by: 16) {
                for x in stride(from: 8, to: 128, by: 16) {
                    let rect = CGRect(x: x, y: y, width: 10, height: 10)
                    ctx.cgContext.strokeEllipse(in: rect)
                }
            }
            Palette.lace.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 6))
            ctx.fill(CGRect(x: 0, y: 122, width: 128, height: 6))
        }
    }

    private static func makeBrick() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format)
        return renderer.image { ctx in
            UIColor(red: 0.22, green: 0.16, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor(red: 0.12, green: 0.08, blue: 0.09, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 30, width: 64, height: 3))
            ctx.fill(CGRect(x: 30, y: 0, width: 3, height: 30))
            ctx.fill(CGRect(x: 8, y: 33, width: 3, height: 31))
        }
    }

    private static func makeBlob() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format)
        return renderer.image { ctx in
            let colors = [UIColor(white: 1, alpha: 0.7).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: 16, y: 16),
                    startRadius: 0,
                    endCenter: CGPoint(x: 16, y: 16),
                    endRadius: 16,
                    options: []
                )
            }
        }
    }
}
