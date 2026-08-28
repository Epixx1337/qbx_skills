<script>
  let { value = $bindable(0), step = 1, min = null, max = null, placeholder = '' } = $props()

  function nudge(direction) {
    let next = (Number(value) || 0) + direction * step
    if (min !== null && next < min) next = min
    if (max !== null && next > max) next = max
    value = Math.round(next * 100) / 100
  }
</script>

<div class="numwrap">
  <input class="input" type="number" bind:value {placeholder} {step} />
  <div class="spin">
    <button type="button" tabindex="-1" onclick={() => nudge(1)} aria-label="Increase">
      <i class="fa-solid fa-chevron-up"></i>
    </button>
    <button type="button" tabindex="-1" onclick={() => nudge(-1)} aria-label="Decrease">
      <i class="fa-solid fa-chevron-down"></i>
    </button>
  </div>
</div>

<style>
  .numwrap {
    position: relative;
    width: 100%;
  }

  .numwrap .input {
    padding-right: 28px;
  }

  .spin {
    position: absolute;
    top: 1px;
    right: 1px;
    bottom: 1px;
    display: flex;
    flex-direction: column;
    width: 22px;
    border-left: 1px solid var(--dark-4);
    border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
    overflow: hidden;
  }

  .spin button {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    font-size: 8px;
    color: var(--dark-2);
    background: var(--dark-6);
    border: none;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .spin button:first-child {
    border-bottom: 1px solid var(--dark-4);
  }

  .spin button:hover {
    color: var(--dark-0);
    background: var(--dark-5);
  }

  .spin button:active {
    background: var(--dark-4);
  }
</style>
