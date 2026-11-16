import * as THREE from 'three'
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js'
import type { CarKind } from '../sim/game'
import { rainGlass } from './rain'

export function createCar(kind: CarKind, color: string) {
  const root = new THREE.Group()
  const paint = new THREE.MeshPhysicalMaterial({
    color,
    metalness: 0.86,
    roughness: 0.22,
    clearcoat: 1,
    clearcoatRoughness: 0.06,
    envMapIntensity: 1.4,
  })
  const glass = new THREE.MeshPhysicalMaterial({
    color: '#9ecbff',
    metalness: 0.1,
    roughness: 0.05,
    transparent: true,
    opacity: 0.45,
    envMapIntensity: 1.6,
  })
  const rubber = new THREE.MeshStandardMaterial({ color: '#111113', roughness: 0.9 })
  const rim = new THREE.MeshStandardMaterial({ color: '#d5d8e0', metalness: 0.95, roughness: 0.2 })
  const lamp = new THREE.MeshStandardMaterial({
    color: '#d7f4ff',
    emissive: new THREE.Color('#9ad8ff'),
    emissiveIntensity: 3,
    toneMapped: false,
  })
  const brake = new THREE.MeshStandardMaterial({
    color: '#ff1a1a',
    emissive: new THREE.Color('#ff1a1a'),
    emissiveIntensity: 1.2,
    toneMapped: false,
  })

  const spec = {
    sports: { w: 1.85, l: 4.35, bh: 0.32, by: 0.36, ch: 0.32 },
    sedan: { w: 1.8, l: 4.5, bh: 0.42, by: 0.5, ch: 0.46 },
    beater: { w: 1.86, l: 4.2, bh: 0.55, by: 0.58, ch: 0.5 },
    police: { w: 1.86, l: 4.6, bh: 0.44, by: 0.5, ch: 0.48 },
  }[kind]

  const body = new THREE.Mesh(new RoundedBoxGeometry(spec.w, spec.bh, spec.l, 3, 0.12), paint)
  body.name = 'body'
  body.position.y = spec.by
  body.castShadow = true
  body.receiveShadow = true
  root.add(body)

  const cabin = new THREE.Mesh(new RoundedBoxGeometry(spec.w * 0.82, spec.ch, spec.l * 0.46, 3, 0.08), rainGlass())
  cabin.position.set(0, spec.by + spec.bh * 0.45, -spec.l * 0.04)
  cabin.castShadow = true
  root.add(cabin)

  const door = new THREE.Group()
  door.name = 'door'
  door.position.set(spec.w * 0.46, spec.by, -spec.l * 0.18)
  const panel = new THREE.Mesh(new THREE.BoxGeometry(0.07, spec.bh * 0.92, spec.l * 0.38), paint)
  panel.position.set(0.02, 0, 0.12)
  panel.castShadow = true
  const windowPane = new THREE.Mesh(new THREE.BoxGeometry(0.05, spec.ch * 0.55, spec.l * 0.22), glass)
  windowPane.position.set(0.04, spec.bh * 0.28, 0.08)
  door.add(panel, windowPane)
  root.add(door)

  const steer = new THREE.Group()
  steer.name = 'steer'
  steer.userData.spin = 'z'
  steer.position.set(0.32, spec.by + spec.bh * 0.15, -0.22)
  const wheelRim = new THREE.Mesh(new THREE.TorusGeometry(0.16, 0.016, 8, 18), rim)
  const wheelHub = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.04, 10), rim)
  wheelHub.rotation.x = Math.PI / 2
  steer.add(wheelRim, wheelHub)
  root.add(steer)

  const wiper = new THREE.Group()
  wiper.name = 'wiper'
  wiper.position.set(0.05, spec.by + spec.bh * 0.72, -spec.l * 0.16)
  const blade = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.02, 0.62), rubber)
  blade.position.set(0, 0, -0.22)
  wiper.add(blade)
  root.add(wiper)

  addLamp(root, lamp, -spec.w * 0.32, spec.by, -spec.l * 0.48, 0.32, 0.1, 0.08)
  addLamp(root, lamp, spec.w * 0.32, spec.by, -spec.l * 0.48, 0.32, 0.1, 0.08)
  addLamp(root, brake, -spec.w * 0.3, spec.by, spec.l * 0.48, 0.28, 0.08, 0.06)
  addLamp(root, brake, spec.w * 0.3, spec.by, spec.l * 0.48, 0.28, 0.08, 0.06)

  for (const [x, z] of [
    [-spec.w * 0.42, -spec.l * 0.32],
    [spec.w * 0.42, -spec.l * 0.32],
    [-spec.w * 0.42, spec.l * 0.32],
    [spec.w * 0.42, spec.l * 0.32],
  ] as const) {
    const pivot = new THREE.Group()
    pivot.position.set(x, 0.32, z)
    pivot.rotation.z = Math.PI / 2
    const tire = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 0.22, 20), rubber)
    tire.name = 'wheel'
    tire.castShadow = true
    const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 0.24, 16), rim)
    tire.add(hub)
    pivot.add(tire)
    root.add(pivot)
  }

  if (kind === 'sports') {
    const glowMat = new THREE.MeshStandardMaterial({
      color: '#ff2f8a',
      emissive: new THREE.Color('#ff2f8a'),
      emissiveIntensity: 4,
      toneMapped: false,
    })
    const glow = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.04, 2.2), glowMat)
    glow.position.y = 0.12
    root.add(glow)
    const light = new THREE.PointLight('#ff2f8a', 6, 8, 2)
    light.position.y = 0.3
    root.add(light)
  }

  if (kind === 'police') {
    const bar = new THREE.Mesh(new RoundedBoxGeometry(0.75, 0.08, 0.24, 2, 0.03), new THREE.MeshStandardMaterial({ color: '#111' }))
    bar.position.set(0, 1.18, -0.1)
    const redMat = new THREE.MeshStandardMaterial({ color: '#ff2040', emissive: new THREE.Color('#ff2040'), emissiveIntensity: 6, toneMapped: false })
    const blueMat = new THREE.MeshStandardMaterial({ color: '#2f6bff', emissive: new THREE.Color('#2f6bff'), emissiveIntensity: 6, toneMapped: false })
    const red = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.1, 0.16), redMat)
    red.name = 'sirenR'
    red.position.set(-0.18, 0.08, 0)
    const blue = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.1, 0.16), blueMat)
    blue.name = 'sirenB'
    blue.position.set(0.18, 0.08, 0)
    bar.add(red)
    bar.add(blue)
    root.add(bar)
    const siren = new THREE.PointLight('#ff3355', 8, 16, 2)
    siren.name = 'sirenLight'
    siren.position.set(0, 1.35, 0)
    root.add(siren)
  }

  root.userData.paint = paint
  return root
}

function addLamp(root: THREE.Group, material: THREE.Material, x: number, y: number, z: number, w: number, h: number, d: number) {
  const lamp = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material)
  lamp.position.set(x, y, z)
  root.add(lamp)
}
