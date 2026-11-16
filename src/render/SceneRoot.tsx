import { useEffect, useMemo, useRef, type MutableRefObject } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import { EffectComposer, Bloom, Vignette } from '@react-three/postprocessing'
import * as THREE from 'three'
import { Game } from '../sim/game'
import { SOLIDS } from '../sim/world'
import { readGamepad } from '../input'
import { cityMaterials, type Maps } from './materials'
import type { Cast } from './people'
import { touchRain } from './rain'

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
      <Dressing />
    </group>
  )
}

const LAMPS: [number, number][] = [
  [-11.2, -11.2],
  [11.2, -11.2],
  [-11.2, 11.2],
  [11.2, 11.2],
  [-47, -11],
  [47, -11],
  [-11, 40],
  [22, -40],
  [40, 11],
  [-40, 22],
]

const PUDDLES: [number, number, number][] = [
  [-16, -20, 2.4],
  [20, -16, 1.8],
  [-20, 16, 2.1],
  [16, 20, 2.2],
  [2, -14, 2.6],
  [-30, -42, 1.6],
  [34, 2, 1.7],
  [4, 16, 2.2],
]

function Dressing() {
  const puddle = useMemo(
    () =>
      new THREE.MeshPhysicalMaterial({
        color: '#0c1420',
        metalness: 0.15,
        roughness: 0.04,
        clearcoat: 1,
        clearcoatRoughness: 0.05,
        envMapIntensity: 1.8,
        transparent: true,
        opacity: 0.72,
      }),
    [],
  )
  return (
    <group>
      {PUDDLES.map(([x, z, s]) => (
        <mesh key={`${x}-${z}`} position={[x, 0.045, z]} rotation-x={-Math.PI / 2} receiveShadow>
          <circleGeometry args={[s, 20]} />
          <primitive object={puddle} attach="material" />
        </mesh>
      ))}
      {LAMPS.map(([x, z]) => (
        <group key={`${x}-${z}`} position={[x, 0, z]}>
          <mesh position={[0, 2.1, 0]} castShadow>
            <cylinderGeometry args={[0.06, 0.08, 4.2, 8]} />
            <meshStandardMaterial color="#2a2e38" metalness={0.7} roughness={0.35} />
          </mesh>
          <mesh position={[0, 4.25, 0]}>
            <boxGeometry args={[0.55, 0.08, 0.28]} />
            <meshStandardMaterial color="#d7e6ff" emissive="#9ecbff" emissiveIntensity={2.4} toneMapped={false} />
          </mesh>
          <pointLight position={[0, 4.1, 0]} color="#c5dcff" intensity={4} distance={9} decay={2} />
        </group>
      ))}
      {[
        [-6, 6],
        [6, 6],
        [-6, -22],
        [22, 6],
      ].map(([x, z]) => (
        <group key={`bench-${x}-${z}`} position={[x, 0, z]}>
          <mesh position={[0, 0.42, 0]} castShadow>
            <boxGeometry args={[1.3, 0.08, 0.42]} />
            <meshStandardMaterial color="#6b3a2a" roughness={0.7} />
          </mesh>
          <mesh position={[0, 0.72, -0.16]} castShadow>
            <boxGeometry args={[1.3, 0.42, 0.08]} />
            <meshStandardMaterial color="#4a2a22" roughness={0.75} />
          </mesh>
        </group>
      ))}
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

const seatOffset = new THREE.Vector3()
const spin = new THREE.Quaternion()

export function SceneRoot({ sim, maps, cast }: { sim: Game; maps: Maps; cast: Cast }) {
  const nightRef = useRef(1)

  useFrame((state, dt) => {
    readGamepad()
    sim.update(dt)
    nightRef.current = sim.night
    const fog = state.scene.fog as THREE.Fog | null
    if (fog) fog.color.set(sim.night > 0.5 ? '#120614' : '#9eb8d4')

    const camera = state.camera.position
    const seated = !!sim.driving
    const ani = cast.ani
    if (seated && sim.driving) {
      seatOffset.set(0.36, 0.02, -0.12)
      seatOffset.applyAxisAngle(new THREE.Vector3(0, 1, 0), sim.driving.yaw)
      ani.root.position.set(sim.driving.x + sim.driving.ox + seatOffset.x, 0.02, sim.driving.z + sim.driving.oz + seatOffset.z)
      ani.face(sim.driving.yaw, 0)
      ani.grip(true)
      ani.update(dt, 0, 'sit', 1, 4)
    } else {
      ani.root.position.set(sim.px, 0, sim.pz)
      ani.face(sim.pyaw, 0)
      ani.grip(false)
      ani.update(dt, sim.foot, 'locomotion', 1, 4)
    }
    ani.root.visible = true

    const mate = cast.mate
    const riding = !!sim.driving && sim.mateSpeed < 0.45
    if (riding && sim.driving) {
      seatOffset.set(-0.38, 0.02, 0.08)
      seatOffset.applyAxisAngle(new THREE.Vector3(0, 1, 0), sim.driving.yaw)
      mate.root.position.set(sim.driving.x + sim.driving.ox + seatOffset.x, 0.02, sim.driving.z + sim.driving.oz + seatOffset.z)
      mate.face(sim.driving.yaw, 0)
      mate.grip(false)
      mate.update(dt, 0, 'sit', 1, 5)
    } else {
      mate.root.position.set(sim.mateX, 0, sim.mateZ)
      mate.face(sim.mateYaw, 0)
      mate.grip(false)
      mate.update(dt, sim.mateSpeed, 'locomotion', 1, camera.distanceTo(mate.root.position))
    }
    mate.root.visible = true

    sim.peds.forEach((ped, i) => {
      const person = cast.peds[i]
      if (!person) return
      person.root.visible = ped.down < 10.2
      person.root.position.set(ped.x, ped.down > 0 ? 0.12 : 0, ped.z)
      person.face(ped.yaw, ped.down > 0 ? 1.15 : 0)
      const distance = camera.distanceTo(person.root.position)
      person.update(dt, ped.down > 0 ? 0 : ped.speed, ped.down > 0 ? 'down' : 'locomotion', 1, distance)
    })

    let copIndex = 0
    sim.cars.forEach((car, i) => {
      const group = cast.cars[i]
      group.visible = car.alive
      group.position.set(car.x + car.ox, 0, car.z + car.oz)
      group.rotation.y = car.yaw
      const open = sim.doorCar === car ? sim.door : 0
      const door = group.getObjectByName('door')
      if (door) door.rotation.y = open * 1.35
      const steer = group.getObjectByName('steer')
      if (steer) {
        const axle = group.userData.axle as THREE.Vector3 | undefined
        const base = group.userData.steerBase as THREE.Quaternion | undefined
        if (axle && base) {
          spin.setFromAxisAngle(axle, -car.steer * 1.7)
          steer.quaternion.copy(base).multiply(spin)
        } else steer.rotation.z = -car.steer * 1.5
      }
      group.traverse((obj) => {
        if (obj.name === 'wheel') {
          if (obj.userData.spin === 'z') obj.rotation.z = car.wheel
          else obj.rotation.y = car.wheel
        }
        if (obj.name === 'wiper') obj.rotation.y = Math.sin(sim.time * 2.1) * 0.6
      })
      touchRain(group, sim.time)
      if (car.role === 'police') {
        const cop = cast.cops[copIndex++]
        if (cop) {
          const near = camera.distanceTo(group.position) < 32
          cop.root.visible = car.alive && near
          if (cop.root.visible) {
            seatOffset.set(0.34, 0.02, -0.08)
            seatOffset.applyAxisAngle(new THREE.Vector3(0, 1, 0), car.yaw)
            cop.root.position.set(car.x + seatOffset.x, 0.02, car.z + seatOffset.z)
            cop.face(car.yaw, 0)
            cop.grip(true)
            cop.update(dt, 0, 'sit', 1, 6)
          }
        }
      }
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
      <primitive object={cast.ani.root} />
      <primitive object={cast.mate.root} />
      {cast.peds.map((person, i) => (
        <primitive key={i} object={person.root} />
      ))}
      {cast.cops.map((cop, i) => (
        <primitive key={`cop-${i}`} object={cop.root} />
      ))}
      {cast.cars.map((car, i) => (
        <primitive key={`car-${i}`} object={car} />
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
