import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { clone as cloneSkinned } from 'three/examples/jsm/utils/SkeletonUtils.js'
import type { Maps } from './materials'
import { createCar } from './cars'
import { loadHeroCar } from './heroCar'
import type { CarKind } from '../sim/game'

export type Pose = 'locomotion' | 'sit' | 'down'

type WetSlot = { mat: THREE.MeshStandardMaterial; color: THREE.Color; rough: number }

export type Human = {
  root: THREE.Group
  update: (dt: number, speed: number, pose: Pose, wet: number, distance: number) => void
  face: (yaw: number, tilt: number) => void
  grip: (on: boolean) => void
}

export type Cast = {
  ani: Human
  mate: Human
  peds: Human[]
  cops: Human[]
  cars: THREE.Group[]
}

const loader = new GLTFLoader()

function url(file: string) {
  return `${import.meta.env.BASE_URL}models/${file}`
}

function loadGltf(file: string) {
  return loader.loadAsync(url(file))
}

function laceMaterial(maps: Maps) {
  const mat = new THREE.MeshPhysicalMaterial({
    map: maps.lace,
    normalMap: maps.laceNormal,
    color: '#12060c',
    roughness: 0.62,
    metalness: 0.04,
    sheen: 0.4,
    sheenRoughness: 0.7,
    sheenColor: new THREE.Color('#2a1520'),
    envMapIntensity: 0.35,
    side: THREE.DoubleSide,
  })
  mat.normalScale.set(1.5, 1.5)
  return mat
}

function hairAlpha() {
  const canvas = document.createElement('canvas')
  canvas.width = 128
  canvas.height = 512
  const ctx = canvas.getContext('2d')!
  ctx.fillStyle = '#000'
  ctx.fillRect(0, 0, 128, 512)
  for (let i = 0; i < 9; i++) {
    const x = 14 + i * 12
    ctx.strokeStyle = '#fff'
    ctx.lineWidth = 1.2
    ctx.beginPath()
    ctx.moveTo(x, 8)
    ctx.bezierCurveTo(x + 6, 180, x - 8, 340, x + 2, 500)
    ctx.stroke()
  }
  const tex = new THREE.CanvasTexture(canvas)
  tex.colorSpace = THREE.NoColorSpace
  return tex
}

function cloneMaterials(root: THREE.Object3D) {
  root.traverse((obj) => {
    const mesh = obj as THREE.Mesh
    if (!mesh.isMesh || !mesh.material) return
    mesh.frustumCulled = false
    if (Array.isArray(mesh.material)) mesh.material = mesh.material.map((m) => m.clone())
    else mesh.material = mesh.material.clone()
  })
}

function eachMaterial(mesh: THREE.Mesh, fn: (mat: THREE.Material) => void) {
  const material = mesh.material
  if (Array.isArray(material)) material.forEach(fn)
  else fn(material)
}

function placeOnBone(bone: THREE.Object3D, mesh: THREE.Object3D, worldPoint: THREE.Vector3) {
  bone.updateWorldMatrix(true, false)
  const local = bone.worldToLocal(worldPoint.clone())
  mesh.position.copy(local)
  bone.add(mesh)
}

function worldAxes(bone: THREE.Object3D) {
  bone.updateWorldMatrix(true, false)
  const origin = new THREE.Vector3()
  const quat = new THREE.Quaternion()
  bone.getWorldPosition(origin)
  bone.getWorldQuaternion(quat)
  const up = new THREE.Vector3(0, 1, 0).applyQuaternion(quat)
  const forward = new THREE.Vector3(0, 0, 1).applyQuaternion(quat)
  const right = new THREE.Vector3(1, 0, 0).applyQuaternion(quat)
  if (up.y < 0) up.multiplyScalar(-1)
  if (forward.z < 0) forward.multiplyScalar(-1)
  return { origin, up, forward, right }
}

function dress(root: THREE.Object3D, maps: Maps, opts: { ani: boolean; police: boolean; hair: string; cloth: string }) {
  const wet: WetSlot[] = []
  const detail: THREE.Object3D[] = []
  const lod: THREE.Object3D[] = []
  const arms: THREE.Bone[] = []
  root.traverse((obj) => {
    if ((obj as THREE.Bone).isBone && /^(lowerarm_[lr]|hand_[lr]|CC_Base_[LR]_(Forearm|Hand))$/.test(obj.name)) {
      arms.push(obj as THREE.Bone)
    }
  })
  const head = root.getObjectByName('head')
  const pelvis = root.getObjectByName('pelvis')
  const lace = opts.ani ? laceMaterial(maps) : null
  const tails: THREE.Object3D[] = []
  root.traverse((obj) => {
    const mesh = obj as THREE.Mesh
    if (!mesh.isMesh) return
    const name = mesh.name.toLowerCase()
    if (name.includes('accessory') || name.includes('phone') || name.includes('briefcase')) {
      mesh.visible = false
      return
    }
    if (name.includes('low-poly')) {
      mesh.visible = false
      lod.push(mesh)
      return
    }
    detail.push(mesh)
    if (opts.ani && (name.includes('short') || name.includes('hairline'))) {
      mesh.visible = false
      mesh.userData.hidden = true
      return
    }
    if (opts.ani && lace && name.includes('suit')) {
      mesh.material = lace
      wet.push({ mat: lace, color: lace.color.clone(), rough: lace.roughness })
      return
    }
    eachMaterial(mesh, (mat) => {
      const standard = mat as THREE.MeshPhysicalMaterial
      if (!standard.color) return
      if (name.includes('suit') || name.includes('shirt')) {
        standard.color.multiply(new THREE.Color(opts.cloth))
        if (opts.police) standard.color.set('#1a2744')
      }
      if (name.includes('short') || name.includes('hair') || name.includes('afro') || name.includes('braid')) {
        standard.color.multiply(new THREE.Color(opts.hair))
      }
      if ((name.includes('anatomical') || standard.name.toLowerCase().includes('skin')) && standard.isMeshPhysicalMaterial) {
        standard.sheen = 1
        standard.sheenRoughness = 0.42
        standard.sheenColor = new THREE.Color('#ffb3a6')
        standard.envMapIntensity = 0.55
      }
      if ('roughness' in standard && standard.color) {
        wet.push({ mat: standard, color: standard.color.clone(), rough: standard.roughness ?? 0.6 })
      }
    })
  })
  if (head) {
    const { origin, up, forward, right } = worldAxes(head)
    const eyeMat = new THREE.MeshPhysicalMaterial({
      color: '#d5ecff',
      roughness: 0.04,
      metalness: 0.02,
      clearcoat: 1,
      clearcoatRoughness: 0.03,
      transparent: true,
      opacity: 0.42,
      envMapIntensity: 2.2,
      depthWrite: false,
    })
    const irisMat = new THREE.MeshBasicMaterial({
      map: maps.iris,
      color: opts.ani ? '#d7ecff' : '#ffffff',
    })
    for (const side of [-1, 1]) {
      const iris = new THREE.Mesh(new THREE.CircleGeometry(0.014, 16), irisMat)
      const cornea = new THREE.Mesh(new THREE.SphereGeometry(0.018, 14, 10), eyeMat)
      const at = origin.clone().addScaledVector(up, 0.045).addScaledVector(forward, 0.085).addScaledVector(right, 0.032 * side)
      placeOnBone(head, cornea, at)
      placeOnBone(head, iris, at.clone().addScaledVector(forward, 0.012))
      iris.lookAt(at.clone().add(forward))
      detail.push(cornea, iris)
    }
    if (opts.ani) {
      const cards = hairAlpha()
      const hairMat = new THREE.MeshStandardMaterial({
        alphaMap: cards,
        alphaTest: 0.45,
        roughness: 0.4,
        color: '#f3d78a',
        side: THREE.DoubleSide,
      })
      for (const side of [-1, 1]) {
        const tail = new THREE.Group()
        const lock = new THREE.Mesh(
          new THREE.CylinderGeometry(0.028, 0.012, 0.72, 7),
          new THREE.MeshStandardMaterial({ color: '#e7c56e', roughness: 0.42 }),
        )
        lock.position.y = -0.34
        tail.add(lock)
        detail.push(lock)
        for (let i = 0; i < 3; i++) {
          const card = new THREE.Mesh(new THREE.PlaneGeometry(0.07, 0.78), hairMat)
          card.position.set((i - 1) * 0.012, -0.36, 0)
          card.rotation.y = i * 0.5
          tail.add(card)
          detail.push(card)
        }
        const anchor = origin.clone().addScaledVector(up, 0.02).addScaledVector(right, 0.08 * side).addScaledVector(forward, -0.06)
        placeOnBone(head, tail, anchor)
        tails.push(tail)
      }
      if (pelvis) {
        const skirt = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.46, 0.78, 18, 1, true), lace!)
        skirt.castShadow = true
        const hip = new THREE.Vector3()
        pelvis.getWorldPosition(hip)
        placeOnBone(pelvis, skirt, hip.clone().add(new THREE.Vector3(0, -0.42, 0.02)))
        const pq = new THREE.Quaternion()
        pelvis.getWorldQuaternion(pq)
        const localUp = new THREE.Vector3(0, 1, 0).applyQuaternion(pq.invert())
        skirt.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), localUp.normalize())
        detail.push(skirt)
      }
    }
    if (opts.police) {
      const cap = new THREE.Mesh(
        new THREE.BoxGeometry(0.18, 0.05, 0.2),
        new THREE.MeshStandardMaterial({ color: '#141a24', roughness: 0.55 }),
      )
      const brim = new THREE.Mesh(
        new THREE.BoxGeometry(0.18, 0.012, 0.08),
        new THREE.MeshStandardMaterial({ color: '#0e1218', roughness: 0.4 }),
      )
      const crown = origin.clone().addScaledVector(up, 0.12)
      placeOnBone(head, cap, crown)
      placeOnBone(head, brim, crown.clone().addScaledVector(forward, 0.1).addScaledVector(up, -0.02))
      detail.push(cap, brim)
    }
  }
  return { wet, detail, lod, arms, tails }
}

function makeHuman(source: THREE.Group, clips: THREE.AnimationClip[], maps: Maps, opts: { ani: boolean; police: boolean; hair: string; cloth: string }): Human {
  const root = cloneSkinned(source) as THREE.Group
  cloneMaterials(root)
  const parts = dress(root, maps, opts)
  const mixer = new THREE.AnimationMixer(root)
  const actions: Record<string, THREE.AnimationAction> = {}
  for (const clip of clips) actions[clip.name] = mixer.clipAction(clip)
  let current = 'Idle_Standing'
  actions[current]?.play()
  root.rotation.order = 'YXZ'
  const gripL = new THREE.Quaternion().setFromEuler(new THREE.Euler(0.7, 0.15, 0.9))
  const gripR = new THREE.Quaternion().setFromEuler(new THREE.Euler(0.7, -0.15, -0.9))
  let gripping = false
  return {
    root,
    face(yaw: number, tilt: number) {
      root.rotation.y = yaw + Math.PI
      root.rotation.x = tilt
    },
    grip(on: boolean) {
      gripping = on
    },
    update(dt, speed, pose, wet, distance) {
      const far = distance > 16
      const visible = root.visible
      for (const mesh of parts.detail) mesh.visible = visible && !far && mesh.userData.hidden !== true
      for (const mesh of parts.lod) mesh.visible = visible && far
      if (!visible) return
      let name = 'Idle_Standing'
      if (pose === 'sit') name = 'Sit_Stand'
      else if (pose === 'down') name = 'Idle_Standing'
      else if (speed > 5.5) name = 'Run'
      else if (speed > 3.3) name = 'Jog'
      else if (speed > 0.35) name = 'Walk_Relaxed'
      if (name !== current && actions[name]) {
        actions[name].reset().fadeIn(0.18).play()
        actions[current]?.fadeOut(0.18)
        current = name
      }
      const sit = actions.Sit_Stand
      if (sit) {
        if (pose === 'sit') {
          sit.paused = true
          sit.time = Math.min(2.35, sit.getClip().duration * 0.4)
        } else sit.paused = false
      }
      mixer.update(dt)
      const parentQuat = new THREE.Quaternion()
      for (const tail of parts.tails) {
        tail.parent?.getWorldQuaternion(parentQuat)
        tail.quaternion.copy(parentQuat.invert())
      }
      if (gripping) {
        for (const bone of parts.arms) {
          const left = bone.name.endsWith('_l') || bone.name.includes('_L_')
          if (left) bone.quaternion.multiply(gripL)
          else bone.quaternion.multiply(gripR)
        }
      }
      const shade = 1 - 0.2 * wet
      for (const slot of parts.wet) {
        slot.mat.roughness = Math.max(0.08, slot.rough * (1 - 0.58 * wet))
        slot.mat.color.copy(slot.color).multiplyScalar(shade)
      }
    },
  }
}

function clipAlias(clip: THREE.AnimationClip) {
  const name = clip.name.replace(/_Camila$/, '').replace(/_Armature$/, '')
  if (name !== clip.name) clip.name = name
  return clip
}

export async function loadCast(
  maps: Maps,
  peds: { hair: string; cloth: string }[],
  cars: { kind: CarKind; color: string }[],
): Promise<Cast> {
  const [aniFile, harper, sam, hero] = await Promise.all([
    loadGltf('ani.glb'),
    loadGltf('harper.glb'),
    loadGltf('sam.glb'),
    loadHeroCar('#07070c').catch(() => null),
  ])
  aniFile.animations.forEach(clipAlias)
  const ani = makeHuman(aniFile.scene, aniFile.animations, maps, { ani: false, police: false, hair: '#f2d27a', cloth: '#111111' })
  const mate = makeHuman(sam.scene, sam.animations, maps, { ani: false, police: false, hair: '#1c140f', cloth: '#243044' })
  const people = peds.map((ped, i) => {
    const female = i % 2 === 0
    const src = female ? harper : sam
    return makeHuman(src.scene, src.animations, maps, { ani: false, police: false, hair: ped.hair, cloth: ped.cloth })
  })
  const copCount = cars.filter((car) => car.kind === 'police').length
  const cops = Array.from({ length: copCount }, () =>
    makeHuman(sam.scene, sam.animations, maps, { ani: false, police: true, hair: '#1a1a1a', cloth: '#1a2744' }),
  )
  const meshes = cars.map((car, i) => {
    if (i === 0 && car.kind === 'sports' && hero) return hero
    return createCar(car.kind, car.color)
  })
  return { ani, mate, peds: people, cops, cars: meshes }
}
