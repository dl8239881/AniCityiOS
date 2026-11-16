import UIKit
import SceneKit

final class GameViewController: UIViewController {
    private let sceneView = SCNView()
    private let hud = HUDView()
    private let input = InputController()
    private let audio = AudioDirector()
    private let impact = UIImpactFeedbackGenerator(style: .heavy)
    private var sim: GameSim!
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark
        sceneView.frame = view.bounds
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = .black
        sceneView.antialiasingMode = .multisampling2X
        sceneView.preferredFramesPerSecond = 60
        sceneView.rendersContinuously = true
        sceneView.autoenablesDefaultLighting = false
        view.addSubview(sceneView)

        hud.frame = view.bounds
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hud)

        sim = GameSim()
        sceneView.scene = sim.scene
        sceneView.pointOfView = sim.cameraNode
        hud.onChoose = { [weak self] index in
            self?.sim.chooseMenu(index)
        }
        sim.onImpact = { [weak self] amount in
            self?.audio.playBump(intensity: amount)
            self?.input.rumble(intensity: amount)
            self?.impact.impactOccurred(intensity: CGFloat(min(1, amount)))
            self?.shake(amount)
        }
        sim.onHorn = { [weak self] in
            self?.audio.playHorn()
        }

        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
        NotificationCenter.default.addObserver(self, selector: #selector(saveGame), name: UIApplication.willResignActiveNotification, object: nil)
        impact.prepare()
    }

    deinit {
        link?.invalidate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        input.pressesBegan(presses)
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        input.pressesEnded(presses)
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        input.pressesEnded(presses)
        super.pressesCancelled(presses, with: event)
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTime == 0 {
            lastTime = link.timestamp
            hud.refresh(sim)
            return
        }
        let dt = Float(min(0.05, link.timestamp - lastTime))
        lastTime = link.timestamp
        let touch = hud.consumeTouch()
        input.touchMoveX = touch.moveX
        input.touchMoveY = touch.moveY
        input.touchLookX = touch.lookX
        input.touchLookY = touch.lookY
        input.touchGas = touch.gas
        input.touchBrake = touch.brake
        input.touchSprint = touch.gas
        input.touchHandbrake = touch.handbrake
        input.touchAction = touch.action
        input.touchPhone = touch.phone
        input.touchHorn = touch.horn
        let frame = input.update()
        sim.update(dt: dt, input: frame)
        input.setDriving(sim.isDriving, sprinting: frame.sprint && !sim.isDriving)
        input.setWanted(stars: sim.stars, time: sim.time)
        audio.update(siren: sim.wantsSiren, distance: sim.sirenDistance, driving: sim.isDriving, speed: sim.moveSpeed)
        hud.refresh(sim)
    }

    @objc private func saveGame() {
        sim?.save()
    }

    private func shake(_ amount: Float) {
        let kick = CGFloat(amount) * 10
        sceneView.transform = CGAffineTransform(translationX: kick, y: kick * 0.3)
        UIView.animate(withDuration: 0.12) {
            self.sceneView.transform = .identity
        }
    }
}
