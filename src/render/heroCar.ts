import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js'
import { rainGlass } from './rain'

const loader = new GLTFLoader()

function take(root: THREE.Object3D, name: string) {
  return root.getObjectByName(name) ?? null
}

export async function loadHeroCar(color: string) {
  const gltf = await loader.loadAsync(`${import.meta.env.BASE_URL}models/coupe.glb`)
  const model = gltf.scene
  model.scale.z = -1
  model.rotation.y = Math.PI / 2
  const wrapper = new THREE.Group()
  wrapper.add(model)
  wrapper.userData.steerAxis = 'axle'

  const driverDoorNames = [
    'Separate closed door panel',
    'Single long coupe door glass',
    'Single long coupe door glass rubber seal',
    'Door pull',
    'Door shut seam',
    'Flush handle recess',
    'Coupe door glazing shoulder',
  ]
  const doorPanel = take(model, 'Separate closed door panel')
  const door = new THREE.Group()
  door.name = 'door'
  if (doorPanel instanceof THREE.Mesh) {
    doorPanel.geometry.computeBoundingBox()
    const box = doorPanel.geometry.boundingBox!
    door.position.set(box.min.x + doorPanel.position.x, (box.min.y + box.max.y) / 2 + doorPanel.position.y, box.min.z + doorPanel.position.z)
  }
  model.add(door)
  for (const name of driverDoorNames) {
    const part = take(model, name)
    if (part) door.attach(part)
  }

  const wheelParts = ['Steering wheel rim', 'Steering spoke', 'Steering spoke.001', 'Steering spoke.002', 'Steering boss'].map((name) => take(model, name)).filter((part): part is THREE.Object3D => !!part)
  const steer = new THREE.Group()
  steer.name = 'steer'
  const rim = take(model, 'Steering wheel rim')
  if (rim) {
    rim.updateWorldMatrix(true, false)
    const center = new THREE.Vector3()
    rim.getWorldPosition(center)
    model.worldToLocal(center)
    steer.position.copy(center)
    model.add(steer)
    for (const part of wheelParts) steer.attach(part)
    const axle = new THREE.Vector3(0, 1, 0).applyQuaternion(rim.quaternion)
    wrapper.userData.axle = axle.normalize()
    wrapper.userData.steerBase = steer.quaternion.clone()
  }

  for (const [name, label] of [
    ['Windscreen wiper', 'wiper'],
    ['Windscreen wiper.001', 'wiper'],
  ] as const) {
    const blade = take(model, name)
    if (!blade || !(blade instanceof THREE.Mesh)) continue
    blade.geometry.computeBoundingBox()
    const box = blade.geometry.boundingBox!
    const pivot = new THREE.Group()
    pivot.name = label
    pivot.position.set(-0.8, (box.min.y + box.max.y) * 0.5, (box.min.z + box.max.z) * 0.5)
    model.add(pivot)
    pivot.attach(blade)
  }

  const screen = take(model, 'Raked transparent windscreen')
  if (screen instanceof THREE.Mesh) screen.material = rainGlass()

  const paint = new THREE.MeshPhysicalMaterial({
    color,
    metalness: 0.86,
    roughness: 0.22,
    clearcoat: 1,
    clearcoatRoughness: 0.08,
    envMapIntensity: 1.3,
  })
  const painted = /body shell|bumper|fender|hood|pillar|door panel|roof|quarter|shoulder|splitter|sill/i
  model.traverse((obj) => {
    if (!(obj instanceof THREE.Mesh)) return
    if (painted.test(obj.name) && obj.parent === model) obj.material = paint
  })
  wrapper.userData.paint = paint

  const buckets: THREE.Mesh[][] = [[], [], [], []]
  const wheelName = /tyre|tread|spoke|rim lip|barrel|lug|hub|brake disc|caliper/i
  model.traverse((obj) => {
    if (!(obj instanceof THREE.Mesh) || obj.parent !== model) return
    if (!wheelName.test(obj.name)) return
    obj.geometry.computeBoundingBox()
    const box = obj.geometry.boundingBox
    if (!box) return
    const center = new THREE.Vector3()
    box.getCenter(center).add(obj.position)
    const xi = center.x > 0 ? 1 : 0
    const zi = center.z > 0 ? 1 : 0
    buckets[xi * 2 + zi].push(obj)
  })
  for (const bucket of buckets) {
    if (!bucket.length) continue
    const center = new THREE.Vector3()
    for (const mesh of bucket) {
      mesh.geometry.computeBoundingBox()
      const box = mesh.geometry.boundingBox!
      const c = new THREE.Vector3()
      box.getCenter(c).add(mesh.position)
      center.add(c)
    }
    center.multiplyScalar(1 / bucket.length)
    const pivot = new THREE.Group()
    pivot.name = 'wheel'
    pivot.userData.spin = 'z'
    pivot.position.copy(center)
    model.add(pivot)
    for (const mesh of bucket) pivot.attach(mesh)
  }

  mergeLoose(model)
  wrapper.traverse((obj) => {
    if (obj instanceof THREE.Mesh) {
      obj.castShadow = true
      obj.receiveShadow = true
    }
  })
  return wrapper
}

function mergeLoose(root: THREE.Object3D) {
  const groups = new Map<string, { mat: THREE.Material; geos: THREE.BufferGeometry[] }>()
  const drop: THREE.Mesh[] = []
  for (const child of [...root.children]) {
    if (!(child instanceof THREE.Mesh)) continue
    if (child.name === 'door' || child.name === 'steer' || child.name === 'wiper' || child.name === 'wheel') continue
    const mat = child.material
    if (Array.isArray(mat) || !child.geometry) continue
    const geo = child.geometry.clone()
    geo.applyMatrix4(child.matrix)
    const key = mat.uuid
    const slot = groups.get(key) ?? { mat, geos: [] as THREE.BufferGeometry[] }
    slot.geos.push(geo)
    groups.set(key, slot)
    drop.push(child)
  }
  for (const mesh of drop) root.remove(mesh)
  for (const { mat, geos } of groups.values()) {
    let merged: THREE.BufferGeometry | null = null
    try {
      merged = geos.length === 1 ? geos[0] : mergeGeometries(geos, false)
    } catch {
      merged = null
    }
    if (!merged) {
      for (const geo of geos) root.add(new THREE.Mesh(geo, mat))
      continue
    }
    root.add(new THREE.Mesh(merged, mat))
  }
}
