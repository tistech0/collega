import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, STATUS_LABEL, banner, block, displayName, empty, fmtAgo, fmtEuro, h, icon, kpi, row, tag } from '../ui.js';

export async function render(root) {
  let data;
  try {
    ({ data } = await api('/pilot'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  const today = new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  root.append(
    h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Pilotage de la beta'),
      h('div', { class: 'sub' }, `${today} · ${data.testers_total} testeuse${data.testers_total > 1 ? 's' : ''}`))),
    h('div', { class: 'grid kpis' },
      kpi({ label: 'ont révisé sur 7 jours', value: data.active_7d.value, previous: data.active_7d.previous }),
      kpi({ label: 'fiches révisées sur 7 jours', value: data.cards_7d.value, previous: data.cards_7d.previous }),
      kpi({ label: 'imports en échec sur 7 jours', value: data.failed_imports_7d.value, previous: data.failed_imports_7d.previous, invert: true }),
      kpi({ label: 'coût Claude sur 30 jours', value: data.cost_30d_eur.value, previous: data.cost_30d_eur.previous, format: fmtEuro, invert: true })),
    h('div', { class: 'grid cols' }, testersBlock(data.testers), watchBlock(data)),
  );
}

function testersBlock(testers) {
  const order = { never_seen: 0, inactive: 1, active: 2 };
  const sorted = [...testers].sort((a, b) => order[a.status] - order[b.status] || (b.last_seen_at ?? '').localeCompare(a.last_seen_at ?? ''));
  const rows = sorted.map((t) => {
    const [label, tone] = STATUS_LABEL[t.status];
    const right = t.status === 'active' ? tag(fmtAgo(t.last_seen_at), 'ok') : tag(label, tone);
    const left = [h('span', { class: 't' }, displayName(t)), t.streak >= 2 ? h('span', { class: 'muted' }, `· série ${t.streak} j`) : null];
    return row(left, right, () => go(`/testeuses/${t.user_id}`));
  });
  return block('Testeuses', h('a', { href: '#/testeuses', class: 'muted' }, 'Tout voir'), rows.length ? rows : empty('Aucune testeuse pour l\'instant.'));
}

function truncate(text, max = 80) {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function watchBlock(data) {
  const rows = [
    ...data.watch_jobs.map((j) => row(
      [icon('warning', 16, j.kind === 'failed' ? 'fb-neg' : ''),
        h('div', {},
          h('div', {}, h('span', { class: 't' }, `Import ${j.college_name}`), h('span', { class: 'muted' }, j.user_email ? ` · ${j.user_email}` : '')),
          j.message ? h('div', { class: 'muted' }, truncate(j.message)) : null)],
      tag(j.kind === 'failed' ? 'échec' : 'bloqué', j.kind === 'failed' ? 'err' : 'warn'),
      () => go(`/imports/${j.job_id}`))),
    ...data.watch_feedback.map((f) => row(
      [icon('thumbDown', 16, 'fb-neg'), h('span', { class: 't' }, f.college_name)],
      tag(`${f.negative_count} avis négatif${f.negative_count > 1 ? 's' : ''}`, 'warn'),
      () => go(`/qualite/${f.college_id}`))),
    ...data.running_jobs.map((j) => row(
      [icon('upload', 16), h('span', { class: 't' }, `Import ${j.college_name}`)],
      tag(`${JOB_STATUS_LABEL[j.status]?.[0] ?? j.status} ${Math.round(j.progress * 100)} %`, 'ok'),
      () => go(`/imports/${j.job_id}`))),
  ];
  return block('À surveiller', null, rows.length ? rows : empty('Rien à signaler.'));
}
