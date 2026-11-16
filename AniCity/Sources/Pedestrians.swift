import SceneKit
import UIKit

final class Pedestrian {
    let root = SCNNode()
    let body = SCNNode()
    let leftLeg = SCNNode()
    let rightLeg = SCNNode()
    var position: Vec3
    var yaw: Float = 0
    var path: [Vec3]
    var index: Int
    var walkSpeed: Float
    var down = false
    var downTimer: Float = 0
    var home: Vec3

    init(position: Vec3, path: [Vec3], shirt: UIColor, walkSpeed: Float) {
        self.position = position
        self.path = path
        self.index = 0
        self.walkSpeed = walkSpeed
        self.home = position
        root.addChildNode(body)
        build(shirt: shirt)
        sync()
    }

    func sync() {
        root.position = SCNVector3(position.x, 0, position.z)
        root.eulerAngles.y = yaw
    }

    private func build(shirt: UIColor) {
        let skin = Art.material(color: Palette.skin)
        let cloth = Art.material(color: shirt, emission: shirt, emissionIntensity: 0.08)
        let pants = Art.material(color: UIColor(white: 0.12, alpha: 1))
        let hair = Art.material(color: UIColor(red: 0.15, green: 0.1, blue: 0.08, alpha: 1))

        leftLeg.position = SCNVector3(-0.08, 0.85, 0)
        rightLeg.position = SCNVector3(0.08, 0.85, 0)
        body.addChildNode(leftLeg)
        body.addChildNode(rightLeg)
        for pivot in [leftLeg, rightLeg] {
            let leg = SCNCylinder(radius: 0.05, height: 0.7)
            leg.materials = [pants]
            let node = SCNNode(geometry: leg)
            node.position = SCNVector3(0, -0.35, 0)
            pivot.addChildNode(node)
        }
        let torso = SCNBox(width: 0.38, height: 0.48, length: 0.2, chamferRadius: 0.05)
        torso.materials = [cloth]
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(0, 1.15, 0)
        body.addChildNode(torsoNode)
        let head = SCNSphere(radius: 0.12)
        head.materials = [skin]
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 1.52, 0)
        body.addChildNode(headNode)
        let hairGeo = SCNSphere(radius: 0.125)
        hairGeo.materials = [hair]
        let hairNode = SCNNode(geometry: hairGeo)
        hairNode.position = SCNVector3(0, 0.04, 0)
        hairNode.scale = SCNVector3(1, 0.7, 1)
        headNode.addChildNode(hairNode)
    }
}

final class PedestrianSystem {
    private(set) var people: [Pedestrian] = []

    init(parent: SCNNode) {
        let posts: [(Int, Int)] = [(0, 1), (0, 1), (0, 2), (1, 1), (1, 1), (1, 2), (2, 1), (2, 2)]
        let shirts: [UIColor] = [
            Palette.pink, Palette.blue, .white, UIColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1),
            UIColor(red: 0.9, green: 0.45, blue: 0.1, alpha: 1), UIColor(red: 0.55, green: 0.2, blue: 0.7, alpha: 1),
            .black, UIColor(red: 0.8, green: 0.15, blue: 0.2, alpha: 1)
        ]
        for (offset, post) in posts.enumerated() {
            let path = sidewalk(post.0, post.1)
            guard let start = path.first else { continue }
            let ped = Pedestrian(
                position: start,
                path: path,
                shirt: shirts[offset % shirts.count],
                walkSpeed: 1.1 + Float(offset % 3) * 0.25
            )
            ped.index = offset % max(path.count, 1)
            parent.addChildNode(ped.root)
            people.append(ped)
        }
    }

    func update(dt: Float, time: Float, cars: [CarEntity], horn: Bool, playerPosition: Vec3, boxes: [AABB]) {
        for ped in people {
            if ped.down {
                ped.downTimer -= dt
                ped.body.eulerAngles.x = 1.2
                ped.body.position.y = 0.2
                if ped.downTimer <= 0 {
                    ped.down = false
                    ped.body.eulerAngles.x = 0
                    ped.body.position.y = 0
                    ped.position = ped.home
                    ped.index = 0
                }
                ped.sync()
                continue
            }
            guard !ped.path.isEmpty else { continue }
            let target = ped.path[ped.index % ped.path.count]
            var step = (target - ped.position).xzNormalized()
            if (target - ped.position).xzLength < 0.45 {
                ped.index = (ped.index + 1) % ped.path.count
            }
            var scare = Vec3.zero
            for car in cars {
                let away = ped.position - car.position
                let distance = away.xzLength
                if distance < 5.5 && distance > 0.001 && car.planarSpeed > 1.5 {
                    scare += away.xzNormalized() * (1.8 / distance)
                }
            }
            if horn && (playerPosition - ped.position).xzLength < 9 {
                step = (playerPosition - ped.position).xzNormalized()
            }
            let delta = (step * ped.walkSpeed + scare) * dt
            ped.position += delta
            ped.position.y = 0
            resolve(ped, boxes: boxes)
            let travel = step + scare
            if travel.xzLength > 0.05 {
                ped.yaw = Vec3.yaw(toward: travel)
            }
            let swing = sin(time * 6 + ped.walkSpeed) * 0.45
            ped.leftLeg.eulerAngles.x = swing
            ped.rightLeg.eulerAngles.x = -swing
            ped.sync()
        }
    }

    private func resolve(_ ped: Pedestrian, boxes: [AABB]) {
        for _ in 0..<2 {
            for box in boxes {
                let result = box.resolveCircle(x: ped.position.x, z: ped.position.z, radius: 0.35)
                if result.hit {
                    ped.position.x = result.x
                    ped.position.z = result.z
                }
            }
        }
    }

    private func sidewalk(_ c: Int, _ r: Int) -> [Vec3] {
        let cell = City.cell(c, r)
        let inset: Float = 1.45
        let x0 = cell.minX + inset
        let x1 = cell.maxX - inset
        let z0 = cell.minZ + inset
        let z1 = cell.maxZ - inset
        return [
            Vec3(x0, 0, z0),
            Vec3(x1, 0, z0),
            Vec3(x1, 0, z1),
            Vec3(x0, 0, z1)
        ]
    }
}
