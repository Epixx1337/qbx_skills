<script>
  import { fetchNui } from './nui.js'
  import { app, treeProgress, isTreeActive } from './store.svelte.js'

  let confirming = $state(null)

  const categories = $derived(app.data.categories)
  const actives = $derived(app.data.player.actives)

  let category = $state(null)
  $effect(() => {
    if (!category || !categories.includes(category)) {
      category = Object.keys(actives)[0] ?? categories[0] ?? null
    }
  })

  const visible = $derived(app.data.trees.filter(
    (t) => t.category === category && (t.enabled || app.data.isAdmin)
  ))

  function rootIcon(tree) {
    const roots = tree.nodes.filter((n) => !tree.links.some((l) => l.child === n.id))
    return roots[0]?.icon ?? 'diagram-project'
  }

  function replacedBy(tree) {
    if (app.data.policy.perCategory) {
      return actives[tree.category] !== tree.name ? actives[tree.category] : null
    }
    const current = Object.values(actives)[0]
    return current !== tree.name ? current : null
  }

  async function select(tree) {
    if (replacedBy(tree) && app.data.policy.abandonResets && confirming !== tree.name) {
      confirming = tree.name
      return
    }
    confirming = null
    await fetchNui('selectTree', { tree: tree.name })
    app.viewTree = tree.name
    app.view = 'tree'
  }

  function view(tree) {
    app.viewTree = tree.name
    app.view = 'tree'
  }

  function editTree(tree) {
    app.treeEditor = { tree }
  }

  function newTree() {
    app.treeEditor = { tree: null, category }
  }
</script>

<div class="picker">
  <div class="picker-head">
    <div>
      <h1>Choose specialization</h1>
      <p class="sub">
        {#if app.data.policy.perCategory}
          One specialization per category is active at a time — its skills and perks apply, the rest lie dormant.
        {:else}
          Only one specialization is active at a time — its skills and perks apply, the rest lie dormant.
        {/if}
        {#if app.data.policy.abandonResets}
          Abandoning a specialization wipes its progress.
        {/if}
        {#if app.data.policy.switchRequiresMax}
          You can only switch once your current specialization is maxed out.
        {/if}
      </p>
    </div>
    <div class="tabs">
      {#each categories as cat (cat)}
        <button class="tab" class:on={category === cat} onclick={() => (category = cat)}>{cat}</button>
      {/each}
    </div>
    <button class="btn subtle icon" onclick={() => fetchNui('close')} aria-label="Close" data-tip="Close" data-tip-down>
      <i class="fa-solid fa-xmark"></i>
    </button>
  </div>

  <div class="cards scroll">
    {#each visible as tree (tree.name)}
      {@const progress = treeProgress(tree.name)}
      <div class="card panel" class:active={isTreeActive(tree.name)} class:disabled={!tree.enabled}
        style:--card-accent={tree.color ?? 'var(--blue)'}>
        <div class="card-art">
          <i class="fa-solid fa-{rootIcon(tree)}"></i>
          {#if app.data.isAdmin && app.editMode}
            <button class="gear" onclick={() => editTree(tree)} aria-label="Edit tree" data-tip="Edit tree" data-tip-down>
              <i class="fa-solid fa-gear"></i>
            </button>
          {/if}
        </div>
        <div class="card-body">
          <div class="card-title">
            <span class="name">{tree.label}</span>
            {#if isTreeActive(tree.name)}
              <span class="badge blue">Active</span>
            {:else if !tree.enabled}
              <span class="badge yellow">Coming soon</span>
            {/if}
          </div>
          {#if progress.level > 0 || progress.xp > 0}
            <span class="badge">Level {progress.level}</span>
          {/if}
          {#if tree.jobs}
            <span class="badge" class:red={!(app.data.qualifies?.[tree.name] ?? true)}>
              <i class="fa-solid fa-briefcase"></i>&nbsp;{Object.keys(tree.jobs).join(' / ')}
            </span>
          {/if}
          <p class="desc">{tree.description ?? ''}</p>
          <div class="card-actions">
            {#if isTreeActive(tree.name)}
              <button class="btn" onclick={() => view(tree)}>Open tree</button>
            {:else}
              <button class="btn subtle" onclick={() => view(tree)}>Preview</button>
              {#if tree.enabled && (app.data.qualifies?.[tree.name] ?? true)}
                <button class="btn" class:danger={confirming === tree.name} onclick={() => select(tree)}>
                  {confirming === tree.name ? 'Progress is lost — sure?' : 'Select'}
                </button>
              {/if}
            {/if}
          </div>
        </div>
      </div>
    {/each}

    {#if app.data.isAdmin && app.editMode}
      <button class="card panel new" onclick={newTree}>
        <i class="fa-solid fa-plus"></i>
        <span>New tree</span>
      </button>
    {/if}
  </div>

  <div class="picker-foot">
    {#if app.data.isAdmin}
      <button class="btn subtle" onclick={() => (app.view = 'players')}>
        <i class="fa-solid fa-users"></i> Players
      </button>
      <button class="btn subtle" class:editing={app.editMode} onclick={() => (app.editMode = !app.editMode)}>
        <i class="fa-solid fa-pen"></i>
        {app.editMode ? 'Stop editing' : 'Edit'}
      </button>
    {/if}
    {#if app.viewTree}
      <button class="btn subtle" onclick={() => (app.view = 'tree')}>Go back</button>
    {/if}
  </div>
</div>

<style>
  .picker {
    display: flex;
    flex-direction: column;
    gap: 20px;
    width: min(1240px, 92vw);
    max-height: 88vh;
  }

  .picker-head {
    display: flex;
    align-items: flex-start;
    gap: 20px;
  }

  h1 {
    font-size: 30px;
    font-weight: 700;
    color: #fff;
  }

  .sub {
    max-width: 520px;
    margin-top: 6px;
    font-size: 13px;
    color: var(--dark-2);
  }

  .tabs {
    display: flex;
    gap: 8px;
    margin-left: auto;
  }

  .tab {
    padding: 8px 18px;
    font-family: inherit;
    font-size: 13px;
    font-weight: 500;
    text-transform: capitalize;
    color: var(--dark-1);
    background: var(--dark-6);
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .tab.on {
    color: #fff;
    background: var(--accent-20);
    border-color: var(--blue);
  }

  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 16px;
    padding: 2px;
  }

  .card {
    display: flex;
    flex-direction: column;
    overflow: hidden;
    transition: transform 0.12s ease, border-color 0.12s ease;
  }

  .card:hover {
    transform: translateY(-2px);
  }

  .card.active {
    border-color: var(--card-accent);
  }

  .card.disabled {
    opacity: 0.65;
  }

  .card-art {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    height: 110px;
    font-size: 42px;
    color: var(--card-accent);
    background:
      radial-gradient(ellipse at top, var(--accent-15), transparent 70%),
      var(--dark-8);
    border-bottom: 2px solid var(--card-accent);
  }

  .gear {
    position: absolute;
    top: 8px;
    right: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    font-size: 13px;
    color: var(--dark-0);
    background: var(--dark-6);
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .card-body {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 14px;
  }

  .card-title {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .name {
    font-size: 17px;
    font-weight: 700;
    color: #fff;
  }

  .card-body > .badge {
    align-self: flex-start;
  }

  .desc {
    min-height: 34px;
    font-size: 12px;
    color: var(--dark-2);
  }

  .card-actions {
    display: flex;
    gap: 8px;
    margin-top: auto;
  }

  .card-actions .btn {
    flex: 1;
  }

  .card.new {
    align-items: center;
    justify-content: center;
    gap: 10px;
    min-height: 220px;
    font-family: inherit;
    font-size: 14px;
    color: var(--dark-2);
    background: transparent;
    border-style: dashed;
    cursor: pointer;
  }

  .card.new i {
    font-size: 26px;
  }

  .card.new:hover {
    color: var(--blue-light);
    border-color: var(--blue);
  }

  .picker-foot {
    display: flex;
    justify-content: center;
    gap: 10px;
  }

  .btn.editing {
    color: var(--blue-light);
    background: var(--accent-15);
  }
</style>
