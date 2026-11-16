/** Shared city layout. One meter per unit. +X east, +Z north, yaw 0 faces south. */

export type Style = 'downtown' | 'hood' | 'brick' | 'food' | 'house' | 'concrete' | 'roof'

export type Solid = {
  name: string
  minX: number
  maxX: number
  minZ: number
  maxZ: number
  h: number
  style: Style
}

export type Zone = { minX: number; maxX: number; minZ: number; maxZ: number }

export function X(c: number) {
  return (c - 1.5) * 36
}
export function Z(r: number) {
  return (r - 1.5) * 36
}

export const SOLIDS: Solid[] = []

function box(name: string, minX: number, maxX: number, minZ: number, maxZ: number, h: number, style: Style) {
  SOLIDS.push({ name, minX, maxX, minZ, maxZ, h, style })
}

function shell(name: string, minX: number, maxX: number, minZ: number, maxZ: number, h: number, style: Style, door: number) {
  const t = 0.42
  const mid = (minX + maxX) / 2
  box(name + '-n', minX, maxX, maxZ - t, maxZ, h, style)
  box(name + '-w', minX, minX + t, minZ, maxZ, h, style)
  box(name + '-e', maxX - t, maxX, minZ, maxZ, h, style)
  box(name + '-sl', minX, mid - door, minZ, minZ + t, h, style)
  box(name + '-sr', mid + door, maxX, minZ, minZ + t, h, style)
  box(name + '-roof', minX, maxX, minZ, maxZ, h + 0.18, 'roof')
  SOLIDS[SOLIDS.length - 1].name = name + '-roof'
}

// Lace Burger
shell('food', -8, 8, -36, -26.4, 4.8, 'food', 1.35)
box('counter', -2.4, 2.4, -29.3, -27.2, 1.05, 'concrete')

// Lace House
shell('home', 28, 46, -33, -26, 4.4, 'house', 1.25)
box('bed', 40, 44.6, -30.4, -27.3, 0.55, 'food')

// Hood
box('hood-a', -44, -34, -20, -8, 5.4, 'hood')
box('hood-b', -32, -27, -6.5, -2.2, 3.6, 'brick')
box('dumpster', -42.2, -40.3, -7.3, -5.3, 1.15, 'concrete')
box('hood-c', -44, -33, 4, 14, 6.2, 'hood')
box('hood-d', -31, -26.4, 16, 21, 4.1, 'brick')

// Plaza towers
box('plaza-sw', -8.8, -3.6, -8.8, -3.6, 16, 'downtown')
box('plaza-se', 3.6, 8.8, -8.8, -3.6, 12, 'downtown')
box('plaza-nw', -8.8, -3.6, 3.6, 8.8, 18, 'downtown')
box('plaza-ne', 3.6, 8.8, 3.6, 8.8, 14, 'downtown')

// Downtown
box('dt-a', 28, 34.5, -8, -2, 13, 'downtown')
box('dt-b', 28, 36, 2, 9, 17, 'downtown')
box('dt-c', -8, -2, 16, 22, 20, 'downtown')
box('dt-d', 2, 8, 24, 32, 15, 'downtown')
box('dt-e', 28, 35, 16, 23, 18, 'downtown')
box('dt-f', 38, 44, 25, 32, 11, 'downtown')
box('north-row', -46, -28, 28, 42, 6.2, 'hood')
box('east-tower', 26, 42, 36, 48, 15, 'downtown')
box('south-shop', -46, -34, -50, -42, 4.4, 'brick')
box('mid-shop', 40, 47, -10, -2, 5.4, 'brick')

// City edge
box('wall-s', -66, 66, -67, -64, 1.4, 'concrete')
box('wall-n', -66, 66, 64, 67, 1.4, 'concrete')
box('wall-w', -67, -64, -64, 64, 1.4, 'concrete')
box('wall-e', 64, 67, -64, 64, 1.4, 'concrete')

export const FOOD_ZONE: Zone = { minX: -1.7, maxX: 1.7, minZ: -31.6, maxZ: -29.45 }
export const HOME_ZONE: Zone = { minX: 34.2, maxX: 39.8, minZ: -35.8, maxZ: -32.55 }
export const FOOD_INSIDE: Zone = { minX: -7.4, maxX: 7.4, minZ: -35.4, maxZ: -26.9 }
export const HOME_INSIDE: Zone = { minX: 28.6, maxX: 45.4, minZ: -32.4, maxZ: -26.5 }

export const SPAWN = { x: -37, z: -36 }
export const SPORTS_PARK = { x: -31, z: -33.2, yaw: 0.5 }
export const SEDAN_PARK = { x: 42, z: -4, yaw: -1.1 }
export const BEATER_PARK = { x: -30, z: -15, yaw: 1.2 }
export const DRIVEWAY = { x: 37, z: -40, yaw: 0 }

export const PICKUPS = [
  { x: -36, z: -46 },
  { x: 0, z: -46 },
  { x: 44, z: -46 },
  { x: -46, z: -12 },
  { x: 0, z: -10.5 },
  { x: 46, z: 2 },
]

export type LightAxis = 'ew' | 'ns'
export type Waypoint = { x: number; z: number; light: LightAxis | null }

function ewRoute(row: number): Waypoint[] {
  const z = Z(row)
  const south = z - 2.35
  const north = z + 2.35
  const pts: Waypoint[] = []
  for (let c = 0; c < 4; c++) pts.push({ x: X(c) - 7, z: south, light: 'ew' })
  pts.push({ x: X(3) + 8, z: south, light: null })
  pts.push({ x: X(3) + 8, z: north, light: null })
  for (let c = 3; c >= 0; c--) pts.push({ x: X(c) + 7, z: north, light: 'ew' })
  pts.push({ x: X(0) - 8, z: north, light: null })
  pts.push({ x: X(0) - 8, z: south, light: null })
  return pts
}

function nsRoute(col: number): Waypoint[] {
  const x = X(col)
  const east = x + 2.35
  const west = x - 2.35
  const pts: Waypoint[] = []
  for (let r = 0; r < 4; r++) pts.push({ x: east, z: Z(r) - 7, light: 'ns' })
  pts.push({ x: east, z: Z(3) + 8, light: null })
  pts.push({ x: west, z: Z(3) + 8, light: null })
  for (let r = 3; r >= 0; r--) pts.push({ x: west, z: Z(r) + 7, light: 'ns' })
  pts.push({ x: west, z: Z(0) - 8, light: null })
  pts.push({ x: east, z: Z(0) - 8, light: null })
  return pts
}

export const ROUTES: Waypoint[][] = []
for (let i = 0; i < 4; i++) {
  ROUTES.push(ewRoute(i))
  ROUTES.push(nsRoute(i))
}

export function lightGreen(axis: LightAxis, time: number) {
  const t = ((time % 10) + 10) % 10
  return axis === 'ew' ? t < 4.3 : t >= 5 && t < 9.3
}

export function inZone(x: number, z: number, zone: Zone, pad = 0) {
  return x >= zone.minX - pad && x <= zone.maxX + pad && z >= zone.minZ - pad && z <= zone.maxZ + pad
}

export function pushOut(x: number, z: number, radius: number) {
  let hit = false
  for (let pass = 0; pass < 2; pass++) {
    for (const s of SOLIDS) {
      if (s.style === 'roof') continue
      const cx = Math.min(Math.max(x, s.minX), s.maxX)
      const cz = Math.min(Math.max(z, s.minZ), s.maxZ)
      let dx = x - cx
      let dz = z - cz
      const d2 = dx * dx + dz * dz
      if (d2 >= radius * radius) continue
      hit = true
      if (d2 > 1e-6) {
        const d = Math.sqrt(d2)
        const push = (radius - d) / d
        x += dx * push
        z += dz * push
      } else {
        const left = x - s.minX
        const right = s.maxX - x
        const south = z - s.minZ
        const north = s.maxZ - z
        const m = Math.min(left, right, south, north)
        if (m === left) x = s.minX - radius
        else if (m === right) x = s.maxX + radius
        else if (m === south) z = s.minZ - radius
        else z = s.maxZ + radius
      }
    }
  }
  return { x, z, hit }
}

export function blockedAhead(x: number, z: number, dx: number, dz: number, dist: number) {
  const px = x + dx * dist
  const pz = z + dz * dist
  for (const s of SOLIDS) {
    if (s.style === 'roof') continue
    if (px > s.minX - 1.2 && px < s.maxX + 1.2 && pz > s.minZ - 1.2 && pz < s.maxZ + 1.2) return true
  }
  return false
}
