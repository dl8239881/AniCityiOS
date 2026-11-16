import UIKit

/// Grid of the prototype city. Roads run along X (east) and Z (north).
/// Yaw 0 faces south (−Z), matching a SceneKit node whose nose points down local −Z.
enum City {
    static let intersections = 4
    static let spacing: Float = 36
    static let roadHalf: Float = 6
    static let laneOffset: Float = 2.35

    static func x(_ column: Int) -> Float { (Float(column) - 1.5) * spacing }
    static func z(_ row: Int) -> Float { (Float(row) - 1.5) * spacing }

    /// Block between intersection (c, r) and (c+1, r+1), inside the road edges.
    static func cell(_ c: Int, _ r: Int) -> AABB {
        AABB(
            minX: x(c) + roadHalf,
            maxX: x(c + 1) - roadHalf,
            minZ: z(r) + roadHalf,
            maxZ: z(r + 1) - roadHalf
        )
    }
}

enum Heading: Int, CaseIterable {
    case east, north, west, south

    var vector: Vec3 {
        switch self {
        case .east: return Vec3(1, 0, 0)
        case .north: return Vec3(0, 0, 1)
        case .west: return Vec3(-1, 0, 0)
        case .south: return Vec3(0, 0, -1)
        }
    }

    var right: Vec3 { Vec3(vector.z, 0, -vector.x) }

    var leftTurn: Heading {
        switch self {
        case .east: return .north
        case .north: return .west
        case .west: return .south
        case .south: return .east
        }
    }

    var rightTurn: Heading {
        switch self {
        case .east: return .south
        case .north: return .east
        case .west: return .north
        case .south: return .west
        }
    }

    var dc: Int {
        switch self {
        case .east: return 1
        case .west: return -1
        default: return 0
        }
    }

    var dr: Int {
        switch self {
        case .north: return 1
        case .south: return -1
        default: return 0
        }
    }

    var axis: LightAxis {
        switch self {
        case .east, .west: return .ew
        case .north, .south: return .ns
        }
    }
}

enum LightAxis {
    case ns
    case ew
}

enum Signals {
    static let period: Float = 10

    static func isGreen(_ axis: LightAxis, time: Float) -> Bool {
        let wrapped = time - floor(time / period) * period
        switch axis {
        case .ew:
            return wrapped < 4.3
        case .ns:
            return wrapped >= 5.0 && wrapped < 9.3
        }
    }
}

enum Economy {
    static let startingCash = 200
    static let housePrice = 750
    static let theftWallet = 40
    static let escapeBonus = 80
    static let starCoolBonus = 30
    static let bustKeep = 0.75
    static let pickupValue = 80
}

enum Heat {
    static let theft: Float = 1
    static let pedestrian: Float = 1.2
    static let wreck: Float = 0.7
    static let fender: Float = 0.35
    static let maxStars = 4
}

struct MapRect {
    var minX: Float
    var maxX: Float
    var minZ: Float
    var maxZ: Float
    var color: UIColor
}

struct Blip {
    var position: Vec3
    var color: UIColor
    var radius: CGFloat
}

struct MapDraw {
    var minX: Float
    var maxX: Float
    var minZ: Float
    var maxZ: Float
    var zones: [MapRect]
    var roads: [MapRect]
    var blips: [Blip]
    var player: Vec3
    var playerYaw: Float
}

struct InputFrame {
    var moveX: Float = 0
    var moveY: Float = 0
    var lookStickX: Float = 0
    var lookStickY: Float = 0
    var lookDragX: Float = 0
    var lookDragY: Float = 0
    var throttle: Float = 0
    var sprint = false
    var handbrake = false
    var hornEdge = false
    var actionEdge = false
    var phoneEdge = false
    var confirmEdge = false
    var cancelEdge = false
    var menuUp = false
    var menuDown = false
    var recenter = false

    static let zero = InputFrame()
}
