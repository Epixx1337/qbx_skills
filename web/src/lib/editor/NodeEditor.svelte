<script>
  import { fetchNui } from '../nui.js'
  import { app, pushUndo, nodeSnapshot } from '../store.svelte.js'
  import IconPicker from './IconPicker.svelte'
  import NumberInput from '../NumberInput.svelte'

  const editing = app.nodeEditor
  const node = editing.node
  const original = node ? nodeSnapshot(node) : null

  let label = $state(node?.label ?? '')
  let name = $state(node?.name ?? '')
  let nameTouched = $state(!!node)
  let description = $state(node?.description ?? '')
  let icon = $state(node?.icon ?? 'star')
  let cost = $state(node?.cost ?? 1)
  let bonuses = $state(
    Object.entries(node?.bonuses ?? {}).map(([key, value]) => ({ key, value }))
  )
  let saving = $state(false)

  $effect(() => {
    if (!nameTouched) name = label.toLowerCase().trim().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
  })

  const valid = $derived(label.trim().length > 0 && /^[a-z0-9_]+$/.test(name))

  function addBonus() {
    bonuses.push({ key: '', value: 0 })
  }

  function removeBonus(index) {
    bonuses.splice(index, 1)
  }

  async function save() {
    if (!valid || saving) return
    saving = true

    const bonusMap = {}
    for (const row of bonuses) {
      const key = row.key.toLowerCase().trim().replace(/[^a-z0-9_]+/g, '_')
      const value = Number(row.value)
      if (key && !Number.isNaN(value)) bonusMap[key] = value
    }

    const result = await fetchNui('editor:saveNode', {
      id: node?.id,
      tree: editing.tree,
      name,
      label: label.trim(),
      description: description.trim() || null,
      icon,
      cost: Math.max(1, Math.floor(Number(cost) || 1)),
      x: node?.x ?? editing.x,
      y: node?.y ?? editing.y,
      bonuses: bonusMap,
    })

    saving = false
    if (result) {
      if (original) pushUndo({ type: 'editNode', node: original })
      else if (result.id) pushUndo({ type: 'createNode', id: result.id })
      app.nodeEditor = null
    }
  }
</script>

<div class="backdrop" role="presentation" onclick={(e) => { if (e.target === e.currentTarget) app.nodeEditor = null }}>
  <div class="modal panel">
    <div class="modal-head">
      <span class="title">{node ? 'Edit skill' : 'New skill'}</span>
      <button class="btn subtle icon" onclick={() => (app.nodeEditor = null)} aria-label="Close">
        <i class="fa-solid fa-xmark"></i>
      </button>
    </div>

    <div class="fields scroll">
      <div class="field">
        <span class="label">Label</span>
        <input class="input" bind:value={label} placeholder="Steady Hands" />
      </div>

      <div class="field">
        <span class="label">Identifier</span>
        <input class="input mono" bind:value={name} oninput={() => (nameTouched = true)} placeholder="steady_hands" />
        <span class="hint">Scripts check this with the HasSkill export — lowercase letters, numbers and underscores.</span>
      </div>

      <div class="field">
        <span class="label">Description</span>
        <textarea class="input" rows="3" bind:value={description} placeholder="What does this skill do for the player?"></textarea>
      </div>

      <div class="field">
        <span class="label">Icon</span>
        <IconPicker bind:value={icon} />
      </div>

      <div class="field">
        <span class="label">Cost (talent points)</span>
        <NumberInput bind:value={cost} min={1} />
      </div>

      <div class="field">
        <span class="label">Bonuses</span>
        <span class="hint">Key/value pairs scripts read with the GetSkillBonus export. Use fractions for percentages (0.15 = 15%).</span>
        {#each bonuses as bonus, index (index)}
          <div class="bonus-row">
            <input class="input mono" bind:value={bonus.key} placeholder="lockpick_speed" />
            <div class="value">
              <NumberInput bind:value={bonus.value} step={0.05} />
            </div>
            <button class="btn subtle icon" onclick={() => removeBonus(index)} aria-label="Remove bonus" data-tip="Remove bonus">
              <i class="fa-solid fa-trash"></i>
            </button>
          </div>
        {/each}
        <button class="btn subtle" onclick={addBonus}>
          <i class="fa-solid fa-plus"></i> Add bonus
        </button>
      </div>
    </div>

    <div class="modal-foot">
      <button class="btn subtle" onclick={() => (app.nodeEditor = null)}>Cancel</button>
      <button class="btn" disabled={!valid || saving} onclick={save}>
        <i class="fa-solid fa-floppy-disk"></i> Save skill
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
    width: 440px;
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

  .bonus-row {
    display: flex;
    gap: 6px;
  }

  .bonus-row .value {
    width: 100px;
    flex: none;
  }

  .modal-foot {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding: 14px 16px;
    border-top: 1px solid var(--dark-4);
  }
</style>
