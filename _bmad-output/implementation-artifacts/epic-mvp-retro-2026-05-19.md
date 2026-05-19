# Rétrospective MVP — AppMédecine (Epics 1→6)

**Date :** 2026-05-19
**Animateur :** Amelia (Senior Software Engineer)
**Participant principal :** Lesurmatthis (Project Lead)
**Périmètre :** Rétrospective globale du MVP — Phase 0 (validation pipeline) + Phase 1 (Flutter iOS/iPadOS)
**Type :** Première rétrospective du projet (toutes les `epic-X-retrospective` étaient `optional`)

---

## 1. Photo objective du MVP

| Dimension | Valeur |
|---|---|
| Epics complétés | 6 / 6 |
| Stories complétées | 25 / 25 (100%) |
| Couverture exigences | FR1→FR50 (50/50) + 18 UX-DR + 12 NFR |
| Durée calendaire | 2026-04-27 → 2026-05-18 (~3 semaines) |
| Migrations Alembic | ~8 (chaînées sans data loss) |
| Migrations Drift | v1→v5 (sans crash signalé) |
| Items de dette différés | ~80 (tous documentés dans `deferred-work.md`) |
| Backend prod | Déjà déployé et fonctionnel sur NAS homelab |
| Test iOS device réel | ❌ Simulateur seulement |
| IAP RevenueCat sandbox | ❌ Non testé en sandbox |

---

## 2. Les 5 patterns cross-epic

### Pattern #1 — Architecture découplée qui a tenu ✅ GROS WIN

Les "hooks d'extensibilité" posés en Epic 1 ont permis d'enchaîner 5 epics sans refonte :

- `SimilarityChecker` ABC (E1) → réutilisé tel quel en E3 (hash-sharing)
- `NotificationService` abstraite (E1) → migration FCM Phase 2 préparée
- `DrillSessionParams` *nullable* `itemId` + `fromSearch: bool` (E4 → E5) → recherche → drill sans toucher au router
- Spaced repetition 100% client-side Drift (E4) → backend ignore complètement la stratégie d'espacement = scalabilité gratuite
- Wrapper `{ "data": ... } / { "error": ... }` jamais oublié sur 30+ routes API
- StaticFiles montés en dernier FastAPI (E1) → coexistence API + admin/tester web sans conflit

**Validation user :** « Tout colle à mon vécu. »

### Pattern #2 — Async correctness : la faille transverse ⚠️ THÈME ROUGE — PRIORITÉ #1 BETA

Le même type de bug est apparu dans **chaque** epic :

| Epic | Incident |
|---|---|
| E1 | Race condition OCR : 2 `POST /process` créent 2 jobs `processing` (pas de `UNIQUE(college_id, status='processing')`) |
| E2 | Intercepteur Dio JWT → boucle infinie de refresh |
| E3 | Compteurs `reload_count` non-atomiques (read-then-write) |
| E3 | SSE token JWT figé à la connexion (3h max) |
| E4 | `reviewCount` non-atomique (D7) — fixé en patch sans vraie transaction Drift |
| E5 | Rate limiting `slowapi` keyed sur IP (NAT partagé → 429 collectif) |
| E6 | `DELETE /account` sans rate limit — ajouté en review post-livraison |
| E6 | DELETE cascade multi-tiers (backend + tokens + Drift + RC) non-atomique |

**Diagnostic :** Aucun de ces bugs n'a été déclenché en prod car mono-utilisateur Phase 0. Beta = 5 abonnées concurrentes = risque réel.

**Priorité user explicite :** « C'est ce qu'il faut traiter avant la beta. »

### Pattern #3 — Le coût qualité est dans la review, pas dans le design ⚠️ MIXTE

Métriques code-review brutes :
- Story 1.2 : 16 patches (8 HIGH)
- Story 1.3 : 10 patches
- Stories 3.x : 10–15 findings/story (≈30% vrais bugs, 50% intentionnels, 20% over-engineering)
- Story 6.1 : bug critique `state ??=` empêchant la propagation des prefs

**Diagnostic :** Optimisation pour vélocité MVP, qualité validée en review. Choix valide pour solo dev — **mais la review n'est pas optionnelle**. Couper la review = shipper les bugs (notamment atomicité DB et contraintes manquantes invisibles en runtime mono-user).

### Pattern #4 — Riverpod state management : pièges récurrents ⚠️ À FORMER

Trois antipatterns cristallisés :

1. **`unawaited()` fire-and-forget partout** — DrillRepository, HomeNotifier, planning sync. 20+ instances. Cache les erreurs (log seul).
2. **State mutation vs initialization confusion** — bug `state ??=` en 6.1, `applyDefault` qui ne propage jamais.
3. **`homeProvider` stale au retour `/drill`** (D15 Epic 4) — fixé empiriquement avec `.watch(planningProvider)`, mais signal d'invalidation fragile.

**Diagnostic :** Patterns idiomatiques (`StreamProvider.family` 4.5 ✅) ET improvisés (`unawaited` partout) coexistent. Riverpod appris en production.

### Pattern #5 — Gotchas SDK tiers récurrentes ⚠️ DOCUMENTABLE

| SDK | Gotcha | Coût |
|---|---|---|
| `shadcn_ui 0.19.x` | `ShadSkeleton` absent → fallback `ShadProgress` indéterminé | E2, E3 |
| Dio intercepteur | Refresh appelle refresh = boucle infinie → solution `_refreshDio` séparé | E2 |
| `flutter_apns_only 1.6.0` | Signature `ApnsRemoteMessage` ≠ doc | E3 |
| RevenueCat webhook | Async timing, pas de réponse synchrone du paywall → polling `/auth/me` 5×2s | E2 |

**Diagnostic :** ~1-2h chacune. Wiki interne éviterait de re-payer. Low cost, real ROI.

---

## 3. Gaps de readiness critiques (révélés par questions readiness)

### Gap #1 — Tests iOS sur device réel manquants 🔴 BLOQUANT

| Zone | Pourquoi simulateur ne couvre pas |
|---|---|
| `BGProcessingTask` (OCR background) | Apple n'exécute pas `BGProcessingTask` sur simulateur. NFR11 (reprise OCR) jamais validée en conditions réelles. |
| APNs push notifications | Pas d'APNs sur simulateur. FR23 ("fiches prêtes") jamais reçue par un vrai device. Format payload, sound, badge — non-validés. |
| Permissions iOS | `UIBackgroundModes`, `NSDocumentBrowserUsageDescription` ne sont prompts que sur device réel. Risque : prompt manquant → feature silencieusement cassée. |

### Gap #2 — IAP RevenueCat non testé en sandbox 🟠 BLOQUANT lancement payant

Phase beta = accès gratuit (promo sœur) → IAP **non bloquant pour la beta**, mais **bloquant pour le lancement payant post-beta**. À valider avant la fin de la beta.

### Gap #3 — Validation Phase 0 testeuse : statut à clarifier ⚠️

Le PRD est explicite : « Phase 0 = qualité validée par la testeuse sur 1 collège réel → go/no-go pour le MVP Flutter ». Le MVP a été développé. **Question ouverte : la testeuse a-t-elle validé un vrai collège, ou a-t-on développé le MVP en présumant que ça allait passer ?** Si non validé : hypothèse non testée que Claude génère des fiches *pédagogiquement bonnes*.

### Signal positif : 1 mois+ de buffer 🟢

Avec ce buffer, tout est faisable sans précipitation : hardening + validation device réel + IAP sandbox + dogfooding solo.

---

## 4. Async correctness — Inventaire priorisé pour beta

| # | Item | Epic | Gravité beta | Fix |
|---|---|---|---|---|
| A1 | Race compteurs `reload_count` / `monthly_reloads` | E3 (3.4) | 🔴 HAUTE — coût Claude $$ | `UPDATE colleges SET reload_count = reload_count + 1 WHERE reload_count < :max RETURNING reload_count` |
| A2 | `DELETE /account` cascade non-atomique | E6 (6.2) | 🔴 HAUTE — RGPD données zombies | Rate limit backend ✅ (3/min) ; **reste** : wrapper Flutter try/catch + rollback si timeout |
| A3 | Rate limit search keyed sur IP (limiter global `_get_client_ip`) | E5 (5.1) | 🟠 MOYENNE — fac/résidence partagée | Surcharger `key_func` au niveau du décorateur : `@limiter.limit("30/minute", key_func=lambda req: req.state.user_id)` — ne PAS toucher au limiter global (casserait login/delete) |
| A4 | Race OCR : 2 jobs `processing` parallèles | E1 (1.2) | 🟠 MOYENNE — OCR dupliqué | `UNIQUE INDEX (college_id) WHERE status='processing'` |
| A5 | Monthly reset jamais exécuté | E3 (3.5) | 🔴 HAUTE — bloqué après 1 mois beta | ARQ cron `reset_monthly_reloads` (1er du mois 00:00 UTC) |
| A6 | SSE token JWT figé 3h | E3 (3.2) | 🟢 BASSE | Doc limitation, Phase 2 |
| A7 | JWT non-révocable post-DELETE (5min) | E6 (DEF4) | 🟢 BASSE | Doc CGU, Phase 2 (allow-list Redis) |
| ~~A8~~ | ~~Rate limit register/login~~ | — | ✅ **DÉJÀ FAIT** | `/register` bloqué 403 par design (cf. mémoire sécurité 2026-05-08) + `/login` a `@limiter.limit("5/minute")`. Item à retirer. |
| A9 | `evaluateSemantic` HTTP timeout 5s < Claude 2-5s | E4 (4.2) | 🟠 MOYENNE — 503 client | Timeout client 15s + retry 1× |
| A10 | APNs `NotificationService` instancié par push | E3 (3.5) | 🟡 PERF | Singleton `aioapns` au startup |

---

## 5. Dette infrastructure pré-prod (issue de Story 1.1, devient bloquante)

| Item | Action |
|---|---|
| `admin_password = "change-me"` et postgres password faible | Validator Pydantic au startup : refuse `change-me` en prod |
| Caddy `tls internal` + domaine `.local` | Vrai certificat Let's Encrypt + domaine public **avant invitation beta** |
| Ports Redis/PostgreSQL exposés sur l'hôte | Retirer `ports:` ou restreindre `127.0.0.1:` en `docker-compose.prod.yml` |
| `claude_api_key` accepté vide | Validator au démarrage (refus en prod) |
| `secret_key` JWT sans validation entropie | Validator longueur ≥ 32 chars |

Note mémoire : le `.env` prod sur le NAS est déjà configuré (`/mnt/user/appdata/compose-stacks/collega/.env`) — vérifier que ces valeurs y sont **non par défaut**.

---

## 6. Plan de préparation beta — Sprint Hardening (~1 mois)

### Critical path — Semaine 1
1. **AI-1** Clarifier statut validation Phase 0 testeuse (si pas fait, générer 1 collège réel + faire valider la qualité des fiches).
2. **AI-2** Setup TestFlight (provisioning profiles, certificats Apple, build release iOS).
3. **AI-3** Test E2E device réel sur un iPhone : import PDF réel → OCR backend (NAS) → réception push notif "fiches prêtes" → drill offline → search en ligne.

### Hardening backend Lots 1-5 — Semaine 2 (~1.5 jour)
- **Lot 1 — Atomicité quotas** : A1 + A5 + migration Alembic `010_atomic_quota_counters.py`
- **Lot 2 — RGPD safe-delete** : A2 Flutter try/catch + rollback + test timeout (backend rate limit déjà OK)
- **Lot 3 — Rate limit search** : A3 (override `key_func=user_id` sur le décorateur search uniquement)
- **Lot 4 — Race OCR + APNs perf + timeout sémantique** : A4 + A10 + A9
- **Lot 5 — Documentation** : A6, A7 dans `deferred-work.md` + wiki gotchas SDK

### Validation IAP sandbox — Semaine 3
- **AI-5** Compte Apple ID sandbox testeur → achat réel sandbox → observation webhook RevenueCat → backend → DB
- Test de rejet (achat refusé), reprise (déjà abonné)

### Buffer dogfooding solo — Semaine 4
- **AI-6** Utiliser l'app au quotidien sur ton iPhone pendant ≥ 5 jours pour ramasser les bugs UX que les tests automatisés ratent

### Finalisation
- **AI-7** Doc CGU/politique de confidentialité finales (FR40)
- **AI-8** Wiki des gotchas SDK (shadcn_ui, Dio, APNs, RC)

### Invitation beta-testeuses — Fin de semaine 4 / début mois suivant

---

## 7. Action items récapitulatifs

| # | Action | Owner | Quand |
|---|---|---|---|
| AI-1 | Vérifier statut validation Phase 0 testeuse | Lesurmatthis | Cette semaine |
| AI-2 | Setup TestFlight + build release iOS | Lesurmatthis | Semaine 1 |
| AI-3 | Test E2E device réel | Lesurmatthis | Semaine 1 |
| AI-4 | Implémenter Lots 1-5 du hardening async | Dev (via stories) | Semaine 2 |
| AI-5 | Validation IAP sandbox end-to-end | Lesurmatthis | Semaine 3 |
| AI-6 | Dogfooding solo ≥ 5 jours sur iPhone | Lesurmatthis | Semaine 4 |
| AI-7 | Doc CGU / politique de confidentialité (FR40) | Lesurmatthis | Semaine 3-4 |
| AI-8 | Wiki des gotchas SDK | Dev (via doc) | Semaine 4 |

**Items différés Phase 2 (non bloquants beta) :** A6 (SSE token gel), A7 (JWT non-révocable), dark mode, multi-tester, hash-sharing v2, ~80 items du `deferred-work.md`.

---

## 8. Insights macro à retenir

1. **L'architecture découplée a tenu** — c'est le plus gros win du MVP. Les abstractions posées en Epic 1 (SimilarityChecker, NotificationService, DrillSessionParams nullable, spaced rep client-side) ont absorbé 5 epics sans refonte. Pari payant.

2. **L'async correctness est un domaine de connaissance manquant** — pas par incompétence, par habitude solo. À documenter en checklist code-review avant Phase 2 multi-utilisateurs.

3. **Le coût qualité s'est concentré en review, pas en design** — vélocité MVP > rigueur upfront. Choix valide pour solo dev, mais la review n'est pas optionnelle. Couper la review = shipper les bugs.

4. **Le MVP technique a été construit sans validation physique sur iPhone réel** — c'est le risque non-technique le plus élevé aujourd'hui. Le 1 mois+ de buffer évite la catastrophe, à condition de s'en servir pour ça.

5. **La dette est consciente et documentée (`deferred-work.md` ≈ 80 items)** — bonne hygiène. Avant le lancement payant post-beta, refaire un passage de triage : qu'est-ce qu'on accepte définitivement ? qu'est-ce qu'on planifie en V1.1 ?

---

## 9. Décisions architecturales qui ont marqué le MVP

| Décision | Epic | Verdict |
|---|---|---|
| `SimilarityChecker` ABC (hash-sharing v1 → v2 sans refonte) | E1 | ✅ Tenue |
| Spaced repetition 100% client-side Drift | E4 | ✅ Backend libéré, offline-first natif |
| SSE polling DB 1.5s (pas WebSocket, pas Redis pub/sub) | E3 | ✅ Simple, robuste — surveillance pool DB en multi-user |
| ARQ cron pour cleanup OCR (24h) | E1 | ✅ Simple, idempotent |
| `routerProvider` réactif sur `authProvider` (GoRouter recréé) | E2 | ✅ Élégant, redirect auto sans nav explicite |
| `DELETE /account` = logout implicit en cascade synchrone | E6 | ⚠️ Élégant mais non-atomique (à wrapper) |
| `fromSearch: bool` dans `DrillSessionParams` (domain layer) | E5 | ⚠️ Pragmatique mais SoC violé (UI dans domain) |
| Régénération Claude synchrone HTTP (pas ARQ) | E3 | ⚠️ UX rapide mais 503 si Claude > 5s |
| `unawaited()` fire-and-forget partout (20+ instances) | E4 | ⚠️ Cristallisé — cache les erreurs |
| Évaluation sémantique Claude optionnelle (fallback flip classique) | E4 | ✅ UX graceful, pas d'état hybride |

---

## 10. Mise à jour sprint-status

Toutes les `epic-X-retrospective` (1 à 6) passent de `optional` à `done` — cette rétro MVP global les couvre toutes.

---

**Statut MVP :** ✅ 100% des stories complétées et déployées sur NAS prod. ❌ Pas encore validé sur device iOS réel. ❌ IAP sandbox non testé. ⚠️ Validation Phase 0 testeuse à clarifier.

**Verdict pour beta :** Pas prêt aujourd'hui. Prêt dans ~1 mois si le plan ci-dessus est exécuté.

---

## 11. Correction post-rétro (vérification code 2026-05-19)

Lors de la sauvegarde, vérification croisée avec la mémoire `project_security.md` (2026-05-08) et l'inspection des décorateurs `@limiter.limit` actuels. Plusieurs items de l'inventaire A1-A10 étaient déjà adressés :

| Item | État réel |
|---|---|
| A2 backend rate limit DELETE /account | ✅ `@limiter.limit("3/minute")` présent dans `auth.py:136`. Reste seulement le wrapping Flutter try/catch/rollback. |
| ~~A8 register/login rate limit~~ | ✅ `/register` retourne 403 par design ; `/login` a `@limiter.limit("5/minute")` (auth.py:34). **Item retiré du plan.** |
| Rate limit regenerate (deferred-work 3.5) | ✅ `@limiter.limit("10/hour")` sur `/flash-cards/{id}/regenerate`. |
| Rate limit /notifications/* | ✅ `@limiter.limit("10/minute")` sur les 2 endpoints. |

**Impact sur le plan :**
- Lot 3 (Rate limits) réduit à **A3 uniquement** : surcharger `key_func=user_id` au niveau du décorateur search (sans toucher au limiter global, qui doit rester sur IP pour les autres endpoints).
- Total hardening révisé : ~**1.5 jour** au lieu de 2 jours.

**Note pour la mémoire :** Confirmer en début de prochain hardening sprint que cette correction est intégrée — éviter de redoubler le travail déjà fait.
