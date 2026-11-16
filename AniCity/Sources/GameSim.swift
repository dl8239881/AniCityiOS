import SceneKit
import UIKit

/// Vertical slice loop: roam, drive, traffic, police, food, and one house.
///
/// Extension points live behind the systems already split out of this type:
/// `CityWorld` for districts, `VehicleFactory` for new cars, `TrafficSystem` for
/// road rules, `PoliceSystem` for response, and `SaveSlot` for persisted fields.
final class GameSim {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let world: CityWorld
    let avatar = AniAvatar()

    private(set) var time: Float = 0
    private(set) var clock: Float = 0.8
    private(set) var health: Float = 100
    private(set) var money: Int = Economy.startingCash
    private(set) var stars = 0
    private(set) var ownsHome = false
    private(set) var banner = ""
    private(set) var prompt = ""
    private(set) var overlay = GameOverlay.none
    private(set) var menuIndex = 0
    private(set) var mapSnapshot: MapDraw
    private(set) var playerPosition = Vec3.zero
    private(set) var playerYaw: Float = 0

    var onImpact: ((Float) -> Void)?
    var onHorn: (() -> Void)?

    private var heat: Float = 0
    private var unseen: Float = 0
    private var bustMeter: Float = 0
    private var mercy: Float = 0
    private var stun: Float = 0
    private var hornTimer: Float = 0
    private var bannerTTL: Float = 0
    private var autosave: Float = 0
    private var footSpeed: Float = 0
    private var cameraYaw: Float = 0
    private var cameraPitch: Float = 0.42
    private var cameraPosition = Vec3.zero
    private var playerCar: CarEntity?
    private var personalCar: CarEntity?
    private var loose: [CarEntity] = []
    private var pickups: [CashPickup] = []
    private let traffic: TrafficSystem
    private let pedestrians: PedestrianSystem
    private let police: PoliceSystem

    private let foodItems = [
        FoodItem(name: "Lace Burger", price: 12, heal: 30),
        FoodItem(name: "Neon Shake", price: 8, heal: 16),
        FoodItem(name: "Mayhem Meal", price: 22, heal: 64)
    ]

    init() {
        world = CityWorld()
        scene.rootNode.addChildNode(world.root)
        scene.rootNode.addChildNode(avatar.root)
        traffic = TrafficSystem(parent: world.root)
        pedestrians = PedestrianSystem(parent: world.root)
        police = PoliceSystem(parent: world.root)
        mapSnapshot = MapDraw(minX: -70, maxX: 70, minZ: -70, maxZ: 70, zones: [], roads: [], blips: [], player: .zero, playerYaw: 0)

        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.08
        camera.zFar = 320
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        addParkedCars()
        addPickups()
        playerPosition = world.spawn
        playerYaw = Vec3.yaw(toward: world.sportsPark - world.spawn)
        cameraYaw = playerYaw
        load()
        snapCamera()
        world.updateAtmosphere(clock: clock, scene: scene)
        world.updateSignals(time: 0)
        setBanner("Take the black car. ACT enters. Lose the cops. Buy Lace House.")
        bannerTTL = 7
        rebuildMap()
    }

    var isDriving: Bool { playerCar != nil }
    var menuVisible: Bool { overlay != .none }
    var moveSpeed: Float { playerCar?.planarSpeed ?? footSpeed }

    var objective: String {
        if stars > 0 { return "Lose the cops" }
        if health < 45 { return "Lace Burger — you're hurt" }
        if !ownsHome { return "Lace House  $\(Economy.housePrice)" }
        return "Lace House is yours"
    }

    var speedText: String {
        guard let car = playerCar else { return "" }
        return "\(Int(car.planarSpeed * 3.6)) km/h"
    }

    var menuTitle: String {
        switch overlay {
        case .none: return ""
        case .phone: return "ANI PHONE"
        case .food: return "LACE BURGER"
        case .home: return "LACE HOUSE"
        }
    }

    var menuLines: [String] {
        switch overlay {
        case .none:
            return []
        case .phone:
            return ["Save game", "Close"]
        case .food:
            return foodItems.map { "\($0.name)    $\($0.price)    +\(Int($0.heal)) HP" } + ["Close"]
        case .home:
            return ["Buy Lace House — $\(Economy.housePrice)", "Not now"]
        }
    }

    var menuFooter: String {
        switch overlay {
        case .phone:
            return "\(objective)   ·   $\(money)\nDualSense / MFi: left stick move, right stick look, R2 gas, L2 brake, Cross action, Triangle phone, Square handbrake, R1 horn.\nTouch: joystick, RUN/GAS, BRK, HB, ACT, MAP."
        case .food:
            return "Cash $\(money). Eating patches you up."
        case .home:
            return ownsHome ? "You already own it." : "Driveway included. Cops don't follow you inside for long."
        case .none:
            return ""
        }
    }

    var menuShowsMap: Bool { overlay == .phone }
    var wantsSiren: Bool { stars > 0 && !police.cars.isEmpty }
    var sirenDistance: Float { police.nearestDistance(to: playerPosition) }

    func chooseMenu(_ index: Int) {
        guard overlay != .none, !menuLines.isEmpty else { return }
        menuIndex = clamp(index, 0, menuLines.count - 1)
        confirmMenu()
    }

    func save() {
        let slot = SaveSlot(
            version: 1,
            money: money,
            health: max(1, health),
            ownsHome: ownsHome,
            x: playerPosition.x,
            z: playerPosition.z,
            yaw: playerYaw
        )
        SaveStore.write(slot)
    }

    func update(dt raw: Float, input: InputFrame) {
        let dt = min(0.033, max(0, raw))
        time += dt
        clock += dt / 150
        if clock >= 1 { clock -= 1 }
        bannerTTL -= dt
        if bannerTTL <= 0 { banner = "" }
        mercy = max(0, mercy - dt)
        stun = max(0, stun - dt)
        hornTimer = max(0, hornTimer - dt)
        autosave += dt

        for car in everyCar() {
            car.hitCooldown = max(0, car.hitCooldown - dt)
        }

        if overlay != .none && stun <= 0 {
            handleMenu(input)
        } else if stun <= 0 && overlay == .none {
            handleWorldActions(input)
        }

        var worldInput = input
        if overlay != .none || stun > 0 {
            worldInput = .zero
        }
        if worldInput.hornEdge {
            hornTimer = 1.3
            onHorn?()
        }
        if worldInput.recenter {
            cameraYaw = playerCar?.yaw ?? playerYaw
        }

        let night = Palette.nightAmount(at: clock)
        if let car = playerCar {
            let pedal = worldInput.throttle
            let stick = worldInput.moveY
            let throttle = abs(pedal) >= abs(stick) ? pedal : stick
            VehicleDynamics.step(car, throttle: throttle, steer: worldInput.moveX, handbrake: worldInput.handbrake, dt: dt)
            collideBuildings(car, damagePlayer: true)
            playerPosition = car.position
            playerYaw = car.yaw
            if !car.driveable {
                exitCar()
                setBanner("The car gave out.")
            } else {
                car.syncVisuals(dt: dt, night: night, braking: throttle < -0.05 || worldInput.handbrake, time: time)
            }
        } else {
            walk(worldInput, dt: dt)
        }

        for car in loose where car !== playerCar {
            car.velocity *= max(0, 1 - 2.2 * dt)
            if car.planarSpeed > 0.15 {
                car.position += car.velocity * dt
                collideBuildings(car, damagePlayer: false)
            }
            car.syncVisuals(dt: dt, night: night, braking: false, time: time)
        }

        traffic.update(
            dt: dt,
            time: time,
            siren: wantsSiren,
            police: police.cars,
            playerPosition: playerPosition,
            playerOnFoot: playerCar == nil
        )
        pedestrians.update(
            dt: dt,
            time: time,
            cars: everyCar(),
            horn: hornTimer > 0,
            playerPosition: playerPosition,
            boxes: world.boxes
        )
        police.update(
            dt: dt,
            time: time,
            stars: stars,
            playerPosition: playerPosition,
            playerVelocity: playerCar?.velocity ?? .zero,
            boxes: world.boxes
        )
        for car in police.cars {
            collideBuildings(car, damagePlayer: false)
            car.syncVisuals(dt: dt, night: night, braking: false, time: time)
        }
        for wreck in police.takeRetired() {
            wreck.role = .abandoned
            loose.append(wreck)
            if wreck.killedByPlayer {
                addHeat(0.8)
                setBanner("Cruiser down.")
            }
        }

        collidePairs()
        retireTrafficWrecks()
        hitPedestrians()
        collectPickups(dt: dt)
        updateWanted(dt: dt)
        if health <= 0 && stun <= 0 {
            respawn(busted: false)
        }

        world.foodRoof.isHidden = world.foodInterior.containsXZ(playerPosition)
        world.homeRoof.isHidden = world.homeInterior.containsXZ(playerPosition)
        world.houseBeacon.isHidden = ownsHome
        world.updateSignals(time: time)
        world.updateAtmosphere(clock: clock, scene: scene)
        updateCamera(worldInput, dt: dt)
        avatar.root.isHidden = playerCar != nil
        avatar.root.position = playerPosition.scn
        avatar.setYaw(playerYaw)
        if playerCar == nil {
            avatar.update(time: time, speed: footSpeed)
        }
        refreshPrompt()
        rebuildMap()
        if autosave > 20 {
            autosave = 0
            save()
        }
    }

    private func handleWorldActions(_ input: InputFrame) {
        if input.phoneEdge {
            overlay = .phone
            menuIndex = 0
            return
        }
        guard input.actionEdge else { return }
        if playerCar != nil {
            exitCar()
            return
        }
        switch interact() {
        case .food:
            overlay = .food
            menuIndex = 0
        case .home:
            if ownsHome {
                health = 100
                save()
                setBanner("Home. Saved.")
            } else {
                overlay = .home
                menuIndex = 0
            }
        case .car(let car):
            enter(car)
        case .none:
            break
        }
    }

    private func handleMenu(_ input: InputFrame) {
        if input.cancelEdge || (input.phoneEdge && overlay == .phone) {
            overlay = .none
            return
        }
        if input.menuUp { menuIndex = max(0, menuIndex - 1) }
        if input.menuDown { menuIndex = min(max(0, menuLines.count - 1), menuIndex + 1) }
        if input.confirmEdge || input.actionEdge {
            confirmMenu()
        }
    }

    private func confirmMenu() {
        switch overlay {
        case .none:
            break
        case .phone:
            if menuIndex == 0 {
                save()
                setBanner("Saved.")
            }
            overlay = .none
        case .food:
            if menuIndex >= foodItems.count {
                overlay = .none
                return
            }
            let item = foodItems[menuIndex]
            guard money >= item.price else {
                setBanner("Need $\(item.price).")
                return
            }
            money -= item.price
            health = min(100, health + item.heal)
            setBanner("\(item.name). + \(Int(item.heal)) HP.")
            save()
        case .home:
            if menuIndex != 0 {
                overlay = .none
                return
            }
            guard money >= Economy.housePrice else {
                setBanner("Lace House is $\(Economy.housePrice).")
                return
            }
            money -= Economy.housePrice
            ownsHome = true
            ensurePersonalCar()
            overlay = .none
            setBanner("Lace House is yours. The sedan in the driveway is clean.")
            save()
        }
    }

    private func walk(_ input: InputFrame, dt: Float) {
        let look = Vec3.direction(yaw: cameraYaw)
        var wish = look * input.moveY + look.xzRight * input.moveX
        let magnitude = wish.xzLength
        if magnitude > 1 {
            wish = wish / magnitude
        }
        let pace: Float = input.sprint ? 7.4 : 4.6
        footSpeed = 0
        if magnitude > 0.08 {
            let direction = wish.xzNormalized()
            let step = min(magnitude, 1)
            playerPosition += direction * pace * step * dt
            footSpeed = pace * step
            playerYaw = approachAngle(playerYaw, Vec3.yaw(toward: direction), maxDelta: 10 * dt)
        }
        playerPosition.y = 0
        pushCircle(&playerPosition, radius: 0.38)
    }

    private func enter(_ car: CarEntity) {
        if !car.driveable {
            setBanner("That one's wrecked.")
            return
        }
        if car.role == .traffic {
            traffic.detach(car)
            car.role = .abandoned
            loose.append(car)
        } else if car.role == .parked {
            car.role = .abandoned
        }
        playerCar = car
        playerPosition = car.position
        if car.role != .personal && !car.walletTaken {
            car.walletTaken = true
            money += Economy.theftWallet
            addHeat(Heat.theft)
            setBanner("Grand theft. +$\(Economy.theftWallet).")
        }
    }

    private func exitCar() {
        guard let car = playerCar else { return }
        playerCar = nil
        playerPosition = clearSpot(around: car)
        playerYaw = car.yaw
        footSpeed = 0
        pushCircle(&playerPosition, radius: 0.38)
    }

    private func clearSpot(around car: CarEntity) -> Vec3 {
        let forward = Vec3.direction(yaw: car.yaw)
        let right = forward.xzRight
        let options = [
            car.position - right * 1.8,
            car.position + right * 1.8,
            car.position - forward * 2.6,
            car.position + forward * 2.6
        ]
        for option in options {
            var spot = option
            spot.y = 0
            var blocked = false
            for box in world.boxes where box.resolveCircle(x: spot.x, z: spot.z, radius: 0.4).hit {
                blocked = true
                break
            }
            if !blocked { return spot }
        }
        return car.position - right * 1.8
    }

    private enum Interact {
        case food
        case home
        case car(CarEntity)
        case none
    }

    private func interact() -> Interact {
        if world.foodZone.containsXZ(playerPosition, pad: 0.2) { return .food }
        if world.homeZone.containsXZ(playerPosition, pad: 0.35) { return .home }
        if let car = nearestJackable() { return .car(car) }
        return .none
    }

    private func nearestJackable() -> CarEntity? {
        var best: CarEntity?
        var bestDistance: Float = 2.7
        for car in everyCar() where car !== playerCar && car.role != .police && car.driveable {
            let parked = car.role == .parked || car.role == .personal || car.role == .abandoned
            let slow = parked || car.planarSpeed < 2.3
            let distance = (car.position - playerPosition).xzLength
            if slow && distance < bestDistance {
                best = car
                bestDistance = distance
            }
        }
        return best
    }

    private func collideBuildings(_ car: CarEntity, damagePlayer: Bool) {
        let radius = car.radius * 0.74
        for _ in 0..<2 {
            for box in world.boxes {
                let result = box.resolveCircle(x: car.position.x, z: car.position.z, radius: radius)
                guard result.hit else { continue }
                let into = max(0, -dot(car.velocity, result.normal))
                car.position.x = result.x
                car.position.z = result.z
                let intoVelocity = dot(car.velocity, result.normal)
                if intoVelocity < 0 {
                    car.velocity -= result.normal * intoVelocity
                }
                car.velocity *= 0.78
                if into > 3.4 && car.hitCooldown <= 0 {
                    car.hitCooldown = 0.45
                    car.applyDamage(into * 1.2, byPlayer: false)
                    if damagePlayer {
                        hurt(into * 0.48)
                        onImpact?(min(1, into / 14))
                        if into > 6.5 {
                            addHeat(into > 11 ? Heat.wreck : Heat.fender)
                        }
                    }
                }
            }
        }
    }

    private func collidePairs() {
        guard let driven = playerCar else {
            for car in everyCar() {
                let delta = playerPosition - car.position
                let distance = delta.xzLength
                let limit = car.radius * 0.7 + 0.45
                if distance < limit && distance > 0.001 {
                    playerPosition += delta.xzNormalized() * (limit - distance)
                }
            }
            pushCircle(&playerPosition, radius: 0.38)
            return
        }
        for other in everyCar() where other !== driven {
            let fixed = other.role == .traffic
            separate(driven, other, otherFixed: fixed)
        }
    }

    private func separate(_ attacker: CarEntity, _ other: CarEntity, otherFixed: Bool) {
        var delta = other.position - attacker.position
        var distance = delta.xzLength
        let limit = attacker.radius * 0.7 + other.radius * 0.7
        guard distance < limit else { return }
        if distance < 0.001 {
            delta = Vec3(1, 0, 0)
            distance = 1
        }
        let normal = delta / distance
        let overlap = limit - distance
        if otherFixed {
            attacker.position -= normal * overlap
        } else {
            attacker.position -= normal * overlap * 0.5
            other.position += normal * overlap * 0.5
        }
        let closing = dot(attacker.velocity - other.velocity, normal)
        if closing > 3 && attacker.hitCooldown <= 0 && other.hitCooldown <= 0 {
            attacker.hitCooldown = 0.5
            other.hitCooldown = 0.5
            let damage = closing * 1.05
            attacker.applyDamage(damage, byPlayer: true)
            other.applyDamage(damage, byPlayer: true)
            hurt(closing * 0.4)
            onImpact?(min(1, closing / 15))
            if closing > 6 {
                addHeat(closing > 12 ? Heat.wreck : Heat.fender)
            }
            if other.role == .traffic {
                other.slowTimer = 1.5
            }
        }
        let closingAttacker = dot(attacker.velocity, normal)
        if closingAttacker > 0 {
            attacker.velocity -= normal * closingAttacker
        }
        attacker.velocity *= 0.72
        if !otherFixed {
            let closingOther = dot(other.velocity, normal)
            if closingOther < 0 {
                other.velocity -= normal * closingOther
            }
            other.velocity *= 0.72
        }
    }

    private func retireTrafficWrecks() {
        let dead = traffic.cars.filter { $0.condition <= 0 }
        for car in dead {
            traffic.detach(car)
            car.role = .abandoned
            car.velocity = .zero
            loose.append(car)
        }
    }

    private func hitPedestrians() {
        guard let car = playerCar, car.planarSpeed > 3.4 else { return }
        for ped in pedestrians.people where !ped.down {
            let distance = (ped.position - car.position).xzLength
            if distance < car.radius * 0.55 + 0.55 {
                ped.down = true
                ped.downTimer = 11
                car.applyDamage(7, byPlayer: true)
                hurt(6)
                addHeat(Heat.pedestrian)
                onImpact?(0.55)
                setBanner("They went down.")
            }
        }
    }

    private func collectPickups(dt: Float) {
        for pickup in pickups {
            if pickup.alive {
                pickup.node.eulerAngles.y += dt * 1.8
                pickup.node.position.y = 0.55 + sin(time * 2.4 + pickup.position.x) * 0.08
                if (pickup.position - playerPosition).xzLength < 1.25 {
                    pickup.alive = false
                    pickup.timer = 70
                    pickup.node.isHidden = true
                    money += Economy.pickupValue
                    setBanner("+$\(Economy.pickupValue)")
                }
            } else {
                pickup.timer -= dt
                if pickup.timer <= 0 {
                    pickup.alive = true
                    pickup.node.isHidden = false
                }
            }
        }
    }

    private func updateWanted(dt: Float) {
        if stars > 0 && mercy <= 0 && stun <= 0 {
            if police.canSee(player: playerPosition, boxes: world.boxes) {
                unseen = 0
            } else {
                unseen += dt
                if unseen >= 8 {
                    unseen = 0
                    let before = stars
                    heat = max(0, heat - 1)
                    refreshStars()
                    if stars < before {
                        if stars == 0 {
                            money += Economy.escapeBonus + Economy.starCoolBonus
                            setBanner("Got away. +$\(Economy.escapeBonus + Economy.starCoolBonus)")
                        } else {
                            money += Economy.starCoolBonus
                            setBanner("One star cooler. +$\(Economy.starCoolBonus)")
                        }
                    }
                }
            }
            let speed = playerCar?.planarSpeed ?? footSpeed
            if police.nearestDistance(to: playerPosition) < 3.35 && speed < 2.4 {
                bustMeter += dt
                if bustMeter >= 1.15 {
                    respawn(busted: true)
                }
            } else {
                bustMeter = max(0, bustMeter - dt * 0.6)
            }
        } else {
            unseen = 0
            bustMeter = 0
        }
    }

    private func respawn(busted: Bool) {
        let lost = money - Int(Float(money) * Economy.bustKeep)
        money = max(0, money - lost)
        health = 60
        stars = 0
        heat = 0
        unseen = 0
        bustMeter = 0
        mercy = 4.5
        stun = 1.5
        overlay = .none
        if playerCar != nil { exitCar() }
        police.despawnAll()
        let base = ownsHome ? world.drivewayPark : world.spawn
        playerPosition = base + Vec3(2.2, 0, 1.4)
        pushCircle(&playerPosition, radius: 0.4)
        setBanner(busted ? "Busted. Lost $\(lost)." : "Wasted. Lost $\(lost).")
        save()
    }

    private func addHeat(_ amount: Float) {
        guard mercy <= 0, amount > 0 else { return }
        let before = stars
        heat = min(Float(Heat.maxStars), heat + amount)
        refreshStars()
        if stars > before {
            setBanner(stars == 1 ? "Wanted." : "Wanted — \(stars) stars.")
        }
    }

    private func refreshStars() {
        if heat <= 0.08 {
            heat = 0
            stars = 0
        } else {
            stars = min(Heat.maxStars, max(1, Int(ceil(heat))))
        }
    }

    private func hurt(_ amount: Float) {
        guard mercy <= 0 else { return }
        health = max(0, health - amount)
    }

    private func pushCircle(_ position: inout Vec3, radius: Float) {
        for _ in 0..<3 {
            for box in world.boxes {
                let result = box.resolveCircle(x: position.x, z: position.z, radius: radius)
                if result.hit {
                    position.x = result.x
                    position.z = result.z
                }
            }
        }
    }

    private func everyCar() -> [CarEntity] {
        loose + traffic.cars + police.cars
    }

    private func addParkedCars() {
        let sports = VehicleFactory.make(.sports, role: .parked, position: world.sportsPark, yaw: world.sportsYaw)
        let sedan = VehicleFactory.make(.sedan, role: .parked, position: world.sedanPark, yaw: world.sedanYaw, paint: UIColor(red: 0.2, green: 0.45, blue: 0.75, alpha: 1))
        let beater = VehicleFactory.make(.beater, role: .parked, position: world.beaterPark, yaw: world.beaterYaw)
        for car in [sports, sedan, beater] {
            world.root.addChildNode(car.root)
            loose.append(car)
            car.syncVisuals(dt: 0, night: 1, braking: false, time: 0)
        }
    }

    private func ensurePersonalCar() {
        guard personalCar == nil else { return }
        let car = VehicleFactory.make(
            .sedan,
            role: .personal,
            position: world.drivewayPark,
            yaw: world.drivewayYaw,
            paint: UIColor(red: 0.38, green: 0.05, blue: 0.16, alpha: 1)
        )
        car.walletTaken = true
        world.root.addChildNode(car.root)
        loose.append(car)
        personalCar = car
        car.syncVisuals(dt: 0, night: 1, braking: false, time: 0)
    }

    private func addPickups() {
        for spot in world.pickupSpots {
            let box = SCNBox(width: 0.38, height: 0.22, length: 0.5, chamferRadius: 0.04)
            let material = Art.material(color: UIColor(red: 0.2, green: 0.85, blue: 0.35, alpha: 1), emission: UIColor(red: 0.3, green: 1, blue: 0.45, alpha: 1), emissionIntensity: 0.8, lit: false)
            box.materials = [material]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(spot.x, 0.55, spot.z)
            world.root.addChildNode(node)
            pickups.append(CashPickup(position: spot, node: node))
        }
    }

    private func updateCamera(_ input: InputFrame, dt: Float) {
        cameraYaw += input.lookStickX * 1.7 * dt
        cameraYaw -= input.lookDragX * 0.012
        cameraPitch += input.lookStickY * 1.05 * dt
        cameraPitch -= input.lookDragY * 0.008
        cameraPitch = clamp(cameraPitch, 0.18, 0.95)
        if let car = playerCar, abs(input.lookStickX) < 0.12, abs(input.lookDragX) < 1 {
            cameraYaw = approachAngle(cameraYaw, car.yaw, maxDelta: 2.5 * dt)
        }
        let indoors = world.foodInterior.containsXZ(playerPosition) || world.homeInterior.containsXZ(playerPosition)
        let distance: Float = playerCar != nil ? 9.0 : (indoors ? 3.2 : 5.7)
        let look = Vec3.direction(yaw: cameraYaw)
        let focus = playerPosition
        let target = Vec3(focus.x, playerCar != nil ? 1.15 : 1.45, focus.z)
        let horizontal = cos(cameraPitch) * distance
        let vertical = sin(cameraPitch) * distance
        var desired = Vec3(target.x - look.x * horizontal, target.y + vertical, target.z - look.z * horizontal)
        let ray = desired - target
        let reach = ray.length
        if reach > 0.3 {
            let direction = ray / reach
            var allowed = reach
            for box in world.boxes {
                if let hit = rayHit(Vec3(target.x, target.y, target.z), direction, box, maxT: allowed), hit > 0.2 {
                    allowed = min(allowed, max(1.25, hit - 0.3))
                }
            }
            desired = target + direction * allowed
        }
        let blend = min(1, dt * 7)
        if cameraPosition == .zero {
            cameraPosition = desired
        } else {
            cameraPosition = cameraPosition + (desired - cameraPosition) * blend
        }
        cameraNode.position = cameraPosition.scn
        cameraNode.look(at: target.scn)
    }

    private func snapCamera() {
        cameraPosition = .zero
        updateCamera(.zero, dt: 1)
    }

    private func refreshPrompt() {
        if overlay != .none || stun > 0 {
            prompt = ""
            return
        }
        if playerCar != nil {
            prompt = "ACT  exit"
            return
        }
        switch interact() {
        case .food: prompt = "ACT  order"
        case .home: prompt = ownsHome ? "ACT  rest & save" : "ACT  buy Lace House"
        case .car(let car): prompt = car.role == .personal ? "ACT  your car" : "ACT  take car"
        case .none: prompt = ""
        }
    }

    private func rebuildMap() {
        var blips = [
            Blip(position: world.foodZone.center, color: Palette.pink, radius: 5),
            Blip(position: world.drivewayPark, color: Palette.blue, radius: 5)
        ]
        for pickup in pickups where pickup.alive {
            blips.append(Blip(position: pickup.position, color: UIColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 1), radius: 3.5))
        }
        for cop in police.cars {
            blips.append(Blip(position: cop.position, color: .red, radius: 4.5))
        }
        let focus = playerCar?.position ?? playerPosition
        let yaw = playerCar?.yaw ?? playerYaw
        mapSnapshot = MapDraw(
            minX: world.mapMin.x,
            maxX: world.mapMax.x,
            minZ: world.mapMin.z,
            maxZ: world.mapMax.z,
            zones: world.mapZones,
            roads: world.mapRoads,
            blips: blips,
            player: focus,
            playerYaw: yaw
        )
    }

    private func load() {
        guard let slot = SaveStore.read(), slot.version == 1 else { return }
        money = max(0, slot.money)
        health = clamp(slot.health, 1, 100)
        ownsHome = slot.ownsHome
        playerPosition = Vec3(slot.x, 0, slot.z)
        playerYaw = slot.yaw
        cameraYaw = slot.yaw
        pushCircle(&playerPosition, radius: 0.4)
        if ownsHome { ensurePersonalCar() }
    }

    private func setBanner(_ text: String) {
        banner = text
        bannerTTL = 3.5
    }
}

enum GameOverlay {
    case none
    case phone
    case food
    case home
}

struct FoodItem {
    var name: String
    var price: Int
    var heal: Float
}

struct SaveSlot: Codable {
    var version: Int
    var money: Int
    var health: Float
    var ownsHome: Bool
    var x: Float
    var z: Float
    var yaw: Float
}

enum SaveStore {
    static func write(_ slot: SaveSlot) {
        do {
            let data = try JSONEncoder().encode(slot)
            try data.write(to: url(), options: .atomic)
        } catch {
            return
        }
    }

    static func read() -> SaveSlot? {
        guard let data = try? Data(contentsOf: url()) else { return nil }
        return try? JSONDecoder().decode(SaveSlot.self, from: data)
    }

    private static func url() -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("anicity-slot1.json")
    }
}

final class CashPickup {
    var position: Vec3
    var node: SCNNode
    var alive = true
    var timer: Float = 0

    init(position: Vec3, node: SCNNode) {
        self.position = position
        self.node = node
    }
}
