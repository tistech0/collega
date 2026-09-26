// Client de l'API admin : Basic Auth, format d'erreur {"detail": {"code", "message"}}.
const KEY = 'collega-admin-auth';
let memory = null;

const MESSAGES = {
  NETWORK: 'Serveur injoignable.',
  RATE_LIMITED: 'Trop de tentatives, réessaie dans une minute.',
  USER_NOT_FOUND: 'Compte introuvable.',
  EMAIL_ALREADY_EXISTS: 'Un compte existe déjà avec cet e-mail.',
  COLLEGE_NOT_FOUND: 'Collège introuvable.',
  JOB_NOT_FOUND: 'Import introuvable.',
  VALIDATION_ERROR: 'Valeur refusée par le serveur.',
};

export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function token() {
  if (memory) return memory;
  try { return sessionStorage.getItem(KEY); } catch { return null; }
}

export function setCredentials(user, pass) {
  memory = btoa(unescape(encodeURIComponent(`${user}:${pass}`)));
  try { sessionStorage.setItem(KEY, memory); } catch { /* navigation privée : reste en mémoire */ }
}

export function hasCredentials() { return Boolean(token()); }

export function clearCredentials() {
  memory = null;
  try { sessionStorage.removeItem(KEY); } catch { /* rien à effacer */ }
}

export async function api(path, { method = 'GET', body, silent401 = false } = {}) {
  const headers = { Authorization: `Basic ${token()}` };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  let res;
  try {
    res = await fetch(`/v1/admin${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  } catch {
    throw new ApiError(0, 'NETWORK', MESSAGES.NETWORK);
  }
  if (res.status === 204) return null;
  const json = await res.json().catch(() => null);
  if (res.ok) return json;
  const detail = json && typeof json.detail === 'object' && json.detail ? json.detail : null;
  const code = detail?.code ?? `HTTP_${res.status}`;
  if (res.status === 401 && !silent401) {
    clearCredentials();
    window.dispatchEvent(new Event('admin:logout'));
  }
  throw new ApiError(res.status, code, MESSAGES[code] ?? detail?.message ?? `Erreur ${res.status}.`);
}

// Écran de connexion : un 401 y est une réponse attendue, pas une déconnexion.
export async function checkCredentials() {
  await api('/badges', { silent401: true });
}
