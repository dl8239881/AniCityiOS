import { Canvas } from '@react-three/fiber'
import { useEffect, useMemo, useState } from 'react'
import * as THREE from 'three'
import { Game } from './sim/game'
import { loadMaps, type Maps } from './render/materials'
import { loadCast, type Cast } from './render/people'
import { SceneRoot } from './render/SceneRoot'
import { HUD } from './hud/HUD'
import './styles.css'

export function App() {
  const sim = useMemo(() => new Game(), [])
  const [ready, setReady] = useState<{ maps: Maps; cast: Cast } | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    loadMaps()
      .then(async (maps) => ({ maps, cast: await loadCast(maps, sim.peds, sim.cars) }))
      .then(setReady)
      .catch((reason: unknown) => setError(String(reason)))
    const onHide = () => sim.save()
    window.addEventListener('pagehide', onHide)
    return () => window.removeEventListener('pagehide', onHide)
  }, [sim])

  return (
    <>
      {ready ? (
        <Canvas
          shadows
          dpr={[1, 1.5]}
          camera={{ fov: 48, near: 0.1, far: 280, position: [0, 4, 8] }}
          gl={{
            antialias: false,
            toneMapping: THREE.ACESFilmicToneMapping,
            toneMappingExposure: 1.02,
            powerPreference: 'high-performance',
          }}
          onCreated={({ gl }) => {
            gl.outputColorSpace = THREE.SRGBColorSpace
          }}
        >
          <SceneRoot sim={sim} maps={ready.maps} cast={ready.cast} />
        </Canvas>
      ) : (
        <div className="load">{error || 'ANI CITY'}</div>
      )}
      <HUD sim={sim} />
    </>
  )
}
