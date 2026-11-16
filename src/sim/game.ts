import {
  BEATER_PARK,
  DRIVEWAY,
  FOOD_INSIDE,
  FOOD_ZONE,
  HOME_INSIDE,
  HOME_ZONE,
  PICKUPS,
  ROUTES,
  SEDAN_PARK,
  SPAWN,
  SPORTS_PARK,
  blockedAhead,
  inZone,
  lightGreen,
  pushOut,
  type LightAxis,
} from './world'
import { control } from '../input'

export type CarKind = 'sports' | 'sedan' | 'beater' | 'police'

export type CarEnt = {
  id: number
  kind: CarKind
  role: 'parked' | 'traffic' | 'police' | 'personal' | 'loose'
  x: number
  z: number
  ox: number
  oz: number
  yaw: number
  vx: number
  vz: number
  condition: number
  alive: boolean
  wallet: boolean
  color: string
  wheel: number
  slow: number
  hit: number
  route: number
  index: number
  cruise: number
  speed: number
  steer: number
}

export type PedEnt = {
  id: number
  x: number
  z: number
  yaw: number
  path: { x: number; z: number }[]
  index: number
  speed: number
  down: number
  tint: string
  cloth: string
  hair: string
}

export type Snapshot = {
  health: number
  money: number
  stars: number
  banner: string
  prompt: string
  speed: string
  objective: string
  driving: boolean
  menu: 'phone' | 'food' | 'home' | null
  menuTitle: string
  lines: string[]
  menuIndex: number
  footer: string
  map: { x: number; z: number; yaw: number; blips: { x: number; z: number; color: string }[] }
}

const FOOD = [
  { name: 'Lace Burger', price: 12, heal: 30 },
  { name: 'Neon Shake', price: 8, heal: 16 },
  { name: 'Mayhem Meal', price: 22, heal: 64 },
]

function yawOf(dx: number, dz: number) {
  return Math.atan2(-dx, -dz)
}
function forward(yaw: number) {
  return { x: -Math.sin(yaw), z: -Math.cos(yaw) }
}
function rightOf(yaw: number) {
  return { x: -Math.cos(yaw), z: Math.sin(yaw) }
}
function len(x: number, z: number) {
  return Math.hypot(x, z)
}
function clamp(v: number, a: number, b: number) {
  return Math.max(a, Math.min(b, v))
}

let nextId = 1

export class Game {
  time = 0
  clock = 0.8
  health = 100
  money = 200
  stars = 0
  heat = 0
  ownsHome = false
  px = SPAWN.x
  pz = SPAWN.z
  pyaw = 0
  camYaw = 0
  camPitch = 0.42
  driving: CarEnt | null = null
  foot = 0
  cars: CarEnt[] = []
  peds: PedEnt[] = []
  pickups: { x: number; z: number; alive: boolean; t: number }[] = []
  menu: Snapshot['menu'] = null
  menuIndex = 0
  banner = 'Take the black sports car. The city is wet, and it is watching.'
  bannerT = 6
  prompt = ''
  mercy = 0
  stun = 0
  unseen = 0
  bust = 0
  hornT = 0
  personal: CarEnt | null = null
  night = 1
  door = 0
  doorCar: CarEnt | null = null
  board: { car: CarEnt; mode: 'in' | 'out'; t: number } | null = null

  constructor() {
    this.cars.push(
      this.make('sports', 'parked', SPORTS_PARK.x, SPORTS_PARK.z, SPORTS_PARK.yaw, '#07070c'),
      this.make('sedan', 'parked', SEDAN_PARK.x, SEDAN_PARK.z, SEDAN_PARK.yaw, '#2a6fbe'),
      this.make('beater', 'parked', BEATER_PARK.x, BEATER_PARK.z, BEATER_PARK.yaw, '#8a4a22'),
    )
    const paints = ['#c0392b', '#f1c40f', '#27ae60', '#ecf0f1', '#8e44ad', '#e67e22', '#16a085', '#d35400', '#7f8c8d', '#2980b9']
    for (let i = 0; i < 10; i++) {
      const route = ROUTES[i % ROUTES.length]
      const start = route[i % route.length]
      const car = this.make(i % 2 ? 'sedan' : 'beater', 'traffic', start.x, start.z, 0, paints[i])
      car.route = i % ROUTES.length
      car.index = (i + 1) % route.length
      car.cruise = 7 + (i % 3)
      car.wallet = false
      this.cars.push(car)
    }
    for (let i = 0; i < 3; i++) {
      const cop = this.make('police', 'police', 0, 0, 0, '#f2f2f4')
      cop.alive = false
      this.cars.push(cop)
    }
    this.personal = this.make('sedan', 'personal', DRIVEWAY.x, DRIVEWAY.z, DRIVEWAY.yaw, '#6a1230')
    this.personal.alive = false
    this.personal.wallet = true
    this.cars.push(this.personal)
    const paths = [
      [-40, -20],
      [-40, 10],
      [0, 0],
      [0, 20],
      [30, 8],
      [36, 20],
      [-36, -8],
      [10, -8],
      [20, 28],
      [-20, 30],
    ]
    const cloth = ['#e23b8c', '#3d8bff', '#f2f2f2', '#2ecc71', '#e67e22', '#9b59b6', '#222', '#e74c3c', '#34495e', '#f5d6c6']
    const hair = ['#2b2118', '#4a3428', '#111', '#6b4a2a', '#1a1a1a', '#3a2a22', '#222', '#5a4030', '#3b2a22', '#111']
    paths.forEach((p, i) => {
      const loop = sidewalk(p[0] < 0 ? 0 : p[0] < 20 ? 1 : 2, p[1] < -10 ? 0 : p[1] < 12 ? 1 : 2)
      this.peds.push({
        id: nextId++,
        x: loop[0].x,
        z: loop[0].z,
        yaw: 0,
        path: loop,
        index: i % loop.length,
        speed: 1.1 + (i % 3) * 0.2,
        down: 0,
        tint: i % 2 ? '#f0c2aa' : '#e0a888',
        cloth: cloth[i],
        hair: hair[i],
      })
    })
    this.pickups = PICKUPS.map((p) => ({ ...p, alive: true, t: 0 }))
    this.pyaw = yawOf(SPORTS_PARK.x - SPAWN.x, SPORTS_PARK.z - SPAWN.z)
    this.camYaw = this.pyaw
    this.load()
  }

  private make(kind: CarKind, role: CarEnt['role'], x: number, z: number, yaw: number, color: string): CarEnt {
    return {
      id: nextId++,
      kind,
      role,
      x,
      z,
      ox: 0,
      oz: 0,
      yaw,
      vx: 0,
      vz: 0,
      condition: 100,
      alive: true,
      wallet: role === 'personal',
      color,
      wheel: 0,
      slow: 0,
      hit: 0,
      route: 0,
      index: 0,
      cruise: 8,
      speed: 0,
      steer: 0,
    }
  }

  update(dt: number) {
    dt = Math.min(0.033, Math.max(0, dt))
    this.time += dt
    this.clock += dt / 150
    if (this.clock >= 1) this.clock -= 1
    this.night = nightAmount(this.clock)
    this.bannerT -= dt
    if (this.bannerT <= 0) this.banner = ''
    this.mercy = Math.max(0, this.mercy - dt)
    this.stun = Math.max(0, this.stun - dt)
    this.hornT = Math.max(0, this.hornT - dt)
    for (const car of this.cars) car.hit = Math.max(0, car.hit - dt)

    const edges = {
      action: control.action,
      phone: control.phone,
      horn: control.horn,
      up: control.up,
      down: control.down,
      confirm: control.confirm,
      cancel: control.cancel,
    }
    control.action = control.phone = control.horn = control.up = control.down = control.confirm = control.cancel = 0

    if (this.menu && this.stun <= 0) this.handleMenu(edges)
    else if (this.stun <= 0) this.handleAction(edges)

    const locked = this.menu !== null || this.stun > 0
    const moveX = locked ? 0 : control.padConnected && Math.hypot(control.padX, control.padY) > 0.18 ? control.padX : control.moveX
    const moveY = locked ? 0 : control.padConnected && Math.hypot(control.padX, control.padY) > 0.18 ? control.padY : control.moveY
    const lookX = locked ? 0 : Math.abs(control.padLookX) > 0.12 ? control.padLookX : 0
    const lookY = locked ? 0 : Math.abs(control.padLookY) > 0.12 ? control.padLookY : 0
    const dragX = locked ? 0 : control.lookDragX
    const dragY = locked ? 0 : control.lookDragY
    control.lookDragX = 0
    control.lookDragY = 0
    const gas = control.gas || control.padGas > 0.15
    const brake = control.brake || control.padBrake > 0.15
    const hand = control.hand || control.padHand
    if (!locked && edges.horn) this.hornT = 1.2

    this.camYaw -= lookX * 1.7 * dt
    this.camYaw -= dragX * 0.012
    this.camPitch += lookY * 1.05 * dt
    this.camPitch += dragY * 0.008
    this.camPitch = clamp(this.camPitch, 0.18, 0.95)

    if (this.board) {
      this.tickBoard(dt)
    } else if (this.driving) {
      const throttle = gas ? 1 : brake ? -1 : moveY
      this.drive(this.driving, throttle, moveX, hand, dt)
      this.px = this.driving.x
      this.pz = this.driving.z
      this.pyaw = this.driving.yaw
      if (Math.abs(lookX) < 0.12 && Math.abs(dragX) < 1) {
        this.camYaw = approach(this.camYaw, this.driving.yaw, 2.4 * dt)
      }
      if (this.driving.condition <= 8) {
        this.board = null
        this.door = 0
        this.doorCar = null
        this.exitCar()
        this.say('The car gave out.')
      }
    } else {
      this.walk(moveX, moveY, gas, dt)
    }

    this.updateTraffic(dt)
    for (const car of this.cars) {
      if (car.role !== 'loose' || car === this.driving || !car.alive) continue
      car.vx *= Math.max(0, 1 - 2.2 * dt)
      car.vz *= Math.max(0, 1 - 2.2 * dt)
      car.x += car.vx * dt
      car.z += car.vz * dt
      car.ox = 0
      car.oz = 0
    }
    this.updatePeds(dt)
    this.updatePolice(dt)
    this.collide()
    this.collect(dt)
    this.wanted(dt)
    if (this.health <= 0 && this.stun <= 0) this.respawn(false)
    this.prompt = this.currentPrompt()
  }

  private handleAction(edges: { action: number; phone: number }) {
    if (edges.phone) {
      this.menu = 'phone'
      this.menuIndex = 0
      return
    }
    if (!edges.action) return
    if (this.board) return
    if (this.driving) {
      this.board = { car: this.driving, mode: 'out', t: 0 }
      return
    }
    if (inZone(this.px, this.pz, FOOD_ZONE, 0.3)) {
      this.menu = 'food'
      this.menuIndex = 0
      return
    }
    if (inZone(this.px, this.pz, HOME_ZONE, 0.4)) {
      if (this.ownsHome) {
        this.health = 100
        this.save()
        this.say('Home. Saved.')
      } else {
        this.menu = 'home'
        this.menuIndex = 0
      }
      return
    }
    const car = this.nearestCar()
    if (car) this.beginEnter(car)
  }

  private beginEnter(car: CarEnt) {
    if (car.role === 'traffic' || car.role === 'parked') car.role = 'loose'
    car.vx = 0
    car.vz = 0
    car.speed = 0
    this.board = { car, mode: 'in', t: 0 }
  }

  private tickBoard(dt: number) {
    const boarding = this.board
    if (!boarding) return
    boarding.t += dt
    const car = boarding.car
    this.doorCar = car
    if (boarding.mode === 'in') {
      const open = Math.min(1, boarding.t / 0.38)
      this.door = boarding.t < 0.55 ? open : Math.max(0, 1 - (boarding.t - 0.55) / 0.4)
      const spot = this.doorSpot(car)
      if (!this.driving) {
        this.px += (spot.x - this.px) * Math.min(1, dt * 4)
        this.pz += (spot.z - this.pz) * Math.min(1, dt * 4)
        this.pyaw = approach(this.pyaw, car.yaw, 8 * dt)
        this.foot = 1.4
      } else {
        this.px = car.x
        this.pz = car.z
        this.pyaw = car.yaw
        this.foot = 0
      }
      if (boarding.t > 0.55 && !this.driving) this.enter(car)
      if (boarding.t > 1.02) {
        this.board = null
        this.door = 0
        this.doorCar = null
      }
      return
    }
    this.door = boarding.t < 0.36 ? Math.min(1, boarding.t / 0.32) : Math.max(0, 1 - (boarding.t - 0.36) / 0.36)
    if (this.driving) {
      this.px = this.driving.x
      this.pz = this.driving.z
      this.pyaw = this.driving.yaw
    }
    if (boarding.t > 0.36 && this.driving) this.exitCar()
    if (boarding.t > 0.78) {
      this.board = null
      this.door = 0
      this.doorCar = null
    }
  }

  private doorSpot(car: CarEnt) {
    const right = rightOf(car.yaw)
    return { x: car.x - right.x * 1.7, z: car.z - right.z * 1.7 }
  }

  private handleMenu(edges: { cancel: number; phone: number; up: number; down: number; confirm: number; action: number }) {
    if (edges.cancel || (edges.phone && this.menu === 'phone')) {
      this.menu = null
      return
    }
    const lines = this.lines().length
    if (edges.up) this.menuIndex = Math.max(0, this.menuIndex - 1)
    if (edges.down) this.menuIndex = Math.min(lines - 1, this.menuIndex + 1)
    if (edges.confirm || edges.action) this.confirm()
  }

  choose(index: number) {
    if (!this.menu) return
    this.menuIndex = index
    this.confirm()
  }

  private lines() {
    if (this.menu === 'phone') return ['Save game', 'Close']
    if (this.menu === 'food') return FOOD.map((f) => `${f.name}   $${f.price}   +${f.heal} HP`).concat('Close')
    if (this.menu === 'home') return [`Buy Lace House — $750`, 'Not now']
    return []
  }

  private confirm() {
    if (this.menu === 'phone') {
      if (this.menuIndex === 0) {
        this.save()
        this.say('Saved.')
      }
      this.menu = null
    } else if (this.menu === 'food') {
      if (this.menuIndex >= FOOD.length) {
        this.menu = null
        return
      }
      const item = FOOD[this.menuIndex]
      if (this.money < item.price) {
        this.say(`Need $${item.price}.`)
        return
      }
      this.money -= item.price
      this.health = Math.min(100, this.health + item.heal)
      this.say(`${item.name}. Feeling better.`)
      this.save()
    } else if (this.menu === 'home') {
      if (this.menuIndex !== 0) {
        this.menu = null
        return
      }
      if (this.money < 750) {
        this.say('Lace House is $750.')
        return
      }
      this.money -= 750
      this.ownsHome = true
      this.ensurePersonal()
      this.menu = null
      this.say('Lace House is yours. The wine sedan is clean.')
      this.save()
    }
  }

  private walk(mx: number, my: number, sprint: boolean, dt: number) {
    const look = forward(this.camYaw)
    const right = rightOf(this.camYaw)
    let x = look.x * my + right.x * mx
    let z = look.z * my + right.z * mx
    const mag = len(x, z)
    if (mag > 1) {
      x /= mag
      z /= mag
    }
    this.foot = 0
    if (mag > 0.08) {
      const inv = 1 / mag
      const pace = (sprint ? 7.2 : 4.5) * Math.min(mag, 1)
      this.px += x * inv * pace * dt
      this.pz += z * inv * pace * dt
      this.foot = pace
      this.pyaw = approach(this.pyaw, yawOf(x, z), 10 * dt)
    }
    const pushed = pushOut(this.px, this.pz, 0.38)
    this.px = pushed.x
    this.pz = pushed.z
  }

  private drive(car: CarEnt, throttle: number, steer: number, hand: boolean, dt: number) {
    car.steer = steer
    const scale = 0.4 + 0.6 * Math.max(car.condition, 0) / 100
    const maxSpeed = (car.kind === 'sports' ? 22 : car.kind === 'police' ? 20 : car.kind === 'sedan' ? 16 : 12.5) * scale
    const accel = (car.kind === 'sports' ? 16 : car.kind === 'police' ? 13 : car.kind === 'sedan' ? 10 : 7.5) * scale
    const grip = car.kind === 'beater' ? 7 : car.kind === 'sports' ? 9 : 12
    const f = forward(car.yaw)
    let speed = car.vx * f.x + car.vz * f.z
    if (throttle > 0.05 && speed < maxSpeed) speed += throttle * accel * dt
    else if (throttle < -0.05 && speed > -6) speed += throttle * accel * 0.65 * dt
    else speed -= speed * Math.min(1, 1.5 * dt)
    if (hand) speed -= speed * Math.min(1, 0.8 * dt)
    const reverse = speed < -0.4 ? -1 : 1
    const turn = Math.abs(speed) < 0.45 ? (Math.abs(throttle) > 0.08 || hand ? 8 : 0) : Math.max(Math.min(Math.abs(speed), 11), 5)
    car.yaw += steer * reverse * turn * (hand ? 0.13 : 0.078) * dt
    const nf = forward(car.yaw)
    let vx = nf.x * speed
    let vz = nf.z * speed
    const response = hand ? 2.2 : grip
    const side = (car.vx - nf.x * (car.vx * nf.x + car.vz * nf.z)) * (1 - Math.min(1, response * dt))
    const sideZ = (car.vz - nf.z * (car.vx * nf.x + car.vz * nf.z)) * (1 - Math.min(1, response * dt))
    vx += side * 0.35
    vz += sideZ * 0.35
    const sp = len(vx, vz)
    if (sp > maxSpeed) {
      vx *= maxSpeed / sp
      vz *= maxSpeed / sp
    }
    car.vx = vx
    car.vz = vz
    car.x += vx * dt
    car.z += vz * dt
    car.wheel += len(vx, vz) * dt / 0.32
    this.collideBuildings(car, car === this.driving)
  }

  private updateTraffic(dt: number) {
    const siren = this.stars > 0 && this.cars.some((c) => c.role === 'police' && c.alive)
    for (const car of this.cars) {
      if (car.role !== 'traffic' || !car.alive || car === this.driving) continue
      const route = ROUTES[car.route]
      const point = route[car.index % route.length]
      let dx = point.x - car.x
      let dz = point.z - car.z
      let dist = len(dx, dz) || 0.0001
      const dirx = dx / dist
      const dirz = dz / dist
      let target = car.cruise
      if (point.light && !lightGreen(point.light, this.time) && dist < 8 && dist > 1.1) target = 0
      if (car.slow > 0) {
        car.slow -= dt
        target = Math.min(target, 1.2)
      }
      if (siren) target = Math.min(target, 3)
      if (!this.driving) {
        const f = forward(car.yaw)
        const ahead = (this.px - car.x) * f.x + (this.pz - car.z) * f.z
        const side = Math.abs((this.px - car.x) * f.z + (this.pz - car.z) * -f.x)
        if (ahead > 0 && ahead < 6 && side < 1.6) target = 0
      }
      car.speed += clamp(target - car.speed, -14 * dt, 7 * dt)
      if (dist < 1.3) {
        if (!point.light || lightGreen(point.light, this.time) || dist < 0.6) car.index = (car.index + 1) % route.length
        else car.speed = 0
      } else {
        car.x += dirx * car.speed * dt
        car.z += dirz * car.speed * dt
        const desired = yawOf(dirx, dirz)
        const diff = Math.atan2(Math.sin(desired - car.yaw), Math.cos(desired - car.yaw))
        car.steer = clamp(diff * 1.8, -1, 1)
        car.yaw = desired
      }
      const right = rightOf(car.yaw)
      const pull = siren ? 1.6 : 0
      car.ox = right.x * pull
      car.oz = right.z * pull
      car.vx = dirx * car.speed
      car.vz = dirz * car.speed
      car.wheel += car.speed * dt / 0.32
    }
  }

  private updatePeds(dt: number) {
    for (const ped of this.peds) {
      if (ped.down > 0) {
        ped.down -= dt
        continue
      }
      const target = ped.path[ped.index % ped.path.length]
      let dx = target.x - ped.x
      let dz = target.z - ped.z
      const dist = len(dx, dz)
      if (dist < 0.4) ped.index = (ped.index + 1) % ped.path.length
      const dirx = dist > 0.001 ? dx / dist : 0
      const dirz = dist > 0.001 ? dz / dist : 0
      let sx = 0
      let sz = 0
      for (const car of this.cars) {
        if (!car.alive) continue
        const ax = ped.x - (car.x + car.ox)
        const az = ped.z - (car.z + car.oz)
        const d = len(ax, az)
        if (d < 5 && d > 0.05 && len(car.vx, car.vz) > 1.5) {
          sx += (ax / d) * 1.6
          sz += (az / d) * 1.6
        }
      }
      ped.x += (dirx * ped.speed + sx) * dt
      ped.z += (dirz * ped.speed + sz) * dt
      const pushed = pushOut(ped.x, ped.z, 0.35)
      ped.x = pushed.x
      ped.z = pushed.z
      if (this.hornT > 0 && len(this.px - ped.x, this.pz - ped.z) < 9) ped.yaw = yawOf(this.px - ped.x, this.pz - ped.z)
      else if (Math.hypot(dirx + sx, dirz + sz) > 0.1) ped.yaw = yawOf(dirx + sx, dirz + sz)
    }
  }

  private updatePolice(dt: number) {
    const active = this.cars.filter((c) => c.role === 'police' && c.alive)
    if (this.stars <= 0) {
      for (const cop of active) cop.alive = false
      return
    }
    const wanted = Math.min(3, this.stars)
    if (active.length < wanted) {
      const idle = this.cars.find((c) => c.role === 'police' && !c.alive)
      if (idle) this.spawnCop(idle)
    }
    for (const cop of this.cars) {
      if (cop.role !== 'police' || !cop.alive) continue
      const dx = this.px - cop.x
      const dz = this.pz - cop.z
      const dist = len(dx, dz) || 0.001
      const f = forward(cop.yaw)
      const side = dx * f.z + dz * -f.x
      const ahead = dx * f.x + dz * f.z
      let steer = clamp((side / dist) * 2.6, -1, 1)
      if (ahead < 0 && dist < 12) steer = side >= 0 ? 1 : -1
      let throttle = dist > 8 ? 1 : 0.45
      if (blockedAhead(cop.x, cop.z, f.x, f.z, 5)) {
        steer = blockedAhead(cop.x, cop.z, -f.z, f.x, 4) ? 1 : -1
        throttle = 0.4
      }
      this.drive(cop, throttle, steer, false, dt)
      cop.condition = Math.max(cop.condition, 40)
    }
  }

  private spawnCop(cop: CarEnt) {
    let best = { x: XSafe(0), z: ZSafe(0), d: 0 }
    for (let c = 0; c < 4; c++) {
      for (let r = 0; r < 4; r++) {
        const x = (c - 1.5) * 36
        const z = (r - 1.5) * 36
        const d = len(x - this.px, z - this.pz)
        if (d > 26 && d > best.d) best = { x, z, d }
      }
    }
    const spot = pushOut(best.x, best.z, 2)
    cop.x = spot.x
    cop.z = spot.z
    cop.yaw = yawOf(this.px - spot.x, this.pz - spot.z)
    cop.vx = cop.vz = 0
    cop.condition = 100
    cop.alive = true
  }

  private collide() {
    const driven = this.driving
    const list = this.cars.filter((c) => c.alive && c !== driven)
    if (!driven) {
      for (const car of list) {
        const dx = this.px - (car.x + car.ox)
        const dz = this.pz - (car.z + car.oz)
        const d = len(dx, dz)
        const limit = 1.6
        if (d < limit && d > 0.001) {
          this.px += (dx / d) * (limit - d)
          this.pz += (dz / d) * (limit - d)
        }
      }
      return
    }
    for (const other of list) {
      const ax = driven.x
      const az = driven.z
      const bx = other.x + other.ox
      const bz = other.z + other.oz
      let dx = bx - ax
      let dz = bz - az
      let d = len(dx, dz)
      const limit = 2.5
      if (d >= limit) continue
      if (d < 0.001) {
        dx = 1
        dz = 0
        d = 1
      }
      const nx = dx / d
      const nz = dz / d
      const overlap = limit - d
      if (other.role === 'traffic') {
        driven.x -= nx * overlap
        driven.z -= nz * overlap
      } else {
        driven.x -= nx * overlap * 0.5
        driven.z -= nz * overlap * 0.5
        other.x += nx * overlap * 0.5
        other.z += nz * overlap * 0.5
      }
      const closing = (driven.vx - other.vx) * nx + (driven.vz - other.vz) * nz
      if (closing > 3 && driven.hit <= 0 && other.hit <= 0) {
        driven.hit = other.hit = 0.45
        driven.condition = Math.max(0, driven.condition - closing * 1.05)
        other.condition = Math.max(0, other.condition - closing * 1.05)
        this.hurt(closing * 0.4)
        if (closing > 6) this.addHeat(closing > 12 ? 0.7 : 0.35)
        if (other.role === 'traffic') other.slow = 1.4
      }
    }
    if (driven && len(driven.vx, driven.vz) > 3.4) {
      for (const ped of this.peds) {
        if (ped.down > 0) continue
        if (len(ped.x - driven.x, ped.z - driven.z) < 1.5) {
          ped.down = 11
          driven.condition = Math.max(0, driven.condition - 7)
          this.hurt(6)
          this.addHeat(1.2)
          this.say('They went down.')
        }
      }
    }
  }

  private collideBuildings(car: CarEnt, damage: boolean) {
    const beforeX = car.x
    const beforeZ = car.z
    const pushed = pushOut(car.x, car.z, 1.55)
    if (!pushed.hit) return
    const into = len(car.vx, car.vz)
    car.x = pushed.x
    car.z = pushed.z
    car.vx *= 0.45
    car.vz *= 0.45
    if (into > 4 && car.hit <= 0 && damage) {
      car.hit = 0.4
      car.condition = Math.max(0, car.condition - into * 1.15)
      this.hurt(into * 0.45)
      if (into > 7) this.addHeat(into > 11 ? 0.7 : 0.35)
    }
    if (Math.hypot(car.x - beforeX, car.z - beforeZ) < 0.001) {
      car.x = beforeX
      car.z = beforeZ
    }
  }

  private collect(dt: number) {
    for (const pickup of this.pickups) {
      if (!pickup.alive) {
        pickup.t -= dt
        if (pickup.t <= 0) pickup.alive = true
        continue
      }
      if (len(pickup.x - this.px, pickup.z - this.pz) < 1.3) {
        pickup.alive = false
        pickup.t = 70
        this.money += 80
        this.say('+$80')
      }
    }
  }

  private wanted(dt: number) {
    if (this.stars <= 0 || this.mercy > 0 || this.stun > 0) {
      this.unseen = 0
      this.bust = 0
      return
    }
    const cops = this.cars.filter((c) => c.role === 'police' && c.alive)
    const seen = cops.some((c) => len(c.x - this.px, c.z - this.pz) < 34)
    if (seen) this.unseen = 0
    else {
      this.unseen += dt
      if (this.unseen >= 8) {
        this.unseen = 0
        const before = this.stars
        this.heat = Math.max(0, this.heat - 1)
        this.refreshStars()
        if (this.stars < before) {
          if (this.stars === 0) {
            this.money += 110
            this.say('Got away. +$110')
          } else {
            this.money += 30
            this.say('One star cooler. +$30')
          }
        }
      }
    }
    const speed = this.driving ? len(this.driving.vx, this.driving.vz) : this.foot
    const near = cops.reduce((m, c) => Math.min(m, len(c.x - this.px, c.z - this.pz)), 99)
    if (near < 3.4 && speed < 2.4) {
      this.bust += dt
      if (this.bust >= 1.15) this.respawn(true)
    } else this.bust = Math.max(0, this.bust - dt * 0.6)
  }

  private nearestCar() {
    let best: CarEnt | null = null
    let bestD = 2.7
    for (const car of this.cars) {
      if (!car.alive || car.role === 'police' || car === this.driving || car.condition <= 8) continue
      const slow = car.role !== 'traffic' || len(car.vx, car.vz) < 2.3
      const d = len(car.x + car.ox - this.px, car.z + car.oz - this.pz)
      if (slow && d < bestD) {
        best = car
        bestD = d
      }
    }
    return best
  }

  private enter(car: CarEnt) {
    if (car.role === 'traffic') car.role = 'loose'
    else if (car.role === 'parked') car.role = 'loose'
    this.driving = car
    if (car.role !== 'personal' && !car.wallet) {
      car.wallet = true
      this.money += 40
      this.addHeat(1)
      this.say('Grand theft. +$40.')
    }
  }

  private exitCar() {
    const car = this.driving
    if (!car) return
    const right = rightOf(car.yaw)
    let spot = pushOut(car.x - right.x * 1.8, car.z - right.z * 1.8, 0.4)
    if (spot.hit) spot = pushOut(car.x + right.x * 1.8, car.z + right.z * 1.8, 0.4)
    this.px = spot.x
    this.pz = spot.z
    this.pyaw = car.yaw
    this.driving = null
    this.foot = 0
  }

  private ensurePersonal() {
    if (!this.personal) return
    this.personal.alive = true
    this.personal.x = DRIVEWAY.x
    this.personal.z = DRIVEWAY.z
    this.personal.yaw = DRIVEWAY.yaw
  }

  private addHeat(amount: number) {
    if (this.mercy > 0 || amount <= 0) return
    const before = this.stars
    this.heat = Math.min(4, this.heat + amount)
    this.refreshStars()
    if (this.stars > before) this.say(this.stars === 1 ? 'Wanted.' : `Wanted — ${this.stars} stars.`)
  }

  private refreshStars() {
    if (this.heat <= 0.08) {
      this.heat = 0
      this.stars = 0
    } else this.stars = Math.min(4, Math.max(1, Math.ceil(this.heat)))
  }

  private hurt(amount: number) {
    if (this.mercy > 0) return
    this.health = Math.max(0, this.health - amount)
  }

  private respawn(busted: boolean) {
    const lost = this.money - Math.floor(this.money * 0.75)
    this.money = Math.max(0, this.money - lost)
    this.health = 60
    this.stars = 0
    this.heat = 0
    this.mercy = 4
    this.stun = 1.4
    this.menu = null
    this.board = null
    this.door = 0
    this.doorCar = null
    if (this.driving) this.exitCar()
    for (const cop of this.cars) if (cop.role === 'police') cop.alive = false
    const base = this.ownsHome ? DRIVEWAY : SPAWN
    const spot = pushOut(base.x + 2.2, base.z + 1.2, 0.4)
    this.px = spot.x
    this.pz = spot.z
    this.say(busted ? `Busted. Lost $${lost}.` : `Wasted. Lost $${lost}.`)
    this.save()
  }

  private currentPrompt() {
    if (this.menu || this.stun > 0) return ''
    if (this.board?.mode === 'in') return 'Getting in'
    if (this.board?.mode === 'out') return 'Getting out'
    if (this.driving) return 'ACT  exit'
    if (inZone(this.px, this.pz, FOOD_ZONE, 0.3)) return 'ACT  order'
    if (inZone(this.px, this.pz, HOME_ZONE, 0.4)) return this.ownsHome ? 'ACT  rest & save' : 'ACT  buy Lace House'
    if (this.nearestCar()) return 'ACT  take car'
    return ''
  }

  private say(text: string) {
    this.banner = text
    this.bannerT = 3.4
  }

  insideFood() {
    return inZone(this.px, this.pz, FOOD_INSIDE)
  }
  insideHome() {
    return inZone(this.px, this.pz, HOME_INSIDE)
  }

  snapshot(): Snapshot {
    const blips = [
      { x: 0, z: -31, color: '#ff2f8a' },
      { x: DRIVEWAY.x, z: DRIVEWAY.z, color: '#3d8bff' },
    ]
    for (const pickup of this.pickups) if (pickup.alive) blips.push({ x: pickup.x, z: pickup.z, color: '#3dff7a' })
    for (const cop of this.cars) if (cop.role === 'police' && cop.alive) blips.push({ x: cop.x, z: cop.z, color: '#ff3040' })
    const speed = this.driving ? `${Math.round(len(this.driving.vx, this.driving.vz) * 3.6)} km/h` : ''
    let objective = 'Lace House  $750'
    if (this.stars > 0) objective = 'Lose the cops'
    else if (this.health < 45) objective = 'Get to Lace Burger'
    else if (this.ownsHome) objective = 'The house is yours'
    const titles = { phone: 'ANI PHONE', food: 'LACE BURGER', home: 'LACE HOUSE' }
    return {
      health: this.health,
      money: this.money,
      stars: this.stars,
      banner: this.banner,
      prompt: this.prompt,
      speed,
      objective,
      driving: Boolean(this.driving),
      menu: this.menu,
      menuTitle: this.menu ? titles[this.menu] : '',
      lines: this.lines(),
      menuIndex: this.menuIndex,
      footer:
        this.menu === 'phone'
          ? 'DualSense: left stick move, right stick look, R2 gas, L2 brake, Cross acts, Triangle is the phone, Square is the handbrake.'
          : this.menu === 'food'
            ? `Cash $${this.money}. Food patches you up.`
            : 'Driveway included.',
      map: { x: this.px, z: this.pz, yaw: this.driving ? this.driving.yaw : this.pyaw, blips },
    }
  }

  save() {
    const data = {
      money: this.money,
      health: Math.max(1, this.health),
      ownsHome: this.ownsHome,
      x: this.px,
      z: this.pz,
      yaw: this.pyaw,
    }
    localStorage.setItem('anicity-slot1', JSON.stringify(data))
  }

  private load() {
    try {
      const raw = localStorage.getItem('anicity-slot1')
      if (!raw) return
      const data = JSON.parse(raw) as { money: number; health: number; ownsHome: boolean; x: number; z: number; yaw: number }
      this.money = Math.max(0, data.money | 0)
      this.health = clamp(data.health, 1, 100)
      this.ownsHome = Boolean(data.ownsHome)
      const spot = pushOut(data.x, data.z, 0.4)
      this.px = spot.x
      this.pz = spot.z
      this.pyaw = data.yaw
      this.camYaw = data.yaw
      if (this.ownsHome) this.ensurePersonal()
    } catch {
      /* fresh city */
    }
  }
}

function approach(from: number, to: number, max: number) {
  let d = to - from
  while (d > Math.PI) d -= Math.PI * 2
  while (d < -Math.PI) d += Math.PI * 2
  return from + clamp(d, -max, max)
}

function nightAmount(clock: number) {
  const day = Math.sin((clock - 0.25) * Math.PI * 2)
  return clamp(1 - Math.max(0, day) * 1.35, 0, 1)
}

function sidewalk(c: number, r: number) {
  const x0 = (c - 1.5) * 36 + 6 + 1.5
  const x1 = (c + 1 - 1.5) * 36 - 6 - 1.5
  const z0 = (r - 1.5) * 36 + 6 + 1.5
  const z1 = (r + 1 - 1.5) * 36 - 6 - 1.5
  return [
    { x: x0, z: z0 },
    { x: x1, z: z0 },
    { x: x1, z: z1 },
    { x: x0, z: z1 },
  ]
}

function XSafe(c: number) {
  return (c - 1.5) * 36
}
function ZSafe(r: number) {
  return (r - 1.5) * 36
}
