import { api, clearCredentials, hasCredentials } from './api.js';
import { currentPath, resolve, route } from './router.js';
import { h, icon } from './ui.js';

const NAV = [
  { path: '/pilotage', label: 'Pilotage', icon: 'progress' },
  { path: '/testeuses', label: 'Testeuses', icon: 'profile', badge: 'testers' },
  { path: '/imports', label: 'Imports', icon: 'upload', badge: 'imports' },
  { path: '/qualite', label: 'Qualité des fiches', icon: 'document', badge: 'quality' },
  { path: '/couts', label: 'Coûts', icon: 'euro' },
  { path: '/reglages', label: 'Réglages', icon: 'settings' },
];

route('/pilotage', () => import('./views/pilotage.js'));
route('/testeuses', () => import('./views/testeuses.js'));
route('/testeuses/:id', () => import('./views/testeuse.js'));
route('/imports', () => import('./views/imports.js'));
route('/imports/:id', () => import('./views/import.js'));
route('/qualite', () => import('./views/qualite.js'));
route('/qualite/:id', () => import('./views/qualite.js'));
route('/couts', () => import('./views/couts.js'));
route('/reglages', () => import('./views/reglages.js'));

const app = document.getElementById('app');
let shell = null;
let cleanup = null;

function buildShell() {
  const links = NAV.map((n) => {
    const pill = n.badge ? h('span', { class: 'pill', hidden: true, 'data-badge': n.badge }) : null;
    return h('a', { class: 'nav-link', href: `#${n.path}`, 'data-path': n.path }, icon(n.icon, 18), n.label, pill);
  });
  const side = h('nav', { class: 'side' },
    h('div', { class: 'brand' }, h('img', { src: '/admin/logo.svg', alt: '' }), 'Collega admin'),
    ...links,
    h('div', { class: 'side-foot' }, h('a', { class: 'nav-link', href: '#', onclick: (e) => { e.preventDefault(); logout(); } }, icon('logout', 18), 'Se déconnecter')));
  const content = h('main', { class: 'main' });
  const root = h('div', { class: 'shell' },
    h('div', { class: 'topbar' }, h('button', { class: 'icon-btn', 'aria-label': 'Menu', onclick: () => root.classList.toggle('drawer-open') }, icon('more', 20)), 'Collega admin'),
    side, content);
  side.addEventListener('click', (e) => { if (e.target.closest('a')) root.classList.remove('drawer-open'); });
  return { root, content, links };
}

async function refreshBadges() {
  try {
    const { data } = await api('/badges');
    for (const el of shell.root.querySelectorAll('[data-badge]')) {
      const n = data[el.dataset.badge] ?? 0;
      el.textContent = String(n);
      el.hidden = n === 0;
    }
  } catch { /* les pastilles ne bloquent jamais l'écran */ }
}

async function render() {
  if (!hasCredentials()) return showLogin();
  if (!shell) { shell = buildShell(); app.replaceChildren(shell.root); }
  cleanup?.();
  cleanup = null;
  const path = currentPath();
  for (const a of shell.links) a.classList.toggle('on', path === a.dataset.path || path.startsWith(`${a.dataset.path}/`));
  const found = resolve(path) ?? resolve('/pilotage');
  shell.content.replaceChildren();
  window.scrollTo(0, 0);
  const view = await found.loader();
  cleanup = (await view.render(shell.content, found.params)) ?? null;
  refreshBadges();
}

async function showLogin() {
  shell = null;
  const { render: renderLogin } = await import('./views/login.js');
  app.replaceChildren();
  renderLogin(app, () => render());
}

function logout() {
  clearCredentials();
  cleanup?.();
  cleanup = null;
  showLogin();
}

window.addEventListener('hashchange', render);
window.addEventListener('admin:logout', () => { cleanup?.(); cleanup = null; showLogin(); });
window.addEventListener('admin:badges', refreshBadges);
render();
