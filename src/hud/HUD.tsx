import { useEffect, useRef, useState, type RefObject } from 'react'
import { Game, type Snapshot } from '../sim/game'
import { control, pulse } from '../input'

export function HUD({ sim }: { sim: Game }) {
  const [hud, setHud] = useState<Snapshot>(() => sim.snapshot())
  useEffect(() => {
    let frame = 0
    const tick = () => {
      setHud(sim.snapshot())
      frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [sim])
  const mapRef = useRef<HTMLCanvasElement>(null)
  const knob = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const canvas = mapRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    const w = canvas.width
    const h = canvas.height
    ctx.clearRect(0, 0, w, h)
    const project = (x: number, z: number) => ({
      px: ((x + 70) / 140) * w,
      py: h - ((z + 70) / 140) * h,
    })
    ctx.strokeStyle = 'rgba(180,180,200,.35)'
    ctx.lineWidth = 4
    for (let i = 0; i < 4; i++) {
      const a = project(-54 + i * 36, -70)
      const b = project(-54 + i * 36, 70)
      ctx.beginPath()
      ctx.moveTo(a.px, a.py)
      ctx.lineTo(b.px, b.py)
      ctx.stroke()
      const c = project(-70, -54 + i * 36)
      const d = project(70, -54 + i * 36)
      ctx.beginPath()
      ctx.moveTo(c.px, c.py)
      ctx.lineTo(d.px, d.py)
      ctx.stroke()
    }
    for (const blip of hud.map.blips) {
      const p = project(blip.x, blip.z)
      ctx.fillStyle = blip.color
      ctx.beginPath()
      ctx.arc(p.px, p.py, 4, 0, Math.PI * 2)
      ctx.fill()
    }
    const player = project(hud.map.x, hud.map.z)
    const fx = -Math.sin(hud.map.yaw)
    const fz = -Math.cos(hud.map.yaw)
    ctx.strokeStyle = 'white'
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(player.px, player.py)
    ctx.lineTo(player.px + fx * 10, player.py - fz * 10)
    ctx.stroke()
    ctx.fillStyle = 'white'
    ctx.beginPath()
    ctx.arc(player.px, player.py, 3.5, 0, Math.PI * 2)
    ctx.fill()
  }, [hud])

  const stars = '★★★★★'.slice(0, hud.stars) + '☆☆☆☆☆'.slice(hud.stars)

  return (
    <div className="hud">
      <div className="top">
        <div>
          <div className="health"><div style={{ width: `${Math.max(0, Math.min(100, hud.health))}%` }} /></div>
          <div className="name">{hud.driving ? 'ANI  ·  DRIVING' : 'ANI'}</div>
          <div className="objective">{hud.objective}</div>
          <canvas ref={mapRef} className="map" width={132} height={132} />
        </div>
        <div className="stars" style={{ color: hud.stars > 0 ? '#ff3040' : 'white' }}>{stars}</div>
        <div className="money">${hud.money}</div>
      </div>
      {hud.banner ? <div className="banner">{hud.banner}</div> : null}
      {hud.speed ? <div className="speed">{hud.speed}</div> : null}
      {hud.prompt ? <div className="prompt">{hud.prompt}</div> : null}
      {!hud.menu ? (
        <>
          <LookPad />
          <Joystick knob={knob} />
          <button className="mapbtn" onPointerDown={() => pulse('phone')}>MAP</button>
          <div className="cluster">
            <Hold label="HOR" onDown={() => pulse('horn')} />
            <Hold label={hud.driving ? 'GAS' : 'RUN'} className="gas" hold={(v) => { control.gas = v }} />
            <Hold label="HB" hold={(v) => { control.hand = v }} />
            <Hold label="ACT" className="act" onDown={() => pulse('action')} />
            <Hold label="BRK" hold={(v) => { control.brake = v }} />
          </div>
        </>
      ) : (
        <div className="dim" onPointerDown={() => pulse('cancel')}>
          <div className="menu" onPointerDown={(event) => event.stopPropagation()}>
            <h2>{hud.menuTitle}</h2>
            {hud.lines.map((line, index) => (
              <button key={line} className={index === hud.menuIndex ? 'row on' : 'row'} onClick={() => sim.choose(index)}>
                {line}
              </button>
            ))}
            <p>{hud.footer}</p>
          </div>
        </div>
      )}
    </div>
  )
}

function Hold({ label, className, hold, onDown }: { label: string; className?: string; hold?: (down: boolean) => void; onDown?: () => void }) {
  return (
    <button
      className={className}
      onPointerDown={(event) => {
        event.currentTarget.setPointerCapture(event.pointerId)
        hold?.(true)
        onDown?.()
      }}
      onPointerUp={() => hold?.(false)}
      onPointerCancel={() => hold?.(false)}
    >
      {label}
    </button>
  )
}

function Joystick({ knob }: { knob: RefObject<HTMLDivElement | null> }) {
  const base = useRef<HTMLDivElement>(null)
  const drag = (clientX: number, clientY: number) => {
    const rect = base.current?.getBoundingClientRect()
    if (!rect || !knob.current) return
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    let dx = clientX - cx
    let dy = clientY - cy
    const max = rect.width * 0.38
    const mag = Math.hypot(dx, dy) || 1
    if (mag > max) {
      dx = (dx / mag) * max
      dy = (dy / mag) * max
    }
    knob.current.style.transform = `translate(${dx}px, ${dy}px)`
    control.moveX = dx / max
    control.moveY = -dy / max
  }
  return (
    <div
      className="joystick"
      ref={base}
      onPointerDown={(event) => {
        event.currentTarget.setPointerCapture(event.pointerId)
        drag(event.clientX, event.clientY)
      }}
      onPointerMove={(event) => {
        if (event.currentTarget.hasPointerCapture(event.pointerId)) drag(event.clientX, event.clientY)
      }}
      onPointerUp={() => {
        if (knob.current) knob.current.style.transform = 'translate(0,0)'
        control.moveX = 0
        control.moveY = 0
      }}
    >
      <div className="knob" ref={knob} />
    </div>
  )
}

function LookPad() {
  const last = useRef<{ x: number; y: number } | null>(null)
  return (
    <div
      className="lookpad"
      onPointerDown={(event) => {
        if ((event.target as HTMLElement).closest('button')) return
        event.currentTarget.setPointerCapture(event.pointerId)
        last.current = { x: event.clientX, y: event.clientY }
      }}
      onPointerMove={(event) => {
        if (!last.current || !event.currentTarget.hasPointerCapture(event.pointerId)) return
        control.lookDragX += event.clientX - last.current.x
        control.lookDragY += event.clientY - last.current.y
        last.current = { x: event.clientX, y: event.clientY }
      }}
      onPointerUp={() => {
        last.current = null
      }}
    />
  )
}
