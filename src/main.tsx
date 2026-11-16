import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'

window.addEventListener('error', (event) => {
  const note = document.createElement('pre')
  note.style.cssText = 'position:fixed;z-index:20;left:12px;bottom:12px;color:white;background:#400;padding:8px;max-width:70%;white-space:pre-wrap'
  note.textContent = `${event.message}\n${event.error?.stack ?? ''}`
  document.body.appendChild(note)
})
window.addEventListener('unhandledrejection', (event) => {
  const note = document.createElement('pre')
  note.style.cssText = 'position:fixed;z-index:20;left:12px;bottom:12px;color:white;background:#400;padding:8px;max-width:70%;white-space:pre-wrap'
  const reason = event.reason
  note.textContent = String(reason?.stack || reason)
  document.body.appendChild(note)
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
