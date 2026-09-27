import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, STATUS_LABEL, banner, bars, block, copyText, displayName, empty, fmtAgo, fmtDate, fmtInt, h, icon, initials, kpi, panel, row, tag, toast } from '../ui.js';
import { invitation } from './testeuses.js';

export async function render(root, { id }) {
  let d;
  let config;
  try {
    [{ data: d }, { data: config }] = await Promise.all([api(`/users/${id}`), api('/config')]);
  } catch (err) {
    root.append(h('a', { class: 'crumb', href: '#/testeuses' }, icon('chevronLeft', 14), 'Testeuses'), banner(err, () => { root.replaceChildren(); render(root, { id }); }));
    return;
  }
  const [statusLabel, statusTone] = STATUS_LABEL[d.status];
  const reload = () => { root.replaceChildren(); render(root, { id }); };

  const actions = h('div', { class: 'actions' },
    h('button', { class: 'btn', onclick: () => resetPassword(d, config.testflight_url) }, 'Réinitialiser le mot de passe'),
    h('button', { class: 'btn', onclick: async () => {
      if (!confirm('Remettre à zéro le quota de réimports du mois ?')) return;
      await run(() => api(`/users/${id}/reset-quota`, { method: 'POST' }), 'Quota réinitialisé', reload);
    } }, 'Réinitialiser le quota'),
    h('button', { class: `btn ${d.is_beta ? 'danger' : ''}`, onclick: async () => {
      if (d.is_beta && !confirm('Retirer l\'accès beta à ce compte ?')) return;
      await run(() => api(`/users/${id}/beta`, { method: 'PATCH', body: { is_beta: !d.is_beta } }), d.is_beta ? 'Accès beta retiré' : 'Accès beta donné', reload);
    } }, d.is_beta ? 'Retirer la beta' : 'Donner la beta'),
    h('button', { class: 'btn danger', onclick: () => deleteAccount(d) }, icon('trash', 16), 'Supprimer le compte'));

  const labels = d.daily.map((x) => new Date(`${x.day}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }));
  root.append(
    h('a', { class: 'crumb', href: '#/testeuses' }, icon('chevronLeft', 14), 'Testeuses'),
    h('div', { class: 'page-head' },
      h('div', { class: 'avatar' }, initials(displayName(d))),
      h('div', {}, h('h1', {}, displayName(d)),
        h('div', { class: 'sub' }, `${d.email} · compte créé le ${fmtDate(d.created_at)} `, d.is_beta ? tag('beta', 'ok') : tag('hors beta'))),
      actions),
    h('div', { class: 'grid kpis' },
      h('div', { class: 'kpi' }, h('div', { class: 'value' }, d.status === 'never_seen' ? '—' : fmtAgo(d.last_seen_at)), h('div', { class: 'label' }, 'dernière activité'), h('div', { class: 'delta' }, tag(statusLabel, statusTone))),
      kpi({ label: 'jours de série', value: d.streak }),
      kpi({ label: 'fiches révisées sur 30 jours', value: d.cards_30d }),
      kpi({ label: 'séances terminées sur 30 jours', value: d.sessions_30d })),
    block('Fiches révisées par jour', '30 derniers jours', bars(d.daily.map((x) => x.cards_reviewed), { labels })),
    h('div', { class: 'grid cols-even' },
      block('Collèges', String(d.colleges.length), d.colleges.length ? d.colleges.map(collegeRow) : empty('Aucun collège importé.')),
      block('Ses avis', feedbackAside(d.feedback), d.feedback.length ? d.feedback.map(feedbackRow) : empty('Aucun avis pour l\'instant.'))),
    block('Imports', String(d.jobs.length), d.jobs.length ? d.jobs.map((j) => row(
      [h('span', { class: 't' }, fmtDate(j.created_at)), h('span', { class: 'muted' }, `· ${fmtInt(j.card_count)} fiches`)],
      tag(...(JOB_STATUS_LABEL[j.status] ?? [j.status, ''])), () => go(`/imports/${j.job_id}`))) : empty('Aucun import.')),
  );
}

function collegeRow(c) {
  const done = c.status === 'generation_complete';
  const right = done ? tag(`${fmtInt(c.card_count)} fiches`, 'ok')
    : c.status === 'failed' ? tag('échec', 'err')
    : h('span', { class: 'left' }, h('span', { class: 'progress' }, h('i', { style: `width:${Math.round(c.progress * 100)}%` })), h('span', { class: 'muted' }, `${Math.round(c.progress * 100)} %`));
  return row(h('span', { class: 't' }, c.college_name), right, () => go(`/qualite/${c.college_id}`));
}

function feedbackAside(list) {
  const pos = list.filter((f) => f.feedback === 'positive').length;
  return [icon('thumbUp', 14), ` ${pos}   `, icon('thumbDown', 14), ` ${list.length - pos}`];
}

function feedbackRow(f) {
  const positive = f.feedback === 'positive';
  return row([icon(positive ? 'thumbUp' : 'thumbDown', 16, positive ? 'fb-pos' : 'fb-neg'), h('span', { class: 't' }, `${f.college_name} · item ${f.item_number ?? '?'} · ${f.recto}`)],
    h('span', { class: 'muted' }, fmtAgo(f.at)));
}

async function run(action, message, after) {
  try {
    await action();
    toast(message);
    window.dispatchEvent(new Event('admin:badges'));
    after();
  } catch (err) {
    toast(err.message);
  }
}

// Suppression définitive : l'e-mail doit être retapé pour éviter une erreur de fiche.
async function deleteAccount(d) {
  const typed = prompt(`Supprimer définitivement ce compte, ses collèges, ses fiches et son activité ?\n\nPour confirmer, tape l'e-mail du compte : ${d.email}`);
  if (typed === null) return;
  if (typed.trim().toLowerCase() !== d.email.toLowerCase()) {
    toast('E-mail différent : compte non supprimé.');
    return;
  }
  try {
    await api(`/users/${d.user_id}`, { method: 'DELETE' });
    toast('Compte supprimé');
    window.dispatchEvent(new Event('admin:badges'));
    go('/testeuses');
  } catch (err) {
    toast(err.message);
  }
}

async function resetPassword(d, testflightUrl) {
  if (!confirm('Générer un nouveau mot de passe ? Tous ses appareils seront déconnectés.')) return;
  try {
    const { data } = await api(`/users/${d.user_id}/reset-password`, { method: 'POST' });
    const text = invitation({ firstName: d.first_name, email: d.email, password: data.temporary_password, testflightUrl });
    panel('Nouveau mot de passe', h('div', {},
      h('p', {}, 'Affiché une seule fois. Copie le message et envoie-le.'),
      h('pre', { class: 'invite' }, text),
      h('button', { class: 'btn primary', onclick: () => copyText(text) }, 'Copier le message')));
  } catch (err) {
    toast(err.message);
  }
}
