import SceneKit
import UIKit

enum CarType: Int {
    case sports
    case sedan
    case beater
    case police

    var maxSpeed: Float {
        switch self {
        case .sports: return 22
        case .sedan: return 16
        case .beater: return 12.5
        case .police: return 20
        }
    }

    var acceleration: Float {
        switch self {
        case .sports: return 16
        case .sedan: return 10
        case .beater: return 7.5
        case .police: return 13
        }
    }

    var grip: Float {
        switch self {
        case .sports: return 9
        case .sedan: return 13
        case .beater: return 7
        case .police: return 11
        }
    }

    var radius: Float {
        switch self {
        case .sports: return 2.05
        case .sedan: return 2.15
        case .beater: return 2.1
        case .police: return 2.2
        }
    }
}

enum CarRole {
    case parked
    case traffic
    case police
    case personal
    case abandoned
}

final class CarEntity {
    let type: CarType
    var role: CarRole
    let root = SCNNode()
    let wheels: [SCNNode]
    let paint: SCNMaterial
    let headLights: SCNMaterial
    let brakeLights: SCNMaterial
    let smoke: SCNParticleSystem
    var underglow: SCNLight?
    var sirenLight: SCNLight?
    var sirenNodes: [SCNNode] = []
    var position: Vec3
    var yaw: Float
    var velocity = Vec3.zero
    var condition: Float = 100
    var walletTaken = false
    var hitCooldown: Float = 0
    var slowTimer: Float = 0
    var killedByPlayer = false

    var radius: Float { type.radius }
    var planarSpeed: Float { velocity.xzLength }
    var driveable: Bool { condition > 8 }

    init(type: CarType, role: CarRole, position: Vec3, yaw: Float, paintColor: UIColor, wheels: [SCNNode], paint: SCNMaterial, headLights: SCNMaterial, brakeLights: SCNMaterial, smoke: SCNParticleSystem) {
        self.type = type
        self.role = role
        self.position = position
        self.yaw = yaw
        self.wheels = wheels
        self.paint = paint
        self.headLights = headLights
        self.brakeLights = brakeLights
        self.smoke = smoke
        root.name = "car"
    }

    func syncVisuals(dt: Float, night: Float, braking: Bool, time: Float) {
        root.position = SCNVector3(position.x, 0, position.z)
        root.eulerAngles.y = yaw
        let spin = planarSpeed * dt / 0.32
        let direction: Float = dot(velocity, Vec3.direction(yaw: yaw)) >= 0 ? 1 : -1
        for wheel in wheels {
            wheel.eulerAngles.y += spin * direction
        }
        let shade = CGFloat(0.22 + 0.78 * max(0, condition) / 100)
        paint.multiply.contents = UIColor(white: shade, alpha: 1)
        smoke.birthRate = condition < 58 ? CGFloat((58 - condition) * 0.55) : 0
        headLights.emission.intensity = 0.35 + CGFloat(night) * 1.1
        brakeLights.emission.intensity = braking ? 1.3 : 0.15 + CGFloat(night) * 0.25
        underglow?.intensity = CGFloat(180 * night * max(0, condition) / 100)
        if type == .police, sirenNodes.count == 2 {
            let flash = sin(time * 18) > 0
            sirenNodes[0].isHidden = !flash
            sirenNodes[1].isHidden = flash
            sirenLight?.color = flash ? UIColor.red : UIColor.systemBlue
            sirenLight?.intensity = 500
        }
    }

    func applyDamage(_ amount: Float, byPlayer: Bool) {
        guard amount > 0 else { return }
        let before = condition
        condition = max(0, condition - amount)
        if byPlayer && before > 0 && condition <= 0 {
            killedByPlayer = true
        }
    }
}

enum VehicleDynamics {
    static func step(_ car: CarEntity, throttle: Float, steer: Float, handbrake: Bool, dt: Float) {
        let scale = 0.35 + 0.65 * max(car.condition, 0) / 100
        let maxSpeed = car.type.maxSpeed * scale
        let accel = car.type.acceleration * (0.5 + 0.5 * scale)
        let forward = Vec3.direction(yaw: car.yaw)
        var speed = dot(car.velocity, forward)
        let drive = clamp(throttle, -1, 1)

        if drive > 0.05 && speed < maxSpeed {
            speed += drive * accel * dt
        } else if drive < -0.05 && speed > -6 {
            speed -= abs(drive) * accel * 0.65 * dt
        } else if abs(drive) < 0.05 {
            speed -= speed * min(1, 1.5 * dt)
        }
        if handbrake {
            speed -= speed * min(1, 0.8 * dt)
        }

        let reverseSteer: Float = speed < -0.4 ? -1 : 1
        let turnBase: Float
        if abs(speed) < 0.45 {
            turnBase = (abs(drive) > 0.08 || handbrake) ? 8 : 0
        } else {
            turnBase = max(min(abs(speed), 11), 5)
        }
        car.yaw += steer * reverseSteer * turnBase * (handbrake ? 0.13 : 0.078) * dt

        let newForward = Vec3.direction(yaw: car.yaw)
        let response = handbrake ? 2.2 : car.type.grip
        var velocity = newForward * speed
        let leftover = car.velocity - forward * speed
        velocity += leftover * (handbrake ? 0.9 : 0.25)
        let sideways = velocity - newForward * dot(velocity, newForward)
        velocity -= sideways * min(1, response * dt)

        let cap = max(3, maxSpeed)
        let magnitude = velocity.xzLength
        if magnitude > cap {
            velocity = velocity * (cap / magnitude)
        }
        car.velocity = velocity
        car.position += velocity * dt
        car.position.y = 0
    }
}

enum VehicleFactory {
    static func make(_ type: CarType, role: CarRole, position: Vec3, yaw: Float, paint override: UIColor? = nil) -> CarEntity {
        let paintColor = override ?? defaultPaint(type)
        let paint = Art.material(color: paintColor, emission: paintColor, emissionIntensity: 0.05)
        paint.specular.contents = UIColor(white: 0.7, alpha: 1)
        paint.shininess = 0.7
        let glass = Art.material(color: UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1), emission: Palette.blue, emissionIntensity: 0.08)
        let dark = Art.material(color: UIColor(white: 0.08, alpha: 1))
        let head = Art.material(color: UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 1), emission: UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1), emissionIntensity: 0.8, lit: false)
        let brake = Art.material(color: UIColor(red: 0.6, green: 0.05, blue: 0.08, alpha: 1), emission: .red, emissionIntensity: 0.2, lit: false)
        let tireMat = Art.material(color: UIColor(white: 0.05, alpha: 1))
        let rimMat = Art.material(color: UIColor(white: 0.75, alpha: 1))

        let visual = SCNNode()
        var wheelSpins: [SCNNode] = []
        let spec = bodySpec(type)

        let body = SCNBox(width: CGFloat(spec.width), height: CGFloat(spec.bodyHeight), length: CGFloat(spec.length), chamferRadius: 0.08)
        body.materials = [paint]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, spec.bodyY, 0)
        visual.addChildNode(bodyNode)

        let cabin = SCNBox(width: CGFloat(spec.width * 0.82), height: CGFloat(spec.cabinHeight), length: CGFloat(spec.length * 0.48), chamferRadius: 0.06)
        cabin.materials = [glass]
        let cabinNode = SCNNode(geometry: cabin)
        cabinNode.position = SCNVector3(0, spec.bodyY + spec.bodyHeight * 0.55, -spec.length * 0.04)
        visual.addChildNode(cabinNode)

        addLight(at: SCNVector3(-spec.width * 0.32, spec.bodyY, -spec.length * 0.5), size: SCNVector3(0.28, 0.1, 0.08), material: head, parent: visual)
        addLight(at: SCNVector3(spec.width * 0.32, spec.bodyY, -spec.length * 0.5), size: SCNVector3(0.28, 0.1, 0.08), material: head, parent: visual)
        addLight(at: SCNVector3(-spec.width * 0.3, spec.bodyY, spec.length * 0.5), size: SCNVector3(0.3, 0.08, 0.06), material: brake, parent: visual)
        addLight(at: SCNVector3(spec.width * 0.3, spec.bodyY, spec.length * 0.5), size: SCNVector3(0.3, 0.08, 0.06), material: brake, parent: visual)

        let corners: [SCNVector3] = [
            SCNVector3(-spec.width * 0.42, 0.32, -spec.length * 0.32),
            SCNVector3(spec.width * 0.42, 0.32, -spec.length * 0.32),
            SCNVector3(-spec.width * 0.42, 0.32, spec.length * 0.32),
            SCNVector3(spec.width * 0.42, 0.32, spec.length * 0.32)
        ]
        for corner in corners {
            wheelSpins.append(addWheel(at: corner, tire: tireMat, rim: rimMat, parent: visual))
        }

        if type == .sports {
            let lip = SCNBox(width: CGFloat(spec.width * 0.7), height: 0.04, length: 0.35, chamferRadius: 0.01)
            lip.materials = [dark]
            let spoiler = SCNNode(geometry: lip)
            spoiler.position = SCNVector3(0, spec.bodyY + spec.bodyHeight * 0.8, spec.length * 0.42)
            visual.addChildNode(spoiler)
        }

        let smoke = SCNParticleSystem()
        smoke.birthRate = 0
        smoke.particleLifeSpan = 0.7
        smoke.particleSize = 0.28
        smoke.particleColor = UIColor(white: 0.35, alpha: 0.45)
        smoke.particleImage = Art.blob
        smoke.blendMode = .alpha
        smoke.spreadingAngle = 25
        smoke.particleVelocity = 0.7
        smoke.emitterShape = SCNSphere(radius: 0.15)
        smoke.isAffectedByGravity = false
        smoke.loops = true
        let smokeNode = SCNNode()
        smokeNode.position = SCNVector3(0, spec.bodyY, spec.length * 0.35)
        smokeNode.addParticleSystem(smoke)
        visual.addChildNode(smokeNode)

        let car = CarEntity(
            type: type,
            role: role,
            position: position,
            yaw: yaw,
            paintColor: paintColor,
            wheels: wheelSpins,
            paint: paint,
            headLights: head,
            brakeLights: brake,
            smoke: smoke
        )
        return adopt(car, visual: visual)
    }

    /// Moves the freshly built geometry onto the entity root.
    private static func adopt(_ car: CarEntity, visual: SCNNode) -> CarEntity {
        let children = visual.childNodes
        for child in children {
            car.root.addChildNode(child)
        }
        if car.type == .sports {
            let glow = SCNBox(width: 1.15, height: 0.04, length: 2.1, chamferRadius: 0.02)
            let glowMat = Art.material(color: Palette.pink, emission: Palette.pink, emissionIntensity: 1, lit: false)
            glow.materials = [glowMat]
            let glowNode = SCNNode(geometry: glow)
            glowNode.position = SCNVector3(0, 0.12, 0)
            car.root.addChildNode(glowNode)
            let light = SCNLight()
            light.type = .omni
            light.color = Palette.pink
            light.intensity = 160
            light.attenuationEndDistance = 7
            let lightNode = SCNNode()
            lightNode.light = light
            lightNode.position = SCNVector3(0, 0.3, 0)
            car.root.addChildNode(lightNode)
            car.underglow = light
        }
        if car.type == .police {
            let redMat = Art.material(color: .red, emission: .red, emissionIntensity: 1, lit: false)
            let blueMat = Art.material(color: .systemBlue, emission: .systemBlue, emissionIntensity: 1, lit: false)
            let bar = SCNBox(width: 0.7, height: 0.08, length: 0.22, chamferRadius: 0.02)
            bar.materials = [Art.material(color: .black)]
            let barNode = SCNNode(geometry: bar)
            barNode.position = SCNVector3(0, 1.15, -0.1)
            car.root.addChildNode(barNode)
            let left = SCNBox(width: 0.28, height: 0.1, length: 0.16, chamferRadius: 0.02)
            left.materials = [redMat]
            let leftNode = SCNNode(geometry: left)
            leftNode.position = SCNVector3(-0.18, 0.08, 0)
            barNode.addChildNode(leftNode)
            let right = SCNBox(width: 0.28, height: 0.1, length: 0.16, chamferRadius: 0.02)
            right.materials = [blueMat]
            let rightNode = SCNNode(geometry: right)
            rightNode.position = SCNVector3(0.18, 0.08, 0)
            barNode.addChildNode(rightNode)
            car.sirenNodes = [leftNode, rightNode]
            let light = SCNLight()
            light.type = .omni
            light.color = UIColor.red
            light.intensity = 400
            light.attenuationEndDistance = 16
            let lightNode = SCNNode()
            lightNode.light = light
            lightNode.position = SCNVector3(0, 1.3, 0)
            car.root.addChildNode(lightNode)
            car.sirenLight = light
            let decal = Art.sign("POLICE", width: 0.9, height: 0.22, background: .black, foreground: .white)
            decal.position = SCNVector3(0.96, 0.7, 0)
            decal.eulerAngles.y = Float.pi / 2
            car.root.addChildNode(decal)
            let decal2 = Art.sign("POLICE", width: 0.9, height: 0.22, background: .black, foreground: .white)
            decal2.position = SCNVector3(-0.96, 0.7, 0)
            decal2.eulerAngles.y = -Float.pi / 2
            car.root.addChildNode(decal2)
        }
        car.syncVisuals(dt: 0, night: 1, braking: false, time: 0)
        return car
    }

    private static func defaultPaint(_ type: CarType) -> UIColor {
        switch type {
        case .sports:
            return UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)
        case .sedan:
            return UIColor(red: 0.65, green: 0.7, blue: 0.78, alpha: 1)
        case .beater:
            return UIColor(red: 0.55, green: 0.28, blue: 0.12, alpha: 1)
        case .police:
            return UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1)
        }
    }

    private struct Spec {
        var width: Float
        var length: Float
        var bodyHeight: Float
        var bodyY: Float
        var cabinHeight: Float
    }

    private static func bodySpec(_ type: CarType) -> Spec {
        switch type {
        case .sports:
            return Spec(width: 1.85, length: 4.4, bodyHeight: 0.38, bodyY: 0.48, cabinHeight: 0.38)
        case .sedan:
            return Spec(width: 1.8, length: 4.5, bodyHeight: 0.48, bodyY: 0.55, cabinHeight: 0.48)
        case .beater:
            return Spec(width: 1.85, length: 4.2, bodyHeight: 0.62, bodyY: 0.62, cabinHeight: 0.55)
        case .police:
            return Spec(width: 1.85, length: 4.6, bodyHeight: 0.5, bodyY: 0.55, cabinHeight: 0.5)
        }
    }

    private static func addLight(at position: SCNVector3, size: SCNVector3, material: SCNMaterial, parent: SCNNode) {
        let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0.02)
        box.materials = [material]
        let node = SCNNode(geometry: box)
        node.position = position
        parent.addChildNode(node)
    }

    private static func addWheel(at position: SCNVector3, tire: SCNMaterial, rim: SCNMaterial, parent: SCNNode) -> SCNNode {
        let pivot = SCNNode()
        pivot.position = position
        pivot.eulerAngles.z = Float.pi / 2
        parent.addChildNode(pivot)
        let tireGeo = SCNCylinder(radius: 0.32, height: 0.22)
        tireGeo.materials = [tire]
        let spin = SCNNode(geometry: tireGeo)
        pivot.addChildNode(spin)
        let rimGeo = SCNCylinder(radius: 0.16, height: 0.24)
        rimGeo.materials = [rim]
        let rimNode = SCNNode(geometry: rimGeo)
        spin.addChildNode(rimNode)
        return spin
    }
}
