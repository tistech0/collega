# Chantier 2 — Sécurité : spécification

Date : 2026-09-24 · Statut : validée avec l'utilisateur · Branche à créer : `feat/chantier-2-securite`
Contexte : `audit-back-infra-2026-09-23.md` (constat 5 et « Sécurité (hors tableau) ») ; absorbe la story 7.10 (`_bmad-output/implementation-artifacts/7-10-hardening-securite-pre-prod.md`) ; la story 7.9 (session admin par cookie) est **abandonnée** au profit de Cloudflare Access.

## 1. Décisions (validées)

| # | Décision |
|---|---|
| S1 | Console admin : **Cloudflare Access (code par e-mail)** sur `/admin` et `/v1/admin` depuis l'extérieur ; sur le LAN, Basic Auth conservé **avec limite d'essais**. Pas de session par cookie (7.9 abandonnée). |
| S2 | Récupération de compte : **côté admin seulement** — « Réinitialiser le mot de passe » génère un mot de passe provisoire affiché une fois et déconnecte tous les appareils. Pas d'écran « changer mon mot de passe » ni de mot de passe oublié par e-mail. |
| S3 | **Sessions glissantes avec rotation** du refresh token ; réutilisation d'un refresh révoqué = vol présumé → toutes les sessions du compte coupées. App et backend déployés ensemble. |

## 2. Jetons

- **PyJWT** remplace `python-jose` (`pyproject.toml`, `app/core/security.py`). HS256 inchangé. `security.JWTError` reste exporté (= `jwt.PyJWTError`) pour les appelants (`deps.py`, `auth.py`).
- Tous les jetons portent `jti` (uuid4 hex) et `tv` (= `users.token_version` au moment de l'émission). Durées inchangées : access 30 min, refresh 30 jours.
- `users.token_version` INT NOT NULL DEFAULT 0 (migration 019). Tout jeton dont `tv` < version courante (ou sans `tv`, émis avant ce chantier) est refusé **sauf** période de transition : un jeton sans `tv` est accepté tant que `version == 0` (les sessions existantes ne sautent pas au déploiement).
- **Rotation** (`POST /v1/auth/refresh`) :
  1. décoder le refresh (type `refresh`, signature, `exp`) ; vérifier `tv` ;
  2. si son `jti` est **révoqué** : si révoqué depuis ≤ 60 s (clé `refresh:grace:{jti}` présente) → accepter (requêtes parallèles) ; sinon **réutilisation** → `users.token_version += 1`, 401 `TOKEN_REUSED` ;
  3. sinon : révoquer le `jti` (`SET revoked:jti:{jti} 1 EX <reste de vie>` + `SET refresh:grace:{jti} 1 EX 60`), émettre **un nouvel access + un nouveau refresh**.
  - Réponse : même forme `TokenResponse` (le `refresh_token` est désormais nouveau).
- **`POST /v1/auth/logout`** (authentifié par l'access token ; corps `{"refresh_token": "..."}` optionnel) : révoque le refresh fourni (s'il appartient à l'utilisatrice), met `users.apns_token = NULL`, 204. Idempotent.
- **Redis indisponible** pendant une vérification de révocation : on **laisse passer** et on journalise un warning (décision PL 2026-06-19). Pendant une révocation (logout/rotation) : on journalise, la réponse n'échoue pas.
- `get_current_user` : refuse 401 `TOKEN_REVOKED` si `tv` < `user.token_version` (lecture du user déjà faite).

## 3. Comptes

- `POST /v1/admin/users/{id}/reset-password` (admin) : génère un mot de passe provisoire (16 caractères, `secrets.token_urlsafe`), le hache, `token_version += 1`, renvoie `{"data": {"temporary_password": "..."}}` **une seule fois** (jamais journalisé). Console admin : bouton sur la fiche utilisatrice, affichage dans une boîte à copier.
- Login : temps de réponse identique si l'e-mail est inconnu (vérification bcrypt contre un hash factice précalculé).

## 4. Adresse client et limites

- `get_client_ip(request)` :
  - si l'en-tête `CF-Connecting-IP` est présent **et** que la requête vient d'un proxy de confiance (`request.client.host` dans `settings.trusted_proxy_ips`, défaut : réseau Docker de NPM `172.16.0.0/12`) → cette IP ;
  - sinon, si la requête vient d'un proxy de confiance et porte `X-Forwarded-For` → le **dernier** élément (ajouté par NPM) ;
  - sinon `request.client.host`.
  - Plus jamais le 1er élément de `X-Forwarded-For` (falsifiable).
- Nouvelles limites (slowapi) : auth admin (dépendance `get_admin_user`) 10/min par IP ; `/v1/auth/refresh` 30/min par IP ; `/v1/drill/evaluate-semantic` 30/min **par utilisatrice** ; régénération de fiche 10/h **par utilisatrice** (au lieu de par IP) ; login 5/min inchangé.
- `max_length=2000` sur `user_answer` (évaluation sémantique) et `user_note` (régénération).
- Limiteur : `swallow_errors=True` (Redis coupé → la requête passe) + warning journalisé.

## 5. Webhook RevenueCat

- Vérification du Bearer secret **avant** la validation du corps (la route lit le corps brut après l'auth ; plus de 422 non authentifiée).
- `users.subscription_event_at` TIMESTAMPTZ NULL (migration 019) : un événement dont `event_timestamp_ms` est antérieur à la valeur stockée est ignoré (`{"status": "stale"}`) ; sinon appliqué et la valeur mise à jour. Événement sans horodatage : appliqué (compatibilité).

## 6. Configuration et journaux

- `ENVIRONMENT` obligatoire : valeur absente ou hors {`development`, `production`, `test`} → démarrage refusé (sauf `test` défini par la suite de tests).
- Plus de terme de recherche dans les logs (`search.py`) ; plus d'`upload_id` dans les logs d'upload (hash tronqué à 8 caractères à la place).

## 7. Cloudflare (actions utilisateur guidées)

- Nouvelle application Access `collega-admin` : destinations `collegatest.matthislesur.com/admin` et `/v1/admin`, policy **Allow** — *Emails* : `contact@matthislesur.com`, méthode One-time PIN. L'application existante `collegatest` (service token de l'app) reste inchangée ; l'app mobile n'appelle jamais `/v1/admin`.
- Vérification : depuis l'extérieur (curl `--resolve` sur l'IP Cloudflare), `/admin` → 302 vers la page de connexion Access ; `/v1/colleges` avec le service token → inchangé.

## 8. App

- `api_client.dart` : `_tryRefresh` enregistre aussi le nouveau `refresh_token` renvoyé.
- `auth_repository.logout()` : appelle `POST /v1/auth/logout` (best-effort, n'empêche jamais la déconnexion locale) avant d'effacer le stockage.
- Déploiement conjoint : une app non mise à jour sera déconnectée une fois (réutilisation détectée) — accepté ; nouvelle build iPhone prévue avant le 28/09.

## 9. Documents

- `privacy.md` : jeton APNs supprimé à la déconnexion (désormais vrai), limites de débit sur connexion et renouvellement, durée de conservation des logs alignée sur la réalité (rotation Docker : 3 × 50 Mo, soit quelques jours à semaines) ; version mise à jour.
- `sprint-status.yaml` : 7.10 → done (absorbée par le chantier 2), 7.9 → abandonnée (remplacée par Cloudflare Access).

## 10. Tests

- Unitaires : `get_client_ip` (tous les cas d'en-têtes et de proxies), création/décodage PyJWT (`jti`, `tv`, expiré → `JWTError`), messages.
- Postgres + **Redis réel** (service `redis-test` ajouté à `docker-compose.test.yml`, `127.0.0.1:56379`) :
  - rotation : nouveau couple, ancien refresh accepté dans les 60 s, refusé ensuite avec incrément de `token_version` ;
  - `tv` périmé → 401 sur une route protégée et au refresh ; jeton sans `tv` accepté tant que version 0 ;
  - logout : refresh révoqué, `apns_token` effacé, idempotent ;
  - Redis coupé (URL invalide) : refresh et login passent, warning journalisé ;
  - reset-password admin : mot de passe provisoire fonctionnel, anciennes sessions refusées ;
  - webhook : 401 sans secret même avec un corps invalide ; événement ancien ignoré ; événement récent appliqué.
- App : `_tryRefresh` stocke le nouveau refresh ; `logout` appelle l'API et efface le stockage même si l'appel échoue.

## 11. Déploiement

Dump avant ; `compose pull/up` (migration 019) ; nouvelle build de l'app sur l'iPhone ; configuration Cloudflare Access admin par l'utilisateur (guidée) ; vérifications : login, refresh (rotation visible dans les logs), logout, `/admin` depuis l'extérieur → page Access, webhook RevenueCat de test (secret réel depuis le NAS) → 200.
