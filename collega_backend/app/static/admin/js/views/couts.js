import { api } from '../api.js';
import { banner, bars, block, empty, fmtEuro, fmtInt, h, kpi, row } from '../ui.js';

const KIND = { generation: 'Génération des fiches', regeneration: 'Régénérations', evaluation: 'Évaluations pendant le drill' };

export async function render(root) {
  let u;
  try {
    ({ data: u } = await api('/usage'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  const labels = u.daily.map((d) => new Date(`${d.day}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }));
  const money = (value) => h('b', {}, fmtEuro(value));
  root.append(
    h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Coûts'), h('div', { class: 'sub' }, 'Consommation Claude, au tarif de chaque modèle.'))),
    h('div', { class: 'grid kpis' },
      kpi({ label: 'coût sur 30 jours', value: u.last_30_days.cost_eur, format: fmtEuro }),
      kpi({ label: 'coût total', value: u.cost_eur, format: fmtEuro }),
      kpi({ label: 'coût moyen d\'un import', value: u.avg_import_cost_eur, format: fmtEuro }),
      kpi({ label: 'tokens sur 30 jours', value: u.last_30_days.input_tokens + u.last_30_days.output_tokens })),
    block('Coût par jour', '30 derniers jours', bars(u.daily.map((d) => d.cost_eur), { labels, format: fmtEuro })),
    h('div', { class: 'grid cols-even' },
      block('Par testeuse', '30 jours', u.by_user.length ? u.by_user.map((x) => row(h('span', { class: 't' }, x.email ?? 'compte supprimé'), money(x.last_30_days.cost_eur))) : empty('Aucune consommation.')),
      block('Par collège', '30 jours', u.by_college.length ? u.by_college.map((c) => row(h('span', { class: 't' }, c.college_name), money(c.cost_eur))) : empty('Aucune consommation.'))),
    block('Par usage', 'depuis le début', Object.entries(u.by_kind).map(([k, t]) => row(h('span', {}, KIND[k] ?? k),
      h('span', {}, money(t.cost_eur), h('span', { class: 'muted' }, ` · ${fmtInt(t.input_tokens + t.output_tokens)} tokens`))))),
  );
}
