import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, banner, block, empty, fmtDateTime, fmtEuro, fmtInt, h, icon, row, tag, toast } from '../ui.js';

const RUNNING = new Set(['pending', 'processing', 'ocr_complete']);
// Événements qui marquent l'échec/l'arrêt d'un import (même liste que l'ancienne
// console : tl-failed pour failed/stale, tl-cancelled pour cancelled), avec le
// point rouge de la timeline.
const FAILURE_EVENTS = new Set(['failed', 'stale', 'cancelled']);

export async function render(root, { id }) {
  const content = h('div');
  root.append(h('a', { class: 'crumb', href: '#/imports' }, icon('chevronLeft', 14), 'Imports'), content);

  // Déclaré avant tout await : cf. imports.js (même piège de navigation pendant
  // le premier chargement).
  let stopped = false;
  let timer = null;

  async function load() {
    let d;
    let college;
    try {
      ({ data: d } = await api(`/jobs/${id}`));
      if (stopped) return;
      college = (await api('/colleges')).data.find((c) => c.college_id === d.college_id);
      if (stopped) return;
    } catch (err) {
      if (!stopped) content.replaceChildren(banner(err, load));
      return;
    }
    const actions = h('div', { class: 'actions' },
      RUNNING.has(d.status) ? h('button', { class: 'btn', onclick: async () => {
        if (!confirm('Arrêter cet import ?')) return;
        try {
          const { data: stop } = await api(`/jobs/${id}/stop`, { method: 'POST' });
          toast(stop.aborted
            ? 'Import arrêté'
            : "Import marqué en échec, mais l'arrêt du worker n'a pas pu être confirmé.");
          load();
        } catch (err) { toast(err.message); }
      } }, 'Arrêter') : null,
      h('button', { class: 'btn danger', onclick: async () => {
        if (!confirm('Supprimer ce collège, ses fiches et ses fichiers ? Action définitive.')) return;
        try { await api(`/colleges/${d.college_id}`, { method: 'DELETE' }); toast('Collège supprimé'); go('/imports'); } catch (err) { toast(err.message); }
      } }, icon('trash', 16), 'Supprimer le collège'));
    const pages = d.total_pages ? `${d.ocr_page_progress}/${d.total_pages} pages` : 'pages inconnues';
    // replaceChildren() est natif : contrairement à h(), il ne filtre pas les
    // enfants null (il les convertirait en texte "null") — filtrer explicitement.
    content.replaceChildren(...[
      h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, `Import ${college?.college_name ?? ''}`.trim()),
        h('div', { class: 'sub' }, `${college?.user_email ?? 'compte supprimé'} · lancé ${fmtDateTime(d.created_at)} `, tag(...(JOB_STATUS_LABEL[d.status] ?? [d.status, ''])))), actions),
      d.error_message ? h('div', { class: 'banner' }, icon('warning', 18), h('span', {}, d.error_message)) : null,
      h('div', { class: 'grid kpis' },
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, pages), h('div', { class: 'label' }, 'OCR')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, fmtInt(d.card_count)), h('div', { class: 'label' }, 'fiches générées')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, String(d.items.length)), h('div', { class: 'label' }, 'items détectés')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, d.hash_shared ? 'oui' : 'non'), h('div', { class: 'label' }, 'PDF déjà connu (cache)')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, fmtEuro(d.cost_eur)), h('div', { class: 'label' }, 'coût Claude'))),
      h('div', { class: 'grid cols' },
        block('Déroulé', `${d.timeline.length} événements`, d.timeline.length
          ? h('ul', { class: 'timeline' }, ...dedupTimeline(d.timeline).map((e) => h('li', {}, h('span', { class: 'muted' }, fmtDateTime(e.created_at)),
            h('span', {}, h('b', { class: FAILURE_EVENTS.has(e.event_type) ? 'fb-neg' : '' }, e.event_type), e.page != null ? ` · page ${e.page}/${e.total ?? '?'}` : '', e.message ? h('div', { class: 'muted' }, e.message) : null))))
          : empty('Aucun événement.')),
        block('Confiance OCR par item', null, d.items.length ? d.items.map((it) => row(h('span', {}, `Item ${it.item_number}`),
          tag(`${Math.round(it.ocr_confidence_score * 100)} %`, it.low_confidence ? 'warn' : 'ok'))) : empty('Aucun item.')),
        block('Détails techniques', null,
          row(h('span', {}, 'Job'), h('span', { class: 'muted' }, d.job_id)),
          row(h('span', {}, 'arq_job_id'), h('span', { class: 'muted' }, d.arq_job_id ?? '—')),
          row(h('span', {}, 'PDF hash'), h('span', { class: 'muted' }, d.pdf_hash ?? '—')),
          row(h('span', {}, 'Appels Claude'), fmtInt(d.claude_calls)),
          row(h('span', {}, 'Tokens'), `${fmtInt(d.input_tokens)} entrée / ${fmtInt(d.output_tokens)} sortie`),
          row(h('span', {}, 'Mis à jour le'), fmtDateTime(d.updated_at)))),
      segmentation(d),
    ].filter(Boolean));
    if (!stopped && RUNNING.has(d.status)) timer = setTimeout(load, 5000);
  }

  await load();
  return () => { stopped = true; clearTimeout(timer); };
}

// Chantier 1 : un « generation_progress » par item — n'afficher que le dernier
// d'une série (même comportement que l'ancienne console, cf. task-9-brief).
function dedupTimeline(events) {
  return events.filter((e, i) => !(e.event_type === 'generation_progress'
    && events[i + 1] && events[i + 1].event_type === 'generation_progress'));
}

// Rapport de découpage (JobDetailData.segmentation = segmentation_overview(...)) :
// items → pages, sections hors item, pages blanches, avertissements. Même contenu
// que l'ancienne console (renderSegmentation), replié dans un <details>.
function segmentation(d) {
  const seg = d.segmentation;
  if (!seg) return null;
  const items = seg.items || [];
  const sections = seg.sections || [];
  const warnings = seg.warnings || [];
  const cell = (v) => h('td', {}, v === null || v === undefined ? '—' : String(v));
  const rows = [
    ...items.map((it) => h('tr', {}, cell(`Item ${it.item_number}`), cell(it.pages), cell(it.rang || '—'), cell(`${it.objectives_a ?? '—'} / ${it.objectives_b ?? '—'}`))),
    ...sections.map((sct) => h('tr', {}, h('td', { class: 'muted' }, String(sct.label)), cell(sct.pages), cell('—'), cell('—'))),
    seg.blank_pages ? h('tr', {}, h('td', { class: 'muted' }, 'pages blanches'), cell(seg.blank_pages), cell('—'), cell('—')) : null,
  ];
  return h('details', { class: 'block' },
    h('summary', {}, h('b', {}, `Découpage : ${items.length} items, ${sections.length} sections, ${warnings.length} avertissements`)),
    h('table', { class: 'table' }, h('thead', {}, h('tr', {}, ...['Item / section', 'Pages', 'Rang', 'Objectifs A / B'].map((c) => h('th', {}, c)))), h('tbody', {}, ...rows)),
    warnings.length ? h('ul', { class: 'muted' }, ...warnings.map((w) => h('li', {}, String(w)))) : null);
}
