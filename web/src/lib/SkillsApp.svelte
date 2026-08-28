<script>
  import { app } from './store.svelte.js'
  import TreePicker from './TreePicker.svelte'
  import SkillTree from './SkillTree.svelte'
  import AdminPanel from './AdminPanel.svelte'
  import NodeEditor from './editor/NodeEditor.svelte'
  import TreeEditor from './editor/TreeEditor.svelte'
</script>

<div class="overlay">
  {#if app.view === 'players' && app.data.isAdmin}
    <AdminPanel />
  {:else if app.view === 'picker' || !app.viewTree}
    <TreePicker />
  {:else}
    <SkillTree />
  {/if}

  {#if app.nodeEditor}
    <NodeEditor />
  {/if}
  {#if app.treeEditor}
    <TreeEditor />
  {/if}
</div>

<style>
  .overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: radial-gradient(ellipse at center, rgba(16, 17, 19, 0.55) 0%, rgba(16, 17, 19, 0.85) 100%);
  }
</style>
