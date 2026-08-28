export const app = $state({
  visible: false,
  data: null,
  view: 'tree',
  viewTree: null,
  selectedNode: null,
  editMode: false,
  linking: null,
  nodeEditor: null,
  treeEditor: null,
  undoStack: [],
})

export function pushUndo(entry) {
  app.undoStack.push(entry)
  if (app.undoStack.length > 50) app.undoStack.shift()
}

export function nodeSnapshot(node) {
  return {
    id: node.id,
    tree: node.tree,
    name: node.name,
    label: node.label,
    description: node.description,
    icon: node.icon,
    x: node.x,
    y: node.y,
    cost: node.cost,
    bonuses: { ...(node.bonuses ?? {}) },
  }
}

export function currentTree() {
  return app.data?.trees.find((t) => t.name === app.viewTree) ?? null
}

export function isTreeActive(name) {
  return Object.values(app.data?.player.actives ?? {}).includes(name)
}

export function treeProgress(name) {
  return app.data?.player.trees[name] ?? { xp: 0, level: 0, points: 0, unlocked: [] }
}

export function xpForNext(level) {
  const xp = app.data?.xp
  if (!xp) return 0
  return Math.floor(xp.base * xp.growth ** level)
}

export function isUnlocked(tree, nodeName) {
  return treeProgress(tree).unlocked.includes(nodeName)
}

export function parentsOf(tree, node) {
  return tree.links.filter((l) => l.child === node.id).map((l) => tree.nodes.find((n) => n.id === l.parent)).filter(Boolean)
}

export function canUnlock(tree, node) {
  if (!isTreeActive(tree.name)) return false
  const progress = treeProgress(tree.name)
  if (progress.unlocked.includes(node.name) || progress.points < node.cost) return false

  const parents = parentsOf(tree, node)
  if (parents.length === 0) return true

  const owned = parents.filter((p) => progress.unlocked.includes(p.name)).length
  return app.data?.policy.linkRequirement === 'all' ? owned === parents.length : owned > 0
}
