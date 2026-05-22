# SDK Gotchas — pièges récurrents

> **Document vivant.** Ajoute une section dès qu'un nouveau gotcha SDK / package tiers coûte ≥ 1h de debug.
> Mets à jour quand un SDK est mis à niveau et que le contournement n'est plus nécessaire.
> Dernière révision : 2026-05-22 (Story 7.4 — initiale).
>
> **Périmètre** : uniquement les pièges externes (packages npm/pub/PyPI, SDK natifs). Les anti-patterns
> internes (Riverpod, magic strings, etc.) sont documentés dans
> `_bmad-output/implementation-artifacts/deferred-work.md` et la rétro MVP.

---

## 1. `shadcn_ui ^0.19.x` — pas de `ShadSkeleton`

**Symptôme** : import `ShadSkeleton` échoue (`undefined name 'ShadSkeleton'`), alors que la doc
officielle du package le mentionne.

**Cause** : le composant n'est pas exposé dans la version `^0.19.0` actuellement utilisée
(`collega_app/pubspec.yaml`).

**Solution** : utiliser `ShadProgress` indéterminé ou `CircularProgressIndicator` natif Flutter.

**Référence code** : `collega_app/lib/features/colleges/presentation/import_progress_screen.dart`,
`collega_app/lib/features/colleges/presentation/college_detail_screen.dart` (apparition staggerée des fiches).

**Statut** : réévaluer dès la mise à jour vers `shadcn_ui ≥ 0.20` — rouvrir l'item correspondant
dans `_bmad-output/implementation-artifacts/deferred-work.md`.

---

## 2. Dio intercepteur — boucle infinie de refresh JWT

**Symptôme** : Dio reçoit 401 → l'intercepteur appelle `POST /v1/auth/refresh` → 401 (refresh token
expiré côté serveur) → boucle infinie, crash silencieux du thread Dio.

**Cause** : si l'intercepteur 401 utilise **le même `Dio`** que les requêtes applicatives, le
`/auth/refresh` lui-même peut redéclencher l'intercepteur — récursion infinie.

**Solution** : utiliser **un `Dio` séparé** (`_refreshDio`) — instance neuve sans intercepteur 401 —
exclusivement pour la requête de refresh.

**Référence code** : `collega_app/lib/core/network/api_client.dart:16-23`
(`_refreshDio = _buildDio()` + champ `final Dio _refreshDio`), cf. dev notes Story 2.3.

**Anti-pattern** : ne JAMAIS partager l'instance Dio entre le flux applicatif et le flux de refresh —
la séparation est structurelle, pas comportementale.

---

## 3. `flutter_apns_only ^1.6.0` — signature `ApnsRemoteMessage` ≠ doc pub.dev

**Symptôme** : tentative d'accéder à `message.data` ou `message.aps` (selon la doc) →
`NoSuchMethodError`.

**Cause** : la version pub.dev publiée a une signature interne différente de la doc.

**Solution réelle** : utiliser `message.payload` (Map) et `message.notification` (objet imbriqué).

**Référence code** : `collega_app/lib/core/notifications/notifications_service.dart` —
`_onNotificationTap(ApnsRemoteMessage message) { final collegeRefId = message.payload['college_ref_id']; … }`.

**Vérification** : avant d'utiliser une nouvelle propriété de `ApnsRemoteMessage`, lire le source
du package localement (`flutter pub deps` → naviguer vers
`~/.pub-cache/hosted/pub.dev/flutter_apns_only-*/lib/...`) plutôt que de croire la doc.

---

## 4. RevenueCat — webhook async + synchronisation `/auth/me`

**Symptôme** : après un achat IAP réussi (fermeture du paywall), l'état `is_subscribed` côté Flutter
reste `false` pendant quelques secondes, malgré un callback de purchase OK.

**Cause** : le webhook RevenueCat est livré au backend **après** la réponse synchrone du SDK.
Le backend met à jour `User.is_subscribed=true` quelques secondes après que Flutter a fermé le paywall.

**Solution actuelle** : appel `refreshSubscription()` immédiatement après `purchaseMonthlySubscription`,
qui interroge `POST /v1/auth/refresh-subscription` côté backend (qui lui-même contacte RC).

**Référence code** : `collega_app/lib/features/auth/paywall_providers.dart` (méthode `purchase`,
~ligne 50-70) + `collega_app/lib/features/auth/auth_providers.dart:184` (`refreshSubscription()`).
Backend : `collega_backend/app/api/v1/billing.py` (webhook RC).

**À considérer** : si l'expérience reste perfectible (latence visible), ajouter un polling à intervalle
court (2 s × 5) sur `GET /v1/auth/me` après fermeture du paywall jusqu'à ce que `is_subscribed=true`,
puis débloquer la navigation.

---

## Comment ajouter une nouvelle entrée

1. Reproduire le bug en local (≥ 1h de debug initialement coûté).
2. Trouver une solution stable (workaround documenté ou patch upstream demandé).
3. Ajouter une section dans ce fichier avec :
   - **Symptôme** (ce que le dev voit)
   - **Cause** (si non évidente)
   - **Solution** (fix opérationnel)
   - **Référence code** (chemin:ligne, à vérifier au moment de la rédaction — pas d'invention)
   - **Statut** ou **Vérification** (optionnel)
4. Si un `// Cf. docs/sdk-gotchas.md § N.` aide à éviter le piège, l'ajouter au-dessus du workaround
   dans le code.
