import SceneKit
import UIKit

final class PoliceSystem {
    private(set) var cars: [CarEntity] = []
    private let parent: SCNNode
    private var spawnTimer: Float = 0
    private var stuck: [ObjectIdentifier: Float] = [:]
    private var reversing: [ObjectIdentifier: Float] = [:]

    init(parent: SCNNode) {
        self.parent = parent
    }

    func nearestDistance(to position: Vec3) -> Float {
        cars.map { ($0.position - position).xzLength }.min() ?? 80
    }

    func canSee(player: Vec3, boxes: [AABB]) -> Bool {
        for car in cars {
            let distance = (car.position - player).xzLength
            if distance < 6 { return true }
            if distance < 36 && lineOfSight(car.position, player, boxes: boxes) {
                return true
            }
        }
        return false
    }

    func despawnAll() {
        for car in cars {
            car.root.removeFromParentNode()
        }
        cars.removeAll()
        stuck.removeAll()
        reversing.removeAll()
    }

    /// Cars the player (or a wall) destroyed. Nodes stay in the world as wrecks.
    func takeRetired() -> [CarEntity] {
        let dead = cars.filter { $0.condition <= 0 }
        cars.removeAll { $0.condition <= 0 }
        return dead
    }

    func update(dt: Float, time: Float, stars: Int, playerPosition: Vec3, playerVelocity: Vec3, boxes: [AABB]) {
        let wanted = max(0, stars)
        if wanted == 0 {
            if !cars.isEmpty { despawnAll() }
            return
        }
        let desired = min(3, wanted)
        spawnTimer -= dt
        if cars.count < desired && spawnTimer <= 0 {
            if spawn(near: playerPosition, boxes: boxes) {
                spawnTimer = 1.5
            } else {
                spawnTimer = 0.4
            }
        }
        if cars.count > desired {
            if let far = cars.max(by: { ($0.position - playerPosition).xzLength < ($1.position - playerPosition).xzLength }),
               (far.position - playerPosition).xzLength > 22 {
                far.root.removeFromParentNode()
                cars.removeAll { $0 === far }
            }
        }

        for car in cars where car.condition > 0 {
            let id = ObjectIdentifier(car)
            let toPlayer = playerPosition - car.position
            let distance = max(0.001, toPlayer.xzLength)
            let forward = Vec3.direction(yaw: car.yaw)
            let side = dot(toPlayer, forward.xzRight)
            let ahead = dot(toPlayer, forward)
            var steer = clamp(side / distance * 2.6, -1, 1)
            if ahead < 0 && distance < 12 {
                steer = side >= 0 ? 1 : -1
            }
            var throttle: Float = distance > 8 ? 1 : 0.55
            if distance < 4.5 { throttle = 0.25 }

            let feeler = blocked(car.position, forward, 5.2, boxes: boxes)
            if feeler {
                let leftClear = !blocked(car.position, rotate(forward, -0.7), 4.2, boxes: boxes)
                steer = leftClear ? -1 : 1
                throttle = 0.45
            }

            var reverseTime = reversing[id] ?? 0
            if reverseTime > 0 {
                reverseTime -= dt
                throttle = -1
                steer = 1
                reversing[id] = reverseTime
            } else {
                let speed = car.planarSpeed
                var stuckTime = stuck[id] ?? 0
                if speed < 0.55 && distance > 6 {
                    stuckTime += dt
                } else {
                    stuckTime = 0
                }
                stuck[id] = stuckTime
                if stuckTime > 1.25 {
                    reversing[id] = 0.7
                    stuck[id] = 0
                }
            }

            if abs(playerVelocity.xzLength) > 8 && ahead > 0 && distance < 14 {
                throttle = 1
            }
            VehicleDynamics.step(car, throttle: throttle, steer: steer, handbrake: false, dt: dt)
            car.syncVisuals(dt: dt, night: 1, braking: throttle < 0, time: time)
        }
    }

    private func spawn(near player: Vec3, boxes: [AABB]) -> Bool {
        var options: [Vec3] = []
        for column in 0..<City.intersections {
            for row in 0..<City.intersections {
                let point = Vec3(City.x(column), 0, City.z(row))
                let distance = (point - player).xzLength
                if distance > 26 && distance < 78 {
                    options.append(point)
                }
            }
        }
        guard var spot = options.randomElement() else { return false }
        for car in cars where (car.position - spot).xzLength < 5 {
            spot += Vec3(4, 0, -3)
        }
        var nudged = spot
        for _ in 0..<3 {
            var hit = false
            for box in boxes {
                let resolved = box.resolveCircle(x: nudged.x, z: nudged.z, radius: 2)
                if resolved.hit {
                    nudged.x = resolved.x
                    nudged.z = resolved.z
                    hit = true
                }
            }
            if !hit { break }
        }
        let yaw = Vec3.yaw(toward: player - nudged)
        let car = VehicleFactory.make(.police, role: .police, position: nudged, yaw: yaw)
        parent.addChildNode(car.root)
        cars.append(car)
        return true
    }

    private func blocked(_ origin: Vec3, _ direction: Vec3, _ distance: Float, boxes: [AABB]) -> Bool {
        let ahead = origin + direction.normalized() * distance
        for box in boxes {
            if box.resolveCircle(x: ahead.x, z: ahead.z, radius: 1.3).hit { return true }
        }
        return false
    }

    private func rotate(_ direction: Vec3, _ radians: Float) -> Vec3 {
        let yaw = Vec3.yaw(toward: direction) + radians
        return Vec3.direction(yaw: yaw)
    }
}
