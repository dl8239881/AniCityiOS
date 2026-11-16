import { useEffect, useMemo, useRef, type MutableRefObject } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import { EffectComposer, Bloom, Vignette } from '@react-three/postprocessing'
import * as THREE from 'three'
import { Game } from '../sim/game'
import { SOLIDS } from '../sim/world'
import { readGamepad } from '../input'
import { cityMaterials, type Maps } from './materials'
import { animateFigure, createFigure, makeMaterials } from './human'
import { createCar } from './cars'

const scratch = new THREE.Color()
const wreck = new THREE.Color('#241816')

function signTexture(text: string, fg: string) {
  const canvas = document.createElement('canvas')
  canvas.width = 512
  canvas.height = 160
  const ctx = canvas.getContext('2d')!
  ctx.fillStyle = '#07010f'
  ctx.fillRect(0, 0, 512, 160)
  ctx.font = '700 72px Avenir Next, Segoe UI, sans-serif'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillStyle = '#3d8bff'
  ctx.fillText(text, 258, 84)
  ctx.fillStyle = fg
  ctx.fillText(text, 252, 78)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  return texture
}

function City({ maps, nightRef }: { maps: Maps; nightRef: MutableRefObject<number> }) {
  const mats = useMemo(() => cityMaterials(maps), [maps])
  const signs = useMemo(
    () =>
      [
        { text: 'LACE BURGER', pos: [0, 5.4, -36.3] as const, rot: Math.PI, color: '#ff4d9a', w: 6.4 },
        { text: 'LACE HOUSE  $750', pos: [37, 3.2, -33.4] as const, rot: Math.PI, color: '#9ecbff', w: 4.6 },
        { text: 'ANI CITY', pos: [0, 3.1, -2.4] as const, rot: Math.PI, color: '#f2f4ff', w: 5.2 },
        { text: 'IMPOUND', pos: [-36, 2.4, -45.2] as const, rot: 0, color: '#ff4d9a', w: 3.2 },
      ].map((sign) => ({ ...sign, map: signTexture(sign.text, sign.color) })),
    [],
  )
  useFrame(() => {
    mats.downtown.emissiveIntensity = 0.25 + nightRef.current * 1.35
    mats.hood.emissiveIntensity = 0.08 + nightRef.current * 0.28
  })
  return (
    <group>
      <mesh rotation-x={-Math.PI / 2} position={[0, 0, 0]} receiveShadow>
        <planeGeometry args={[220, 220]} />
        <meshStandardMaterial color="#07080c" roughness={0.95} />
      </mesh>
      <mesh rotation-x={-Math.PI / 2} position={[0, 0.03, 0]} receiveShadow>
        <planeGeometry args={[132, 132]} />
        <primitive object={mats.asphalt} attach="material" />
      </mesh>
      {SOLIDS.map((solid) => {
        const width = solid.maxX - solid.minX
        const depth = solid.maxZ - solid.minZ
        const roof = solid.style === 'roof'
        const height = roof ? 0.22 : solid.h
        const y = roof ? solid.h - 0.1 : height / 2
        const material =
          solid.style === 'downtown'
            ? mats.downtown
            : solid.style === 'hood'
              ? mats.hood
              : solid.style === 'brick'
                ? mats.brick
                : solid.style === 'food'
                  ? mats.food
                  : solid.style === 'house'
                    ? mats.house
                    : solid.style === 'roof'
                      ? mats.roof
                      : mats.concrete
        return (
          <mesh key={solid.name} name={solid.name} position={[(solid.minX + solid.maxX) / 2, y, (solid.minZ + solid.maxZ) / 2]} castShadow={!roof} receiveShadow>
            <boxGeometry args={[width, height, depth]} />
            <primitive object={material} attach="material" />
          </mesh>
        )
      })}
      {signs.map((sign) => (
        <mesh key={sign.text} position={sign.pos} rotation-y={sign.rot}>
          <planeGeometry args={[sign.w, sign.w * 0.28]} />
          <meshStandardMaterial map={sign.map} emissive={sign.color} emissiveIntensity={1.4} toneMapped={false} />
        </mesh>
      ))}
      <mesh position={[0, 0.4, 0]}>
        <cylinderGeometry args={[1.5, 1.6, 0.35, 24]} />
        <meshStandardMaterial color="#16324f" emissive="#3d8bff" emissiveIntensity={0.4} roughness={0.15} metalness={0.4} />
      </mesh>
    </group>
  )
}

function Sky({ nightRef }: { nightRef: MutableRefObject<number> }) {
  const mat = useMemo(
    () =>
      new THREE.ShaderMaterial({
        side: THREE.BackSide,
        uniforms: { uNight: { value: 1 } },
        vertexShader: `varying vec3 vP; void main(){ vP = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
        fragmentShader: `
          varying vec3 vP;
          uniform float uNight;
          void main() {
            float h = normalize(vP).y;
            vec3 night = mix(vec3(0.015, 0.004, 0.03), vec3(0.09, 0.04, 0.16), smoothstep(-0.15, 0.55, h));
            vec3 day = mix(vec3(0.35, 0.55, 0.85), vec3(0.75, 0.84, 0.95), smoothstep(-0.2, 0.6, h));
            vec3 col = mix(day, night, uNight);
            float stars = step(0.996, fract(sin(dot(floor(normalize(vP) * 90.0), vec3(12.9, 78.2, 37.1))) * 43758.5));
            col += stars * uNight * 0.85;
            gl_FragColor = vec4(col, 1.0);
          }
        `,
      }),
    [],
  )
  useFrame(() => {
    mat.uniforms.uNight.value = nightRef.current
  })
  return (
    <mesh frustumCulled={false}>
      <sphereGeometry args={[180, 32, 20]} />
      <primitive object={mat} attach="material" />
    </mesh>
  )
}

function Rain() {
  const ref = useRef<THREE.Points>(null)
  const count = 700
  const positions = useMemo(() => {
    const data = new Float32Array(count * 3)
    for (let i = 0; i < count; i++) {
      data[i * 3] = (Math.random() - 0.5) * 130
      data[i * 3 + 1] = Math.random() * 28
      data[i * 3 + 2] = (Math.random() - 0.5) * 130
    }
    return data
  }, [])
  useFrame((_, dt) => {
    const attr = ref.current?.geometry.getAttribute('position')
    if (!attr) return
    const array = attr.array as Float32Array
    for (let i = 0; i < count; i++) {
      array[i * 3 + 1] -= dt * 22
      array[i * 3] -= dt * 4
      if (array[i * 3 + 1] < 0) array[i * 3 + 1] = 26
    }
    attr.needsUpdate = true
  })
  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial color="#d5e2ff" size={0.07} transparent opacity={0.35} depthWrite={false} />
    </points>
  )
}

function Reflections() {
  const gl = useThree((s) => s.gl)
  const scene = useThree((s) => s.scene)
  useEffect(() => {
    const pmrem = new THREE.PMREMGenerator(gl)
    const room = new THREE.Scene()
    room.add(new THREE.Mesh(new THREE.BoxGeometry(12, 8, 12), new THREE.MeshBasicMaterial({ color: '#070014', side: THREE.BackSide })))
    const panel = (color: string, x: number, y: number, z: number, rx = 0, ry = 0) => {
      const mesh = new THREE.Mesh(new THREE.PlaneGeometry(4, 2.2), new THREE.MeshBasicMaterial({ color }))
      mesh.position.set(x, y, z)
      mesh.rotation.set(rx, ry, 0)
      room.add(mesh)
    }
    panel('#ff2f8a', 0, 2, -5)
    panel('#3d8bff', -5, 1.5, 0, 0, Math.PI / 2)
    panel('#7a4dff', 5, 2.4, 0, 0, -Math.PI / 2)
    panel('#ffd0a0', 0, 6, 0, Math.PI / 2, 0)
    const target = pmrem.fromScene(room, 0.04)
    scene.environment = target.texture
    scene.environmentIntensity = 0.85
    return () => {
      target.texture.dispose()
      pmrem.dispose()
    }
  }, [gl, scene])
  return null
}

export function SceneRoot({ sim, maps }: { sim: Game; maps: Maps }) {
  const nightRef = useRef(1)
  const actors = useMemo(() => {
    const aniMats = makeMaterials(maps, { skinTint: '#ffd0be', clothTint: '#111', hairTint: '#f2d27a', dress: true })
    const ani = createFigure({ ...aniMats, dress: true, tails: true })
    const people = sim.peds.map((ped) => {
      const mats = makeMaterials(maps, { skinTint: ped.tint, clothTint: ped.cloth, hairTint: ped.hair, dress: false })
      return createFigure({ ...mats, dress: false, tails: false, hairScale: 0.9 })
    })
    const cars = sim.cars.map((car) => createCar(car.kind, car.color))
    return { ani, people, cars }
  }, [maps, sim])

  useFrame((state, dt) => {
    readGamepad()
    sim.update(dt)
    nightRef.current = sim.night
    const fog = state.scene.fog as THREE.Fog | null
    if (fog) fog.color.set(sim.night > 0.5 ? '#120614' : '#9eb8d4')

    const { ani, people, cars } = actors
    ani.visible = !sim.driving
    ani.position.set(sim.px, 0, sim.pz)
    const yaw = ani.getObjectByName('yaw')
    if (yaw) yaw.rotation.y = sim.pyaw
    animateFigure(ani, sim.time, sim.driving ? 0 : sim.foot)

    sim.peds.forEach((ped, i) => {
      const group = people[i]
      group.visible = ped.down < 10.2
      group.position.set(ped.x, ped.down > 0 ? 0.15 : 0, ped.z)
      const pedYaw = group.getObjectByName('yaw')
      if (pedYaw) {
        pedYaw.rotation.y = ped.yaw
        pedYaw.rotation.x = ped.down > 0 ? 1.2 : 0
      }
      animateFigure(group, sim.time + i, ped.down > 0 ? 0 : ped.speed)
    })

    sim.cars.forEach((car, i) => {
      const group = cars[i]
      group.visible = car.alive
      group.position.set(car.x + car.ox, 0, car.z + car.oz)
      group.rotation.y = car.yaw
      group.traverse((obj) => {
        if (obj.name === 'wheel') obj.rotation.y = car.wheel
      })
      const paint = group.userData.paint as THREE.MeshPhysicalMaterial | undefined
      if (paint) {
        scratch.set(car.color).lerp(wreck, 1 - car.condition / 100)
        paint.color.copy(scratch)
      }
      const red = group.getObjectByName('sirenR')
      const blue = group.getObjectByName('sirenB')
      const flash = Math.sin(sim.time * 18) > 0
      if (red) red.visible = flash
      if (blue) blue.visible = !flash
      const siren = group.getObjectByName('sirenLight') as THREE.PointLight | null
      if (siren) siren.color.set(flash ? '#ff3355' : '#3d7bff')
    })

    const foodRoof = state.scene.getObjectByName('food-roof')
    const homeRoof = state.scene.getObjectByName('home-roof')
    if (foodRoof) foodRoof.visible = !sim.insideFood()
    if (homeRoof) homeRoof.visible = !sim.insideHome()

    const indoors = sim.insideFood() || sim.insideHome()
    const distance = sim.driving ? 8.4 : indoors ? 3.3 : 5.1
    const look = forward(sim.camYaw)
    const targetY = sim.driving ? 1.05 : 1.35
    const horizontal = Math.cos(sim.camPitch) * distance
    const vertical = Math.sin(sim.camPitch) * distance
    state.camera.position.set(sim.px - look.x * horizontal, targetY + vertical, sim.pz - look.z * horizontal)
    state.camera.lookAt(sim.px, targetY, sim.pz)
  })

  return (
    <>
      <color attach="background" args={['#07010f']} />
      <fog attach="fog" args={['#120614', 22, 110]} />
      <hemisphereLight args={['#8aa0ff', '#3a1422', 0.55]} />
      <ambientLight intensity={0.18} color="#6a4a78" />
      <directionalLight
        position={[30, 48, 12]}
        intensity={1.15}
        color="#d7e4ff"
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-camera-near={5}
        shadow-camera-far={140}
        shadow-camera-left={-70}
        shadow-camera-right={70}
        shadow-camera-top={70}
        shadow-camera-bottom={-70}
        shadow-bias={-0.0004}
      />
      <directionalLight position={[0, 6, 8]} intensity={0.9} color="#ffe4f2" />
      <directionalLight position={[-18, 8, -24]} intensity={0.55} color="#ff4d9a" />
      <directionalLight position={[22, 6, 16]} intensity={0.4} color="#4aa0ff" />
      <Reflections />
      <Sky nightRef={nightRef} />
      <City maps={maps} nightRef={nightRef} />
      <primitive object={actors.ani} />
      {actors.people.map((person, i) => (
        <primitive key={i} object={person} />
      ))}
      {actors.cars.map((car, i) => (
        <primitive key={i} object={car} />
      ))}
      <Rain />
      <EffectComposer multisampling={4} enableNormalPass={false}>
        <Bloom luminanceThreshold={0.72} mipmapBlur intensity={0.85} luminanceSmoothing={0.2} />
        <Vignette eskil={false} offset={0.18} darkness={0.72} />
      </EffectComposer>
    </>
  )
}

function forward(yaw: number) {
  return { x: -Math.sin(yaw), z: -Math.cos(yaw) }
}
