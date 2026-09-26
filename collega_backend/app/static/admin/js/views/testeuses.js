import { api } from '../api.js';
import { go } from '../router.js';
import { STATUS_LABEL, banner, displayName, empty, fmtAgo, fmtDate, h, icon, panel, tag, toast } from '../ui.js';

const FILTERS = [['all', 'Toutes'], ['active', 'Actives'], ['inactive', 'Inactives'], ['never_seen', 'Jamais connectées']];

export async function render(root) {
  let pilot;
  let config;
  try {
    [{ data: pilot }, { data: config }] = await Promise.all([api('/pilot'), api('/config')]);
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  let filter = 'all';
  const list = h('div');
  const seg = h('div', { class: 'seg', role: 'tablist' }, ...FILTERS.map(([key, label]) =>
    h('button', { class: key === filter ? 'on' : '', onclick: (e) => { filter = key; for (const b of seg.children) b.classList.toggle('on', b === e.currentTarget); draw(); } }, label)));

  function draw() {
    const rows = pilot.testers.filter((t) => filter === 'all' || t.status === filter);
    if (!rows.length) { list.replaceChildren(empty('Aucune testeuse dans ce filtre.')); return; }
    list.replaceChildren(h('table', { class: 'table' },
      h('thead', {}, h('tr', {}, ...['Testeuse', 'Créée le', 'Dernière activité', 'Série', 'Fiches 7 j', 'Collèges'].map((c) => h('th', {}, c)))),
      h('tbody', {}, ...rows.map((t) => {
        const [label, tone] = STATUS_LABEL[t.status];
        return h('tr', { class: 'link', onclick: () => go(`/testeuses/${t.user_id}`) },
          h('td', {}, h('div', {}, displayName(t)), t.first_name ? h('div', { class: 'muted' }, t.email) : null),
          h('td', {}, fmtDate(t.created_at)),
          h('td', {}, t.status === 'active' ? fmtAgo(t.last_seen_at) : tag(label, tone)),
          h('td', {}, t.streak ? `${t.streak} j` : '—'),
          h('td', {}, String(t.cards_7d)),
          h('td', {}, String(t.college_count)));
      }))));
  }

  root.append(
    h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Testeuses'), h('div', { class: 'sub' }, `${pilot.testers.length} compte${pilot.testers.length > 1 ? 's' : ''} beta`)),
      h('div', { class: 'actions' }, h('button', { class: 'btn primary', onclick: () => openCreate(config.testflight_url) }, icon('plus', 16), 'Nouvelle testeuse'))),
    h('div', { class: 'toolbar' }, seg),
    list);
  draw();
}

function randomPassword() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('');
}

export function invitation({ firstName, email, password, testflightUrl }) {
  return [
    `Bonjour${firstName ? ` ${firstName}` : ''},`,
    '',
    'Merci de tester Collega. Pour installer la beta :',
    testflightUrl ? `1. Ouvre ce lien sur ton iPhone : ${testflightUrl}` : '1. Installe TestFlight depuis l\'App Store, puis ouvre l\'invitation reçue par e-mail.',
    '2. Installe Collega depuis TestFlight, puis connecte-toi avec :',
    `   Identifiant : ${email}`,
    `   Mot de passe : ${password}`,
    '',
    'Tes retours sont précieux : réponds simplement à ce message.',
  ].join('\n');
}

function openCreate(testflightUrl) {
  const email = h('input', { class: 'input', id: 'n-email', type: 'email', required: true, autocomplete: 'off' });
  const firstName = h('input', { class: 'input', id: 'n-first', autocomplete: 'off', maxlength: '100' });
  const error = h('div');
  const submit = h('button', { class: 'btn primary', type: 'submit' }, 'Créer le compte');
  const form = h('form', { onsubmit: async (e) => {
    e.preventDefault();
    submit.disabled = true;
    error.replaceChildren();
    const password = randomPassword();
    try {
      const { data } = await api('/users', { method: 'POST', body: { email: email.value.trim(), password, is_beta: true, first_name: firstName.value.trim() || null } });
      const text = invitation({ firstName: firstName.value.trim(), email: data.email, password, testflightUrl });
      form.replaceChildren(
        h('p', {}, 'Compte créé. Le mot de passe n\'est affiché qu\'une fois : copie le message maintenant.'),
        h('pre', { class: 'invite' }, text),
        h('div', { class: 'toolbar' },
          h('button', { class: 'btn primary', type: 'button', onclick: async () => { await navigator.clipboard.writeText(text); toast('Message copié'); } }, 'Copier le message d\'invitation'),
          h('button', { class: 'btn', type: 'button', onclick: () => { p.close(); go(`/testeuses/${data.user_id}`); } }, 'Voir la fiche')));
      window.dispatchEvent(new Event('admin:badges'));
    } catch (err) {
      error.replaceChildren(banner(err));
      submit.disabled = false;
    }
  } },
    error,
    h('div', { class: 'field' }, h('label', { for: 'n-email' }, 'E-mail'), email),
    h('div', { class: 'field' }, h('label', { for: 'n-first' }, 'Prénom'), firstName, h('div', { class: 'help' }, 'Facultatif, utilisé dans le message d\'invitation.')),
    h('div', { class: 'field' }, h('div', { class: 'help' }, 'Un mot de passe provisoire est généré ; le compte a l\'accès beta.')),
    submit);
  const p = panel('Nouvelle testeuse', form);
  email.focus();
}
