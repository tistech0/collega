import { api } from '../api.js';
import { go } from '../router.js';
import { banner, empty, fmtInt, h, icon, tag } from '../ui.js';

const FILTERS = [['all', 'Toutes'], ['negative', 'Avis négatifs'], ['low', 'Confiance OCR faible']];

export async function render(root, { id } = {}) {
  let colleges;
  try {
    ({ data: colleges } = await api('/colleges'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root, { id }); }));
    return;
  }
  // Best-effort : marquer la qualité comme vue ne doit jamais bloquer l'écran
  // (la pastille resterait simplement affichée un peu plus longtemps).
  try {
    await api('/badges/quality-seen', { method: 'POST' });
    window.dispatchEvent(new Event('admin:badges'));
  } catch { /* pastille : non bloquant */ }
  root.append(h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Qualité des fiches'))));
  if (!colleges.length) { root.append(empty('Aucun collège importé pour l\'instant.')); return; }

  const current = colleges.find((c) => c.college_id === id) ?? colleges.find((c) => c.negative_count > 0) ?? colleges[0];
  const select = h('select', { class: 'input', style: 'width:auto;max-width:100%', onchange: (e) => go(`/qualite/${e.target.value}`) },
    ...colleges.map((c) => h('option', { value: c.college_id, selected: c.college_id === current.college_id }, `${c.college_name} — ${c.user_email ?? 'compte supprimé'}${c.negative_count ? ` (${c.negative_count} négatif${c.negative_count > 1 ? 's' : ''})` : ''}`)));
  let filter = current.negative_count ? 'negative' : 'all';
  const stats = h('div', { class: 'stats' });
  const grid = h('div', { class: 'cards' });
  const seg = h('div', { class: 'seg' }, ...FILTERS.map(([key, label]) =>
    h('button', { class: key === filter ? 'on' : '', onclick: (e) => { filter = key; for (const b of seg.children) b.classList.toggle('on', b === e.currentTarget); draw(); } }, label)));
  root.append(h('div', { class: 'toolbar' }, select, seg, stats), grid);

  let cards;
  try {
    const [{ data: s }, { data: c }] = await Promise.all([api(`/colleges/${current.college_id}/stats`), api(`/colleges/${current.college_id}/cards`)]);
    cards = c;
    const rated = cards.filter((x) => x.user_feedback);
    const positive = rated.filter((x) => x.user_feedback === 'positive').length;
    stats.replaceChildren(
      h('span', {}, h('b', {}, fmtInt(cards.length)), ' fiches'),
      h('span', {}, h('b', {}, fmtInt(s.items_ocr_confidence.length)), ' items'),
      h('span', {}, h('b', {}, rated.length ? `${Math.round((positive / rated.length) * 100)} %` : '—'), ' avis positifs'),
      h('span', {}, h('b', {}, fmtInt(cards.filter((x) => x.low_confidence).length)), ' OCR faible'));
  } catch (err) {
    grid.replaceChildren(banner(err));
    return;
  }

  function draw() {
    const shown = cards.filter((c) => filter === 'all' || (filter === 'negative' && c.user_feedback === 'negative') || (filter === 'low' && c.low_confidence));
    // Auteur de l'avis (spec § 3.2 écran 6) : seule la propriétaire du collège
    // note ses fiches, donc l'auteur = l'e-mail du compte du collège affiché.
    grid.replaceChildren(...(shown.length ? shown.map((c) => card(c, current.user_email)) : [empty('Aucune fiche dans ce filtre.')]));
  }
  draw();
}

function card(c, authorEmail) {
  const fb = c.user_feedback === 'negative' ? icon('thumbDown', 16, 'fb-neg') : c.user_feedback === 'positive' ? icon('thumbUp', 16, 'fb-pos') : null;
  return h('article', { class: `fc${c.user_feedback === 'negative' ? ' neg' : ''}` },
    h('div', { class: 'top' }, h('span', { class: `rank ${c.rang}` }, c.rang), h('span', { class: 'item' }, `Item ${c.item_number ?? '?'}`), h('span', { class: 'fb' }, fb)),
    h('div', { class: 'recto' }, c.recto),
    h('div', { class: 'verso' }, c.verso),
    h('div', { class: 'foot' }, tag(c.card_type.replace('_', ' ')), c.low_confidence ? tag(`OCR ${c.ocr_confidence_score.toFixed(2)}`, 'warn') : null,
      c.user_feedback ? h('span', { class: 'muted' }, `avis de ${authorEmail ?? 'compte supprimé'}`) : null));
}
