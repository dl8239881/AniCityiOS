import UIKit
import GameController
import CoreHaptics

/// Merges on-screen touch, keyboard, and MFi / DualSense into one frame.
/// DualSense gets the light bar and adaptive triggers; other extended pads share the same buttons.
final class InputController {
    var touchMoveX: Float = 0
    var touchMoveY: Float = 0
    var touchLookX: Float = 0
    var touchLookY: Float = 0
    var touchGas = false
    var touchBrake = false
    var touchSprint = false
    var touchHandbrake = false
    var touchAction = false
    var touchPhone = false
    var touchHorn = false

    private(set) var controllerConnected = false
    private(set) var controllerName = "Touch"

    private var keys: Set<UIKeyboardHIDUsage> = []
    private var previous = Set<String>()
    private var boundController: GCController?
    private var dualSense: GCDualSenseGamepad?
    private var hapticEngine: CHHapticEngine?
    private var triggerMode = ""
    private var discoveryStarted = false

    func update() -> InputFrame {
        if !discoveryStarted {
            discoveryStarted = true
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
        }
        let controller = GCController.controllers().first
        if controller !== boundController {
            bind(controller)
        }

        var frame = InputFrame()
        var moveX = touchMoveX
        var moveY = touchMoveY
        var lookX: Float = 0
        var lookY: Float = 0
        var throttle = touchGas ? Float(1) : (touchBrake ? Float(-1) : 0)
        var sprint = touchSprint
        var handbrake = touchHandbrake
        var action = touchAction
        var phone = touchPhone
        var horn = touchHorn
        var confirm = false
        var cancel = false
        var menuUp = false
        var menuDown = false
        var recenter = false

        if keys.contains(.keyboardA) { moveX -= 1 }
        if keys.contains(.keyboardD) { moveX += 1 }
        if keys.contains(.keyboardW) { moveY += 1 }
        if keys.contains(.keyboardS) { moveY -= 1 }
        if keys.contains(.keyboardLeftArrow) { lookX -= 1 }
        if keys.contains(.keyboardRightArrow) { lookX += 1 }
        if keys.contains(.keyboardUpArrow) { lookY += 1 }
        if keys.contains(.keyboardDownArrow) { lookY -= 1 }
        if keys.contains(.keyboardLeftShift) || keys.contains(.keyboardRightShift) { sprint = true }
        if keys.contains(.keyboardSpacebar) { handbrake = true }
        if keys.contains(.keyboardC) { throttle = min(throttle, -1) }
        if keys.contains(.keyboardE) { action = true }
        if keys.contains(.keyboardQ) || keys.contains(.keyboardM) { phone = true }
        if keys.contains(.keyboardF) { horn = true }
        if keys.contains(.keyboardReturnOrEnter) { confirm = true }
        if keys.contains(.keyboardEscape) { cancel = true }
        if keys.contains(.keyboardUpArrow) { menuUp = true }
        if keys.contains(.keyboardDownArrow) { menuDown = true }

        if let pad = boundController?.extendedGamepad {
            let stickX = pad.leftThumbstick.xAxis.value
            let stickY = pad.leftThumbstick.yAxis.value
            if sqrt(stickX * stickX + stickY * stickY) > 0.12 {
                moveX = stickX
                moveY = stickY
            }
            let rx = pad.rightThumbstick.xAxis.value
            let ry = pad.rightThumbstick.yAxis.value
            if sqrt(rx * rx + ry * ry) > 0.08 {
                lookX = rx
                lookY = ry
            }
            let trigger = pad.rightTrigger.value - pad.leftTrigger.value
            if abs(trigger) > 0.05 {
                throttle = trigger
            }
            if pad.rightTrigger.value > 0.45 { sprint = true }
            if pad.buttonX.isPressed { handbrake = true }
            if pad.buttonA.isPressed { action = true; confirm = true }
            if pad.buttonB.isPressed { cancel = true }
            if pad.buttonY.isPressed || pad.buttonMenu.isPressed || pad.buttonOptions?.isPressed == true {
                phone = true
            }
            if pad.rightShoulder.isPressed || pad.leftShoulder.isPressed { horn = true }
            if pad.dpad.yAxis.value > 0.5 { menuUp = true }
            if pad.dpad.yAxis.value < -0.5 { menuDown = true }
            if pad.rightThumbstickButton?.isPressed == true { recenter = true }
            if abs(pad.leftThumbstick.yAxis.value) > 0.65 {
                if pad.leftThumbstick.yAxis.value > 0 { menuUp = true } else { menuDown = true }
            }
        }

        frame.moveX = clamp(moveX, -1, 1)
        frame.moveY = clamp(moveY, -1, 1)
        frame.lookStickX = lookX
        frame.lookStickY = lookY
        frame.lookDragX = touchLookX
        frame.lookDragY = touchLookY
        frame.throttle = clamp(throttle, -1, 1)
        frame.sprint = sprint
        frame.handbrake = handbrake
        frame.hornEdge = edge("horn", horn)
        frame.actionEdge = edge("action", action)
        frame.phoneEdge = edge("phone", phone)
        frame.confirmEdge = edge("confirm", confirm)
        frame.cancelEdge = edge("cancel", cancel)
        frame.menuUp = edge("menuUp", menuUp)
        frame.menuDown = edge("menuDown", menuDown)
        frame.recenter = edge("recenter", recenter)

        touchAction = false
        touchPhone = false
        touchHorn = false
        touchLookX = 0
        touchLookY = 0
        return frame
    }

    func pressesBegan(_ presses: Set<UIPress>) {
        for press in presses {
            if let code = press.key?.keyCode {
                keys.insert(code)
            }
        }
    }

    func pressesEnded(_ presses: Set<UIPress>) {
        for press in presses {
            if let code = press.key?.keyCode {
                keys.remove(code)
            }
        }
    }

    func setDriving(_ driving: Bool, sprinting: Bool) {
        guard let dualSense else { return }
        let mode = driving ? "drive" : (sprinting ? "sprint" : "foot")
        if mode == triggerMode { return }
        triggerMode = mode
        switch mode {
        case "drive":
            dualSense.rightTrigger.setModeWeaponWithStartPosition(0.05, endPosition: 0.45, resistiveStrength: 0.6)
            dualSense.leftTrigger.setModeFeedbackWithStartPosition(0.02, resistiveStrength: 0.9)
        case "sprint":
            dualSense.rightTrigger.setModeFeedbackWithStartPosition(0.15, resistiveStrength: 0.35)
            dualSense.leftTrigger.setModeOff()
        default:
            dualSense.rightTrigger.setModeFeedbackWithStartPosition(0.35, resistiveStrength: 0.15)
            dualSense.leftTrigger.setModeOff()
        }
    }

    func setWanted(stars: Int, time: Float) {
        guard let light = boundController?.light else { return }
        if stars > 0 {
            let flash = sin(time * 14) > 0
            if flash {
                light.color = GCColor(red: 1, green: 0.08, blue: 0.35)
            } else {
                light.color = GCColor(red: 0.15, green: 0.35, blue: 1)
            }
        } else {
            light.color = GCColor(red: 0.55, green: 0.15, blue: 0.85)
        }
    }

    func rumble(intensity: Float) {
        guard let hapticEngine else { return }
        let amount = clamp(intensity, 0.15, 1)
        let sharp = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
        let power = CHHapticEventParameter(parameterID: .hapticIntensity, value: amount)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [power, sharp], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            return
        }
    }

    private func bind(_ controller: GCController?) {
        boundController = controller
        dualSense = nil
        triggerMode = ""
        hapticEngine?.stop { _ in }
        hapticEngine = nil
        guard let controller else {
            controllerConnected = false
            controllerName = "Touch"
            return
        }
        controllerConnected = true
        controllerName = controller.vendorName ?? "Controller"
        if let dual = controller.physicalInputProfile as? GCDualSenseGamepad {
            dualSense = dual
            controllerName = "DualSense"
        }
        lightIdle(controller)
        if let haptics = controller.haptics {
            hapticEngine = haptics.createEngine(withLocality: .handles)
            try? hapticEngine?.start()
        }
    }

    private func lightIdle(_ controller: GCController) {
        controller.light?.color = GCColor(red: 0.55, green: 0.15, blue: 0.85)
    }

    private func edge(_ name: String, _ down: Bool) -> Bool {
        let was = previous.contains(name)
        if down {
            previous.insert(name)
        } else {
            previous.remove(name)
        }
        return down && !was
    }
}
