// Fabriques DOM partagées. Tout texte passe par textContent, jamais par une
// insertion HTML brute ; seuls les SVG de icons.js, générés depuis le dépôt,
// sont injectés via ICONS[nom] ci-dessous.
import { ICONS } from './icons.js';

export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs ?? {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export function icon(name, size = 16, cls = '') {
  const span = h('span', { class: `icon ${cls}`, 'aria-hidden': 'true', style: `display:inline-flex;width:${size}px;height:${size}px` });
  span.innerHTML = ICONS[name] ?? ICONS.more;
  const svg = span.firstElementChild;
  if (svg) { svg.setAttribute('width', size); svg.setAttribute('height', size); }
  return span;
}

const nf = new Intl.NumberFormat('fr-FR');
const euro = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 });
export const fmtInt = (n) => nf.format(Math.round(n ?? 0));
export const fmtEuro = (n) => euro.format(n ?? 0);
export const fmtDate = (iso) => (iso ? new Date(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' }) : '—');
export const fmtDateTime = (iso) => (iso ? new Date(iso).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—');

export function fmtAgo(iso) {
  if (!iso) return 'jamais';
  const d = new Date(iso);
  const days = Math.floor((startOfDay(new Date()) - startOfDay(d)) / 86400000);
  if (days <= 0) return `aujourd'hui, ${d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`;
  if (days === 1) return 'hier';
  return `il y a ${days} j`;
}
const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

export const STATUS_LABEL = { active: ['active', 'ok'], inactive: ['inactive', 'warn'], never_seen: ['jamais connectée', 'warn'] };
export const JOB_STATUS_LABEL = {
  pending: ['en attente', ''], processing: ['en cours', 'ok'], ocr_complete: ['génération', 'ok'],
  generation_complete: ['terminé', 'ok'], failed: ['échec', 'err'], stalled: ['bloqué', 'warn'],
};

export function tag(text, tone = '') {
  return h('span', { class: `tag ${tone}` }, text);
}

export function kpi({ label, value, previous, format = fmtInt, invert = false }) {
  const node = h('div', { class: 'kpi' }, h('div', { class: 'value' }, format(value)), h('div', { class: 'label' }, label));
  if (previous !== undefined && previous !== null) {
    const diff = value - previous;
    const better = invert ? diff < 0 : diff > 0;
    const text = diff === 0 ? 'stable vs période précédente' : `${diff > 0 ? '+' : '−'}${format(Math.abs(diff))} vs période précédente`;
    node.append(h('div', { class: `delta ${diff === 0 ? '' : better ? 'up' : 'down'}` }, text));
  }
  return node;
}

export function block(title, aside, ...children) {
  return h('section', { class: 'block' }, h('div', { class: 'block-head' }, h('h2', {}, title), aside ? h('span', { class: 'aside' }, aside) : null), ...children);
}

export function row(left, right, onClick) {
  return h('div', { class: `row${onClick ? ' link' : ''}`, onclick: onClick }, h('div', { class: 'left' }, left), right);
}

// Sur mobile, les lignes de tableau s'empilent : chaque cellule reprend l'intitulé
// de sa colonne (data-label, affiché en CSS), sauf la première qui sert de titre.
export function labelCells(table) {
  const heads = [...table.querySelectorAll('thead th')].map((th) => th.textContent);
  for (const tr of table.querySelectorAll('tbody tr')) {
    [...tr.children].forEach((td, i) => { if (i > 0 && heads[i]) td.dataset.label = heads[i]; });
  }
  return table;
}

export function empty(text) {
  return h('div', { class: 'empty' }, text);
}

export function banner(error, onRetry) {
  return h('div', { class: 'banner', role: 'alert' }, icon('warning', 18), h('span', {}, error?.message ?? String(error)),
    onRetry ? h('button', { class: 'btn', onclick: onRetry }, icon('refresh', 16), 'Réessayer') : null);
}

export function toast(text) {
  const node = h('div', { class: 'toast', role: 'status' }, text);
  document.body.append(node);
  setTimeout(() => node.remove(), 2600);
}

// Copie presse-papiers avec retour utilisateur dans les deux cas : `navigator.clipboard`
// peut rejeter (contexte non sûr, permission refusée…) ; jamais de rejet non géré ni de
// silence sur un mot de passe provisoire affiché une seule fois.
export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast('Message copié');
  } catch {
    toast('Copie impossible : sélectionne le message et copie-le à la main.');
  }
}

export function panel(title, content) {
  const scrim = h('div', { class: 'scrim' });
  const node = h('aside', { class: 'panel', role: 'dialog', 'aria-label': title });
  const close = () => { scrim.remove(); node.remove(); document.removeEventListener('keydown', onKey); };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  scrim.addEventListener('click', close);
  document.addEventListener('keydown', onKey);
  node.append(h('div', { class: 'panel-head' }, h('h2', {}, title), h('button', { class: 'icon-btn', 'aria-label': 'Fermer', onclick: close }, icon('close', 20))), content);
  document.body.append(scrim, node);
  return { close, node };
}

// Barres en SVG : une valeur par jour, jours à 0 en trait gris.
// Survol : colonne entière sensible, infobulle immédiate avec la valeur exacte.
export function bars(values, { labels = [], format = fmtInt } = {}) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  const w = 600, hgt = 120, gap = 3, n = Math.max(values.length, 1);
  const bw = (w - gap * (n - 1)) / n;
  const max = Math.max(1, ...values);
  const tip = h('div', { class: 'chart-tip', hidden: true });
  svg.setAttribute('viewBox', `0 0 ${w} ${hgt}`);
  svg.setAttribute('preserveAspectRatio', 'none');
  values.forEach((v, i) => {
    const x = i * (bw + gap);
    const rect = document.createElementNS(ns, 'rect');
    const bh = v > 0 ? Math.max(3, (v / max) * (hgt - 4)) : 3;
    rect.setAttribute('x', x);
    rect.setAttribute('y', hgt - bh);
    rect.setAttribute('width', bw);
    rect.setAttribute('height', bh);
    rect.setAttribute('rx', 2);
    rect.setAttribute('fill', v > 0 ? 'var(--accent)' : 'var(--soft)');
    const hit = document.createElementNS(ns, 'rect');
    hit.setAttribute('x', x - gap / 2);
    hit.setAttribute('y', 0);
    hit.setAttribute('width', bw + gap);
    hit.setAttribute('height', hgt);
    hit.setAttribute('fill', 'transparent');
    hit.addEventListener('mouseenter', () => {
      const pct = ((x + bw / 2) / w) * 100;
      tip.replaceChildren(h('b', {}, format(v)), labels[i] ? h('span', {}, labels[i]) : null);
      tip.style.left = `${pct}%`;
      tip.style.transform = `translate(${pct < 12 ? '-10%' : pct > 88 ? '-90%' : '-50%'}, -100%)`;
      tip.hidden = false;
      rect.classList.add('on');
    });
    hit.addEventListener('mouseleave', () => { tip.hidden = true; rect.classList.remove('on'); });
    svg.append(rect, hit);
  });
  const axis = labels.length ? h('div', { class: 'axis' }, h('span', {}, labels[0]), h('span', {}, labels[Math.floor(labels.length / 2)]), h('span', {}, labels[labels.length - 1])) : null;
  return h('div', { class: 'chart' }, tip, svg, axis);
}

export function initials(nameOrEmail) {
  const base = (nameOrEmail || '?').split('@')[0];
  const parts = base.split(/[\s._-]+/).filter(Boolean);
  return ((parts[0]?.[0] ?? '?') + (parts[1]?.[0] ?? '')).toUpperCase();
}

export function displayName(t) {
  return t.first_name || t.email;
}
