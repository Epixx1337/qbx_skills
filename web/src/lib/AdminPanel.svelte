<script>
  import { fetchNui } from './nui.js'
  import { app } from './store.svelte.js'
  import NumberInput from './NumberInput.svelte'

  let players = $state([])
  let search = $state('')
  let selected = $state(null)
  let giveTree = $state(null)
  let amount = $state(10)
  let busy = $state(false)
  let expanded = $state(null)

  const filtered = $derived(players.filter((p) => {
    const query = search.toLowerCase().trim()
    if (!query) return true
    return p.name.toLowerCase().includes(query) || p.citizenid.toLowerCase().includes(query) || String(p.id) === query
  }))

  async function load() {
    players = (await fetchNui('admin:getPlayers')) ?? []
    if (selected && !players.some((p) => p.id === selected.id)) selected = null
  }

  async function open(entry) {
    const detail = await fetchNui('admin:getPlayer', { id: entry.id })
    if (!detail) return
    if (!detail.actives || Array.isArray(detail.actives)) detail.actives = {}
    selected = detail
    expanded = null
    if (!giveTree || !detail.trees.some((t) => t.name === giveTree)) {
      giveTree = Object.values(detail.actives)[0] ?? detail.trees[0]?.name ?? null
    }
  }

  async function give(type) {
    if (!selected || !giveTree || busy) return
    const value = Math.floor(Number(amount))
    if (!value) return
    busy = true
    await fetchNui('admin:give', { id: selected.id, tree: giveTree, type, amount: value })
    const detail = await fetchNui('admin:getPlayer', { id: selected.id })
    if (detail) selected = detail
    await load()
    busy = false
  }

  function back() {
    app.view = app.viewTree ? 'tree' : 'picker'
  }

  load()
</script>

<div class="admin">
  <div class="head panel">
    <div class="head-id">
      <h1>Players</h1>
      <span class="badge red">Admin</span>
    </div>
    <div class="head-actions">
      <button class="btn subtle" onclick={load}>
        <i class="fa-solid fa-rotate"></i> Refresh
      </button>
      <button class="btn subtle" onclick={back}>Go back</button>
      <button class="btn subtle icon" onclick={() => fetchNui('close')} aria-label="Close" data-tip="Close" data-tip-down>
        <i class="fa-solid fa-xmark"></i>
      </button>
    </div>
  </div>

  <div class="body">
    <div class="list panel">
      <div class="list-search">
        <input class="input" placeholder="Search name, citizen id or server id" bind:value={search} />
      </div>
      <div class="rows scroll">
        {#each filtered as entry (entry.id)}
          <button class="row" class:on={selected?.id === entry.id} onclick={() => open(entry)}>
            <span class="row-id">{entry.id}</span>
            <span class="row-name">
              {entry.name}
              <span class="row-cid">{entry.citizenid}</span>
            </span>
            <span class="row-tree">
              {#if entry.active}
                {entry.activeLabel ?? entry.active}
                <span class="row-lvl">Lv {entry.level}</span>
              {:else}
                <span class="row-none">No specialization</span>
              {/if}
            </span>
          </button>
        {:else}
          <div class="empty">No players found.</div>
        {/each}
      </div>
    </div>

    <div class="detail panel">
      {#if selected}
        <div class="detail-head">
          <div>
            <div class="detail-name">{selected.name}</div>
            <div class="detail-cid">{selected.citizenid} — server id {selected.id}</div>
          </div>
        </div>

        <div class="give">
          <select class="select" bind:value={giveTree}>
            {#each selected.trees as tree (tree.name)}
              <option value={tree.name}>{tree.label}{selected.actives[tree.category] === tree.name ? ' (active)' : ''}</option>
            {/each}
          </select>
          <div class="amount">
            <NumberInput bind:value={amount} step={5} />
          </div>
          <button class="btn" disabled={busy} onclick={() => give('xp')}>XP</button>
          <button class="btn" disabled={busy} onclick={() => give('levels')}>Levels</button>
          <button class="btn" disabled={busy} onclick={() => give('points')}>Points</button>
        </div>
        <span class="hint">XP is positive only and levels up normally; levels and points accept negative amounts for corrections.</span>

        <div class="trees scroll">
          {#each selected.trees as tree (tree.name)}
            <div class="tree-row" class:active={selected.actives[tree.category] === tree.name}>
              <div class="tree-top">
                <span class="tree-label">
                  {tree.label}
                  {#if selected.actives[tree.category] === tree.name}
                    <span class="badge blue">Active</span>
                  {/if}
                </span>
                <span class="tree-stats">
                  Lv {tree.level}{tree.level >= selected.maxLevel ? ' (max)' : ` — ${tree.xp} / ${tree.next} XP`}
                  · {tree.points} pt{tree.points === 1 ? '' : 's'}
                </span>
              </div>
              <div class="bar">
                <div class="fill" style:width={`${tree.level >= selected.maxLevel ? 100 : Math.min(100, (tree.xp / Math.max(1, tree.next)) * 100)}%`}></div>
              </div>
              {#if tree.skills.length}
                <button class="skills-toggle" onclick={() => (expanded = expanded === tree.name ? null : tree.name)}>
                  {tree.skills.length} skill{tree.skills.length === 1 ? '' : 's'} unlocked
                  <i class="fa-solid fa-chevron-{expanded === tree.name ? 'up' : 'down'}"></i>
                </button>
                {#if expanded === tree.name}
                  <div class="chips">
                    {#each tree.skills as skill (skill)}
                      <span class="badge green">{skill}</span>
                    {/each}
                  </div>
                {/if}
              {:else}
                <span class="hint">No skills unlocked.</span>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty">Select a player to inspect and adjust their progression.</div>
      {/if}
    </div>
  </div>
</div>

<style>
  .admin {
    display: flex;
    flex-direction: column;
    gap: 12px;
    width: min(1100px, 92vw);
    height: min(760px, 88vh);
  }

  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
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

  .head-actions {
    display: flex;
    gap: 8px;
  }

  .body {
    flex: 1;
    display: flex;
    gap: 12px;
    min-height: 0;
  }

  .list {
    display: flex;
    flex-direction: column;
    width: 400px;
    flex-shrink: 0;
  }

  .list-search {
    padding: 12px;
    border-bottom: 1px solid var(--dark-4);
  }

  .rows {
    flex: 1;
    display: flex;
    flex-direction: column;
    padding: 8px;
    gap: 4px;
  }

  .row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    font-family: inherit;
    font-size: 13px;
    text-align: left;
    color: var(--dark-0);
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .row:hover {
    background: var(--dark-6);
  }

  .row.on {
    background: var(--accent-8);
    border-color: var(--blue);
  }

  .row-id {
    flex: none;
    min-width: 30px;
    font-weight: 700;
    color: var(--dark-2);
  }

  .row-name {
    flex: 1;
    display: flex;
    flex-direction: column;
    font-weight: 500;
    min-width: 0;
  }

  .row-cid {
    font-size: 11px;
    font-weight: 400;
    color: var(--dark-3);
  }

  .row-tree {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    font-size: 12px;
    color: var(--dark-1);
  }

  .row-lvl {
    font-size: 11px;
    color: var(--blue-light);
  }

  .row-none {
    font-size: 11px;
    color: var(--dark-3);
  }

  .detail {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 16px;
    min-width: 0;
  }

  .detail-name {
    font-size: 17px;
    font-weight: 700;
    color: #fff;
  }

  .detail-cid {
    font-size: 12px;
    color: var(--dark-2);
  }

  .give {
    display: flex;
    gap: 8px;
  }

  .give .select {
    flex: 1;
  }

  .give .amount {
    width: 90px;
    flex: none;
  }

  .trees {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .tree-row {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px 14px;
    background: var(--dark-8);
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-md);
  }

  .tree-row.active {
    border-color: var(--blue);
  }

  .tree-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .tree-label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 700;
    color: #fff;
  }

  .tree-stats {
    font-size: 12px;
    color: var(--dark-1);
  }

  .bar {
    height: 6px;
    background: var(--dark-5);
    border-radius: 3px;
    overflow: hidden;
  }

  .fill {
    height: 100%;
    background: var(--blue);
    border-radius: 3px;
  }

  .skills-toggle {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    align-self: flex-start;
    font-family: inherit;
    font-size: 12px;
    color: var(--blue-light);
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
</style>
