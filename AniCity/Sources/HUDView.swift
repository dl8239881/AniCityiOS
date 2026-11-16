import UIKit

struct TouchSample {
    var moveX: Float = 0
    var moveY: Float = 0
    var lookX: Float = 0
    var lookY: Float = 0
    var gas = false
    var brake = false
    var handbrake = false
    var action = false
    var phone = false
    var horn = false
}

final class HUDView: UIView {
    var onChoose: ((Int) -> Void)?

    private let lookPad = LookPad()
    private let joystick = JoystickView()
    private let gas = GameButton(title: "RUN", color: Palette.pink)
    private let brake = GameButton(title: "BRK", color: UIColor(white: 0.2, alpha: 0.75))
    private let handbrake = GameButton(title: "HB", color: UIColor(white: 0.2, alpha: 0.75))
    private let action = GameButton(title: "ACT", color: Palette.blue)
    private let phone = GameButton(title: "MAP", color: UIColor(red: 0.45, green: 0.15, blue: 0.7, alpha: 0.9))
    private let horn = GameButton(title: "HOR", color: UIColor(white: 0.2, alpha: 0.75))
    private let healthBack = UIView()
    private let healthFill = UIView()
    private let nameLabel = HUDView.makeLabel(size: 13, color: .white)
    private let starLabel = HUDView.makeLabel(size: 20, color: .white)
    private let moneyLabel = HUDView.makeLabel(size: 18, color: Palette.pink)
    private let bannerLabel = HUDView.makeLabel(size: 15, color: .white)
    private let promptLabel = HUDView.makeLabel(size: 14, color: .white)
    private let speedLabel = HUDView.makeLabel(size: 16, color: .white)
    private let objectiveLabel = HUDView.makeLabel(size: 12, color: UIColor(white: 0.85, alpha: 1))
    private let minimap = MinimapView()
    private let dimmer = UIView()
    private let menu = MenuPanel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        lookPad.backgroundColor = .clear
        healthBack.backgroundColor = UIColor(white: 0, alpha: 0.45)
        healthBack.layer.cornerRadius = 4
        healthFill.backgroundColor = Palette.pink
        healthFill.layer.cornerRadius = 4
        healthBack.addSubview(healthFill)
        dimmer.backgroundColor = UIColor(white: 0, alpha: 0.45)
        dimmer.isHidden = true
        minimap.isUserInteractionEnabled = false
        menu.isHidden = true
        menu.onChoose = { [weak self] index in self?.onChoose?(index) }
        for label in [nameLabel, starLabel, moneyLabel, bannerLabel, promptLabel, speedLabel, objectiveLabel] {
            label.isUserInteractionEnabled = false
            label.textAlignment = .center
        }
        nameLabel.textAlignment = .left
        objectiveLabel.textAlignment = .left
        moneyLabel.textAlignment = .right
        starLabel.textAlignment = .center
        nameLabel.text = "ANI"
        addSubview(lookPad)
        addSubview(joystick)
        for button in [gas, brake, handbrake, action, phone, horn] {
            addSubview(button)
        }
        addSubview(healthBack)
        addSubview(nameLabel)
        addSubview(objectiveLabel)
        addSubview(starLabel)
        addSubview(moneyLabel)
        addSubview(bannerLabel)
        addSubview(promptLabel)
        addSubview(speedLabel)
        addSubview(minimap)
        addSubview(dimmer)
        addSubview(menu)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func consumeTouch() -> TouchSample {
        let look = lookPad.consume()
        return TouchSample(
            moveX: joystick.valueX,
            moveY: joystick.valueY,
            lookX: Float(look.x),
            lookY: Float(look.y),
            gas: gas.held,
            brake: brake.held,
            handbrake: handbrake.held,
            action: action.consumeEdge(),
            phone: phone.consumeEdge(),
            horn: horn.consumeEdge()
        )
    }

    func refresh(_ sim: GameSim) {
        let fraction = CGFloat(clamp(sim.health / 100, 0, 1))
        healthFill.frame = CGRect(x: 0, y: 0, width: healthBack.bounds.width * fraction, height: healthBack.bounds.height)
        let filled = min(5, sim.stars)
        starLabel.text = String(repeating: "★", count: filled) + String(repeating: "☆", count: 5 - filled)
        starLabel.textColor = sim.stars > 0 ? UIColor.red : UIColor(white: 0.9, alpha: 1)
        moneyLabel.text = "$\(sim.money)"
        bannerLabel.text = sim.banner
        promptLabel.text = sim.prompt
        speedLabel.text = sim.speedText
        objectiveLabel.text = sim.objective
        nameLabel.text = sim.isDriving ? "ANI  ·  DRIVING" : "ANI"
        gas.setTitle(sim.isDriving ? "GAS" : "RUN", for: .normal)
        minimap.map = sim.mapSnapshot
        minimap.setNeedsDisplay()
        let showMenu = sim.menuVisible
        dimmer.isHidden = !showMenu
        menu.isHidden = !showMenu
        lookPad.isUserInteractionEnabled = !showMenu
        for view in [joystick, gas, brake, handbrake, action, phone, horn] {
            view.isHidden = showMenu
        }
        if showMenu {
            menu.title = sim.menuTitle
            menu.lines = sim.menuLines
            menu.selection = sim.menuIndex
            menu.footer = sim.menuFooter
            menu.showsMap = sim.menuShowsMap
            menu.mapView.map = sim.mapSnapshot
            menu.mapView.setNeedsDisplay()
            menu.setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets
        let width = bounds.width
        let height = bounds.height
        lookPad.frame = CGRect(x: width * 0.38, y: 0, width: width * 0.62, height: height)
        dimmer.frame = bounds

        healthBack.frame = CGRect(x: safe.left + 16, y: safe.top + 8, width: 170, height: 12)
        nameLabel.frame = CGRect(x: safe.left + 16, y: safe.top + 22, width: 180, height: 16)
        objectiveLabel.frame = CGRect(x: safe.left + 16, y: safe.top + 38, width: 210, height: 16)
        minimap.frame = CGRect(x: safe.left + 16, y: safe.top + 58, width: 128, height: 128)
        starLabel.frame = CGRect(x: width * 0.5 - 80, y: safe.top + 8, width: 160, height: 24)
        moneyLabel.frame = CGRect(x: width - safe.right - 150, y: safe.top + 8, width: 130, height: 24)
        bannerLabel.frame = CGRect(x: width * 0.22, y: safe.top + 34, width: width * 0.56, height: 20)
        speedLabel.frame = CGRect(x: width * 0.38, y: height - safe.bottom - 52, width: width * 0.24, height: 20)
        promptLabel.frame = CGRect(x: width * 0.28, y: height - safe.bottom - 28, width: width * 0.44, height: 20)

        let button: CGFloat = 58
        let gap: CGFloat = 8
        let right = width - safe.right - 12 - button
        let bottom = height - safe.bottom - 12 - button
        action.frame = CGRect(x: right, y: bottom, width: button, height: button)
        gas.frame = CGRect(x: right, y: bottom - button - gap, width: button, height: button)
        brake.frame = CGRect(x: right - button - gap, y: bottom, width: button, height: button)
        handbrake.frame = CGRect(x: right - button - gap, y: bottom - button - gap, width: button, height: button)
        horn.frame = CGRect(x: right - (button + gap) * 2, y: bottom, width: button, height: button)
        phone.frame = CGRect(x: right, y: safe.top + 36, width: button, height: button)
        joystick.frame = CGRect(x: safe.left + 18, y: height - safe.bottom - 156, width: 140, height: 140)

        let menuWidth = min(560, width - 28)
        let menuHeight = min(320, height - 20)
        menu.frame = CGRect(x: (width - menuWidth) * 0.5, y: (height - menuHeight) * 0.5, width: menuWidth, height: menuHeight)
        if healthFill.bounds.height == 0 {
            healthFill.frame = CGRect(x: 0, y: 0, width: 170, height: 12)
        }
    }

    private static func makeLabel(size: CGFloat, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: size)
        label.textColor = color
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.9
        label.layer.shadowOffset = .zero
        return label
    }
}

final class JoystickView: UIView {
    private(set) var valueX: Float = 0
    private(set) var valueY: Float = 0
    private let knob = UIView()
    private var tracked: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 1, alpha: 0.08)
        layer.borderWidth = 2
        layer.borderColor = UIColor(white: 1, alpha: 0.28).cgColor
        knob.backgroundColor = Palette.pink
        addSubview(knob)
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width * 0.5
        knob.bounds = CGRect(x: 0, y: 0, width: 54, height: 54)
        knob.layer.cornerRadius = 27
        if tracked == nil {
            knob.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracked == nil, let touch = touches.first else { return }
        tracked = touch
        move(touch)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracked, touches.contains(tracked) else { return }
        move(tracked)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracked, touches.contains(tracked) else { return }
        reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }

    private func move(_ touch: UITouch) {
        let point = touch.location(in: self)
        var dx = point.x - bounds.midX
        var dy = point.y - bounds.midY
        let maxRadius = bounds.width * 0.38
        let magnitude = hypot(dx, dy)
        if magnitude > maxRadius && magnitude > 0 {
            dx *= maxRadius / magnitude
            dy *= maxRadius / magnitude
        }
        knob.center = CGPoint(x: bounds.midX + dx, y: bounds.midY + dy)
        if maxRadius > 0 {
            valueX = Float(dx / maxRadius)
            valueY = Float(-dy / maxRadius)
        }
    }

    private func reset() {
        tracked = nil
        valueX = 0
        valueY = 0
        knob.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

final class LookPad: UIView {
    private var tracked: UITouch?
    private var last = CGPoint.zero
    private var accumulated = CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func consume() -> CGPoint {
        let value = accumulated
        accumulated = .zero
        return value
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracked == nil, let touch = touches.first else { return }
        tracked = touch
        last = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tracked, touches.contains(tracked) else { return }
        let point = tracked.location(in: self)
        accumulated.x += point.x - last.x
        accumulated.y += point.y - last.y
        last = point
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tracked, touches.contains(tracked) { self.tracked = nil }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        tracked = nil
    }
}

final class GameButton: UIControl {
    private(set) var held = false
    private var edge = false
    private let titleLabel = UILabel()
    private let tint: UIColor

    init(title: String, color: UIColor) {
        tint = color
        super.init(frame: .zero)
        backgroundColor = color.withAlphaComponent(0.88)
        layer.cornerRadius = 29
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.35).cgColor
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        accessibilityLabel = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width * 0.5
        titleLabel.frame = bounds
    }

    func setTitle(_ title: String, for state: UIControl.State) {
        titleLabel.text = title
        accessibilityLabel = title
    }

    func consumeEdge() -> Bool {
        let value = edge
        edge = false
        return value
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        held = true
        edge = true
        backgroundColor = .white
        titleLabel.textColor = .black
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        held = false
        backgroundColor = tint.withAlphaComponent(0.88)
        titleLabel.textColor = .white
    }

    override func cancelTracking(with event: UIEvent?) {
        held = false
        backgroundColor = tint.withAlphaComponent(0.88)
        titleLabel.textColor = .white
    }
}

final class MinimapView: UIView {
    var map = MapDraw(minX: -1, maxX: 1, minZ: -1, maxZ: 1, zones: [], roads: [], blips: [], player: .zero, playerYaw: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.4)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
        clipsToBounds = true
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let canvas = bounds
        let spanX = max(0.001, map.maxX - map.minX)
        let spanZ = max(0.001, map.maxZ - map.minZ)
        func project(_ point: Vec3) -> CGPoint {
            let u = CGFloat((point.x - map.minX) / spanX)
            let v = CGFloat((point.z - map.minZ) / spanZ)
            return CGPoint(x: canvas.minX + u * canvas.width, y: canvas.maxY - v * canvas.height)
        }
        func fill(_ item: MapRect, alpha: CGFloat) {
            let a = project(Vec3(item.minX, 0, item.maxZ))
            let b = project(Vec3(item.maxX, 0, item.minZ))
            context.setFillColor(item.color.withAlphaComponent(alpha).cgColor)
            context.fill(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)))
        }
        for zone in map.zones { fill(zone, alpha: 0.85) }
        for road in map.roads { fill(road, alpha: 0.95) }
        for blip in map.blips {
            let point = project(blip.position)
            let radius = blip.radius
            context.setFillColor(blip.color.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - radius * 0.5, y: point.y - radius * 0.5, width: radius, height: radius))
        }
        let player = project(map.player)
        let facing = Vec3.direction(yaw: map.playerYaw)
        let tip = CGPoint(x: player.x + CGFloat(facing.x) * 9, y: player.y - CGFloat(facing.z) * 9)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.move(to: player)
        context.addLine(to: tip)
        context.strokePath()
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: player.x - 3.5, y: player.y - 3.5, width: 7, height: 7))
    }
}

final class MenuPanel: UIView {
    var title = ""
    var lines: [String] = []
    var selection = 0
    var footer = ""
    var showsMap = false {
        didSet { mapView.isHidden = !showsMap }
    }
    var onChoose: ((Int) -> Void)?
    let mapView = MinimapView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.05, alpha: 0.92)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = Palette.pink.cgColor
        clipsToBounds = true
        mapView.isHidden = true
        mapView.isUserInteractionEnabled = false
        addSubview(mapView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let mapHeight: CGFloat = showsMap ? min(100, bounds.height * 0.34) : 0
        mapView.frame = CGRect(x: 14, y: 40, width: bounds.width - 28, height: mapHeight)
    }

    override func draw(_ rect: CGRect) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: Palette.pink
        ]
        NSString(string: title).draw(in: CGRect(x: 16, y: 10, width: rect.width - 32, height: 24), withAttributes: titleAttrs)
        let header: CGFloat = showsMap ? 150 : 42
        let rowHeight: CGFloat = 32
        for (index, line) in lines.enumerated() {
            let row = CGRect(x: 12, y: header + CGFloat(index) * rowHeight, width: rect.width - 24, height: rowHeight - 4)
            if index == selection {
                Palette.pink.withAlphaComponent(0.35).setFill()
                UIBezierPath(roundedRect: row, cornerRadius: 8).fill()
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 15),
                .foregroundColor: UIColor.white
            ]
            NSString(string: line).draw(in: row.insetBy(dx: 10, dy: 6), withAttributes: attrs)
        }
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor(white: 0.8, alpha: 1)
        ]
        let footerRect = CGRect(x: 14, y: rect.height - 78, width: rect.width - 28, height: 70)
        NSString(string: footer).draw(in: footerRect, withAttributes: footerAttrs)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let y = touch.location(in: self).y
        let header: CGFloat = showsMap ? 150 : 42
        let index = Int((y - header) / 32)
        if index >= 0 && index < lines.count {
            onChoose?(index)
        }
    }
}
