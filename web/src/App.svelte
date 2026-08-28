<script>
  import './lib/theme.css'
  import { applyTheme } from './lib/mantine.js'
  import { onMessage, fetchNui } from './lib/nui.js'
  import { app } from './lib/store.svelte.js'
  import SkillsApp from './lib/SkillsApp.svelte'

  let fresh = false

  onMessage('theme', (data) => applyTheme(data?.color, data?.shade))

  onMessage('setVisible', (data) => {
    app.visible = data === true
    if (app.visible) {
      fresh = true
    } else {
      app.editMode = false
      app.linking = null
      app.nodeEditor = null
      app.treeEditor = null
      app.selectedNode = null
      app.undoStack = []
    }
  })

  // FiveM serializes empty Lua tables as {} — normalize everything the UI indexes as arrays
  function normalize(data) {
    if (!Array.isArray(data.trees)) data.trees = []
    if (!Array.isArray(data.categories)) data.categories = []
    data.qualifies = data.qualifies && !Array.isArray(data.qualifies) ? data.qualifies : {}
    data.player = data.player && !Array.isArray(data.player) ? data.player : {}
    if (!data.player.trees || Array.isArray(data.player.trees)) data.player.trees = {}
    if (!data.player.actives || Array.isArray(data.player.actives)) data.player.actives = {}
    for (const progress of Object.values(data.player.trees)) {
      if (!Array.isArray(progress.unlocked)) progress.unlocked = []
    }
    for (const tree of data.trees) {
      if (!Array.isArray(tree.nodes)) tree.nodes = []
      if (!Array.isArray(tree.links)) tree.links = []
      for (const node of tree.nodes) {
        if (!node.bonuses || Array.isArray(node.bonuses)) node.bonuses = {}
      }
    }
    return data
  }

  onMessage('skills:init', (data) => {
    app.data = normalize(data)
    if (!data.isAdmin) {
      app.editMode = false
      app.linking = null
      app.nodeEditor = null
      app.treeEditor = null
    }

    const actives = Object.values(data.player.actives)
    if (fresh) {
      fresh = false
      app.viewTree = actives[0] ?? data.trees.find((t) => t.enabled)?.name ?? null
      app.view = actives.length ? 'tree' : 'picker'
      app.selectedNode = null
      return
    }

    if (app.viewTree && !data.trees.some((t) => t.name === app.viewTree)) {
      app.viewTree = actives[0] ?? null
      app.view = app.viewTree ? 'tree' : 'picker'
    }
    if (app.selectedNode) {
      const tree = data.trees.find((t) => t.name === app.selectedNode.tree)
      app.selectedNode = tree?.nodes.find((n) => n.id === app.selectedNode.id) ?? null
    }
  })

  function onKeydown(event) {
    if (!app.visible) return
    if (event.key !== 'Escape') return
    event.preventDefault()

    if (app.nodeEditor) app.nodeEditor = null
    else if (app.treeEditor) app.treeEditor = null
    else if (app.linking) app.linking = null
    else if (app.selectedNode) app.selectedNode = null
    else fetchNui('close')
  }
</script>

<svelte:window on:keydown={onKeydown} />

{#if app.visible && app.data}
  <SkillsApp />
{/if}
