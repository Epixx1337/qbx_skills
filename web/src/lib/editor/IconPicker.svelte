<script>
  import { ICONS } from '../icons.js'

  let { value = $bindable('star') } = $props()

  let search = $state('')
  let open = $state(false)

  const filtered = $derived(
    search ? ICONS.filter((i) => i.includes(search.toLowerCase().trim())) : ICONS
  )
</script>

<div class="picker">
  <div class="row">
    <span class="preview">
      <i class="fa-solid fa-{value}"></i>
    </span>
    <input
      class="input"
      placeholder="Search icons or type any Font Awesome name"
      bind:value={search}
      onfocus={() => (open = true)}
    />
    <button class="btn subtle" type="button" onclick={() => (open = !open)} aria-label="Toggle icon list">
      <i class="fa-solid fa-chevron-{open ? 'up' : 'down'}"></i>
    </button>
  </div>

  {#if open}
    <div class="grid scroll">
      {#each filtered as icon (icon)}
        <button
          type="button"
          class="opt"
          class:on={icon === value}
          data-tip={icon}
          onclick={() => { value = icon; open = false }}
        >
          <i class="fa-solid fa-{icon}"></i>
        </button>
      {/each}
      {#if search && !ICONS.includes(search.toLowerCase().trim())}
        <button type="button" class="opt custom" data-tip="Use '{search}'" onclick={() => { value = search.toLowerCase().trim(); open = false }}>
          <i class="fa-solid fa-{search.toLowerCase().trim()}"></i>
        </button>
      {/if}
      {#if !filtered.length && !search}
        <div class="empty">No icons</div>
      {/if}
    </div>
    <span class="hint">Any free Font Awesome solid icon name works — type it and click the last tile to use it.</span>
  {/if}
</div>

<style>
  .picker {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .preview {
    display: flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 36px;
    height: 36px;
    font-size: 16px;
    color: var(--blue-light);
    background: var(--accent-15);
    border: 1px solid var(--blue);
    border-radius: var(--radius-sm);
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(38px, 1fr));
    gap: 4px;
    max-height: 160px;
    padding: 6px;
    background: var(--dark-8);
    border: 1px solid var(--dark-4);
    border-radius: var(--radius-sm);
  }

  .opt {
    display: flex;
    align-items: center;
    justify-content: center;
    aspect-ratio: 1;
    font-size: 15px;
    color: var(--dark-1);
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .opt:hover {
    color: #fff;
    background: var(--dark-5);
  }

  .opt.on {
    color: var(--blue-light);
    background: var(--accent-15);
    border-color: var(--blue);
  }

  .opt.custom {
    color: var(--yellow);
    border: 1px dashed var(--dark-3);
  }
</style>
