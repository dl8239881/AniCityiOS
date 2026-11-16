import Foundation
import SceneKit

struct Vec3: Equatable {
    var x: Float
    var y: Float
    var z: Float

    init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    static let zero = Vec3(0, 0, 0)

    var scn: SCNVector3 { SCNVector3(x, y, z) }
    var length: Float { sqrt(x * x + y * y + z * z) }
    var xzLength: Float { sqrt(x * x + z * z) }

    /// Right-hand perpendicular on the ground plane.
    var xzRight: Vec3 { Vec3(z, 0, -x) }

    func normalized() -> Vec3 {
        let len = length
        if len < 0.0001 { return .zero }
        return self / len
    }

    func xzNormalized() -> Vec3 {
        let len = xzLength
        if len < 0.0001 { return .zero }
        return Vec3(x / len, 0, z / len)
    }

    static func direction(yaw: Float) -> Vec3 {
        Vec3(-sin(yaw), 0, -cos(yaw))
    }

    static func yaw(toward dir: Vec3) -> Float {
        atan2(-dir.x, -dir.z)
    }

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (a: Vec3, s: Float) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    static func * (s: Float, a: Vec3) -> Vec3 { a * s }
    static func / (a: Vec3, s: Float) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }
    static func += (a: inout Vec3, b: Vec3) { a = a + b }
    static func -= (a: inout Vec3, b: Vec3) { a = a - b }
    static func *= (a: inout Vec3, s: Float) { a = a * s }
}

func dot(_ a: Vec3, _ b: Vec3) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}

func clamp<T: Comparable>(_ value: T, _ low: T, _ high: T) -> T {
    min(max(value, low), high)
}

func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
}

func approachAngle(_ from: Float, _ to: Float, maxDelta: Float) -> Float {
    var delta = to - from
    while delta > Float.pi { delta -= 2 * Float.pi }
    while delta < -Float.pi { delta += 2 * Float.pi }
    if delta > maxDelta { delta = maxDelta }
    if delta < -maxDelta { delta = -maxDelta }
    return from + delta
}

struct AABB {
    var minX: Float
    var maxX: Float
    var minZ: Float
    var maxZ: Float
    var minY: Float = 0
    var maxY: Float = 30

    var center: Vec3 {
        Vec3((minX + maxX) * 0.5, 0, (minZ + maxZ) * 0.5)
    }

    func containsXZ(_ p: Vec3, pad: Float = 0) -> Bool {
        p.x >= minX - pad && p.x <= maxX + pad && p.z >= minZ - pad && p.z <= maxZ + pad
    }

    func containsPoint(_ p: Vec3) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY && p.z >= minZ && p.z <= maxZ
    }

    /// Pushes a circle out of the box. `normal` points away from the box.
    func resolveCircle(x: Float, z: Float, radius: Float) -> (x: Float, z: Float, hit: Bool, normal: Vec3) {
        let closestX = min(max(x, minX), maxX)
        let closestZ = min(max(z, minZ), maxZ)
        let dx = x - closestX
        let dz = z - closestZ
        let distSq = dx * dx + dz * dz
        let radiusSq = radius * radius
        if distSq >= radiusSq {
            return (x, z, false, .zero)
        }
        if distSq > 0.000001 {
            let dist = sqrt(distSq)
            let scale = (radius - dist) / dist
            let nx = dx / dist
            let nz = dz / dist
            return (x + dx * scale, z + dz * scale, true, Vec3(nx, 0, nz))
        }
        let left = x - minX
        let right = maxX - x
        let south = z - minZ
        let north = maxZ - z
        let best = min(left, min(right, min(south, north)))
        if best == left { return (minX - radius, z, true, Vec3(-1, 0, 0)) }
        if best == right { return (maxX + radius, z, true, Vec3(1, 0, 0)) }
        if best == south { return (x, minZ - radius, true, Vec3(0, 0, -1)) }
        return (x, maxZ + radius, true, Vec3(0, 0, 1))
    }
}

/// First positive hit distance of a ray against a box, or nil.
func rayHit(_ origin: Vec3, _ dir: Vec3, _ box: AABB, maxT: Float) -> Float? {
    if box.containsPoint(origin) { return nil }
    var tMin: Float = 0
    var tMax = maxT
    if !slab(origin.x, dir.x, box.minX, box.maxX, &tMin, &tMax) { return nil }
    if !slab(origin.y, dir.y, box.minY, box.maxY, &tMin, &tMax) { return nil }
    if !slab(origin.z, dir.z, box.minZ, box.maxZ, &tMin, &tMax) { return nil }
    if tMax < 0 { return nil }
    let t = tMin >= 0 ? tMin : tMax
    if t < 0 || t > maxT { return nil }
    return t
}

private func slab(_ origin: Float, _ dir: Float, _ minB: Float, _ maxB: Float, _ tMin: inout Float, _ tMax: inout Float) -> Bool {
    if abs(dir) < 0.00001 {
        return origin >= minB && origin <= maxB
    }
    var t1 = (minB - origin) / dir
    var t2 = (maxB - origin) / dir
    if t1 > t2 {
        let swap = t1
        t1 = t2
        t2 = swap
    }
    if t1 > tMin { tMin = t1 }
    if t2 < tMax { tMax = t2 }
    return tMin <= tMax
}

func lineOfSight(_ a: Vec3, _ b: Vec3, boxes: [AABB]) -> Bool {
    let delta = b - a
    let dist = delta.length
    if dist < 0.001 { return true }
    let dir = delta / dist
    let eyeA = Vec3(a.x, 1.2, a.z)
    let eyeB = Vec3(b.x, 1.2, b.z)
    let deltaEye = eyeB - eyeA
    let eyeDist = deltaEye.length
    let eyeDir = eyeDist > 0.001 ? deltaEye / eyeDist : dir
    for box in boxes {
        if let t = rayHit(eyeA, eyeDir, box, maxT: eyeDist), t < eyeDist - 0.4 {
            return false
        }
    }
    return true
}
