import SceneKit
import UIKit

/// Lane graph: each edge runs from one intersection's stop line, through that intersection, to the next stop line.
final class TrafficSystem {
    private(set) var cars: [CarEntity] = []
    private var edges: [LaneEdge] = []
    private var nextEdges: [[Int]] = []
    private var drivers: [Driver] = []
    private let parent: SCNNode

    init(parent: SCNNode) {
        self.parent = parent
        buildGraph()
        spawnCars()
    }

    func detach(_ car: CarEntity) {
        drivers.removeAll { $0.car === car }
        cars.removeAll { $0 === car }
    }

    func update(dt: Float, time: Float, siren: Bool, police: [CarEntity], playerPosition: Vec3, playerOnFoot: Bool) {
        guard dt > 0, !edges.isEmpty else { return }
        for index in drivers.indices {
            var driver = drivers[index]
            let car = driver.car
            let edge = edges[driver.edge]
            let remaining = edge.total - driver.distance
            var target = driver.cruise
            let axis = edge.to.heading.axis
            let green = Signals.isGreen(axis, time: time)

            if remaining < 8 && remaining > 1.35 && !green {
                target = min(target, max(0, (remaining - 1.35) * 1.1))
            }
            if car.slowTimer > 0 {
                car.slowTimer -= dt
                target = min(target, 1.2)
            }
            if siren {
                target = min(target, 3.0)
            }
            for cop in police {
                if (cop.position - car.position).xzLength < 14 {
                    target = 0
                    break
                }
            }
            if playerOnFoot {
                let forward = Vec3.direction(yaw: car.yaw)
                let toPlayer = playerPosition - car.position
                let ahead = dot(toPlayer, forward)
                let side = abs(dot(toPlayer, forward.xzRight))
                if ahead > 0 && ahead < 6.5 && side < 1.7 {
                    target = 0
                }
            }
            for other in drivers where other.car !== car {
                let forward = Vec3.direction(yaw: car.yaw)
                let delta = other.car.position - car.position
                let ahead = dot(delta, forward)
                if ahead > 0 && ahead < 7.5 && abs(dot(delta, forward.xzRight)) < 2.1 {
                    target = min(target, max(0, other.speed * 0.9))
                    if ahead < 3.4 { target = 0 }
                }
            }

            let deltaSpeed = clamp(target - driver.speed, -14 * dt, 7 * dt)
            driver.speed += deltaSpeed
            driver.distance += max(0, driver.speed) * dt

            if driver.distance >= edge.total - 0.3 {
                if green || driver.distance >= edge.total {
                    let options = nextEdges[driver.edge]
                    if let choice = options.randomElement() {
                        driver.edge = choice
                        driver.distance = 0.4
                    } else if let anywhere = edges.indices.randomElement() {
                        driver.edge = anywhere
                        driver.distance = 1
                    }
                } else {
                    driver.distance = max(0, edge.total - 0.45)
                    driver.speed = 0
                }
            }

            let pull: Float = siren ? 1.6 : 0
            let previous = car.position
            let sample = samplePoint(edges[driver.edge], distance: driver.distance, pull: pull)
            car.position = sample.position
            car.yaw = sample.yaw
            let delta = car.position - previous
            let jumped = delta.xzLength / dt
            if jumped > 22 {
                car.velocity = Vec3.direction(yaw: car.yaw) * driver.speed
            } else {
                car.velocity = delta / dt
            }
            car.syncVisuals(dt: dt, night: 0.5, braking: driver.speed < 1 && target < 1, time: time)
            drivers[index] = driver
        }
    }

    private struct Gate: Hashable {
        var c: Int
        var r: Int
        var heading: Heading
    }

    private struct LaneEdge {
        var from: Gate
        var to: Gate
        var points: [Vec3]
        var cumulative: [Float]
        var total: Float
    }

    private struct Driver {
        var car: CarEntity
        var edge: Int
        var distance: Float
        var speed: Float
        var cruise: Float
    }

    private func buildGraph() {
        var built: [LaneEdge] = []
        for column in 0..<City.intersections {
            for row in 0..<City.intersections {
                for heading in Heading.allCases {
                    let from = Gate(c: column, r: row, heading: heading)
                    let maneuvers = [heading, heading.rightTurn, heading.leftTurn]
                    for turn in maneuvers {
                        let nc = column + turn.dc
                        let nr = row + turn.dr
                        guard nc >= 0, nr >= 0, nc < City.intersections, nr < City.intersections else { continue }
                        let to = Gate(c: nc, r: nr, heading: turn)
                        let points = curve(from: from, to: to, turning: turn != heading)
                        let totals = measure(points)
                        if totals.total > 4 {
                            built.append(LaneEdge(from: from, to: to, points: points, cumulative: totals.cumulative, total: totals.total))
                        }
                    }
                }
            }
        }
        edges = built
        var starters: [Gate: [Int]] = [:]
        for (index, edge) in edges.enumerated() {
            starters[edge.from, default: []].append(index)
        }
        nextEdges = edges.map { starters[$0.to] ?? [] }
    }

    private func curve(from: Gate, to: Gate, turning: Bool) -> [Vec3] {
        let start = stopLine(from)
        let end = stopLine(to)
        let center = Vec3(City.x(from.c), 0, City.z(from.r))
        var points = [start, center + from.heading.right * City.laneOffset]
        if turning {
            points.append(center + to.heading.right * City.laneOffset)
        }
        if let last = points.last {
            points.append((last + end) * 0.5)
        }
        points.append(end)
        return points
    }

    private func stopLine(_ gate: Gate) -> Vec3 {
        let center = Vec3(City.x(gate.c), 0, City.z(gate.r))
        return center - gate.heading.vector * (City.roadHalf + 0.35) + gate.heading.right * City.laneOffset
    }

    private func measure(_ points: [Vec3]) -> (cumulative: [Float], total: Float) {
        var cumulative: [Float] = [0]
        var total: Float = 0
        guard points.count > 1 else { return ([0], 0) }
        for index in 1..<points.count {
            total += (points[index] - points[index - 1]).xzLength
            cumulative.append(total)
        }
        return (cumulative, total)
    }

    private func samplePoint(_ edge: LaneEdge, distance: Float, pull: Float) -> (position: Vec3, yaw: Float) {
        let clamped = min(max(0, distance), max(0.01, edge.total - 0.05))
        var index = 0
        while index < edge.cumulative.count - 2 && edge.cumulative[index + 1] < clamped {
            index += 1
        }
        let endIndex = min(index + 1, edge.points.count - 1)
        let span = max(0.001, edge.cumulative[endIndex] - edge.cumulative[index])
        let t = (clamped - edge.cumulative[index]) / span
        let position = edge.points[index] + (edge.points[endIndex] - edge.points[index]) * t
        let yaw = Vec3.yaw(toward: edge.points[endIndex] - edge.points[index])
        let right = Vec3.direction(yaw: yaw).xzRight
        return (position + right * pull, yaw)
    }

    private func spawnCars() {
        let usable = edges.enumerated().filter { $0.element.total > 14 }.map { $0.offset }
        guard !usable.isEmpty else { return }
        let paints = [
            UIColor(red: 0.15, green: 0.35, blue: 0.75, alpha: 1),
            UIColor(red: 0.75, green: 0.15, blue: 0.25, alpha: 1),
            UIColor(red: 0.85, green: 0.75, blue: 0.2, alpha: 1),
            UIColor(red: 0.2, green: 0.55, blue: 0.35, alpha: 1),
            UIColor(white: 0.85, alpha: 1),
            UIColor(red: 0.45, green: 0.2, blue: 0.55, alpha: 1),
            UIColor(red: 0.9, green: 0.45, blue: 0.1, alpha: 1)
        ]
        for index in 0..<7 {
            let edgeIndex = usable[index % usable.count]
            let type: CarType = index == 0 ? .sports : (index % 2 == 0 ? .sedan : .beater)
            let sample = samplePoint(edges[edgeIndex], distance: Float(index) * 9 + 3, pull: 0)
            let car = VehicleFactory.make(type, role: .traffic, position: sample.position, yaw: sample.yaw, paint: paints[index % paints.count])
            parent.addChildNode(car.root)
            cars.append(car)
            drivers.append(Driver(car: car, edge: edgeIndex, distance: Float(index) * 9 + 3, speed: 0, cruise: 7 + Float(index % 3)))
        }
    }
}
