import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, banner, empty, fmtInt, h, tag } from '../ui.js';

const FILTERS = [['all', 'Tous'], ['running', 'En cours'], ['failed', 'En échec'], ['done', 'Terminés']];
const RUNNING = new Set(['pending', 'processing', 'ocr_complete']);

export async function render(root) {
  let filter = 'all';
  let jobs = [];
  let names = {};
  const list = h('div');
  const error = h('div');
  const seg = h('div', { class: 'seg' }, ...FILTERS.map(([key, label]) =>
    h('button', { class: key === filter ? 'on' : '', onclick: (e) => { filter = key; for (const b of seg.children) b.classList.toggle('on', b === e.currentTarget); draw(); } }, label)));

  async function load() {
    try {
      const [{ data }, { data: colleges }] = await Promise.all([api('/queue'), api('/colleges')]);
      jobs = data;
      names = Object.fromEntries(colleges.map((c) => [c.college_id, c]));
      error.replaceChildren();
      draw();
    } catch (err) {
      error.replaceChildren(banner(err, load));
    }
  }

  function draw() {
    const rows = jobs.filter((j) => filter === 'all' || (filter === 'running' && RUNNING.has(j.status)) || (filter === 'failed' && j.status === 'failed') || (filter === 'done' && j.status === 'generation_complete'));
    if (!rows.length) { list.replaceChildren(empty('Aucun import dans ce filtre.')); return; }
    list.replaceChildren(h('table', { class: 'table' },
      h('thead', {}, h('tr', {}, ...['Collège', 'Testeuse', 'Statut', 'OCR', 'Fiches', 'Durée'].map((c) => h('th', {}, c)))),
      h('tbody', {}, ...rows.map((j) => {
        const c = names[j.college_id];
        return h('tr', { class: 'link', onclick: () => go(`/imports/${j.job_id}`) },
          h('td', {}, c?.college_name ?? 'Collège supprimé'),
          h('td', {}, c?.user_email ?? '—'),
          h('td', {}, tag(...(JOB_STATUS_LABEL[j.status] ?? [j.status, '']))),
          h('td', {}, j.college_total_pages ? `${j.college_ocr_page_progress}/${j.college_total_pages}` : '—'),
          h('td', {}, fmtInt(j.card_count)),
          h('td', {}, `${Math.round(j.elapsed_seconds / 60)} min`));
      }))));
  }

  root.append(h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Imports'), h('div', { class: 'sub' }, '50 derniers imports, rafraîchis toutes les 5 secondes.'))),
    error, h('div', { class: 'toolbar' }, seg), list);
  await load();
  const timer = setInterval(load, 5000);
  return () => clearInterval(timer);
}
