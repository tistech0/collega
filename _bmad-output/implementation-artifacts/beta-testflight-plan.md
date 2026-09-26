# Beta TestFlight : plan d'implémentation

> **Agents :** exécuter tâche par tâche (TDD : test rouge, code, test vert, commit). Cases `- [ ]` pour le suivi.

**Objectif :** rendre l'app envoyable sur TestFlight et le backend prêt pour des testeurs externes, sans abonnement (accès par `is_beta`).

**Architecture :** côté backend, trois petits changements isolés : bundle APNs corrigé et repli sandbox/production par jeton, pages publiques `/legal/*` rendues depuis les mêmes Markdown que l'app. Côté app : entitlements push, clé de chiffrement dans `Info.plist`, RevenueCat désactivé tant qu'il n'y a pas de clé iOS `appl_`, script `tool/build_ipa.sh`.

**Stack :** FastAPI + aioapns 4 (backend), Flutter 3.27.1 + purchases_flutter 10 + flutter_apns_only (app).

**Spec :** `_bmad-output/planning-artifacts/beta-testflight-handoff.md`

## Contraintes globales

- Erreurs API : `AppError` et fabriques de `app/core/errors.py`, jamais `HTTPException`.
- `app/api/v1` = HTTP seulement ; logique dans `app/services`.
- Tests app par dossier (`test/core`, `test/features/<dossier>`), jamais toute la suite.
- Backend : pytest, ruff check, ruff format --check, mypy `app/core app/services` à 0 erreur.
- Déploiement uniquement via `collega_backend/scripts/deploy.sh <sha>` (CI verte).
- `.env` du NAS : ajout de lignes seulement, jamais d'écrasement, jamais de secret affiché.
- Contenu publié : éditeur Matthis Lesur, contact@matthislesur.com.
- Bundle de l'app : `com.lesurmatthis.collegaApp`.
- Compte Apple : celui d'un proche (Team ID inconnu à ce stade) ; ne rien coder en dur qui dépende du Team ID hors du projet Xcode.

---

### Tâche 1 (backend) : APNs, bundle et repli d'environnement

**Pourquoi :** le défaut `apns_bundle_id = "com.lesurmatthis.collega"` ne correspond pas à l'app. Un build TestFlight produit un jeton **production**, un build installé depuis Xcode un jeton **sandbox** : on envoie sur l'environnement configuré et, si APNs répond `BadDeviceToken`, on retente une fois sur l'autre.

**Fichiers :**
- Modifier : `collega_backend/app/core/config.py` (`apns_bundle_id` → `com.lesurmatthis.collegaApp`, `apns_use_sandbox` → `False`)
- Modifier : `collega_backend/app/services/notifications/apns_service.py` (deux clients, primaire et secondaire, construits paresseusement)
- Tester : `collega_backend/tests/services/test_apns_fallback.py` (nouveau)

**Interfaces :** `APNsNotificationService.__init__(self, clients: tuple[Any, Any] | None = None)` ; `clients` = (primaire, secondaire), injectable en test ; `_send_alert` inchangé côté appelants.

- [ ] Test rouge : faux clients qui renvoient `NotificationResult`-like (`is_successful`, `description`). Cas : succès au primaire (secondaire jamais appelé) ; `BadDeviceToken` au primaire puis succès au secondaire ; autre échec (`Unregistered`) → pas de repli ; défaut de config = bundle `com.lesurmatthis.collegaApp`.
- [ ] Code minimal, ruff, mypy, commit `feat(push): bundle de l'app et repli sandbox/production par jeton`.

### Tâche 2 (backend) : pages publiques `/legal`

**Pourquoi :** App Store Connect exige une URL de politique de confidentialité et une URL de support accessibles sans Cloudflare Access.

**Fichiers :**
- Créer : `collega_backend/app/static/legal/privacy.md` et `cgu.md` (copies exactes de `collega_app/assets/legal/*.md`)
- Créer : `collega_backend/app/services/legal_pages.py` (rendu Markdown → HTML avec `markdown-it-py`, gabarit sobre, mis en cache)
- Créer : `collega_backend/app/api/v1/legal.py` (routes `GET /legal/privacy`, `/legal/terms`, `/legal/support`, `HTMLResponse`)
- Modifier : `collega_backend/app/main.py` (inclure le routeur sans préfixe `/v1`, avant le montage statique), `pyproject.toml` / `poetry.lock` (`markdown-it-py`)
- Tester : `collega_backend/tests/api/test_legal_pages.py`

- [ ] Tests rouges : 200 sans authentification, `text/html`, contient « Matthis Lesur » et `contact@matthislesur.com` ; les `.md` du backend sont identiques octet pour octet à ceux de l'app (sinon le test dit de recopier) ; page support avec e-mail de contact.
- [ ] Code, qualité, commit `feat(legal): pages publiques confidentialité, CGU et support`.

### Tâche 3 (app) : RevenueCat désactivé sans clé iOS

**Pourquoi :** la clé de `env.dart` n'est pas une clé `appl_`. Sans `Purchases.configure`, tout appel `Purchases.*` plante côté natif : il faut un point d'entrée unique qui ne fait rien quand RevenueCat est désactivé.

**Fichiers :**
- Modifier : `collega_app/lib/env.dart` (`const bool kRevenueCatEnabled = ...startsWith('appl_')`)
- Modifier : `collega_app/lib/main.dart` (configure seulement si activé)
- Modifier : `collega_app/lib/features/auth/data/revenuecat_service.dart` (constructeur `RevenueCatService({bool enabled = kRevenueCatEnabled})` ; `logIn`, `logOut` ajoutés ; chaque méthode sans effet si désactivé : offre `null`, infos `null`)
- Modifier : `collega_app/lib/features/auth/auth_providers.dart`, `paywall_providers.dart` (passer par le service au lieu de `Purchases.*`)
- Tester : `collega_app/test/features/auth/revenuecat_service_test.dart` (nouveau) et tests auth existants

- [ ] Test rouge : service désactivé → `getMonthlyOffering()` null, `logIn`/`logOut` ne lèvent rien et n'appellent pas le canal natif ; `kRevenueCatEnabled` faux avec la clé actuelle.
- [ ] Code, `flutter test test/features/auth`, `test/features/profile`, `test/core`, commit `fix(app): RevenueCat inerte tant qu'il n'y a pas de clé iOS`.

### Tâche 4 (app) : push, chiffrement, script de build

**Fichiers :**
- Créer : `collega_app/ios/Runner/Runner.entitlements` (`aps-environment` = `development` ; l'export App Store le passe en `production`)
- Modifier : `collega_app/ios/Runner.xcodeproj/project.pbxproj` (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` sur Debug, Release, Profile)
- Modifier : `collega_app/ios/Runner/Info.plist` (`ITSAppUsesNonExemptEncryption` = false ; `UIBackgroundModes` = `remote-notification`)
- Créer : `collega_app/tool/build_ipa.sh` (lit `.env.local` comme `run_device.sh` ; `--build-number` = minutes depuis le 2026-01-01, toujours croissant ; `flutter build ipa --release --export-options-plist` ; envoi par `xcrun altool --upload-app` si `ASC_KEY_ID`/`ASC_ISSUER_ID` et la clé `.p8` sont présents, sinon ouvre l'archive dans l'Organizer)
- Créer : `collega_app/ios/ExportOptions.plist` (méthode `app-store-connect`, signature automatique)
- Tester : `collega_app/test/core/ios_release_config_test.dart` (lit les fichiers : entitlements référencés dans les 3 configurations, clés `Info.plist` présentes)

- [ ] Test rouge, code, `flutter test test/core`, `bash -n tool/build_ipa.sh`, `flutter build ios --release --no-codesign` pour vérifier que le projet compile, commit `feat(ios): entitlements push, déclaration de chiffrement, script d'envoi TestFlight`.
- [ ] Team ID : remplacé quand Matthis l'aura (3 occurrences de `DEVELOPMENT_TEAM`).

### Tâche 5 : revue, CI, déploiement

- [ ] Revue du diff complet (sous-agent), corrections.
- [ ] Backend : pytest, ruff, format, mypy, `alembic check` (aucune migration attendue).
- [ ] Push de la branche, CI verte, puis `scripts/deploy.sh <sha>` ; `curl` sur `/legal/privacy` depuis le LAN.
- [ ] APNs en prod : quand Matthis a la clé `.p8`, la déposer sur le NAS, ajouter les lignes `APNS_*` au `.env` (ajout seulement), redémarrer api et worker, vérifier le log « Notification service initialized (type=APNsNotificationService) ».

### Hors code (après le compte Apple)

- Compte de démo pour la revue d'Apple (`is_beta`, un collège importé) et comptes des testeurs depuis la console admin.
- Bypass Cloudflare Access sur `/legal` (Matthis, dans le tableau de bord Cloudflare).
- Test hors LAN (`--resolve` sur une IP Cloudflare) avant la revue.
