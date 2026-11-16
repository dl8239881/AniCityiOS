import * as THREE from 'three'
import type { Maps } from './materials'

/** Lofted body meshes. Cross-sections change shape along the limb, so these are not capsules. */

type Ring = {
  center: THREE.Vector3
  axisU: THREE.Vector3
  axisV: THREE.Vector3
  rx: number
  ry: number
}

const UP = new THREE.Vector3(0, 1, 0)
const XAXIS = new THREE.Vector3(1, 0, 0)
const ZAXIS = new THREE.Vector3(0, 0, 1)

function loft(rings: Ring[], segs = 18): THREE.BufferGeometry {
  const nR = rings.length
  const count = nR * segs
  const positions = new Float32Array(count * 3)
  const uvs = new Float32Array(count * 2)
  const nPow = 2.35
  for (let i = 0; i < nR; i++) {
    const ring = rings[i]
    for (let s = 0; s < segs; s++) {
      const a = (s / segs) * Math.PI * 2
      const c = Math.cos(a)
      const sn = Math.sin(a)
      const ex = Math.sign(c) * Math.pow(Math.abs(c), 2 / nPow)
      const ey = Math.sign(sn) * Math.pow(Math.abs(sn), 2 / nPow)
      const px = ring.center.x + ring.axisU.x * ex * ring.rx + ring.axisV.x * ey * ring.ry
      const py = ring.center.y + ring.axisU.y * ex * ring.rx + ring.axisV.y * ey * ring.ry
      const pz = ring.center.z + ring.axisU.z * ex * ring.rx + ring.axisV.z * ey * ring.ry
      const vi = i * segs + s
      positions[vi * 3] = px
      positions[vi * 3 + 1] = py
      positions[vi * 3 + 2] = pz
      uvs[vi * 2] = s / segs
      uvs[vi * 2 + 1] = nR === 1 ? 0 : i / (nR - 1)
    }
  }
  const indices: number[] = []
  for (let i = 0; i < nR - 1; i++) {
    for (let s = 0; s < segs; s++) {
      const a = i * segs + s
      const b = i * segs + ((s + 1) % segs)
      const c = (i + 1) * segs + s
      const d = (i + 1) * segs + ((s + 1) % segs)
      indices.push(a, c, b, b, c, d)
    }
  }
  const geo = new THREE.BufferGeometry()
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3))
  geo.setAttribute('uv', new THREE.BufferAttribute(uvs, 2))
  geo.setIndex(indices)
  const center = rings[0].center
  const pa = new THREE.Vector3(positions[0], positions[1], positions[2])
  const i1 = indices[1] * 3
  const i2 = indices[2] * 3
  const pb = new THREE.Vector3(positions[i1], positions[i1 + 1], positions[i1 + 2])
  const pc = new THREE.Vector3(positions[i2], positions[i2 + 1], positions[i2 + 2])
  const normal = new THREE.Vector3().crossVectors(pb.clone().sub(pa), pc.clone().sub(pa))
  if (normal.dot(pa.clone().sub(center)) < 0) {
    for (let i = 0; i < indices.length; i += 3) {
      const swap = indices[i + 1]
      indices[i + 1] = indices[i + 2]
      indices[i + 2] = swap
    }
    geo.setIndex(indices)
  }
  geo.computeVertexNormals()
  return geo
}

function framesAlong(points: THREE.Vector3[]) {
  const tangents = points.map((_, i) => {
    const a = points[Math.max(0, i - 1)]
    const b = points[Math.min(points.length - 1, i + 1)]
    return b.clone().sub(a).normalize()
  })
  let normal = new THREE.Vector3(0, 0, 1)
  if (Math.abs(tangents[0].dot(normal)) > 0.85) normal = new THREE.Vector3(1, 0, 0)
  let prevT = tangents[0].clone()
  let prevN = normal.clone().addScaledVector(prevT, -normal.dot(prevT)).normalize()
  const frames: { u: THREE.Vector3; v: THREE.Vector3 }[] = []
  for (let i = 0; i < points.length; i++) {
    const t = tangents[i]
    const axis = new THREE.Vector3().crossVectors(prevT, t)
    const sin = axis.length()
    const cos = THREE.MathUtils.clamp(prevT.dot(t), -1, 1)
    if (sin > 1e-5) {
      axis.multiplyScalar(1 / sin)
      prevN.applyAxisAngle(axis, Math.atan2(sin, cos))
    }
    prevN.addScaledVector(t, -prevN.dot(t)).normalize()
    const u = new THREE.Vector3().crossVectors(t, prevN).normalize()
    frames.push({ u, v: prevN.clone() })
    prevT = t.clone()
  }
  return frames
}

function loftPath(points: THREE.Vector3[], radius: (t: number) => { rx: number; ry: number }, segs = 14) {
  const frames = framesAlong(points)
  const rings: Ring[] = points.map((p, i) => {
    const r = radius(points.length === 1 ? 0 : i / (points.length - 1))
    return { center: p, axisU: frames[i].u, axisV: frames[i].v, rx: r.rx, ry: r.ry }
  })
  return loft(rings, segs)
}

function yRings(samples: { y: number; rx: number; ry: number; z?: number }[]): Ring[] {
  return samples.map((s) => ({
    center: new THREE.Vector3(0, s.y, s.z ?? 0),
    axisU: XAXIS,
    axisV: ZAXIS,
    rx: s.rx,
    ry: s.ry,
  }))
}

function addFolds(geo: THREE.BufferGeometry, amount: number, waves: number) {
  const pos = geo.getAttribute('position')
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i)
    const y = pos.getY(i)
    const z = pos.getZ(i)
    const ang = Math.atan2(x, z)
    const fold = Math.sin(ang * waves + y * 6) * amount * Math.max(0, 1.15 - y)
    const len = Math.hypot(x, z) || 1
    pos.setX(i, x + (x / len) * fold)
    pos.setZ(i, z + (z / len) * fold)
  }
  pos.needsUpdate = true
  geo.computeVertexNormals()
}

function mesh(geo: THREE.BufferGeometry, material: THREE.Material, shadow = true) {
  const m = new THREE.Mesh(geo, material)
  m.castShadow = shadow
  m.receiveShadow = true
  return m
}

export type FigureOptions = {
  skin: THREE.Material
  cloth: THREE.Material
  hair: THREE.Material
  boot: THREE.Material
  iris: THREE.Material
  lip: THREE.Material
  dress: boolean
  tails: boolean
  hairScale?: number
}

export function createFigure(opt: FigureOptions) {
  const root = new THREE.Group()
  const yaw = new THREE.Group()
  yaw.name = 'yaw'
  root.add(yaw)
  const bob = new THREE.Group()
  bob.name = 'bob'
  yaw.add(bob)

  const shoulderY = 1.36
  const hipY = 0.86

  if (opt.dress) {
    const dressGeo = loft(
      yRings([
        { y: 1.3, rx: 0.155, ry: 0.11, z: -0.01 },
        { y: 1.2, rx: 0.15, ry: 0.125, z: -0.02 },
        { y: 1.08, rx: 0.132, ry: 0.1, z: -0.005 },
        { y: 0.96, rx: 0.15, ry: 0.11 },
        { y: 0.84, rx: 0.2, ry: 0.14 },
        { y: 0.66, rx: 0.32, ry: 0.2 },
        { y: 0.5, rx: 0.42, ry: 0.26 },
        { y: 0.38, rx: 0.5, ry: 0.3 },
      ]),
      28,
    )
    addFolds(dressGeo, 0.018, 9)
    const dress = mesh(dressGeo, opt.cloth)
    dress.name = 'skirt'
    bob.add(dress)
  } else {
    bob.add(
      mesh(
        loft(
          yRings([
            { y: 1.42, rx: 0.2, ry: 0.11 },
            { y: 1.32, rx: 0.17, ry: 0.12, z: -0.01 },
            { y: 1.18, rx: 0.16, ry: 0.12, z: -0.012 },
            { y: 1.05, rx: 0.145, ry: 0.105 },
            { y: 0.9, rx: 0.155, ry: 0.11 },
          ]),
          20,
        ),
        opt.cloth,
      ),
    )
    const pants = mesh(
      loft(
        yRings([
          { y: 0.92, rx: 0.16, ry: 0.12 },
          { y: 0.78, rx: 0.15, ry: 0.12 },
          { y: 0.55, rx: 0.13, ry: 0.1 },
          { y: 0.4, rx: 0.12, ry: 0.09 },
        ]),
        18,
      ),
      opt.boot,
    )
    bob.add(pants)
  }

  // Exposed shoulder girdle. The dress neckline sits below this.
  const shoulders = mesh(
    loft(
      yRings([
        { y: 1.46, rx: 0.09, ry: 0.08 },
        { y: 1.4, rx: 0.2, ry: 0.11 },
        { y: 1.34, rx: 0.22, ry: 0.12 },
        { y: 1.28, rx: 0.14, ry: 0.1 },
      ]),
      20,
    ),
    opt.skin,
  )
  bob.add(shoulders)

  const neck = mesh(
    loft(
      yRings([
        { y: 1.44, rx: 0.055, ry: 0.05 },
        { y: 1.52, rx: 0.05, ry: 0.048 },
      ]),
      14,
    ),
    opt.skin,
  )
  bob.add(neck)

  const headPivot = new THREE.Group()
  headPivot.position.set(0, 1.58, 0)
  headPivot.name = 'head'
  bob.add(headPivot)
  headPivot.add(
    mesh(
      loft(
        yRings([
          { y: -0.09, rx: 0.055, ry: 0.05, z: 0.005 },
          { y: -0.05, rx: 0.075, ry: 0.078, z: 0.0 },
          { y: -0.02, rx: 0.08, ry: 0.086, z: -0.008 },
          { y: 0.02, rx: 0.083, ry: 0.092, z: -0.006 },
          { y: 0.055, rx: 0.084, ry: 0.098, z: 0.004 },
          { y: 0.09, rx: 0.072, ry: 0.088, z: 0.02 },
          { y: 0.12, rx: 0.03, ry: 0.04, z: 0.02 },
        ]),
        20,
      ),
      opt.skin,
    ),
  )

  const nose = mesh(
    loftPath(
      [new THREE.Vector3(0, -0.01, -0.07), new THREE.Vector3(0, 0.01, -0.105), new THREE.Vector3(0, 0.035, -0.09)],
      () => ({ rx: 0.012, ry: 0.012 }),
      8,
    ),
    opt.skin,
    false,
  )
  headPivot.add(nose)

  addEye(headPivot, -0.032, opt)
  addEye(headPivot, 0.032, opt)

  const mouth = new THREE.Mesh(new THREE.SphereGeometry(0.014, 12, 8), opt.lip)
  mouth.scale.set(1.8, 0.45, 0.6)
  mouth.position.set(0, -0.045, -0.086)
  headPivot.add(mouth)

  const hairCap = mesh(
    loft(
      yRings([
        { y: 0.0, rx: 0.086, ry: 0.1, z: 0.01 },
        { y: 0.06, rx: 0.09, ry: 0.1, z: 0.0 },
        { y: 0.11, rx: 0.04, ry: 0.05, z: 0.01 },
      ]),
      16,
    ),
    opt.hair,
  )
  hairCap.scale.setScalar(opt.hairScale ?? 1)
  headPivot.add(hairCap)

  const bangs = mesh(
    loftPath(
      [
        new THREE.Vector3(-0.07, 0.05, -0.04),
        new THREE.Vector3(-0.02, 0.03, -0.09),
        new THREE.Vector3(0.04, 0.025, -0.09),
        new THREE.Vector3(0.08, 0.045, -0.05),
      ],
      () => ({ rx: 0.02, ry: 0.012 }),
      8,
    ),
    opt.hair,
    false,
  )
  headPivot.add(bangs)

  if (opt.tails) {
    headPivot.add(makeTail(-1, opt.hair))
    headPivot.add(makeTail(1, opt.hair))
  }

  bob.add(makeArm(-1, shoulderY, opt))
  bob.add(makeArm(1, shoulderY, opt))
  bob.add(makeLeg(-1, hipY, opt))
  bob.add(makeLeg(1, hipY, opt))

  return root
}

function addEye(head: THREE.Group, x: number, opt: FigureOptions) {
  const sclera = new THREE.Mesh(new THREE.SphereGeometry(0.018, 16, 12), new THREE.MeshPhysicalMaterial({ color: '#f4f1ee', roughness: 0.35 }))
  sclera.position.set(x, 0.02, -0.078)
  sclera.scale.set(1, 0.82, 0.75)
  head.add(sclera)
  const iris = new THREE.Mesh(new THREE.CircleGeometry(0.011, 20), opt.iris)
  iris.position.set(x, 0.02, -0.092)
  iris.rotation.y = Math.PI
  head.add(iris)
  const glaze = new THREE.Mesh(
    new THREE.SphereGeometry(0.019, 16, 12),
    new THREE.MeshPhysicalMaterial({
      color: '#ffffff',
      roughness: 0.04,
      metalness: 0,
      clearcoat: 1,
      clearcoatRoughness: 0.05,
      transparent: true,
      opacity: 0.22,
      depthWrite: false,
    }),
  )
  glaze.position.copy(sclera.position)
  head.add(glaze)
  const lash = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.005, 0.008), new THREE.MeshStandardMaterial({ color: '#14080c', roughness: 0.6 }))
  lash.position.set(x, 0.036, -0.09)
  head.add(lash)
}

function makeTail(side: number, hair: THREE.Material) {
  const pivot = new THREE.Group()
  pivot.name = side < 0 ? 'tailL' : 'tailR'
  pivot.position.set(side * 0.09, 0.04, 0.02)
  const pts: THREE.Vector3[] = []
  for (let i = 0; i < 8; i++) {
    pts.push(new THREE.Vector3(side * i * 0.018, -i * 0.12, i < 3 ? 0.015 : -0.012 * (i - 2)))
  }
  const geo = loftPath(pts, (t) => ({ rx: 0.045 * (1 - t * 0.65), ry: 0.04 * (1 - t * 0.55) }), 10)
  pivot.add(mesh(geo, hair, false))
  const tie = new THREE.Mesh(
    new THREE.TorusGeometry(0.03, 0.008, 8, 16),
    new THREE.MeshStandardMaterial({ color: '#0a0608', roughness: 0.5 }),
  )
  tie.rotation.y = Math.PI / 2
  pivot.add(tie)
  return pivot
}

function makeArm(side: number, shoulderY: number, opt: FigureOptions) {
  const pivot = new THREE.Group()
  pivot.name = side < 0 ? 'armL' : 'armR'
  pivot.position.set(side * 0.18, shoulderY, 0)
  const s = side
  const pts = [
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(s * 0.02, -0.14, 0.01),
    new THREE.Vector3(s * 0.03, -0.28, 0.03),
    new THREE.Vector3(s * 0.015, -0.42, 0.035),
    new THREE.Vector3(0, -0.56, 0.04),
  ]
  pivot.add(
    mesh(
      loftPath(pts, (t) => {
        const rx = THREE.MathUtils.lerp(0.055, 0.03, t)
        const ry = THREE.MathUtils.lerp(0.05, 0.026, t) * (t > 0.45 && t < 0.6 ? 1.15 : 1)
        return { rx, ry }
      }, 12),
      opt.skin,
    ),
  )
  const hand = new THREE.Group()
  hand.position.set(0, -0.58, 0.04)
  const palm = mesh(
    loftPath(
      [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, -0.04, -0.01), new THREE.Vector3(0, -0.07, -0.012)],
      (t) => ({ rx: 0.034 - t * 0.004, ry: 0.014 }),
      10,
    ),
    opt.skin,
    false,
  )
  hand.add(palm)
  for (let f = 0; f < 4; f++) {
    const x = -0.024 + f * 0.016
    const finger = mesh(
      loftPath(
        [
          new THREE.Vector3(x, -0.06, -0.01),
          new THREE.Vector3(x, -0.09, -0.018),
          new THREE.Vector3(x, -0.115, -0.016),
        ],
        (t) => ({ rx: 0.007 - t * 0.002, ry: 0.0055 - t * 0.001 }),
        7,
      ),
      opt.skin,
      false,
    )
    hand.add(finger)
  }
  const thumb = mesh(
    loftPath(
      [
        new THREE.Vector3(s * 0.03, -0.02, -0.008),
        new THREE.Vector3(s * 0.048, -0.045, -0.02),
        new THREE.Vector3(s * 0.05, -0.065, -0.03),
      ],
      (t) => ({ rx: 0.009 - t * 0.002, ry: 0.007 }),
      7,
    ),
    opt.skin,
    false,
  )
  hand.add(thumb)
  pivot.add(hand)
  return pivot
}

function makeLeg(side: number, hipY: number, opt: FigureOptions) {
  const pivot = new THREE.Group()
  pivot.name = side < 0 ? 'legL' : 'legR'
  pivot.position.set(side * 0.09, hipY, 0)
  // Visible lower leg only. The thigh stays inside the skirt or trousers.
  const calf = mesh(
    loftPath(
      [new THREE.Vector3(0, -0.34, 0.01), new THREE.Vector3(0, -0.55, 0.02), new THREE.Vector3(0, -0.72, 0)],
      (t) => ({ rx: THREE.MathUtils.lerp(0.055, 0.038, t), ry: THREE.MathUtils.lerp(0.06, 0.038, t) }),
      12,
    ),
    opt.skin,
  )
  pivot.add(calf)
  const boot = mesh(
    loftPath(
      [
        new THREE.Vector3(0, -0.68, 0),
        new THREE.Vector3(0, -0.8, -0.01),
        new THREE.Vector3(0, -0.84, -0.06),
        new THREE.Vector3(0, -0.85, -0.14),
      ],
      (t) => ({ rx: t < 0.5 ? 0.045 : 0.04, ry: t < 0.6 ? 0.05 : 0.035 }),
      12,
    ),
    opt.boot,
  )
  const heel = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.045, 0.05), opt.boot)
  heel.position.set(0, -0.84, 0.02)
  heel.castShadow = true
  pivot.add(boot)
  pivot.add(heel)
  return pivot
}

export function animateFigure(root: THREE.Object3D, time: number, speed: number) {
  const moving = speed > 0.4
  const phase = time * (3 + Math.min(speed, 7) * 0.45)
  const swing = moving ? Math.sin(phase) * 0.55 : Math.sin(time * 1.3) * 0.04
  const legL = root.getObjectByName('legL')
  const legR = root.getObjectByName('legR')
  const armL = root.getObjectByName('armL')
  const armR = root.getObjectByName('armR')
  const bob = root.getObjectByName('bob')
  const tailL = root.getObjectByName('tailL')
  const tailR = root.getObjectByName('tailR')
  const skirt = root.getObjectByName('skirt')
  if (legL) legL.rotation.x = swing
  if (legR) legR.rotation.x = -swing
  if (armL) armL.rotation.x = -swing * 0.65
  if (armR) armR.rotation.x = swing * 0.65
  if (bob) bob.position.y = moving ? Math.abs(Math.sin(phase)) * 0.035 : 0
  if (skirt) skirt.rotation.z = Math.sin(time * 2) * (moving ? 0.03 : 0.01)
  if (tailL) {
    tailL.rotation.z = 0.12 + Math.sin(time * 2.1) * 0.08
    tailL.rotation.x = 0.15
  }
  if (tailR) {
    tailR.rotation.z = -0.12 - Math.sin(time * 2.1) * 0.08
    tailR.rotation.x = 0.15
  }
}

export function makeMaterials(maps: Maps, opts: { skinTint: string; clothTint: string; hairTint: string; dress: boolean }) {
  const skin = new THREE.MeshPhysicalMaterial({
    map: maps.skin,
    normalMap: maps.skinNormal,
    roughnessMap: maps.skinRough,
    color: opts.skinTint,
    roughness: 0.55,
    metalness: 0,
    sheen: 0.35,
    sheenColor: new THREE.Color('#ffd2c4'),
    sheenRoughness: 0.6,
  })
  skin.normalScale.set(1.5, 1.5)
  const cloth = opts.dress
    ? new THREE.MeshPhysicalMaterial({
        map: maps.lace,
        normalMap: maps.laceNormal,
        color: '#10080c',
        roughness: 0.62,
        metalness: 0.02,
        sheen: 0.85,
        sheenColor: new THREE.Color('#c9a0b4'),
        sheenRoughness: 0.45,
      })
    : new THREE.MeshPhysicalMaterial({
        map: maps.fabric,
        normalMap: maps.fabricNormal,
        color: opts.clothTint,
        roughness: 0.72,
        metalness: 0,
      })
  if (opts.dress) cloth.normalScale.set(1.8, 1.8)
  const hair = new THREE.MeshPhysicalMaterial({
    map: maps.hair,
    normalMap: maps.hairNormal,
    color: opts.hairTint,
    roughness: 0.38,
    metalness: 0.05,
    anisotropy: 0.85,
    sheen: 0.6,
    sheenColor: new THREE.Color(opts.hairTint),
  })
  const boot = new THREE.MeshPhysicalMaterial({
    color: opts.dress ? '#070608' : '#1a1c22',
    roughness: 0.42,
    metalness: 0.15,
    clearcoat: opts.dress ? 0.35 : 0.05,
    clearcoatRoughness: 0.4,
  })
  const iris = new THREE.MeshBasicMaterial({ map: maps.iris, toneMapped: false })
  const lip = new THREE.MeshPhysicalMaterial({ color: '#6a2438', roughness: 0.35, sheen: 0.8, sheenColor: new THREE.Color('#c46a86') })
  return { skin, cloth, hair, boot, iris, lip }
}
