import * as THREE from 'three'

export type Maps = {
  asphalt: THREE.Texture
  asphaltNormal: THREE.Texture
  asphaltRough: THREE.Texture
  facade: THREE.Texture
  facadeEmit: THREE.Texture
  brick: THREE.Texture
  brickNormal: THREE.Texture
  concrete: THREE.Texture
  concreteNormal: THREE.Texture
  hood: THREE.Texture
  skin: THREE.Texture
  skinNormal: THREE.Texture
  skinRough: THREE.Texture
  lace: THREE.Texture
  laceNormal: THREE.Texture
  fabric: THREE.Texture
  fabricNormal: THREE.Texture
  hair: THREE.Texture
  hairNormal: THREE.Texture
  iris: THREE.Texture
}

const FILES: { key: keyof Maps; file: string; srgb: boolean; repeat: number }[] = [
  { key: 'asphalt', file: 'asphalt.jpg', srgb: true, repeat: 10 },
  { key: 'asphaltNormal', file: 'asphalt_normal.png', srgb: false, repeat: 10 },
  { key: 'asphaltRough', file: 'asphalt_rough.png', srgb: false, repeat: 10 },
  { key: 'facade', file: 'facade.jpg', srgb: true, repeat: 1 },
  { key: 'facadeEmit', file: 'facade_emit.jpg', srgb: true, repeat: 1 },
  { key: 'brick', file: 'brick.jpg', srgb: true, repeat: 2 },
  { key: 'brickNormal', file: 'brick_normal.png', srgb: false, repeat: 2 },
  { key: 'concrete', file: 'concrete.jpg', srgb: true, repeat: 2 },
  { key: 'concreteNormal', file: 'concrete_normal.png', srgb: false, repeat: 2 },
  { key: 'hood', file: 'hood.jpg', srgb: true, repeat: 1 },
  { key: 'skin', file: 'skin.jpg', srgb: true, repeat: 1 },
  { key: 'skinNormal', file: 'skin_normal.png', srgb: false, repeat: 1 },
  { key: 'skinRough', file: 'skin_rough.png', srgb: false, repeat: 1 },
  { key: 'lace', file: 'lace.jpg', srgb: true, repeat: 3 },
  { key: 'laceNormal', file: 'lace_normal.png', srgb: false, repeat: 3 },
  { key: 'fabric', file: 'fabric.jpg', srgb: true, repeat: 2 },
  { key: 'fabricNormal', file: 'fabric_normal.png', srgb: false, repeat: 2 },
  { key: 'hair', file: 'hair.jpg', srgb: true, repeat: 1 },
  { key: 'hairNormal', file: 'hair_normal.png', srgb: false, repeat: 1 },
  { key: 'iris', file: 'iris.jpg', srgb: true, repeat: 1 },
]

export function loadMaps() {
  const loader = new THREE.TextureLoader()
  const base = import.meta.env.BASE_URL
  return Promise.all(
    FILES.map(
      (spec) =>
        new Promise<[keyof Maps, THREE.Texture]>((resolve, reject) => {
          loader.load(
            `${base}textures/${spec.file}`,
            (texture) => {
              texture.colorSpace = spec.srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace
              texture.wrapS = texture.wrapT = THREE.RepeatWrapping
              texture.repeat.set(spec.repeat, spec.repeat)
              texture.anisotropy = 8
              resolve([spec.key, texture])
            },
            undefined,
            () => reject(new Error(`texture ${spec.file}`)),
          )
        }),
    ),
  ).then((pairs) => {
    const maps = {} as Maps
    for (const [key, texture] of pairs) maps[key] = texture
    return maps
  })
}

export function cityMaterials(maps: Maps) {
  const roof = new THREE.MeshStandardMaterial({ color: '#121018', roughness: 0.85, metalness: 0.05 })
  const downtown = new THREE.MeshStandardMaterial({
    map: maps.facade,
    emissiveMap: maps.facadeEmit,
    emissive: new THREE.Color('#ffffff'),
    emissiveIntensity: 1.15,
    roughness: 0.72,
    metalness: 0.08,
  })
  const hood = new THREE.MeshStandardMaterial({
    map: maps.hood,
    roughness: 0.78,
    metalness: 0.02,
    emissiveMap: maps.hood,
    emissive: new THREE.Color('#ffffff'),
    emissiveIntensity: 0.18,
  })
  const brick = new THREE.MeshStandardMaterial({
    map: maps.brick,
    normalMap: maps.brickNormal,
    roughness: 0.86,
    metalness: 0,
  })
  const food = new THREE.MeshStandardMaterial({
    color: '#2a1020',
    roughness: 0.55,
    metalness: 0.08,
    emissive: new THREE.Color('#ff2f7a'),
    emissiveIntensity: 0.08,
  })
  const house = new THREE.MeshStandardMaterial({
    color: '#1a2040',
    map: maps.concrete,
    roughness: 0.6,
    metalness: 0.12,
    emissive: new THREE.Color('#3d8bff'),
    emissiveIntensity: 0.05,
  })
  const concrete = new THREE.MeshStandardMaterial({
    map: maps.concrete,
    normalMap: maps.concreteNormal,
    roughness: 0.8,
    metalness: 0.04,
  })
  const asphalt = new THREE.MeshPhysicalMaterial({
    map: maps.asphalt,
    normalMap: maps.asphaltNormal,
    roughnessMap: maps.asphaltRough,
    color: '#9aa0b0',
    roughness: 0.35,
    metalness: 0.72,
    clearcoat: 0.45,
    clearcoatRoughness: 0.25,
  })
  return { roof, downtown, hood, brick, food, house, concrete, asphalt }
}
