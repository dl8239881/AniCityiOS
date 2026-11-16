/** HUD writes touch fields. Gamepad is sampled each frame. The sim merges them. */
export const control = {
  moveX: 0,
  moveY: 0,
  lookDragX: 0,
  lookDragY: 0,
  gas: false,
  brake: false,
  hand: false,
  action: 0,
  phone: 0,
  horn: 0,
  up: 0,
  down: 0,
  confirm: 0,
  cancel: 0,
  padX: 0,
  padY: 0,
  padLookX: 0,
  padLookY: 0,
  padGas: 0,
  padBrake: 0,
  padHand: false,
  padConnected: false,
}

export function pulse(key: 'action' | 'phone' | 'horn' | 'up' | 'down' | 'confirm' | 'cancel') {
  control[key] += 1
}

const held = new Set<string>()

function edge(name: string, down: boolean, fire: () => void) {
  if (down && !held.has(name)) {
    held.add(name)
    fire()
  } else if (!down) {
    held.delete(name)
  }
}

export function readGamepad() {
  const pads = navigator.getGamepads?.()
  control.padConnected = false
  control.padX = 0
  control.padY = 0
  control.padLookX = 0
  control.padLookY = 0
  control.padGas = 0
  control.padBrake = 0
  control.padHand = false
  if (!pads) return
  let pad: Gamepad | null = null
  for (const candidate of pads) {
    if (candidate && candidate.connected) {
      pad = candidate
      break
    }
  }
  if (!pad) return
  control.padConnected = true
  const ax = (i: number) => pad.axes[i] ?? 0
  const analog = (i: number) => pad.buttons[i]?.value ?? 0
  const down = (i: number) => Boolean(pad.buttons[i]?.pressed)
  control.padX = ax(0)
  control.padY = -ax(1)
  control.padLookX = ax(2)
  control.padLookY = -ax(3)
  control.padGas = analog(7)
  control.padBrake = analog(6)
  control.padHand = down(2)
  edge('a', down(0), () => pulse('action'))
  edge('b', down(1), () => pulse('cancel'))
  edge('y', down(3) || down(9), () => pulse('phone'))
  edge('horn', down(4) || down(5), () => pulse('horn'))
  edge('up', down(12) || ax(1) < -0.65, () => pulse('up'))
  edge('down', down(13) || ax(1) > 0.65, () => pulse('down'))
  edge('confirm', down(0), () => pulse('confirm'))
}
