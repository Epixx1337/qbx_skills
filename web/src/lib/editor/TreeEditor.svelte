<script>
  import { fetchNui } from '../nui.js'
  import { app } from '../store.svelte.js'
  import NumberInput from '../NumberInput.svelte'

  const editing = app.treeEditor
  const tree = editing.tree

  let label = $state(tree?.label ?? '')
  let name = $state(tree?.name ?? '')
  let nameTouched = $state(!!tree)
  let category = $state(tree?.category ?? editing.category ?? 'civilian')
  let description = $state(tree?.description ?? '')
  let color = $state(tree?.color ?? '')
  let sort = $state(tree?.sort ?? 0)
  let enabled = $state(tree ? tree.enabled : true)
  let jobs = $state(tree?.jobs ? Object.entries(tree.jobs).map(([job, grade]) => (grade > 0 ? `${job}:${grade}` : job)).join(', ') : '')
  let confirmingDelete = $state(false)
  let saving = $state(false)

  $effect(() => {
    if (!nameTouched) name = label.toLowerCase().trim().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
  })

  const valid = $derived(label.trim().length > 0 && /^[a-z0-9_]+$/.test(name) && /^[a-z0-9_]+$/.test(category.toLowerCase().trim()))

  async function save() {
    if (!valid || saving) return
    saving = true

    let jobsMap = null
    if (jobs.trim()) {
      jobsMap = {}
      for (const part of jobs.split(',')) {
        const [job, grade] = part.trim().split(':')
        const jobName = job?.toLowerCase().trim().replace(/[^a-z0-9_]+/g, '_')
        if (jobName) jobsMap[jobName] = Math.max(0, Math.floor(Number(grade) || 0))
      }
      if (!Object.keys(jobsMap).length) jobsMap = null
    }

    const ok = await fetchNui('editor:saveTree', {
      originalName: tree?.name,
      name,
      label: label.trim(),
      category: category.toLowerCase().trim(),
      description: description.trim() || null,
      color: /^#[0-9a-fA-F]{6}$/.test(color) ? color : null,
      sort: Math.floor(Number(sort) || 0),
      enabled,
      jobs: jobsMap,
    })

    saving = false
    if (ok) {
      if (app.viewTree === tree?.name) app.viewTree = name
      app.treeEditor = null
    }
  }

  async function remove() {
    if (!confirmingDelete) {
      confirmingDelete = true
      return
    }
    const ok = await fetchNui('editor:deleteTree', tree.name)
    if (ok) {
      if (app.viewTree === tree.name) {
        app.viewTree = null
        app.view = 'picker'
      }
      app.treeEditor = null
    }
  }
</script>

<div class="backdrop" role="presentation" onclick={(e) => { if (e.target === e.currentTarget) app.treeEditor = null }}>
  <div class="modal panel">
    <div class="modal-head">
      <span class="title">{tree ? 'Edit tree' : 'New tree'}</span>
      <button class="btn subtle icon" onclick={() => (app.treeEditor = null)} aria-label="Close">
        <i class="fa-solid fa-xmark"></i>
      </button>
    </div>

    <div class="fields scroll">
      <div class="field">
        <span class="label">Label</span>
        <input class="input" bind:value={label} placeholder="Shadow Work" />
      </div>

      <div class="field">
        <span class="label">Identifier</span>
        <input class="input mono" bind:value={name} oninput={() => (nameTouched = true)} placeholder="shadow_work" />
        <span class="hint">Used by the AddTreeXp export — lowercase letters, numbers and underscores.</span>
      </div>

      <div class="field">
        <span class="label">Category</span>
        <input class="input mono" bind:value={category} placeholder="crime" list="categories" />
        <datalist id="categories">
          {#each app.data.categories as cat (cat)}
            <option value={cat}></option>
          {/each}
        </datalist>
        <span class="hint">Scripts award experience per category — the AddXp export only applies when the active tree matches.</span>
      </div>

      <div class="field">
        <span class="label">Description</span>
        <textarea class="input" rows="3" bind:value={description} placeholder="Shown on the specialization card."></textarea>
      </div>

      <div class="field">
        <span class="label">Job lock</span>
        <input class="input mono" bind:value={jobs} placeholder="police, ambulance:2" />
        <span class="hint">Empty means everyone. Comma-separated job names, optionally with a minimum grade (job:grade). Players who lose the job get the tree deactivated.</span>
      </div>

      <div class="field">
        <span class="label">Accent color</span>
        <div class="color-row">
          <input type="color" class="swatch" value={/^#[0-9a-fA-F]{6}$/.test(color) ? color : '#228be6'} oninput={(e) => (color = e.target.value)} />
          <input class="input mono" bind:value={color} placeholder="Empty uses the server theme color" />
          {#if color}
            <button class="btn subtle icon" onclick={() => (color = '')} aria-label="Clear color">
              <i class="fa-solid fa-xmark"></i>
            </button>
          {/if}
        </div>
      </div>

      <div class="split">
        <div class="field">
          <span class="label">Sort order</span>
          <NumberInput bind:value={sort} />
        </div>
        <label class="check">
          <input type="checkbox" bind:checked={enabled} />
          Selectable by players
        </label>
      </div>
    </div>

    <div class="modal-foot">
      {#if tree}
        <button class="btn danger" onclick={remove}>
          {confirmingDelete ? 'Deletes all progress — sure?' : 'Delete tree'}
        </button>
      {/if}
      <span class="spacer"></span>
      <button class="btn subtle" onclick={() => (app.treeEditor = null)}>Cancel</button>
      <button class="btn" disabled={!valid || saving} onclick={save}>
        <i class="fa-solid fa-floppy-disk"></i> Save tree
      </button>
    </div>
  </div>
</div>

<style>
  .backdrop {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(16, 17, 19, 0.6);
    z-index: 10;
  }

  .modal {
    display: flex;
    flex-direction: column;
    width: 420px;
    max-height: 84vh;
  }

  .modal-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    border-bottom: 1px solid var(--dark-4);
  }

  .title {
    font-size: 15px;
    font-weight: 700;
  }

  .fields {
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 16px;
    overflow-y: auto;
  }

  .mono {
    font-family: 'Roboto Mono', monospace;
    font-size: 12px;
  }

  .color-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .swatch {
    flex: none;
    width: 36px;
    height: 36px;
    padding: 0;
    background: none;
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .split {
    display: flex;
    align-items: flex-end;
    gap: 16px;
  }

  .split .field {
    width: 110px;
  }

  .modal-foot {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 14px 16px;
    border-top: 1px solid var(--dark-4);
  }

  .spacer {
    flex: 1;
  }
</style>
