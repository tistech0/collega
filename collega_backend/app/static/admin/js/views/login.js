import { ApiError, checkCredentials, clearCredentials, setCredentials } from '../api.js';
import { banner, h } from '../ui.js';

export function render(root, onSuccess) {
  const user = h('input', { class: 'input', id: 'u', autocomplete: 'username', required: true });
  const pass = h('input', { class: 'input', id: 'p', type: 'password', autocomplete: 'current-password', required: true });
  const error = h('div');
  const submit = h('button', { class: 'btn primary', type: 'submit' }, 'Se connecter');
  const form = h('form', { class: 'login-card', onsubmit: async (e) => {
    e.preventDefault();
    submit.disabled = true;
    error.replaceChildren();
    setCredentials(user.value.trim(), pass.value);
    try {
      await checkCredentials();
      onSuccess();
    } catch (err) {
      clearCredentials();
      const e2 = err instanceof ApiError && err.status === 401 ? new Error('Identifiant ou mot de passe incorrect.') : err;
      error.replaceChildren(banner(e2));
      submit.disabled = false;
    }
  } },
    h('img', { src: '/admin/logo.svg', alt: '' }),
    h('h1', {}, 'Collega admin'),
    h('div', { class: 'sub' }, 'Pilotage de la beta'),
    error,
    h('div', { class: 'field' }, h('label', { for: 'u' }, 'Identifiant'), user),
    h('div', { class: 'field' }, h('label', { for: 'p' }, 'Mot de passe'), pass),
    submit);
  root.append(h('div', { class: 'login' }, form));
  user.focus();
}
