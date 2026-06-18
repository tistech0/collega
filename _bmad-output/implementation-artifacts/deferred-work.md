# Deferred Work

## Deferred from: code review of 7-4-chronometre-apns-singleton-docs (2026-05-22)

- `flutter_markdown` en mode maintenance / discontinued (annonce Flutter team fin 2024) — migration prévisible vers `markdown_widget` ou fork communautaire à la prochaine MAJ Flutter [`collega_app/pubspec.yaml:55-56`]
- Workaround test viewport `Size(1200, 1600)` ne reflète plus le rendu prod iPhone — préférer `scrollUntilVisible` pour fidélité réelle [`collega_app/test/features/profile/profile_screen_test.dart:173-180,220,239`]
- `_DrillActiveView.build()` watch `revisionPrefsProvider` → en iPad split-view, changer la durée timer depuis Profile restart le timer de la carte courante. Unreachable iPhone single-window (acceptable MVP). Documenter ou snapshot prefs au `initState` [`collega_app/lib/features/drill/presentation/drill_screen.dart:118`]
- Icônes pause inversées vs convention iOS HIG (`Icons.timer` ↔ `Icons.timer_off` au lieu de `Icons.pause` ↔ `Icons.play_arrow`). Conforme au spec L.309 mais surprend les utilisatrices iOS — à soumettre Sally (UX) avant beta [`collega_app/lib/features/drill/presentation/drill_screen.dart:163-170`]
- Tests `pump(Duration)` autour de `ShadToaster` peuvent être racy avec les animations internes du toast. Passent actuellement mais flakiness latente à monitorer en CI [`collega_app/test/features/drill/drill_screen_test.dart:184`]

## Deferred from: code review of 7-3-hardening-rgpd-safe-delete-config (2026-05-22)

- Logger possiblement non configuré au moment de `Settings()` (instanciation module-level avant que uvicorn monte ses handlers) — warning dev peut être avalé silencieusement [`collega_backend/app/core/config.py:105`]
- `ShadToaster.of(context)` peut throw si force-logout déclenche un redirect `/demo` pendant l'`await deleteAccount` — pattern UI pré-existant, hors scope hardening 7.3 [`collega_app/lib/features/profile/presentation/profile_screen.dart:569,577`]
- Commentaires sécurité `docker-compose.prod.yml` non enforceables par CI — un futur dev peut ajouter `ports:` sur `db`/`redis` malgré le commentaire ; à coupler avec un step CI grep quand un pipeline sera monté [`collega_backend/docker-compose.prod.yml`]

## Deferred from: code review of 7-2-hardening-async-backend (2026-05-22)

- Migration 012 sans `IF NOT EXISTS` — convention Alembic acceptable via cycle up/down, idempotence stricte non garantie en cas de re-stamp manuel [`collega_backend/alembic/versions/012_atomic_quota_and_unique_processing.py`]
- Test AC2 e2e replay reimports manquant — `test_monthly_reset.py` mocke le UPDATE batch mais ne vérifie pas qu'un user reseté peut à nouveau lancer `monthly_reloads_max` reimports de bout en bout [`collega_backend/tests/workers/test_monthly_reset.py`]
- Mois sautés par le cron sans log d'audit — un user inactif plusieurs mois est resété silencieusement sans trace audit des fenêtres « perdues » [`collega_backend/app/workers/cleanup_worker.py`]
- `_ScriptedAdapter` Dio dans `drill_repository_test.dart` — abstraction fragile : un Dio dédié pour le test 422 (à cause de `validateStatus < 422`) signale une mauvaise séparation des cas de test [`collega_app/test/features/drill/drill_repository_test.dart`]
- Mock `db.execute.side_effect=[...]` ordonné fragile — l'ajout d'un SELECT supplémentaire dans `import_college_pdf` cassera tous les tests assumant un ordre strict [`collega_backend/tests/api/test_colleges_reimport.py`]
- Rate limit bypass partiel sur tokens invalides — `get_current_user` lève 401 AVANT `request.state.user_id = ...` → `_user_id_key` tombe sur fallback IP pour les requêtes 401 ; pré-existant côté slowapi global, hors scope hardening async [`collega_backend/app/deps.py`]

## Deferred from: code review of 7-1-corrections-ux-flashcard-router (2026-05-19)

- Pas de test transition `AsyncLoading → Data` couvrant AC4 (« pas de flash visuel `/demo` si authentifié »). Le `_FakeAuthNotifier.build()` retourne immédiatement, donc le scénario loading→data réel n'est jamais exécuté — une régression sur `if (authAsync.isLoading) return null;` (app_router.dart L.30) passera silencieusement. Ajout d'un test avec `Completer<AuthState>` recommandé en hardening [`collega_app/test/core/router/app_router_test.dart:14-17`]
- Pas de test pour la branche `state.fullPath == null || state.fullPath == '/'` du redirect (app_router.dart L.42-44). Cette branche a été touchée par Story 6.2 (logique `isAuth ? (hasAccess ? '/home' : '/paywall') : '/demo'`) mais hors périmètre Story 7.1. À couvrir dans une future story router/auth [`collega_app/lib/core/router/app_router.dart:42-44`]
- Pas de test explicite de non-régression `_handleDefinitionSubmit` (flow `setSemanticFeedback` + `flip()` après toggle bidirectionnel). Completion Notes du Dev Agent Record affirme cette vérification mais sans test couvrant explicitement le cas définition (cardType + submit + flip true). Comportement trivial à analyser mais non testé [`collega_app/test/features/drill/drill_session_notifier_test.dart`]

## Deferred from: code review of 6-2-suppression-compte-conformite-rgpd (2026-05-18)

- DEF1 — Tests backend fragiles : `mock_db.get` intercepte `get_current_user` indirectement ; un changement d'implémentation pourrait casser silencieusement l'auth dans les tests [`test_auth.py`]
- DEF2 — Absence de test pour le chemin d'erreur AC4 : aucun test ne vérifie que `ShadToast.destructive` s'affiche et que l'écran reste ouvert en cas d'erreur réseau [`profile_screen_test.dart`]
- DEF3 — Absence de test pour le toast de succès AC2 : aucun test ne vérifie l'affichage de "Ton compte a été supprimé" [`profile_screen_test.dart`]
- DEF4 — JWT toujours valide après suppression : le token d'accès reste exploitable jusqu'à son expiry naturelle (limitation JWT stateless pré-existante)
- DEF5 — Absence de `RevenueCat.logOut()` lors de la suppression : la session RC anonyme reste liée à l'ancien user ID [`auth_providers.dart`]
- DEF6 — HTTP 200 au lieu de 204 sur `DELETE /account` : convention REST mineure, aucun impact fonctionnel [`auth.py`]
- DEF7 — Flag `isSubscribed` potentiellement obsolète dans le dialog : valeur figée à la construction du widget, pas relue au moment de l'ouverture [`profile_screen.dart`]

## Deferred from: code review of 6-1-ecran-profil-preferences (2026-05-17)

- W1 — Corps de réponse PATCH /profile ignoré côté Flutter — risque mineur de désynchronisation serveur/client (normalisations client et serveur sont équivalentes en pratique) [`auth_repository.dart`]
- W2 — `getSubscriptionInfo` broad `catch(_)` — masque les erreurs d'initialisation SDK RevenueCat (comportement intentionnel de dégradation gracieuse) [`revenuecat_service.dart`]
- W3 — `_subInfo` dans `_SubscriptionCardState` non rafraîchi si l'abonnement change en cours de session — cas limite rare [`profile_screen.dart`]

## Deferred from: code review of 5-2-lancement-session-depuis-resultat-recherche (2026-05-16)

- V1 — Duplicate "Retour à l'accueil" dans les deux branches `if/else fromSearch` — refactor avec bouton conditionnel "Nouvelle recherche" uniquement [`drill_screen.dart:356-372`]
- V2 — `fromSearch` dans `DrillSessionParams` (domain) est un concern de navigation/UI — violation SoC potentielle ; envisager un wrapper navigation ou paramètre de route [`drill_session_state.dart`]
- V3 — Cartes Rang B/C sans feedback visuel (ripple/ink) sur le `GestureDetector` — UX enhancement [`search_result_tile.dart`]
- V4 — Collège non importé → `ItemDetailScreen` spinner infini sans message d'erreur ni back button — pre-existing [`item_detail_screen.dart`]
- V5 — `_collegeName` fallback `'Collège #X'` si `collegeRefId` absent du catalogue statique — pre-existing [`search_result_tile.dart`]
- V6 — `result.rang == 'A'` comparaison case-sensitive sans normalisation — pre-existing (contrainte DB uppercase, risque insert raw) [`search_result_tile.dart`]
- V7 — Item sans fiches Rang A → session complète immédiatement avec 0% maîtrise, "Nouvelle recherche" affiché sur un drill vide — pre-existing [`drill_providers.dart`]
- V8 — `/colleges/:ref_id/items/:item_id` dans ShellRoute + `context.push` depuis search : comportement GoRouter non testé (double nav bar potentielle) — pre-existing [`app_router.dart`]

## Deferred from: code review of 5-1-recherche-full-text-resultats-contextuels (2026-05-16)

- W1 — Rate limit keyed sur IP (slowapi default) et non sur `user_id` — un NAT partagé peut déclencher un 429 collectif ; un abonné avec multi-IP peut contourner la limite. [`search.py`]
- W2 — `to_tsvector` recalculé pour `ts_rank` (pas de colonne tsvector stockée) — vecteur de texte matérialisé 2× par ligne (WHERE + ts_rank) ; envisager une colonne générée stockée pour optimiser. [`full_text_search.py`]
- W3 — `require_subscription` évalué après `get_db` — slot de connexion DB acquis pour chaque requête 403 non-abonné ; pattern pré-existant sur tous les endpoints subscribed. [`search.py`]
- W4 — Champ `rank` (float, score de pertinence interne) exposé dans la réponse API sans Pydantic response model — à filtrer avec un schéma `SearchResultResponse`. [`search.py`]
- W5 — Tiebreaker non-déterministe dans `DISTINCT ON` quand deux flashcards ont le même `ts_rank` pour un même `item_id` — ajouter `fc.id` comme clé de tri secondaire stable. [`full_text_search.py`]
- W6 — Couleur highlight `Color(0xFFB7F2C8)` hardcodée en dehors de `AppColors` — extraire en `AppColors.searchHighlight` pour cohérence avec le dark mode futur. [`search_result_tile.dart`]

## Deferred from: code review of 4-5-progression-college-rang-rappels (2026-05-16)

- D1 — Clock skew ARQ à la frontière d'heure — `datetime.now(timezone.utc).hour` peut capturer la mauvaise heure en cas de dérive cron ; pas de guard de déduplication ni de fenêtre de tolérance. [`daily_reminder_worker.py:15`]
- D2 — `getDrillStatsByItem` charge toutes les flashcards d'un collège en mémoire sans pagination — performance concern pour grands collèges ; acceptable pour MVP. [`college_detail_repository.dart:63-88`]

## Deferred from: code review of 4-4-planning-algorithmique-personnalisation (2026-05-15)

- D1 — `getActiveConfig()` fetch-all au lieu de `orderBy + limit(1)` — performance, une seule config en pratique mais pas idiomatique [`planning_repository.dart:16`]
- D2 — ID config = `DateTime.now().millisecondsSinceEpoch.toString()` — fragile en tests rapides, UUID serait plus robuste [`planning_providers.dart:78`]
- D3 — `whenData().value ?? SizedBox.shrink()` swallows loading/error states silencieusement — style uniquement, fonctionnel [`home_screen.dart:79-86`]

## Deferred from: code review of 4-3-ecran-accueil-sessionherocard (2026-05-14)

- D1 — SELECT * pour comptage dans `_countCards` — performance, utiliser Drift `count()` [`home_providers.dart`]
- D2 — `maxCards` sans borne supérieure dans le stepper [`session_config_sheet.dart`]
- D3 — `HomeNotifier` lit `homeSessionConfigProvider` via `ref.read` — désynchronisation connue, documentée en Dev Notes [`home_providers.dart`]
- D4 — `SemanticFeedback.result` String libre — devrait être un enum [`drill_repository.dart`]
- D5 — Insertion infinie dans queue pour carte aRevoir réévaluée — pré-existant Story 4.2 [`drill_providers.dart`]
- D6 — `restartWithErrors()` sans rechargement base — pré-existant Story 4.2 [`drill_providers.dart`]
- D7 — `reviewCount` non incrémenté lors des évaluations — scope Story 4.4 [`drill_repository.dart`]
- D8 — `evaluate()` sans guard `isFlipped` — pré-existant Story 4.2, UI enforce le flow [`drill_providers.dart`]
- D9 — `unawaited updateCardDrillLevel` fire-and-forget — intentionnel, pattern établi [`drill_providers.dart`]
- D10 — `statusFilter` inconnu silencieusement ignoré [`home_providers.dart`]
- D11 — Race condition rebuild pendant `_countCards` [`home_providers.dart`]
- D12 — `estimatedDuration` affiche "0 min" quand totalCards == 0 [`home_providers.dart`]
- D13 — `drillLevel` inconnu en BDD trié comme 'new' [`drill_repository.dart`]
- D14 — Nom de collège vide dans `HomeOcrInProgress` [`home_providers.dart`]
- D15 — Route `/drill` + ShellRoute — état `homeProvider` au retour [`app_router.dart`]

## Deferred from: code review of 4-2-mode-drill-session-revision (2026-05-14)

- D1 — HTTP 404 utilisé pour "non trouvé" ET "interdit" dans `evaluate_semantic` — pattern pré-existant dans toute l'API, pas introduit par cette story [`collega_backend/app/api/v1/drill.py:35-36`]
- D2 — `evaluateSemantic` appelé directement depuis la couche widget (bypass notifier) — architecture intentionnelle documentée dans la story pour le fallback offline [`drill_screen.dart`]
- D3 — Model ID `claude-haiku-4-5-20251001` hardcodé dans `ask_json` — préoccupation de maintenance, pattern cohérent avec le reste du `ClaudeClient` [`collega_backend/app/services/generation/claude_client.py`]

## Deferred from: code review of 4-1-composants-flashcard-drillevaluationbar (2026-05-12)

- F8 — `score == 0.0` masqué par condition `<= 0.0` dans `OcrConfidenceBadge` : un score OCR de 0.0 (échec total) ne déclenche pas le badge d'avertissement — comportement pré-existant Story 3.3 [`ocr_confidence_badge.dart:27`]
- F9 — Popover `OcrConfidenceBadge` reste ouvert si le badge sort du viewport lors d'un scroll — limitation shadcn_ui, pas de listener scroll [`ocr_confidence_badge.dart:59`]
- F10 — Tap en file peut passer à travers toggle rapide de `isVisible` sur `DrillEvaluationBar` : `IgnorePointer` ne couvre que les nouveaux événements — comportement pipeline gesture Flutter [`drill_evaluation_bar.dart:18`]
- F14 — `AnimatedOpacity` + `IgnorePointer` pilotés par le même `isVisible` sans source unique de vérité interne — décision architecturale à reconsidérer si Story 4.2 ajoute de la complexité [`drill_evaluation_bar.dart`]
- F16 — Pas de test pour l'animation flip (pump 300ms) ni pour le reset `didUpdateWidget` card-change — hors T5 requirements Story 4.1 [`flash_card_widget_test.dart`]
- F17 — `OcrConfidenceBadge` : contenu du popover accessible uniquement au tap, sans activation clavier ni screen reader — gap d'accessibilité pré-existant Story 3.3 [`ocr_confidence_badge.dart`]
- F19 — `_makeCard` fixture utilise des IDs fixes (`'test-id'`, `'item-id'`, `'college-id'`) : risque de collision si un widget de collection déduplique par ID dans le futur [`flash_card_widget_test.dart`]
- F27 — Extension `DrillEvaluationResultX` sans getter `slidesNeutral` pour `bien` : les appelants doivent inférer `bien` par exclusion de `slidesUp`/`slidesDown` — choix de design [`drill_state.dart:8-9`]

## Deferred from: code review of 3-5-feedback-fiches-regeneration-notification-push (2026-05-12)

- `monthly_reloads_reset_at` ajouté au modèle `User` sans logique de reset mensuel — compteur `monthly_reloads` ne sera jamais réinitialisé, limite mensuelle devient permanente [`collega_backend/app/models/user.py`]
- SSE JWT stale sur longue connexion — `_tokenProvider()` capturé à la connexion pour `receiveTimeout` 3h, dépend de l'intercepteur auth [`collega_app/lib/core/network/sse_client.dart`]
- APNs token persisté après logout — pas d'endpoint DELETE pour invalider le token, nouvelle feature à ajouter [`collega_backend/app/api/v1/notifications.py`]
- Prompt injection via `user_note` dans `regenerate_single_card` — risque acceptable en app fermée, décision produit [`collega_backend/app/services/generation/claude_client.py`]

## Deferred from: code review of 3-4-hash-sharing-limites-reimport (2026-05-12)

- Reset mensuel commité avec le premier `db.commit()` avant l'enqueue ARQ — si l'enqueue échoue, le job est supprimé mais `monthly_reloads_reset_at` avance d'un mois ; impact faible (favorable à l'utilisateur ou neutre) [`collega_backend/app/api/v1/colleges.py`]
- Comparaison `now >= monthly_reloads_reset_at` sans coercion timezone explicite — certains drivers SQLAlchemy retournent des datetimes naïves depuis `DateTime(timezone=True)`, risque de `TypeError` ; pattern pré-existant dans le projet [`collega_backend/app/api/v1/colleges.py`]

## Deferred from: code review of 3-3-affichage-fiches-generees-score-confiance-ocr (2026-05-10)

- `SseClient.connect` non réentrant : annulation du token précédent, mais le stream HTTP n'est pas fermé immédiatement → leak descripteur fichier sur reconnexions rapides [`collega_app/lib/core/network/sse_client.dart`]
- Migration Drift `onUpgrade` : aucune gestion explicite des downgrades ou des gaps de version future — `from < 2` est correct mais fragile si de futures migrations sautent des versions [`collega_app/lib/core/database/app_database.dart`]
- `limiter.py` sans fallback Redis : si Redis est indisponible, `slowapi` lève une exception au moment de la requête → toutes les tentatives de login retournent 500 plutôt que de passer en fail-open [`collega_backend/app/core/limiter.py`]
- `list_college_items` retourne 409 `GENERATION_NOT_COMPLETE` pour le statut `failed` : le client ne peut pas distinguer "génération en cours" de "génération définitivement échouée" — décision produit nécessaire [`collega_backend/app/api/v1/colleges.py`]
- Apparition progressive des fiches : AC5 suggère une apparition SSE-driven item par item ; l'implémentation utilise une animation staggerée au chargement initial — acceptable pour une première version [`collega_app/lib/features/colleges/presentation/college_detail_screen.dart`]

## Deferred from: code review of 3-2-import-pdf-progression-ocr-temps-reel (2026-05-10)

- Token SSE figé — token JWT capturé une seule fois à la connexion ; risque si le token expire pendant une session SSE active longue (3h max) et que l'utilisateur revient en foreground [`collega_app/lib/features/colleges/colleges_import_providers.dart:296`]
- Pool DB saturé par streams SSE simultanés — chaque stream ouvre/ferme une session DB toutes les 1.5s ; acceptable à l'échelle solo, à monitorer si passage en multi-utilisateurs [`collega_backend/app/api/v1/colleges.py:655`]
- Reconnexion SSE absente depuis CollegeImportScreen — AppLifecycleListener uniquement sur ImportProgressScreen ; si l'utilisateur quitte la progress screen avant la fin, la reconnexion foreground ne se fait pas [`collega_app/lib/features/colleges/colleges_import_providers.dart`]
- CircularProgressIndicator utilisé à deux endroits — ShadSkeleton absent de shadcn_ui ^0.19.0, documenté dans le Dev Agent Record ; réévaluer quand shadcn_ui sera mis à jour [`collega_app/lib/features/colleges/presentation/import_progress_screen.dart:594`]
- FilePicker appelé directement dans le ConsumerStatefulWidget — violation mineure du pattern "logique dans le Notifier" ; fonctionnel, à refactoriser si le test de ce code devient nécessaire [`collega_app/lib/features/colleges/presentation/college_import_screen.dart:420`]

## Deferred from: code review of 3-1-liste-colleges-navigation (2026-05-08)

- `FlashCard.rang` sensibilité à la casse — la contrainte DB enforce uppercase `'A'/'B'/'C'` mais un insert raw `'a'` contournerait le check, causant un sous-comptage silencieux dans `list_user_colleges` [`collega_backend/app/api/v1/colleges.py`]
- `ref.read` dans `CollegesNotifier.build()` — provider non invalidé automatiquement après re-login ; données du précédent utilisateur potentiellement visibles avant refresh explicite [`collega_app/lib/features/colleges/colleges_providers.dart`]
- `college_ref_id` non validé contre le catalogue statique côté backend — un ID hors 1-40 est retourné dans l'API mais silencieusement ignoré par le merge Flutter [`collega_backend/app/api/v1/colleges.py`]
- Champ `college_id` (UUID interne) présent dans `UserCollegeData`/`UserCollegeStatus` mais jamais consommé par le client — potentiellement utile en Story 3.2/3.3 [`collega_backend/app/schemas/college.py`]
- `status` typé `String` au lieu d'`Enum` dans le schéma et le modèle Flutter — `isGenerationComplete` repose sur une comparaison de chaîne littérale, fragile si l'enum backend change [`collega_backend/app/schemas/college.py`]

## Deferred from: code review of 2-4-abonnement-in-app-purchase-paywall (2026-05-06)

- `authProvider` en état `AsyncError` non géré dans le router — perte de session silencieuse si `loadStoredUser` lève une exception (ex. corruption keychain iOS) ; l'app dégrade en état non-authentifié sans feedback [`app_router.dart`]
- TOCTOU dans `refreshFromMe` — `userId`/`email` lus depuis le storage *après* l'écriture des flags subscription, vulnérable à un `logout()` concurrent qui viderait le storage entre les deux opérations (low severity) [`auth_repository.dart`]

## Deferred from: code review of 2-3-inscription-authentification (2026-05-05)

- Pas de révocation server-side — logout ne invalide pas les tokens JWT côté serveur ; aucune allow-list ni endpoint de révocation ; token capturé avant logout reste valide 30 jours
- `decode_token` ne valide pas le claim `type` en interne — risque futur si un appelant oublie la vérification manuelle du type access/refresh [`security.py`]
- Imports différés de `settings` dans `create_access_token`/`create_refresh_token` — masque la dépendance, complique les tests unitaires isolés [`security.py`]
- Pas de rate limiting sur `/register` et `/login` — énumération d'emails via 409 + brute-force possible ; à traiter côté infrastructure (middleware / API gateway)
- `bcrypt<4.0.0` sans commentaire dans pyproject.toml — raison documentée : incompatibilité passlib 1.7.4 avec bcrypt 4.x/5.x [`pyproject.toml`]
- Token d'accès expiré au démarrage à froid → `loadStoredUser()` retourne état authentifié avant le premier appel ; l'intercepteur gère le refresh automatiquement mais crée un glitch UX mineur [`auth_repository.dart`]

## Deferred from: code review of 2-2-demo-interactive-college-fictif (2026-05-04)

- Redirect `'/demo'` redondant avec `initialLocation: '/demo'` — dead code sans impact fonctionnel, à nettoyer [`app_router.dart:11`]
- Magic strings `'A_REVOIR'`/`'BIEN'`/`'MAITRISE'` non encapsulées — tech debt intentionnel conforme à la spec Story 2.2 ; extraire en enum ou constantes dans une story de refactoring [`demo_providers.dart`]
- Google Fonts sans `allowRuntimeFetching = false` — déjà référencé dans la review Story 2.1 ; à configurer avant déploiement production [`app_theme.dart`]

## Deferred from: code review of 2-1-theme-design-system-flutter (2026-05-04)

- Dark mode non géré — `brightness: Brightness.light` hardcodé, pas de `darkTheme` dans `ShadApp.router` — hors scope story 2.1, à traiter dans une story dédiée UI/thème avant le lancement public [`app_theme.dart:41`]
- `google_fonts` non bundlé offline — Inter chargée par réseau; sans `GoogleFonts.config.allowRuntimeFetching = false` + assets bundlés, la typo est incohérente hors réseau (ex. intranet hôpital) — à configurer avant déploiement production [`pubspec.yaml`]
- `onTap` sans bounds check sur `paths[i]` dans `_AppShell` — risque `RangeError` si le nombre de tabs change sans synchroniser la liste `paths` — safe actuellement (4 tabs fixes), à corriger dès l'ajout d'un onglet [`app_router.dart`]
- Smoke test faible — seul `takeException() isNull` est vérifié, aucune assertion sur les widgets rendus — à enrichir (ex. `find.byType(BottomNavBar)`) dans une story test dédiée [`smoke_test.dart`]

## Deferred from: code review of 1-5-interface-testeur-web-phase-0 (2026-04-30)

- D1 — `app/static/index.html` utilise un formulaire HTML custom au lieu de la dialog native browser (AC #6) — déviation consciente acceptée pour Phase 0 (meilleure UX), à reconsidérer si la spec est durcie en Phase 1
- W1 — `REVENUECAT_WEBHOOK_SECRET` validator dans `Settings` plante le démarrage si la variable n'est pas définie (valeur par défaut `""`) — pré-existant Story 1.3/1.4, à corriger avant la mise en production [app/core/config.py]
- W2 — Tous les feedbacks partagent `tester_id="tester"` car un seul jeu de credentials existe — Phase 0 intentionnel mono-tester, à repenser en Epic 3 si multi-tester nécessaire [app/deps.py]
- W3 — Race condition UPSERT feedback (double-clic rapide) → `IntegrityError` 500 non géré — risque négligeable Phase 0 mono-utilisateur, à corriger avec try/except en Phase 1 [app/api/v1/tester.py]
- W4 — N+1 queries dans `list_colleges` : 2 COUNT queries par collège — acceptable Phase 0, à optimiser via `GROUP BY college_id` avant mise en production multi-collèges [app/api/v1/tester.py]
- W5 — N+1 queries dans `get_college_summary` : 2 queries par item — acceptable Phase 0, à optimiser via JOIN + agrégation SQL avant mise en production [app/api/v1/tester.py]
- W6 — Pas de `updated_at` sur `TesterFeedback` — pas d'audit trail pour les modifications de feedback, à ajouter si besoin de traçabilité [app/models/tester_feedback.py]
- W7 — `avg_confidence = sum(r[1] for r in items_rows) / len(items_rows)` peut lever `TypeError` si `ocr_confidence_score` est NULL — pré-existant Story 1.4, à corriger avec `sum(r[1] for r in items_rows if r[1] is not None)` [app/api/v1/admin.py]

## Deferred from: code review of 1-3-pipeline-generation-fiches-claude (2026-04-28)

- `FlashCardCreate` expose `user_id` en champ client — risque sécurité si branché sur un endpoint API ; à corriger en Story 1.4 (injection server-side depuis la session auth)
- `FlashCardCreate`/`FlashCardRead` sans validation Pydantic sur `card_type` et `rang` — ajouter `Literal` ou `Enum` en Story 1.4 quand les endpoints sont exposés
- Durée de vie de `pdf_path` à travers la queue ARQ — aucune garantie que le fichier existe quand le job est dépilé ; à traiter via object storage ou URL signée dans une story dédiée
- `claude_api_key` a une valeur par défaut `""` dans config.py — le démarrage ne plante pas si la clé est absente ; ajouter un `@validator` ou champ sans default en Story 1.4
- Test manquant : vérifier que `rang` de la flashcard créée correspond au `rang` de l'item source (AC#1 end-to-end) dans `test_card_generator.py`
- Test manquant : vérifier que `cleanup_ocr_text` ne touche pas aux `flash_cards` (AC#4 NFR9) dans `test_cleanup_worker.py`
- Job GenerationJob chargé deux fois (worker + CardGenerator via `db.get`) — round-trip DB redondant, mineur

## Deferred from: code review de 1-2-pipeline-ocr-backend (2026-04-27)

- Mot de passe admin par défaut `"change-me"` sans validation au démarrage — design Phase 0, à enforcer via validator Pydantic en Story 2.3
- `_ITEM_PATTERN` matche les références inline (ex. "voir item 42") — limitation algorithmique du détecteur ECNi, nécessite analyse de vrais PDFs pour affiner le pattern
- PDF ouvert N+1 fois dans `OcrProcessor` (`count_pages` + une ouverture par page) — optimisation perf future, garder un contexte pdfplumber ouvert sur toute la boucle
- Cap score pdfplumber (max 0.95 × ratio) vs pytesseract (moyenne brute, peut atteindre 1.0) — incohérence de scoring à normaliser dans une future story de raffinement OCR
- `claude_api_key` défaut `""` — intentionnel Story 1.2 (la clé n'est pas utilisée ici), à valider au démarrage en Story 1.3 avant le premier appel Anthropic
- Monkey-patch `create_async_engine` dans `conftest.py` sensible à l'ordre d'import — infrastructure test fonctionnelle mais fragile, à remplacer par `override_settings` ou SQLite fixture propre
- Pas de scoping d'autorisation par opérateur sur les routes `/v1/admin/` — intentionnel Phase 0 (single-operator), à revisiter si plusieurs opérateurs en Story 1.4

## Deferred from: code review of 1-1-infrastructure-homelab-squelettes-projets (2026-04-27)

- Mots de passe par défaut faibles (`admin_password = "change-me"`, postgres `password`) — config dev intentionnelle, à forcer via validation au démarrage en Story 2.3
- `volumes: - .:/app` + `--reload` exposent le code source dans le conteneur — créer un `docker-compose.prod.yml` sans ces flags avant le déploiement homelab
- Ports Redis (6379) et PostgreSQL (5432) exposés sur l'hôte — retirer les `ports:` en production ou restreindre à `127.0.0.1:`
- `secret_key` sans validation d'entropie minimum — ajouter un validator Pydantic en Story 2.3 (auth JWT)
- Caddy `tls internal` + domaine `.local` — design homelab intentionnel ; remplacer par un vrai certificat Let's Encrypt avec un domaine public pour la prod
- Email personnel `lesur.matthis@gmail.com` dans Caddyfile — acceptable pour homelab ; utiliser une adresse organisationnelle si déploiement public
- `CollegeStatus` stocké comme `String(50)` sans contrainte DB — ajouter un `CHECK constraint` ou `ENUM PostgreSQL` lors de l'implémentation des endpoints (Story 3.x)
- `college_ref_id` sans `UniqueConstraint("user_id", "college_ref_id")` — ajouter en Story 3.x lors de l'import PDF
- `updated_at` sans trigger PostgreSQL — `onupdate` SQLAlchemy ne s'applique pas aux UPDATE directs ; ajouter un trigger `CREATE TRIGGER` dans la migration Story 1.2
- `BottomNavBar.build()` lève `UnimplementedError` — stub intentionnel, implémenté en Story 2.1
- `AppDatabase` non connecté à `GeneratedDatabase` Drift — intentionnel Story 1.1, tables Drift ajoutées en Story 2.1+
- `python-jose` avec CVEs connues — évaluer migration vers `PyJWT` ou `joserfc` en Story 2.3 avant d'implémenter les tokens JWT
- `passlib` incompatible avec `bcrypt >= 4.0` — ajouter `bcrypt = "<4.0"` dans pyproject.toml en Story 2.3 si erreur `AttributeError: module 'bcrypt' has no attribute '__about__'`
- ARQ `retry_jobs: True` sans `max_retries` — configurer `max_tries` par job dans WorkerSettings en Story 1.3
- `job_timeout: 7200s` — justifié par NFR2 ; à surveiller lors des premiers tests de génération Claude
- `claude_api_key` sans validation de format au démarrage — ajouter un validator en Story 1.3 avant le premier appel Anthropic
- `AppLogger` sans sink production (pas de crash reporting) — intégrer Firebase Crashlytics ou Sentry dans une story dédiée
- `settings = Settings()` instancié au niveau module — testability concern ; considérer `@lru_cache` + dependency injection en Story 2.x si les tests deviennent difficiles à isoler
- `ApiClient.dio` getter public expose le Dio partagé — retirer le getter ou le restreindre ; ajouter intercepteur auth en Story 2.3
- `/health` ne vérifie pas la connectivité DB/Redis — ajouter `GET /health/ready` avec checks dépendances en Story 1.2 ou 2.x
- `asyncio.run()` dans `alembic/env.py` échoue si appelé depuis un event loop existant — edge case ; documenté, non bloquant en pratique
- `app/models/__init__.py` doit importer tous les futurs modèles — règle à respecter : chaque nouveau fichier `models/xxx.py` doit être ajouté à `models/__init__.py`

## Deferred from: code review of story-7.6 (2026-06-17) — TOUS RÉSOLUS le 2026-06-17

_Décision PL : tout régler avant le commit 7.6. Aucun report restant._

- ✅ FIX — Normalisation email au login (`auth.py` : `.strip().lower()` avant lookup) → connexion insensible à la casse
- ✅ FIX — `create_user` : `id` généré explicitement, réponse construite depuis les invariants compte-neuf, `db.refresh` supprimé (plus de 500 si refresh échoue)
- ✅ FIX — Test create-user non-tautologique (`_fake_refresh_factory` supprimé, vérifie le vrai contrat)
- ✅ FIX — Test overview indépendant de l'ordre des `db.execute`
- ✅ VÉRIFIÉ CORRECT — `is_beta` bypasse le paywall (`deps.py:119`), quota mensuel uniforme : comportement voulu, aucun changement
- ✅ ACCEPTÉ (architectural) — Basic Auth creds en mémoire JS : inhérent au pattern ; vol via XSS désormais clos par le patch XSS ; session-token = redesign hors périmètre
- ✅ FIX — `monthly_reloads_max` ajouté à `UserBetaData` (4 sites) + affiché `x / max` dans la liste users

## Deferred from: code review of story-7.7 (2026-06-17)

- **Garantie « écriture défensive » de la timeline plus faible qu'annoncée** — `record_job_event` (`app/services/jobs/job_events.py:35`) enveloppe `db.add(...)` (opération mémoire qui n'échoue quasi jamais) et non le flush/commit appelant. Un INSERT d'event défaillant remonterait au `commit()` de l'appelant et annulerait la transaction de transition légitime, contredisant l'exigence AC1 « ne jamais casser le pipeline ». Risque pratique quasi nul (event_type hardcodés courts, message Text, FK valide), et `generation_worker` fait `rollback()` avant son commit. Le commit-sans-rollback de l'`except` d'`ocr_worker` (`app/workers/ocr_worker.py:63-70`) est un pattern PRÉ-EXISTANT explicitement conservé par la story 7.7. Durcissement possible si besoin : isoler l'écriture d'event dans un savepoint (`db.begin_nested()`).

## Deferred from: code review of story-7.8 (2026-06-18)

- **`generate_cards_for_item` — réponse Claude tronquée non signalée** (`app/services/generation/claude_client.py:118,127`) — `max_tokens=2000` sans vérification de `response.stop_reason`. Une réponse coupée (`stop_reason="max_tokens"`) produit un JSON invalide → `cards=[]` silencieux, mais les tokens **sont facturés** et comptés dans le coût. Aucun signal côté admin pour distinguer « Claude a renvoyé du garbage » d'une « génération tronquée ». Pré-existant (le `max_tokens` précède la story 7.8), hors périmètre 7.8. Durcissement possible : logger un warning distinct si `stop_reason == "max_tokens"`, ou exposer un compteur d'items tronqués sur le job.
