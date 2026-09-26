// Routes en hash : #/pilotage, #/testeuses/<id>… (Retour du navigateur, favoris).
const routes = [];

export function route(pattern, loader) {
  const re = new RegExp(`^${pattern.replace(/:(\w+)/g, '(?<$1>[^/]+)')}$`);
  routes.push({ re, loader });
}

export function currentPath() {
  return location.hash.replace(/^#/, '') || '/pilotage';
}

export function resolve(path) {
  for (const r of routes) {
    const m = path.match(r.re);
    if (m) return { loader: r.loader, params: m.groups ?? {} };
  }
  return null;
}

export function go(path) {
  location.hash = path;
}
