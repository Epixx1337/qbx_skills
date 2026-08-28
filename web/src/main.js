import { mount } from 'svelte'
import '@fortawesome/fontawesome-free/css/all.min.css'
import App from './App.svelte'

export default mount(App, { target: document.getElementById('app') })
