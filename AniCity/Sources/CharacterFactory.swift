import SceneKit
import UIKit

/// Stylised Ani: blonde twin-tails, blue eyes, black off-shoulder lace dress.
/// Built from primitives so the prototype stays light and obvious at camera distance.
final class AniAvatar {
    let root = SCNNode()
    private let yawNode = SCNNode()
    private let bob = SCNNode()
    private let leftLeg = SCNNode()
    private let rightLeg = SCNNode()
    private let leftArm = SCNNode()
    private let rightArm = SCNNode()
    private let leftTail = SCNNode()
    private let rightTail = SCNNode()
    private let skirt = SCNNode()

    init() {
        root.name = "ani"
        root.addChildNode(yawNode)
        yawNode.addChildNode(bob)
        build()
    }

    func setYaw(_ yaw: Float) {
        yawNode.eulerAngles.y = yaw
    }

    func update(time: Float, speed: Float) {
        let moving = speed > 0.35
        let phase = time * (3.2 + min(speed, 8) * 0.55)
        let swing: Float = moving ? sin(phase) * 0.55 : sin(time * 1.4) * 0.04
        leftLeg.eulerAngles.x = swing
        rightLeg.eulerAngles.x = -swing
        leftArm.eulerAngles.x = -swing * 0.55
        rightArm.eulerAngles.x = swing * 0.55
        bob.position.y = moving ? abs(sin(phase)) * 0.045 : 0
        let sway = sin(time * 2.1) * 0.07
        leftTail.eulerAngles.z = 0.15 + sway
        rightTail.eulerAngles.z = -0.15 - sway
        leftTail.eulerAngles.x = 0.18 + sin(time * 1.6) * 0.05
        rightTail.eulerAngles.x = 0.18 + cos(time * 1.6) * 0.05
        skirt.eulerAngles.z = sin(time * 2.4) * (moving ? 0.03 : 0.012)
    }

    private func build() {
        let skin = Art.material(color: Palette.skin, emission: Palette.skin, emissionIntensity: 0.12)
        let hair = Art.material(color: Palette.blonde, emission: Palette.blonde, emissionIntensity: 0.28)
        let dress = Art.textured(Art.lace, emission: Art.lace, intensity: 0.18)
        let black = Art.material(color: UIColor(white: 0.04, alpha: 1), emission: UIColor(white: 0.02, alpha: 1), emissionIntensity: 0.05)
        let laceTrim = Art.material(color: Palette.lace, emission: Palette.lace, emissionIntensity: 0.35, lit: false)
        let white = Art.material(color: .white, lit: false)
        let iris = Art.material(color: Palette.eye, emission: Palette.eye, emissionIntensity: 1, lit: false)
        let pupil = Art.material(color: .black, lit: false)
        let lip = Art.material(color: Palette.lipstick, emission: Palette.lipstick, emissionIntensity: 0.2, lit: false)

        addLeg(leftLeg, x: -0.09, skin: skin, boot: black)
        addLeg(rightLeg, x: 0.09, skin: skin, boot: black)

        let skirtGeo = SCNCone(topRadius: 0.16, bottomRadius: 0.48, height: 0.62)
        skirtGeo.materials = [dress]
        skirt.geometry = skirtGeo
        skirt.position = SCNVector3(0, 0.78, 0)
        bob.addChildNode(skirt)

        let hem = SCNTorus(ringRadius: 0.46, pipeRadius: 0.018)
        hem.materials = [laceTrim]
        let hemNode = SCNNode(geometry: hem)
        hemNode.position = SCNVector3(0, 0.49, 0)
        bob.addChildNode(hemNode)

        let torso = SCNBox(width: 0.36, height: 0.34, length: 0.2, chamferRadius: 0.06)
        torso.materials = [dress]
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(0, 1.22, 0)
        bob.addChildNode(torsoNode)

        let neckline = SCNTorus(ringRadius: 0.16, pipeRadius: 0.02)
        neckline.materials = [laceTrim]
        let neckNode = SCNNode(geometry: neckline)
        neckNode.position = SCNVector3(0, 1.36, 0)
        bob.addChildNode(neckNode)

        // Bare shoulders sit above the off-shoulder neckline.
        addSphere(radius: 0.07, material: skin, at: SCNVector3(-0.2, 1.38, 0), parent: bob)
        addSphere(radius: 0.07, material: skin, at: SCNVector3(0.2, 1.38, 0), parent: bob)

        addArm(leftArm, x: -0.24, skin: skin, sleeve: black)
        addArm(rightArm, x: 0.24, skin: skin, sleeve: black)

        let neck = SCNCylinder(radius: 0.05, height: 0.08)
        neck.materials = [skin]
        let neckPivot = SCNNode(geometry: neck)
        neckPivot.position = SCNVector3(0, 1.46, 0)
        bob.addChildNode(neckPivot)

        let headGeo = SCNSphere(radius: 0.135)
        headGeo.materials = [skin]
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0, 1.62, 0)
        head.scale = SCNVector3(0.98, 1.06, 0.96)
        bob.addChildNode(head)

        addEye(x: -0.048, white: white, iris: iris, pupil: pupil, parent: head)
        addEye(x: 0.048, white: white, iris: iris, pupil: pupil, parent: head)

        let mouth = SCNBox(width: 0.045, height: 0.012, length: 0.02, chamferRadius: 0.004)
        mouth.materials = [lip]
        let mouthNode = SCNNode(geometry: mouth)
        mouthNode.position = SCNVector3(0, -0.03, -0.12)
        head.addChildNode(mouthNode)

        let bangs = SCNSphere(radius: 0.11)
        bangs.materials = [hair]
        let bangNode = SCNNode(geometry: bangs)
        bangNode.position = SCNVector3(0, 0.06, -0.04)
        bangNode.scale = SCNVector3(1.05, 0.55, 0.72)
        head.addChildNode(bangNode)

        let crown = SCNSphere(radius: 0.125)
        crown.materials = [hair]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, 0.07, 0.02)
        crownNode.scale = SCNVector3(1.05, 0.85, 1.05)
        head.addChildNode(crownNode)

        let bow = Art.material(color: .black, emission: Palette.pink, emissionIntensity: 0.15, lit: false)
        addSphere(radius: 0.035, material: bow, at: SCNVector3(0, 0.14, -0.06), parent: head).scale = SCNVector3(1.4, 0.7, 0.6)

        addTail(leftTail, side: -1, hair: hair, tie: black, parent: head)
        addTail(rightTail, side: 1, hair: hair, tie: black, parent: head)

        let choker = SCNTorus(ringRadius: 0.055, pipeRadius: 0.012)
        choker.materials = [laceTrim]
        let chokerNode = SCNNode(geometry: choker)
        chokerNode.position = SCNVector3(0, 1.44, 0)
        bob.addChildNode(chokerNode)
    }

    private func addLeg(_ pivot: SCNNode, x: Float, skin: SCNMaterial, boot: SCNMaterial) {
        pivot.position = SCNVector3(x, 0.78, 0)
        bob.addChildNode(pivot)
        let thigh = SCNCylinder(radius: 0.055, height: 0.34)
        thigh.materials = [skin]
        let thighNode = SCNNode(geometry: thigh)
        thighNode.position = SCNVector3(0, -0.18, 0)
        pivot.addChildNode(thighNode)
        let bootGeo = SCNBox(width: 0.09, height: 0.16, length: 0.16, chamferRadius: 0.02)
        bootGeo.materials = [boot]
        let bootNode = SCNNode(geometry: bootGeo)
        bootNode.position = SCNVector3(0, -0.4, -0.02)
        pivot.addChildNode(bootNode)
        let heel = SCNBox(width: 0.06, height: 0.06, length: 0.06, chamferRadius: 0.01)
        heel.materials = [boot]
        let heelNode = SCNNode(geometry: heel)
        heelNode.position = SCNVector3(0, -0.46, 0.04)
        pivot.addChildNode(heelNode)
    }

    private func addArm(_ pivot: SCNNode, x: Float, skin: SCNMaterial, sleeve: SCNMaterial) {
        pivot.position = SCNVector3(x, 1.34, 0)
        bob.addChildNode(pivot)
        let upper = SCNCylinder(radius: 0.04, height: 0.22)
        upper.materials = [skin]
        let upperNode = SCNNode(geometry: upper)
        upperNode.position = SCNVector3(0, -0.12, 0)
        pivot.addChildNode(upperNode)
        let cuff = SCNTorus(ringRadius: 0.045, pipeRadius: 0.012)
        cuff.materials = [sleeve]
        let cuffNode = SCNNode(geometry: cuff)
        cuffNode.position = SCNVector3(0, -0.22, 0)
        pivot.addChildNode(cuffNode)
        let fore = SCNCylinder(radius: 0.035, height: 0.2)
        fore.materials = [sleeve]
        let foreNode = SCNNode(geometry: fore)
        foreNode.position = SCNVector3(0, -0.34, 0)
        pivot.addChildNode(foreNode)
    }

    private func addEye(x: Float, white: SCNMaterial, iris: SCNMaterial, pupil: SCNMaterial, parent: SCNNode) {
        let eye = SCNSphere(radius: 0.038)
        eye.materials = [white]
        let eyeNode = SCNNode(geometry: eye)
        eyeNode.position = SCNVector3(x, 0.02, -0.1)
        parent.addChildNode(eyeNode)
        let irisGeo = SCNSphere(radius: 0.024)
        irisGeo.materials = [iris]
        let irisNode = SCNNode(geometry: irisGeo)
        irisNode.position = SCNVector3(0, 0, -0.02)
        eyeNode.addChildNode(irisNode)
        let pupilGeo = SCNSphere(radius: 0.011)
        pupilGeo.materials = [pupil]
        let pupilNode = SCNNode(geometry: pupilGeo)
        pupilNode.position = SCNVector3(0, 0, -0.016)
        irisNode.addChildNode(pupilNode)
        let lash = SCNBox(width: 0.07, height: 0.012, length: 0.02, chamferRadius: 0.004)
        lash.materials = [pupil]
        let lashNode = SCNNode(geometry: lash)
        lashNode.position = SCNVector3(x, 0.055, -0.1)
        parent.addChildNode(lashNode)
    }

    private func addTail(_ pivot: SCNNode, side: Float, hair: SCNMaterial, tie: SCNMaterial, parent: SCNNode) {
        pivot.position = SCNVector3(side * 0.11, 0.02, 0.02)
        parent.addChildNode(pivot)
        let band = SCNTorus(ringRadius: 0.04, pipeRadius: 0.012)
        band.materials = [tie]
        let bandNode = SCNNode(geometry: band)
        bandNode.eulerAngles.y = Float.pi / 2
        pivot.addChildNode(bandNode)
        var y: Float = -0.02
        var x: Float = side * 0.02
        var z: Float = 0.01
        for index in 0..<8 {
            let radius = 0.075 - Float(index) * 0.006
            let sphere = SCNSphere(radius: CGFloat(radius))
            sphere.materials = [hair]
            let node = SCNNode(geometry: sphere)
            y -= 0.075
            x += side * 0.018
            z += index < 3 ? 0.012 : -0.004
            node.position = SCNVector3(x, y, z)
            pivot.addChildNode(node)
        }
    }

    @discardableResult
    private func addSphere(radius: CGFloat, material: SCNMaterial, at position: SCNVector3, parent: SCNNode) -> SCNNode {
        let geo = SCNSphere(radius: radius)
        geo.materials = [material]
        let node = SCNNode(geometry: geo)
        node.position = position
        parent.addChildNode(node)
        return node
    }
}
