import SceneKit
import UIKit

/// A few blocks: lot, Lace Burger, Lace House, a graffiti hood, a plaza, and downtown towers.
final class CityWorld {
    let root = SCNNode()
    var boxes: [AABB] = []
    var mapZones: [MapRect] = []
    var mapRoads: [MapRect] = []
    let mapMin = Vec3(-70, 0, -70)
    let mapMax = Vec3(70, 0, 70)

    let sun = SCNLight()
    let ambient = SCNLight()
    let windowMaterial: SCNMaterial
    let ewLamp: SCNMaterial
    let nsLamp: SCNMaterial
    var lampMaterials: [SCNMaterial] = []

    var foodZone = AABB(minX: 0, maxX: 0, minZ: 0, maxZ: 0)
    var foodInterior = AABB(minX: 0, maxX: 0, minZ: 0, maxZ: 0)
    var homeZone = AABB(minX: 0, maxX: 0, minZ: 0, maxZ: 0)
    var homeInterior = AABB(minX: 0, maxX: 0, minZ: 0, maxZ: 0)
    var foodRoof = SCNNode()
    var homeRoof = SCNNode()
    var houseBeacon = SCNNode()

    var spawn = Vec3(-40, 0, -36)
    var sportsPark = Vec3(-31, 0, -34)
    var sportsYaw: Float = 0.45
    var sedanPark = Vec3(42, 0, -4)
    var sedanYaw: Float = -1.1
    var beaterPark = Vec3(-30, 0, -15)
    var beaterYaw: Float = 1.15
    var drivewayPark = Vec3(37, 0, -40)
    var drivewayYaw: Float = 0
    var pickupSpots: [Vec3] = []

    private let concrete = Art.material(color: Palette.concrete)
    private let asphalt = Art.material(color: Palette.asphalt, doubleSided: true)
    private let walkMat = Art.material(color: Palette.sidewalk, doubleSided: true)
    private let curb = Art.material(color: UIColor(white: 0.75, alpha: 1), lit: false)
    private let yellow = Art.material(color: UIColor(red: 0.95, green: 0.82, blue: 0.2, alpha: 1), lit: false)

    init() {
        windowMaterial = Art.textured(Art.windows, emission: Art.windows, intensity: 0.9)
        ewLamp = Art.material(color: .red, emission: .red, emissionIntensity: 1, lit: false)
        nsLamp = Art.material(color: .green, emission: .green, emissionIntensity: 1, lit: false)
        construct()
    }

    func updateSignals(time: Float) {
        let ewGreen = Signals.isGreen(.ew, time: time)
        let nsGreen = Signals.isGreen(.ns, time: time)
        ewLamp.diffuse.contents = ewGreen ? UIColor.green : UIColor.red
        ewLamp.emission.contents = ewGreen ? UIColor.green : UIColor.red
        nsLamp.diffuse.contents = nsGreen ? UIColor.green : UIColor.red
        nsLamp.emission.contents = nsGreen ? UIColor.green : UIColor.red
    }

    func updateAtmosphere(clock: Float, scene: SCNScene) {
        let night = Palette.nightAmount(at: clock)
        let sky = Palette.sky(at: clock)
        scene.background.contents = sky
        scene.fogColor = sky
        scene.fogStartDistance = 36
        scene.fogEndDistance = 125
        scene.fogDensityExponent = 1.1
        windowMaterial.emission.intensity = 0.08 + CGFloat(night) * 1.0
        for lamp in lampMaterials {
            lamp.emission.intensity = CGFloat(0.05 + night * 1.1)
        }
        sun.intensity = CGFloat(90 + (1 - night) * 1050)
        ambient.intensity = CGFloat(170 + (1 - night) * 300)
        ambient.color = night > 0.45 ? Palette.rgb(0.42, 0.28, 0.62) : UIColor(white: 0.92, alpha: 1)
        let elevation = sin((clock - floor(clock) - 0.25) * 2 * Float.pi)
        if let sunNode = sunNode {
            sunNode.eulerAngles = SCNVector3(-0.4 - elevation, clock * 0.7, 0)
        }
    }

    private var sunNode: SCNNode?

    private func construct() {
        addGroundPad()
        addRoads()
        addBoundary()
        addSkyline()
        for row in 0..<3 {
            for column in 0..<3 {
                placeBlock(column, row)
            }
        }
        addSignalsAndLamps()
        addLights()
        pickupSpots = [
            Vec3(-36, 0, -46),
            Vec3(0, 0, -46),
            Vec3(44, 0, -46),
            Vec3(-46, 0, -12),
            Vec3(0, 0, -10.4),
            Vec3(46, 0, 2)
        ]
    }

    private func addGroundPad() {
        addPlane(minX: -120, maxX: 120, minZ: -120, maxZ: 120, y: 0, color: UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1))
    }

    private func addRoads() {
        let x0 = City.x(0) - City.roadHalf
        let x1 = City.x(City.intersections - 1) + City.roadHalf
        let z0 = City.z(0) - City.roadHalf
        let z1 = City.z(City.intersections - 1) + City.roadHalf
        for index in 0..<City.intersections {
            let z = City.z(index)
            addPlane(minX: x0, maxX: x1, minZ: z - City.roadHalf, maxZ: z + City.roadHalf, y: 0.025, color: Palette.asphalt)
            mapRoads.append(MapRect(minX: x0, maxX: x1, minZ: z - City.roadHalf, maxZ: z + City.roadHalf, color: Palette.asphalt))
            addMarkings(horizontal: true, fixed: z, from: x0 + 1, to: x1 - 1)
            let x = City.x(index)
            addPlane(minX: x - City.roadHalf, maxX: x + City.roadHalf, minZ: z0, maxZ: z1, y: 0.025, color: Palette.asphalt)
            mapRoads.append(MapRect(minX: x - City.roadHalf, maxX: x + City.roadHalf, minZ: z0, maxZ: z1, color: Palette.asphalt))
            addMarkings(horizontal: false, fixed: x, from: z0 + 1, to: z1 - 1)
        }
    }

    private func addMarkings(horizontal: Bool, fixed: Float, from: Float, to: Float) {
        let length = to - from
        if horizontal {
            addStripe(width: length, depth: 0.1, x: (from + to) * 0.5, z: fixed + City.roadHalf * 0.9, material: curb)
            addStripe(width: length, depth: 0.1, x: (from + to) * 0.5, z: fixed - City.roadHalf * 0.9, material: curb)
            var cursor = from
            while cursor < to {
                addStripe(width: 1.5, depth: 0.12, x: cursor, z: fixed, material: yellow)
                cursor += 5
            }
        } else {
            addStripe(width: 0.1, depth: length, x: fixed + City.roadHalf * 0.9, z: (from + to) * 0.5, material: curb)
            addStripe(width: 0.1, depth: length, x: fixed - City.roadHalf * 0.9, z: (from + to) * 0.5, material: curb)
            var cursor = from
            while cursor < to {
                addStripe(width: 0.12, depth: 1.5, x: fixed, z: cursor, material: yellow)
                cursor += 5
            }
        }
    }

    private func addBoundary() {
        let limit: Float = 64
        let wall = Art.material(color: UIColor(white: 0.18, alpha: 1))
        addSolid(minX: -limit - 2, maxX: limit + 2, minZ: -limit - 2, maxZ: -limit, height: 1.3, material: wall)
        addSolid(minX: -limit - 2, maxX: limit + 2, minZ: limit, maxZ: limit + 2, height: 1.3, material: wall)
        addSolid(minX: -limit - 2, maxX: -limit, minZ: -limit, maxZ: limit, height: 1.3, material: wall)
        addSolid(minX: limit, maxX: limit + 2, minZ: -limit, maxZ: limit, height: 1.3, material: wall)
    }

    private func addSkyline() {
        let spots: [(Float, Float, Float)] = [
            (-90, -40, 22), (-70, 20, 30), (-40, 80, 26), (0, 86, 34),
            (40, 82, 24), (78, 30, 28), (88, -20, 18), (70, -80, 20),
            (-20, -86, 16), (20, -84, 22)
        ]
        for spot in spots {
            addVisualBox(minX: spot.0, maxX: spot.0 + 8, minZ: spot.1, maxZ: spot.1 + 8, minY: 0, maxY: spot.2, material: windowMaterial)
        }
    }

    private func placeBlock(_ c: Int, _ r: Int) {
        let cell = City.cell(c, r)
        let tint: UIColor
        switch (c, r) {
        case (0, 0): tint = UIColor(white: 0.16, alpha: 1)
        case (1, 0): tint = UIColor(red: 0.28, green: 0.1, blue: 0.18, alpha: 1)
        case (2, 0): tint = UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1)
        case (0, 1), (0, 2): tint = UIColor(red: 0.18, green: 0.08, blue: 0.16, alpha: 1)
        default: tint = Palette.sidewalk
        }
        addPlane(minX: cell.minX, maxX: cell.maxX, minZ: cell.minZ, maxZ: cell.maxZ, y: 0.03, color: tint)
        mapZones.append(MapRect(minX: cell.minX, maxX: cell.maxX, minZ: cell.minZ, maxZ: cell.maxZ, color: tint))
        switch (c, r) {
        case (0, 0): buildLot(cell)
        case (1, 0): buildFood(cell)
        case (2, 0): buildHome(cell)
        case (0, 1): buildHoodSouth(cell)
        case (0, 2): buildHoodNorth(cell)
        case (1, 1): buildPlaza(cell)
        default: buildDowntown(cell, column: c, row: r)
        }
    }

    private func buildLot(_ cell: AABB) {
        addSolid(minX: cell.minX + 0.4, maxX: cell.minX + 2.2, minZ: cell.center.z - 6, maxZ: cell.center.z + 4, height: 2.4, material: Art.textured(Art.graffiti, emission: Art.graffiti, intensity: 0.25))
        placeSign("IMPOUND", at: Vec3(cell.center.x, 0, cell.minZ + 2.2), y: 2.2, width: 3.2, facingSouth: false)
        spawn = Vec3(cell.center.x - 4, 0, cell.center.z)
        sportsPark = Vec3(cell.center.x + 5, 0, cell.center.z + 1)
    }

    private func buildFood(_ cell: AABB) {
        let minX = cell.center.x - 8
        let maxX = cell.center.x + 8
        let minZ: Float = -36
        let maxZ: Float = -26.5
        let wall = Art.material(color: UIColor(red: 0.16, green: 0.05, blue: 0.1, alpha: 1), emission: Palette.pink, emissionIntensity: 0.08)
        let shell = makeShell(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, doorWidth: 2.5, height: 4.6, wall: wall, withCounter: true)
        foodInterior = shell.interior
        foodRoof = shell.roof
        foodZone = shell.zone
        placeSign("LACE BURGER", at: Vec3(cell.center.x, 0, minZ - 0.2), y: 5.3, width: 6.5, facingSouth: true)
        placeSign("LACE BURGER", at: Vec3(cell.center.x, 0, maxZ + 0.2), y: 5.3, width: 6.5, facingSouth: false)
        addOmni(at: Vec3(cell.center.x, 2.4, -31), color: UIColor(red: 1, green: 0.62, blue: 0.45, alpha: 1), intensity: 260, range: 12)
    }

    private func buildHome(_ cell: AABB) {
        let minX: Float = 28
        let maxX: Float = 46
        let minZ: Float = -33
        let maxZ: Float = -26
        let wall = Art.material(color: UIColor(red: 0.1, green: 0.1, blue: 0.16, alpha: 1), emission: Palette.blue, emissionIntensity: 0.06)
        let shell = makeShell(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, doorWidth: 2.4, height: 4.2, wall: wall, withCounter: false)
        homeInterior = shell.interior
        homeRoof = shell.roof
        homeZone = AABB(minX: 34.2, maxX: 39.8, minZ: -35.6, maxZ: -32.6, minY: 0, maxY: 3)
        addPlane(minX: 33.2, maxX: 40.8, minZ: -48, maxZ: -33, y: 0.04, color: UIColor(white: 0.42, alpha: 1))
        drivewayPark = Vec3(37, 0, -40)
        let bed = Art.material(color: UIColor(red: 0.25, green: 0.08, blue: 0.16, alpha: 1))
        addSolid(minX: 40, maxX: 44.5, minZ: -30.2, maxZ: -27.2, height: 0.55, material: bed)
        placeSign("LACE HOUSE  $750", at: Vec3(37, 0, -35.8), y: 2.4, width: 4.4, facingSouth: true)
        houseBeacon = beacon(at: Vec3(37, 0, -29.5))
        addOmni(at: Vec3(37, 2.2, -30), color: Palette.blue, intensity: 180, range: 10)
    }

    private func buildHoodSouth(_ cell: AABB) {
        let graffiti = Art.textured(Art.graffiti, emission: Art.graffiti, intensity: 0.35)
        let brick = Art.textured(Art.brick, emission: Art.brick, intensity: 0.05)
        addSolid(minX: -44, maxX: -34, minZ: -20, maxZ: -8, height: 5.2, material: graffiti)
        addSolid(minX: -32, maxX: -27, minZ: -6.5, maxZ: -2.2, height: 3.6, material: brick)
        addSolid(minX: -42.2, maxX: -40.4, minZ: -7.2, maxZ: -5.4, height: 1.1, material: Art.material(color: UIColor(white: 0.18, alpha: 1)))
        placeSign("REBEL FM", at: Vec3(-39, 0, -8.2), y: 3.4, width: 3.4, facingSouth: true)
        beaterPark = Vec3(-30, 0, -15)
    }

    private func buildHoodNorth(_ cell: AABB) {
        let graffiti = Art.textured(Art.graffiti, emission: Art.graffiti, intensity: 0.35)
        let brick = Art.textured(Art.brick, emission: Art.brick, intensity: 0.05)
        addSolid(minX: -44, maxX: -33, minZ: 4, maxZ: 14, height: 6, material: graffiti)
        addSolid(minX: -31, maxX: -26.5, minZ: 16, maxZ: 21, height: 4, material: brick)
        placeSign("HOOD", at: Vec3(-38, 0, 4.2), y: 3.2, width: 3, facingSouth: true)
    }

    private func buildPlaza(_ cell: AABB) {
        addSolid(minX: -8.8, maxX: -3.6, minZ: -8.8, maxZ: -3.6, height: 16, material: windowMaterial)
        addSolid(minX: 3.6, maxX: 8.8, minZ: -8.8, maxZ: -3.6, height: 12, material: windowMaterial)
        addSolid(minX: -8.8, maxX: -3.6, minZ: 3.6, maxZ: 8.8, height: 18, material: windowMaterial)
        addSolid(minX: 3.6, maxX: 8.8, minZ: 3.6, maxZ: 8.8, height: 14, material: windowMaterial)
        let water = Art.material(color: Palette.blue, emission: Palette.blue, emissionIntensity: 0.6, lit: false)
        addVisualBox(minX: -1.4, maxX: 1.4, minZ: -1.4, maxZ: 1.4, minY: 0.2, maxY: 0.55, material: water)
        placeSign("ANI CITY", at: Vec3(0, 0, -2.2), y: 2.8, width: 5, facingSouth: true)
        placeSign("ANI CITY", at: Vec3(0, 0, 2.2), y: 2.8, width: 5, facingSouth: false)
    }

    private func buildDowntown(_ cell: AABB, column: Int, row: Int) {
        if column == 2 && row == 1 {
            addSolid(minX: 28, maxX: 34.5, minZ: -8, maxZ: -2, height: 12, material: windowMaterial)
            addSolid(minX: 28, maxX: 36, minZ: 2, maxZ: 9, height: 16, material: windowMaterial)
            sedanPark = Vec3(42, 0, -4)
            return
        }
        if column == 1 && row == 2 {
            addSolid(minX: -8, maxX: -2, minZ: 16, maxZ: 22, height: 20, material: windowMaterial)
            addSolid(minX: 2, maxX: 8, minZ: 24, maxZ: 32, height: 15, material: windowMaterial)
            return
        }
        addSolid(minX: 28, maxX: 35, minZ: 16, maxZ: 23, height: 18, material: windowMaterial)
        addSolid(minX: 38, maxX: 44, minZ: 25, maxZ: 32, height: 11, material: windowMaterial)
    }

    private struct Shell {
        var interior: AABB
        var roof: SCNNode
        var zone: AABB
    }

    private func makeShell(minX: Float, maxX: Float, minZ: Float, maxZ: Float, doorWidth: Float, height: Float, wall: SCNMaterial, withCounter: Bool) -> Shell {
        let t: Float = 0.45
        let midX = (minX + maxX) * 0.5
        let doorHalf = doorWidth * 0.5
        addSolid(minX: minX, maxX: maxX, minZ: maxZ - t, maxZ: maxZ, height: height, material: wall)
        addSolid(minX: minX, maxX: minX + t, minZ: minZ, maxZ: maxZ, height: height, material: wall)
        addSolid(minX: maxX - t, maxX: maxX, minZ: minZ, maxZ: maxZ, height: height, material: wall)
        addSolid(minX: minX, maxX: midX - doorHalf, minZ: minZ, maxZ: minZ + t, height: height, material: wall)
        addSolid(minX: midX + doorHalf, maxX: maxX, minZ: minZ, maxZ: minZ + t, height: height, material: wall)
        addVisualBox(minX: midX - doorHalf, maxX: midX + doorHalf, minZ: minZ, maxZ: minZ + t, minY: 2.35, maxY: height, material: wall)
        let roof = addVisualBox(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, minY: height - 0.2, maxY: height + 0.05, material: Art.material(color: UIColor(white: 0.08, alpha: 1)))
        var zone = AABB(minX: midX - 1.5, maxX: midX + 1.5, minZ: minZ + 1.2, maxZ: minZ + 3.2, maxY: 2)
        if withCounter {
            let counterNear = maxZ - t - 2.3
            let counterFar = maxZ - t - 0.35
            let counterMat = Art.material(color: UIColor(white: 0.75, alpha: 1), emission: Palette.pink, emissionIntensity: 0.15)
            addSolid(minX: midX - 2.4, maxX: midX + 2.4, minZ: counterNear, maxZ: counterFar, height: 1.05, material: counterMat)
            zone = AABB(minX: midX - 1.7, maxX: midX + 1.7, minZ: counterNear - 1.7, maxZ: counterNear - 0.15, maxY: 2)
        }
        let interior = AABB(minX: minX + t, maxX: maxX - t, minZ: minZ + t, maxZ: maxZ - t, minY: 0, maxY: height)
        return Shell(interior: interior, roof: roof, zone: zone)
    }

    private func addSignalsAndLamps() {
        for column in 0..<City.intersections {
            for row in 0..<City.intersections {
                let cx = City.x(column)
                let cz = City.z(row)
                addPole(x: cx + City.roadHalf + 0.5, z: cz + City.roadHalf + 0.5)
                if (column + row) % 2 == 0 {
                    addStreetLamp(x: cx - City.roadHalf - 0.8, z: cz + City.roadHalf + 0.8)
                }
            }
        }
    }

    private func addPole(x: Float, z: Float) {
        let poleMat = Art.material(color: UIColor(white: 0.2, alpha: 1))
        let pole = SCNCylinder(radius: 0.07, height: 4.4)
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(x, 2.2, z)
        root.addChildNode(poleNode)
        let arm = SCNBox(width: 1.4, height: 0.08, length: 0.08, chamferRadius: 0.02)
        arm.materials = [poleMat]
        let armNode = SCNNode(geometry: arm)
        armNode.position = SCNVector3(-0.6, 1.9, -0.2)
        poleNode.addChildNode(armNode)
        let ew = SCNBox(width: 0.28, height: 0.28, length: 0.28, chamferRadius: 0.04)
        ew.materials = [ewLamp]
        let ewNode = SCNNode(geometry: ew)
        ewNode.position = SCNVector3(-0.9, 1.7, -0.2)
        poleNode.addChildNode(ewNode)
        let ns = SCNBox(width: 0.28, height: 0.28, length: 0.28, chamferRadius: 0.04)
        ns.materials = [nsLamp]
        let nsNode = SCNNode(geometry: ns)
        nsNode.position = SCNVector3(-0.5, 1.7, -0.2)
        poleNode.addChildNode(nsNode)
    }

    private func addStreetLamp(x: Float, z: Float) {
        let poleMat = Art.material(color: UIColor(white: 0.25, alpha: 1))
        let pole = SCNCylinder(radius: 0.06, height: 4.8)
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(x, 2.4, z)
        root.addChildNode(poleNode)
        let bulbMat = Art.material(color: UIColor(red: 1, green: 0.86, blue: 0.45, alpha: 1), emission: UIColor(red: 1, green: 0.86, blue: 0.45, alpha: 1), emissionIntensity: 0.2, lit: false)
        lampMaterials.append(bulbMat)
        let bulb = SCNSphere(radius: 0.18)
        bulb.materials = [bulbMat]
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0, 2.45, 0)
        poleNode.addChildNode(bulbNode)
    }

    private func addLights() {
        sun.type = .directional
        sun.intensity = 700
        sun.castsShadow = false
        sun.color = UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1)
        let sunHolder = SCNNode()
        sunHolder.light = sun
        sunHolder.eulerAngles = SCNVector3(-0.9, 0.4, 0)
        root.addChildNode(sunHolder)
        sunNode = sunHolder

        ambient.type = .ambient
        ambient.intensity = 220
        ambient.color = Palette.rgb(0.42, 0.28, 0.62)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)
    }

    private func addOmni(at position: Vec3, color: UIColor, intensity: CGFloat, range: CGFloat) {
        let light = SCNLight()
        light.type = .omni
        light.color = color
        light.intensity = intensity
        light.attenuationEndDistance = range
        let node = SCNNode()
        node.light = light
        node.position = position.scn
        root.addChildNode(node)
    }

    private func beacon(at position: Vec3) -> SCNNode {
        let beam = SCNCylinder(radius: 0.1, height: 16)
        let mat = Art.material(color: Palette.pink, emission: Palette.pink, emissionIntensity: 0.8, lit: false)
        mat.transparency = 0.55
        beam.materials = [mat]
        let node = SCNNode(geometry: beam)
        node.position = SCNVector3(position.x, 8, position.z)
        root.addChildNode(node)
        return node
    }

    private func placeSign(_ text: String, at position: Vec3, y: Float, width: CGFloat, facingSouth: Bool) {
        let sign = Art.sign(text, width: width, height: width * 0.28, background: UIColor(white: 0.02, alpha: 1), foreground: Palette.pink)
        sign.position = SCNVector3(position.x, y, position.z)
        sign.eulerAngles.y = facingSouth ? Float.pi : 0
        root.addChildNode(sign)
    }

    @discardableResult
    private func addSolid(minX: Float, maxX: Float, minZ: Float, maxZ: Float, height: Float, material: SCNMaterial, minY: Float = 0) -> SCNNode {
        let node = addVisualBox(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, minY: minY, maxY: height, material: material)
        if minY < 1.2 {
            boxes.append(AABB(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, minY: 0, maxY: height))
        }
        return node
    }

    @discardableResult
    private func addVisualBox(minX: Float, maxX: Float, minZ: Float, maxZ: Float, minY: Float, maxY: Float, material: SCNMaterial) -> SCNNode {
        let width = max(0.05, maxX - minX)
        let depth = max(0.05, maxZ - minZ)
        let height = max(0.05, maxY - minY)
        let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0.03)
        box.materials = [material]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3((minX + maxX) * 0.5, minY + height * 0.5, (minZ + maxZ) * 0.5)
        root.addChildNode(node)
        return node
    }

    private func addPlane(minX: Float, maxX: Float, minZ: Float, maxZ: Float, y: Float, color: UIColor) {
        let plane = SCNPlane(width: CGFloat(maxX - minX), height: CGFloat(maxZ - minZ))
        let material = Art.material(color: color, doubleSided: true)
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -Float.pi / 2
        node.position = SCNVector3((minX + maxX) * 0.5, y, (minZ + maxZ) * 0.5)
        root.addChildNode(node)
    }

    private func addStripe(width: Float, depth: Float, x: Float, z: Float, material: SCNMaterial) {
        let box = SCNBox(width: CGFloat(width), height: 0.02, length: CGFloat(depth), chamferRadius: 0)
        box.materials = [material]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(x, 0.05, z)
        root.addChildNode(node)
    }
}
