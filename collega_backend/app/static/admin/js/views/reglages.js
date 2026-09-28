import { api } from '../api.js';
import { banner, block, h, toast } from '../ui.js';

const FIELDS = [
  ['inactivity_days', 'Seuil d\'inactivité (jours)', 'Au-delà, une testeuse est signalée « inactive » dans la pastille et sur l\'accueil.', 'number', { min: 1, max: 60, required: true }],
  ['testflight_url', 'Lien public TestFlight', 'Inséré dans le message d\'invitation. Laisser vide si les invitations passent par e-mail Apple.', 'url', { placeholder: 'https://testflight.apple.com/join/…' }],
  ['reload_count_max', 'Réimports par collège', 'Nombre de réimports autorisés pour un même collège.', 'number', { min: 0, required: true }],
  ['monthly_reloads_max', 'Réimports par mois', 'Plafond mensuel de réimports par compte.', 'number', { min: 0, required: true }],
];

export async function render(root) {
  let config;
  try {
    ({ data: config } = await api('/config'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  const error = h('div');
  const inputs = {};
  const form = h('form', { onsubmit: async (e) => {
    e.preventDefault();
    const body = {};
    for (const [key, , , type] of FIELDS) {
      const v = inputs[key].value.trim();
      // Un champ nombre vidé (Number('') === 0) ne doit jamais s'enregistrer comme
      // 0 : on l'omet du corps plutôt que d'envoyer une valeur non voulue.
      if (type === 'number') {
        if (v === '') continue;
        body[key] = Number(v);
      } else {
        body[key] = v;
      }
    }
    try {
      ({ data: config } = await api('/config', { method: 'PATCH', body }));
      error.replaceChildren();
      toast('Réglages enregistrés');
      window.dispatchEvent(new Event('admin:badges'));
    } catch (err) {
      error.replaceChildren(banner(err));
    }
  } }, error,
    ...FIELDS.map(([key, label, help, type, attrs]) => {
      inputs[key] = h('input', { class: 'input', id: key, type, value: String(config[key] ?? ''), ...attrs });
      return h('div', { class: 'field' }, h('label', { for: key }, label), inputs[key], h('div', { class: 'help' }, help));
    }),
    h('button', { class: 'btn primary', type: 'submit' }, 'Enregistrer'));
  root.append(h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Réglages'), h('div', { class: 'sub' }, 'Appliqués en 30 secondes au plus, sans redémarrage.'))), block('Beta et anti-spam', null, form));
}
