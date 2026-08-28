<script>
  import { fetchNui } from './nui.js'
  import { app, currentTree, treeProgress, xpForNext, canUnlock, parentsOf, pushUndo, nodeSnapshot, isTreeActive } from './store.svelte.js'

  const CELL_W = 132
  const CELL_H = 124
  const NODE = 68
  const MIN_ZOOM = 0.4
  const MAX_ZOOM = 1.75

  const tree = $derived(currentTree())
  const progress = $derived(treeProgress(app.viewTree))
  const isActive = $derived(isTreeActive(app.viewTree))
  const maxLevel = $derived(app.data.xp.maxLevel)
  const atMax = $derived(progress.level >= maxLevel)
  const nextXp = $derived(xpForNext(progress.level))

  const xs = $derived(tree?.nodes.map((n) => n.x) ?? [])
  const ys = $derived(tree?.nodes.map((n) => n.y) ?? [])
  const offX = $derived(xs.length ? Math.max(0, Math.min(...xs) - (app.editMode ? 1 : 0)) : 0)
  const offY = $derived(ys.length ? Math.max(0, Math.min(...ys) - (app.editMode ? 1 : 0)) : 0)
  const cols = $derived(xs.length ? Math.max(...xs) - offX + 1 + (app.editMode ? 1 : 0) : app.editMode ? 6 : 1)
  const rows = $derived(ys.length ? Math.max(...ys) - offY + 1 + (app.editMode ? 1 : 0) : app.editMode ? 4 : 1)

  let dragging = $state(null)
  let container = $state(null)
  let view = $state({ x: 0, y: 0, scale: 1 })
  let panned = false
  let centeredTree = null
  let undoBusy = $state(false)

  function recenter() {
    if (!container) return
    const rect = container.getBoundingClientRect()
    view.scale = Math.min(1, Math.max(MIN_ZOOM, Math.min(rect.width / (cols * CELL_W + 60), rect.height / (rows * CELL_H + 60))))
    view.x = (rect.width - cols * CELL_W * view.scale) / 2
    view.y = Math.max(24, (rect.height - rows * CELL_H * view.scale) / 2)
  }

  $effect(() => {
    if (tree && container && centeredTree !== tree.name) {
      centeredTree = tree.name
      requestAnimationFrame(recenter)
    }
  })

  function onWheel(event) {
    event.preventDefault()
    const rect = container.getBoundingClientRect()
    const cx = event.clientX - rect.left
    const cy = event.clientY - rect.top
    const next = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, view.scale * (event.deltaY < 0 ? 1.12 : 0.89)))
    view.x = cx - (cx - view.x) * (next / view.scale)
    view.y = cy - (cy - view.y) * (next / view.scale)
    view.scale = next
  }

  function panStart(event) {
    panned = false
    if (event.button !== 0 && event.button !== 1) return
    if (event.target.closest('.node')) return
    const start = { x: event.clientX, y: event.clientY, ox: view.x, oy: view.y }

    const move = (e) => {
      const dx = e.clientX - start.x
      const dy = e.clientY - start.y
      if (Math.abs(dx) > 5 || Math.abs(dy) > 5) panned = true
      if (panned) {
        view.x = start.ox + dx
        view.y = start.oy + dy
      }
    }
    const up = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }

  function unlocked(node) {
    return progress.unlocked.includes(node.name)
  }

  function available(node) {
    return canUnlock(tree, node)
  }

  function cx(node) {
    return (node.x - offX) * CELL_W + CELL_W / 2
  }

  function cyTop(node) {
    return (node.y - offY) * CELL_H + (CELL_H - NODE) / 2
  }

  function dragOff(node, axis) {
    return dragging?.node.id === node.id ? dragging[axis] / view.scale : 0
  }

  function linkPath(link) {
    const parent = tree.nodes.find((n) => n.id === link.parent)
    const child = tree.nodes.find((n) => n.id === link.child)
    if (!parent || !child) return null

    const px = cx(parent) + dragOff(parent, 'dx')
    const py = cyTop(parent) + NODE + dragOff(parent, 'dy')
    const kx = cx(child) + dragOff(child, 'dx')
    const ky = cyTop(child) + dragOff(child, 'dy')
    const mid = (py + ky) / 2

    const path = px === kx ? `M ${px} ${py} L ${kx} ${ky}` : `M ${px} ${py} L ${px} ${mid} L ${kx} ${mid} L ${kx} ${ky}`
    let state = 'locked'
    if (unlocked(parent) && unlocked(child)) state = 'done'
    else if (unlocked(parent)) state = 'open'
    return { path, state }
  }

  function nodeState(node) {
    if (unlocked(node)) return 'unlocked'
    if (available(node)) return 'available'
    return 'locked'
  }

  async function clickNode(node) {
    if (panned) return
    if (app.linking) {
      if (app.linking !== node.id) {
        const source = app.linking
        if (await fetchNui('editor:toggleLink', { parent: source, child: node.id })) {
          pushUndo({ type: 'link', parent: source, child: node.id })
        }
      }
      app.linking = null
      return
    }
    app.selectedNode = node
  }

  function clickCell(x, y) {
    if (panned || !app.editMode || app.linking) return
    const gx = x + offX
    const gy = y + offY
    if (tree.nodes.some((n) => n.x === gx && n.y === gy)) return
    app.nodeEditor = { node: null, tree: tree.name, x: gx, y: gy }
  }

  async function removeLink(link) {
    if (panned) return
    if (await fetchNui('editor:toggleLink', { parent: link.parent, child: link.child })) {
      pushUndo({ type: 'link', parent: link.parent, child: link.child })
    }
  }

  function pointerDown(event, node) {
    if (!app.editMode || app.linking || event.button !== 0) return
    event.preventDefault()
    dragging = { node, startX: event.clientX, startY: event.clientY, dx: 0, dy: 0, moved: false }

    const move = (e) => {
      dragging.dx = e.clientX - dragging.startX
      dragging.dy = e.clientY - dragging.startY
      if (Math.abs(dragging.dx) > 6 || Math.abs(dragging.dy) > 6) dragging.moved = true
    }
    const up = async () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
      const drag = dragging
      dragging = null
      if (!drag.moved) {
        clickNode(drag.node)
        return
      }
      const x = Math.max(0, drag.node.x + Math.round(drag.dx / (CELL_W * view.scale)))
      const y = Math.max(0, drag.node.y + Math.round(drag.dy / (CELL_H * view.scale)))
      if ((x !== drag.node.x || y !== drag.node.y) && !tree.nodes.some((n) => n.id !== drag.node.id && n.x === x && n.y === y)) {
        const fromX = drag.node.x
        const fromY = drag.node.y
        drag.node.x = x
        drag.node.y = y
        if (await fetchNui('editor:moveNode', { id: drag.node.id, x, y })) {
          pushUndo({ type: 'move', id: drag.node.id, x: fromX, y: fromY })
        }
      }
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }

  async function unlock(node) {
    await fetchNui('unlock', { name: node.name })
  }

  async function deleteNode(node) {
    app.selectedNode = null
    const snapshot = nodeSnapshot(node)
    delete snapshot.id
    const links = tree.links
      .filter((l) => l.parent === node.id || l.child === node.id)
      .map((l) => ({
        parentName: l.parent === node.id ? null : tree.nodes.find((n) => n.id === l.parent)?.name,
        childName: l.child === node.id ? null : tree.nodes.find((n) => n.id === l.child)?.name,
      }))
    if (await fetchNui('editor:deleteNode', node.id)) {
      pushUndo({ type: 'deleteNode', node: snapshot, links })
    }
  }

  async function undo() {
    const entry = app.undoStack.pop()
    if (!entry || undoBusy) return
    undoBusy = true

    if (entry.type === 'move') {
      await fetchNui('editor:moveNode', { id: entry.id, x: entry.x, y: entry.y })
    } else if (entry.type === 'link') {
      await fetchNui('editor:toggleLink', { parent: entry.parent, child: entry.child })
    } else if (entry.type === 'editNode') {
      await fetchNui('editor:saveNode', entry.node)
    } else if (entry.type === 'createNode') {
      await fetchNui('editor:deleteNode', entry.id)
    } else if (entry.type === 'deleteNode') {
      const result = await fetchNui('editor:saveNode', entry.node)
      if (result?.id) {
        for (const link of entry.links) {
          const parent = link.parentName ? tree.nodes.find((n) => n.name === link.parentName)?.id : result.id
          const child = link.childName ? tree.nodes.find((n) => n.name === link.childName)?.id : result.id
          if (parent && child) await fetchNui('editor:toggleLink', { parent, child })
        }
      }
    }

    undoBusy = false
  }

  function startLink(node) {
    app.selectedNode = null
    app.linking = node.id
  }

  function formatBonus(key, value) {
    const label = key.replaceAll('_', ' ')
    const sign = value > 0 ? '+' : ''
    if (Math.abs(value) < 1) return `${sign}${Math.round(value * 100)}% ${label}`
    return `${sign}${value} ${label}`
  }

  function toggleEdit() {
    app.editMode = !app.editMode
    app.linking = null
    app.selectedNode = null
    if (!app.editMode) app.undoStack = []
  }
</script>

{#if tree}
  <div class="wrap" style:--accent={tree.color ?? 'var(--blue)'}>
    <div class="head panel">
      <div class="head-id">
        <h1>{tree.label}</h1>
        <span class="badge">{tree.category}</span>
        {#if !isActive}
          <span class="badge yellow">Not active</span>
        {/if}
        {#if app.editMode}
          <span class="badge red">Editing</span>
        {/if}
      </div>

      <div class="head-progress">
        <div class="xp-row">
          <span class="lvl">Level {progress.level}</span>
          <span class="xp">{atMax ? 'MAX' : `${progress.xp} / ${nextXp} XP`}</span>
          <span class="points" class:has={progress.points > 0}>
            <i class="fa-solid fa-star"></i>
            {progress.points} point{progress.points === 1 ? '' : 's'}
          </span>
        </div>
        <div class="bar">
          <div class="fill" style:width={`${atMax ? 100 : Math.min(100, (progress.xp / Math.max(1, nextXp)) * 100)}%`}></div>
        </div>
      </div>

      <div class="head-actions">
        {#if app.data.isAdmin}
          <button class="btn subtle" onclick={() => (app.view = 'players')} aria-label="Players" data-tip="Players" data-tip-down>
            <i class="fa-solid fa-users"></i>
          </button>
          <button class="btn subtle" class:editing={app.editMode} onclick={toggleEdit}>
            <i class="fa-solid fa-pen"></i>
            {app.editMode ? 'Stop editing' : 'Edit'}
          </button>
          {#if app.editMode}
            <button class="btn subtle" onclick={() => (app.treeEditor = { tree })} aria-label="Tree settings" data-tip="Tree settings" data-tip-down>
              <i class="fa-solid fa-gear"></i>
            </button>
          {/if}
        {/if}
        <button class="btn subtle" onclick={() => (app.view = 'picker')}>Change specialization</button>
        <button class="btn subtle icon" onclick={() => fetchNui('close')} aria-label="Close" data-tip="Close" data-tip-down>
          <i class="fa-solid fa-xmark"></i>
        </button>
      </div>
    </div>

    {#if app.editMode}
      <div class="edit-hint">
        <span>
          {#if app.linking}
            Pick the skill this one should unlock — click the source again or press Escape to cancel.
          {:else}
            Click an empty cell to add a skill, drag a skill to move it, click one to edit or link it. Click a link line to remove it.
          {/if}
        </span>
        <button class="btn subtle undo" disabled={!app.undoStack.length || undoBusy} onclick={undo}>
          <i class="fa-solid fa-rotate-left"></i>
          Undo{app.undoStack.length ? ` (${app.undoStack.length})` : ''}
        </button>
      </div>
    {/if}

    <div
      class="canvas panel"
      class:linking={app.linking}
      bind:this={container}
      onpointerdown={panStart}
      onwheel={onWheel}
      role="presentation"
    >
      <div
        class="grid"
        class:edit={app.editMode}
        style:width={`${cols * CELL_W}px`}
        style:height={`${rows * CELL_H}px`}
        style:transform={`translate(${view.x}px, ${view.y}px) scale(${view.scale})`}
      >
        {#if app.editMode}
          {#each Array(rows) as _, y}
            {#each Array(cols) as _, x}
              <button
                class="cell"
                style:left={`${x * CELL_W}px`}
                style:top={`${y * CELL_H}px`}
                onclick={() => clickCell(x, y)}
                aria-label="Add skill"
              ><i class="fa-solid fa-plus"></i></button>
            {/each}
          {/each}
        {/if}

        <svg width={cols * CELL_W} height={rows * CELL_H}>
          {#each tree.links as link (link.parent + '-' + link.child)}
            {@const drawn = linkPath(link)}
            {#if drawn}
              {#if app.editMode}
                <g class="link-group" role="button" tabindex="-1" aria-label="Remove link" onclick={() => removeLink(link)} onkeydown={(e) => { if (e.key === 'Enter') removeLink(link) }}>
                  <path class="link {drawn.state} editable" d={drawn.path} />
                  <path class="link-hit" d={drawn.path} />
                </g>
              {:else}
                <path class="link {drawn.state}" d={drawn.path} />
              {/if}
            {/if}
          {/each}
        </svg>

        {#each tree.nodes as node (node.id)}
          <div
            class="node {nodeState(node)}"
            class:link-source={app.linking === node.id}
            style:left={`${cx(node) - NODE / 2 + dragOff(node, 'dx')}px`}
            style:top={`${cyTop(node) + dragOff(node, 'dy')}px`}
            role="button"
            tabindex="0"
            onpointerdown={(e) => pointerDown(e, node)}
            onclick={() => { if (!app.editMode || app.linking) clickNode(node) }}
            onkeydown={(e) => { if (e.key === 'Enter') clickNode(node) }}
          >
            <i class="fa-solid fa-{node.icon}"></i>
            {#if node.cost > 1 && !unlocked(node)}
              <span class="cost">{node.cost}</span>
            {/if}
            <span class="node-label">{node.label}</span>
          </div>
        {/each}
      </div>

      <div class="zoom">
        <button class="zoom-btn" onclick={() => onWheel({ preventDefault: () => {}, clientX: container.getBoundingClientRect().left + container.clientWidth / 2, clientY: container.getBoundingClientRect().top + container.clientHeight / 2, deltaY: 100 })} aria-label="Zoom out" data-tip="Zoom out">
          <i class="fa-solid fa-minus"></i>
        </button>
        <span class="zoom-value">{Math.round(view.scale * 100)}%</span>
        <button class="zoom-btn" onclick={() => onWheel({ preventDefault: () => {}, clientX: container.getBoundingClientRect().left + container.clientWidth / 2, clientY: container.getBoundingClientRect().top + container.clientHeight / 2, deltaY: -100 })} aria-label="Zoom in" data-tip="Zoom in">
          <i class="fa-solid fa-plus"></i>
        </button>
        <button class="zoom-btn" onclick={recenter} aria-label="Recenter" data-tip="Recenter">
          <i class="fa-solid fa-crosshairs"></i>
        </button>
      </div>
    </div>

    {#if app.selectedNode}
      {@const node = app.selectedNode}
      {@const state = nodeState(node)}
      {@const parents = parentsOf(tree, node)}
      <div class="modal-backdrop" role="presentation" onclick={(e) => { if (e.target === e.currentTarget) app.selectedNode = null }}>
        <div class="skill-modal panel">
          <button class="modal-close" onclick={() => (app.selectedNode = null)} aria-label="Close">
            <i class="fa-solid fa-xmark"></i>
          </button>

          <div class="modal-art {state}">
            <div class="modal-icon {state}">
              <i class="fa-solid fa-{node.icon}"></i>
            </div>
          </div>

          <div class="modal-body">
            <div class="modal-title">
              <span class="name">{node.label}</span>
              {#if state === 'unlocked'}
                <span class="badge green">Unlocked</span>
              {:else}
                <span class="badge yellow">{node.cost} point{node.cost === 1 ? '' : 's'}</span>
              {/if}
            </div>

            {#if node.description}
              <p class="modal-desc">{node.description}</p>
            {/if}

            {#if Object.keys(node.bonuses ?? {}).length}
              <div class="chips">
                {#each Object.entries(node.bonuses) as [key, value] (key)}
                  <span class="badge blue">{formatBonus(key, value)}</span>
                {/each}
              </div>
            {/if}

            {#if parents.length}
              <div class="chips">
                <span class="label">Requires{app.data.policy.linkRequirement === 'all' ? ' all of' : ''}</span>
                {#each parents as parent (parent.id)}
                  <span class="badge" class:green={unlocked(parent)}>{parent.label}</span>
                {/each}
              </div>
            {/if}

            <div class="modal-actions">
              {#if state === 'unlocked'}
                {#if app.editMode}
                  <span class="badge green">Skill unlocked</span>
                {:else}
                  <button class="btn subtle wide" onclick={() => (app.selectedNode = null)}>Close</button>
                {/if}
              {:else if !isActive}
                <span class="hint center">Activate this specialization to unlock skills.</span>
              {:else if state === 'available'}
                <button class="btn success wide" onclick={() => unlock(node)}>
                  <i class="fa-solid fa-unlock"></i> Unlock — {node.cost} point{node.cost === 1 ? '' : 's'}
                </button>
              {:else if progress.points < node.cost}
                <span class="hint center">Not enough talent points.</span>
              {:else}
                <span class="hint center">Unlock the connected skill{parents.length === 1 ? '' : 's'} above it first.</span>
              {/if}
            </div>

            {#if app.editMode}
              <div class="modal-actions">
                <button class="btn" onclick={() => { app.nodeEditor = { node, tree: tree.name, x: node.x, y: node.y }; app.selectedNode = null }}>
                  <i class="fa-solid fa-pen"></i> Edit details
                </button>
                <button class="btn subtle" onclick={() => startLink(node)}>
                  <i class="fa-solid fa-link"></i> Link
                </button>
                <button class="btn danger" onclick={() => deleteNode(node)}>
                  <i class="fa-solid fa-trash"></i> Delete
                </button>
              </div>
            {/if}
          </div>
        </div>
      </div>
    {/if}
  </div>
{/if}

<style>
  .wrap {
    display: flex;
    flex-direction: column;
    gap: 12px;
    width: min(1360px, 94vw);
    height: min(860px, 90vh);
  }

  .head {
    display: flex;
    align-items: center;
    gap: 24px;
    padding: 16px 20px;
  }

  .head-id {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  h1 {
    font-size: 26px;
    font-weight: 700;
    color: #fff;
  }

  .head-id .badge {
    text-transform: capitalize;
  }

  .head-progress {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 6px;
    max-width: 520px;
    margin-left: auto;
  }

  .xp-row {
    display: flex;
    align-items: center;
    gap: 14px;
    font-size: 13px;
  }

  .lvl {
    font-weight: 700;
    color: var(--accent);
  }

  .xp {
    color: var(--dark-1);
  }

  .points {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-left: auto;
    color: var(--dark-2);
  }

  .points.has {
    color: var(--yellow);
    font-weight: 500;
  }

  .bar {
    height: 8px;
    background: var(--dark-5);
    border-radius: 4px;
    overflow: hidden;
  }

  .fill {
    height: 100%;
    background: var(--accent);
    border-radius: 4px;
    transition: width 0.25s ease;
  }

  .head-actions {
    display: flex;
    gap: 8px;
  }

  .btn.editing {
    color: var(--blue-light);
    background: var(--accent-15);
  }

  .edit-hint {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 6px 8px 6px 14px;
    font-size: 12px;
    color: var(--yellow);
    background: rgba(250, 176, 5, 0.08);
    border: 1px dashed rgba(250, 176, 5, 0.4);
    border-radius: var(--radius-sm);
  }

  .btn.undo {
    padding: 6px 10px;
    font-size: 12px;
    flex: none;
  }

  .canvas {
    position: relative;
    flex: 1;
    min-height: 0;
    overflow: hidden;
    cursor: grab;
  }

  .canvas:active {
    cursor: grabbing;
  }

  .canvas.linking {
    cursor: crosshair;
  }

  .grid {
    position: absolute;
    transform-origin: 0 0;
  }

  .grid.edit {
    background-image:
      linear-gradient(to right, rgba(144, 146, 150, 0.22) 1px, transparent 1px),
      linear-gradient(to bottom, rgba(144, 146, 150, 0.22) 1px, transparent 1px);
    background-size: 132px 124px;
    border: 1px solid rgba(144, 146, 150, 0.35);
  }

  svg {
    position: absolute;
    inset: 0;
    pointer-events: none;
  }

  .link {
    fill: none;
    stroke: var(--dark-4);
    stroke-width: 2;
    stroke-dasharray: 5 5;
  }

  .link.editable {
    stroke: var(--dark-3);
  }

  .link.open {
    stroke: var(--accent);
    opacity: 0.65;
  }

  .link.done {
    stroke: var(--accent);
    stroke-dasharray: none;
    filter: drop-shadow(0 0 4px var(--accent-35));
  }

  .link-hit {
    fill: none;
    stroke: transparent;
    stroke-width: 16;
    pointer-events: stroke;
    cursor: pointer;
  }

  .link-group {
    outline: none;
  }

  .link-group:hover .link {
    stroke: var(--red);
    stroke-dasharray: none;
    filter: drop-shadow(0 0 4px rgba(250, 82, 82, 0.5));
  }

  .cell {
    position: absolute;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 132px;
    height: 124px;
    font-size: 14px;
    color: transparent;
    background: transparent;
    border: none;
    cursor: pointer;
  }

  .cell:hover {
    color: var(--dark-1);
    background: rgba(255, 255, 255, 0.03);
    box-shadow: inset 0 0 0 1px var(--dark-3);
  }

  .node {
    position: absolute;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 68px;
    height: 68px;
    font-size: 24px;
    color: var(--dark-2);
    background: var(--dark-6);
    border: 2px solid var(--dark-4);
    border-radius: 20px;
    cursor: pointer;
    transition: border-color 0.12s ease, color 0.12s ease, box-shadow 0.12s ease;
  }

  .node:hover {
    border-color: var(--dark-3);
  }

  .node.available {
    color: var(--dark-0);
    border-color: var(--accent);
    animation: pulse 2s ease-in-out infinite;
  }

  .node.unlocked {
    color: #fff;
    background: var(--dark-5);
    border-color: var(--accent);
    box-shadow: 0 0 14px var(--accent-35);
  }

  .node.link-source {
    outline: 2px dashed var(--yellow);
    outline-offset: 3px;
  }

  @keyframes pulse {
    50% {
      box-shadow: 0 0 12px var(--accent-35);
    }
  }

  .cost {
    position: absolute;
    top: -7px;
    right: -7px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 20px;
    height: 20px;
    font-size: 11px;
    font-weight: 700;
    color: var(--dark-9);
    background: var(--yellow);
    border-radius: 10px;
  }

  .node-label {
    position: absolute;
    top: calc(100% + 6px);
    width: 120px;
    font-size: 11px;
    font-weight: 500;
    text-align: center;
    color: var(--dark-2);
    pointer-events: none;
  }

  .node.unlocked .node-label,
  .node.available .node-label {
    color: var(--dark-0);
  }

  .zoom {
    position: absolute;
    bottom: 14px;
    right: 14px;
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 4px;
    background: var(--dark-8);
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-sm);
  }

  .zoom-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    font-size: 12px;
    color: var(--dark-1);
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .zoom-btn:hover {
    color: #fff;
    background: var(--dark-5);
  }

  .zoom-value {
    min-width: 40px;
    font-size: 11px;
    font-weight: 500;
    text-align: center;
    color: var(--dark-1);
  }

  .modal-backdrop {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(16, 17, 19, 0.6);
    z-index: 5;
  }

  .skill-modal {
    position: relative;
    display: flex;
    flex-direction: column;
    width: 380px;
    overflow: hidden;
    animation: modal-in 0.16s ease;
  }

  @keyframes modal-in {
    from {
      opacity: 0;
      transform: translateY(10px) scale(0.97);
    }
  }

  .modal-close {
    position: absolute;
    top: 10px;
    right: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    font-size: 13px;
    color: var(--dark-1);
    background: rgba(16, 17, 19, 0.5);
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-sm);
    cursor: pointer;
    z-index: 1;
  }

  .modal-close:hover {
    color: #fff;
    background: var(--dark-5);
  }

  .modal-art {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 28px 0 22px;
    background:
      radial-gradient(ellipse at top, var(--accent-15), transparent 75%),
      var(--dark-8);
    border-bottom: 2px solid var(--dark-4);
  }

  .modal-art.unlocked,
  .modal-art.available {
    border-bottom-color: var(--accent);
  }

  .modal-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 84px;
    height: 84px;
    font-size: 32px;
    color: var(--dark-2);
    background: var(--dark-6);
    border: 2px solid var(--dark-4);
    border-radius: 24px;
  }

  .modal-icon.available {
    color: var(--dark-0);
    border-color: var(--accent);
  }

  .modal-icon.unlocked {
    color: #fff;
    background: var(--dark-5);
    border-color: var(--accent);
    box-shadow: 0 0 18px var(--accent-35);
  }

  .modal-body {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 18px 20px 20px;
  }

  .modal-title {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
  }

  .modal-title .name {
    font-size: 18px;
    font-weight: 700;
    color: #fff;
  }

  .modal-desc {
    font-size: 13px;
    line-height: 1.5;
    text-align: center;
    color: var(--dark-1);
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: center;
    gap: 6px;
  }

  .modal-actions {
    display: flex;
    justify-content: center;
    gap: 8px;
    margin-top: 6px;
  }

  .btn.wide {
    flex: 1;
  }

  .hint.center {
    width: 100%;
    text-align: center;
    padding: 8px 0;
  }
</style>
