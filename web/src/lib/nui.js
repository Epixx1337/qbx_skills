const RESOURCE = 'qbx_skills'

export const isBrowser = !window.invokeNative

export async function fetchNui(name, data = {}) {
  if (isBrowser) return null

  try {
    const response = await fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    })
    return await response.json()
  } catch (err) {
    console.error(`fetchNui ${name} failed`, err)
    return null
  }
}

const handlers = new Map()

export function onMessage(action, handler) {
  handlers.set(action, handler)
}

window.addEventListener('message', (event) => {
  const { action, data } = event.data ?? {}
  if (!action) return
  const handler = handlers.get(action)
  if (handler) handler(data)
})
