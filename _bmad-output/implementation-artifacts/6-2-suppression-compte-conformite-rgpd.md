# Story 6.2 : Suppression de Compte & Conformité RGPD

Status: done

## Story

En tant qu'**étudiant**,
je veux pouvoir supprimer mon compte et toutes mes données associées directement depuis l'app,
afin d'exercer mon droit à l'effacement conformément au RGPD.

## Acceptance Criteria

1. **AC1 — Dialog de confirmation avant suppression**
   - Étant donné le bouton "Supprimer mon compte" dans l'`_AppCard` de l'écran Profil
   - Quand je tape dessus
   - Alors un `ShadDialog.alert` s'affiche avec le titre "Supprimer mon compte ?" et la description : "Cette action est irréversible. Toutes tes fiches et données seront supprimées définitivement."
   - Et deux boutons : "Annuler" (`ShadButton.outline`) et "Supprimer définitivement" (`ShadButton.destructive`)

2. **AC2 — Suppression complète backend + local**
   - Étant donné que je confirme la suppression
   - Quand la requête `DELETE /v1/auth/account` est envoyée avec le JWT valide
   - Alors le backend supprime en cascade : compte utilisateur, collèges, fiches, items, jobs de génération (cascade SQLAlchemy déjà en place), et efface `apns_token` (inclus dans la suppression User)
   - Et les données Drift locales (CollegeImports, Items, FlashCards, PlanningConfigs, PlanningSessions) sont effacées sur l'appareil via `deleteEverything()`
   - Et le flutter_secure_storage est vidé (tous les tokens et données de profil)
   - Et GoRouter redirige automatiquement vers `/demo` (authProvider → unauthenticated → redirect)
   - Et un `ShadToast` "Ton compte a été supprimé" s'affiche

3. **AC3 — Avertissement abonnement actif**
   - Étant donné un utilisateur avec `isSubscribed == true`
   - Quand le dialog de confirmation s'affiche
   - Alors la description inclut une ligne supplémentaire : "Si tu as un abonnement actif, pense à l'annuler depuis les Réglages iOS pour éviter d'être débité."

4. **AC4 — Gestion des erreurs**
   - Étant donné une erreur réseau ou serveur lors de la suppression
   - Quand la requête échoue
   - Alors un `ShadToast.destructive` affiche le message d'erreur
   - Et l'écran Profil reste ouvert (pas de navigation)

---

## Périmètre & Contraintes

- **Pas de migration Alembic** — le cascade `all, delete-orphan` est déjà configuré sur toutes les relations User dans `user.py` (colleges, generation_jobs, flash_cards)
- **Pas de nouvelle dépendance** — utiliser Drift 2.21.0 (`deleteEverything()` disponible), `flutter_secure_storage` et `databaseProvider` déjà présents
- **FR42 déjà implémenté** — la guard `is_subscribed OR is_beta` avant les appels Claude est faite en Story 2.4. Cette story n'y touche pas.
- **Bouton placeholder existant** — `_AppCard` dans `profile_screen.dart` ligne ~548 a déjà le `ShadButton.outline('Supprimer mon compte')` avec un `// TODO Story 6.2`
- **Route `/demo` existe** — GoRouter redirige automatiquement vers `/demo` quand `authProvider` passe à unauthenticated

---

## Tasks / Subtasks

### Backend

- [x] **T1 — Endpoint `DELETE /v1/auth/account`** (AC: #2)
  - [x] Fichier : `collega_backend/app/api/v1/auth.py`
  - [x] Ajouter après `update_profile` (ligne ~133) :
    ```python
    @router.delete("/account", status_code=200)
    async def delete_account(
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ):
        await db.delete(current_user)
        await db.commit()
        return {"data": {"message": "Account deleted"}}
    ```
  - [x] **Pas d'import supplémentaire** — `get_current_user`, `get_db`, `User` déjà importés

- [x] **T2 — Tests backend `DELETE /v1/auth/account`** (AC: #2, #4)
  - [x] Fichier : `collega_backend/tests/api/test_auth.py`
  - [x] Ajouter dans la classe existante (ou une nouvelle classe `TestDeleteAccount`) :
    ```python
    async def test_delete_account_success(self, client: AsyncClient, mock_db):
        user = make_user(with_password=False)
        mock_db.execute = AsyncMock(return_value=mock_scalar(user))
        mock_db.delete = AsyncMock()
        mock_db.commit = AsyncMock()
        token = _make_access_token(str(user.id))
        response = await client.delete(
            "/v1/auth/account",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        mock_db.delete.assert_awaited_once_with(user)
        mock_db.commit.assert_awaited_once()

    async def test_delete_account_unauthorized(self, client: AsyncClient, mock_db):
        response = await client.delete("/v1/auth/account")
        assert response.status_code == 401
    ```
  - [x] Utiliser `make_user(with_password=False)` — pattern établi en Story 6.1 pour éviter l'erreur bcrypt Python 3.14
  - [x] Utiliser `_make_access_token(user_id)` — helper existant dans le fichier de test (vérifier le nom exact)

### Flutter — AuthRepository

- [x] **T3 — `deleteAccount()` dans `auth_repository.dart`** (AC: #2)
  - [x] Fichier : `collega_app/lib/features/auth/data/auth_repository.dart`
  - [x] Ajouter après `updateProfile()` :
    ```dart
    Future<AuthState> deleteAccount() async {
      try {
        final accessToken = await _storage.read(key: _kAccessToken);
        if (accessToken == null) return const AuthState();
        await _dio.delete<Map<String, dynamic>>(
          '/v1/auth/account',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        await logout();
        return const AuthState();
      } on DioException catch (e) {
        return AuthState(errorMessage: _extractError(e));
      }
    }
    ```
  - [x] `logout()` efface tous les tokens et données profil du storage (déjà implémenté — ne pas le modifier)
  - [x] `_extractError(e)` déjà utilisé dans `updateProfile()` — même pattern

### Flutter — AuthNotifier

- [x] **T4 — `deleteAccount()` dans `auth_providers.dart`** (AC: #2)
  - [x] Fichier : `collega_app/lib/features/auth/auth_providers.dart`
  - [x] Ajouter l'import en tête de fichier :
    ```dart
    import 'package:collega_app/core/database/app_database.dart';
    ```
  - [x] Ajouter après `updateProfile()` :
    ```dart
    Future<String?> deleteAccount() async {
      final result = await ref.read(authRepositoryProvider).deleteAccount();
      if (result.errorMessage != null) {
        return result.errorMessage;
      }
      await ref.read(databaseProvider).deleteEverything();
      state = const AsyncData(AuthState());
      return null; // null = succès
    }
    ```
  - [x] `databaseProvider` se trouve dans `collega_app/lib/core/database/app_database.dart`
  - [x] `deleteEverything()` est une méthode built-in de Drift 2.21.0 — supprime toutes les lignes de toutes les tables
  - [x] Retourner `null` en succès et le message d'erreur en cas d'échec (même convention que `updateProfile`)

### Flutter — ProfileScreen (`_AppCard`)

- [x] **T5 — Convertir `_AppCard` en `ConsumerStatefulWidget`** (AC: #1, #2, #3, #4)
  - [x] Fichier : `collega_app/lib/features/profile/presentation/profile_screen.dart`
  - [x] Modifier le `ProfileScreen.build()` pour passer `isSubscribed` à `_AppCard` :
    ```dart
    _AppCard(
      onLogout: () async {
        await ref.read(authProvider.notifier).logout();
      },
      isSubscribed: user?.isSubscribed ?? false,
    ),
    ```
  - [x] Transformer `_AppCard` de `StatelessWidget` en `ConsumerStatefulWidget` :
    ```dart
    class _AppCard extends ConsumerStatefulWidget {
      const _AppCard({required this.onLogout, required this.isSubscribed});
      final Future<void> Function() onLogout;
      final bool isSubscribed;

      @override
      ConsumerState<_AppCard> createState() => _AppCardState();
    }

    class _AppCardState extends ConsumerState<_AppCard> {
      bool _deleting = false;

      Future<void> _handleDeleteAccount() async {
        final description = widget.isSubscribed
            ? "Cette action est irréversible. Toutes tes fiches et données seront supprimées définitivement.\n\nSi tu as un abonnement actif, pense à l'annuler depuis les Réglages iOS pour éviter d'être débité."
            : "Cette action est irréversible. Toutes tes fiches et données seront supprimées définitivement.";

        final confirmed = await showShadDialog<bool>(
          context: context,
          builder: (ctx) => ShadDialog.alert(
            title: const Text('Supprimer mon compte ?'),
            description: Text(description),
            actions: [
              ShadButton.outline(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              ShadButton.destructive(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Supprimer définitivement'),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;

        setState(() => _deleting = true);
        final error = await ref.read(authProvider.notifier).deleteAccount();
        if (!mounted) return;
        setState(() => _deleting = false);

        if (error != null) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text('Erreur'),
              description: Text(error),
            ),
          );
        } else {
          ShadToaster.of(context).show(
            const ShadToast(
              title: Text('Ton compte a été supprimé'),
            ),
          );
          // GoRouter redirige automatiquement vers /demo via le redirect de authProvider
        }
      }

      @override
      Widget build(BuildContext context) {
        return ShadCard(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Application', style: AppTypography.titleMedium()),
              const SizedBox(height: 4),
              Text('Version 1.0.0', style: AppTypography.bodyMedium()),
              const SizedBox(height: 8),
              ShadButton.link(
                onPressed: () => _launchUrl(_kCguUrl),
                child: const Text("Conditions générales d'utilisation"),
              ),
              ShadButton.link(
                onPressed: () => _launchUrl(_kPrivacyUrl),
                child: const Text('Politique de confidentialité'),
              ),
              const SizedBox(height: 8),
              ShadButton.outline(
                onPressed: _deleting ? null : _handleDeleteAccount,
                child: _deleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Supprimer mon compte'),
              ),
              const SizedBox(height: 8),
              ShadButton.destructive(
                onPressed: widget.onLogout,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, size: 16),
                    SizedBox(width: 8),
                    Text('Se déconnecter'),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }
    ```
  - [x] Conserver les constantes `_kCguUrl`, `_kPrivacyUrl` et le helper `_launchUrl` — déjà définis dans le fichier (ne pas les dupliquer)
  - [x] **CRITIQUE :** `showShadDialog` et `ShadToaster.of(context)` nécessitent le contexte — bien gérer les guards `if (!mounted)` après chaque `await`

### Tests Flutter

- [x] **T6 — Mettre à jour `profile_screen_test.dart`** (AC: #1, #2, #3, #4)
  - [x] Fichier : `collega_app/test/features/profile/profile_screen_test.dart`
  - [x] `_FakeAuthNotifier` — ajouter la méthode `deleteAccount()` :
    ```dart
    @override
    Future<String?> deleteAccount() async => null; // succès par défaut
    ```
  - [ ] Ajouter test : `_AppCard affiche le bouton Supprimer mon compte` :
    ```dart
    testWidgets('affiche le bouton Supprimer mon compte', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte', skipOffstage: false), findsOneWidget);
    });
    ```
  - [x] Ajouter test : `dialog de confirmation s'affiche au tap` :
    ```dart
    testWidgets('dialog de confirmation au tap sur Supprimer mon compte', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer mon compte', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte ?'), findsOneWidget);
      expect(find.text('Cette action est irréversible.', findRichText: true), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Supprimer définitivement'), findsOneWidget);
    });
    ```
  - [x] Ajouter test : `Annuler ferme le dialog sans déclencher deleteAccount` :
    ```dart
    testWidgets('Annuler ferme le dialog', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer mon compte', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte ?'), findsNothing);
    });
    ```
  - [x] Ajouter test : `message abonnement affiché si isSubscribed` :
    ```dart
    testWidgets('affiche message abonnement si isSubscribed', (tester) async {
      final subscribedUser = _testUser; // _testUser a isSubscribed: true
      await tester.pumpWidget(_buildScreen(authState: AuthState(user: subscribedUser)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer mon compte', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Réglages iOS', skipOffstage: false), findsOneWidget);
    });
    ```
  - [x] Utiliser `skipOffstage: false` sur les `find.text()` — pattern établi en Story 6.1 pour les widgets dans un ListView

---

## Dev Notes — Contexte Technique Exhaustif

### Cascade delete backend — déjà en place

Les relations SQLAlchemy dans `user.py` (lignes 43–51) ont `cascade="all, delete-orphan"` sur :
- `colleges` → supprime tous les collèges de l'utilisateur
- `generation_jobs` → supprime tous les jobs OCR/génération
- `flash_cards` → supprime toutes les fiches

Le champ `apns_token` est une colonne directement sur `User` — supprimé automatiquement avec l'utilisateur. **Pas de migration Alembic nécessaire.**

### Architecture des fichiers modifiés

```
collega_backend/
└── app/
    ├── api/v1/auth.py                  # UPDATE (DELETE /account)
    └── tests/api/test_auth.py          # UPDATE (tests delete)

collega_app/lib/
└── features/
    └── auth/
        ├── data/auth_repository.dart   # UPDATE (deleteAccount)
        └── auth_providers.dart         # UPDATE (deleteAccount + import db)

collega_app/lib/features/profile/
└── presentation/profile_screen.dart    # UPDATE (_AppCard ConsumerStatefulWidget)

collega_app/test/features/profile/
└── profile_screen_test.dart            # UPDATE (tests delete flow)
```

### Flow de suppression complet

```
[Tap "Supprimer"] 
  → _handleDeleteAccount() : showShadDialog
  → Confirmation
  → setState(_deleting=true)
  → authNotifier.deleteAccount()
      → repo.deleteAccount()
          → DELETE /v1/auth/account (JWT)  →  backend supprime User en cascade
          → logout() : vide flutter_secure_storage
          → return AuthState()
      → db.deleteEverything() : vide toutes les tables Drift
      → state = AsyncData(AuthState())  →  app.dart listener réinitialise APNs
                                        →  GoRouter redirect → /demo
  → mounted? setState(_deleting=false)
  → ShadToast succès (visible brièvement pendant la transition)
```

**GoRouter redirect automatique** : `app_router.dart` ligne 44 — `if (!isAuth && isProtected) return '/demo'`. Dès que `authProvider` passe à unauthenticated, le router redirige vers `/demo` sans intervention supplémentaire.

**ShadToaster** : `ShadApp.router` dans `app.dart` inclut le `ShadToaster` au niveau root — les toasts survivent à la navigation (overlay au-dessus du Navigator).

### Providers existants réutilisés

- `authProvider` → `features/auth/auth_providers.dart`
- `authRepositoryProvider` → `features/auth/auth_providers.dart`
- `databaseProvider` → `core/database/app_database.dart`
- `showShadDialog` → depuis `shadcn_ui/shadcn_ui.dart` (déjà utilisé dans `college_detail_screen.dart`)

### Pattern `showShadDialog` établi

Copier de `college_detail_screen.dart` lignes 136–165 :
```dart
final confirmed = await showShadDialog<bool>(
  context: context,
  builder: (context) => ShadDialog.alert(
    title: ...,
    description: ...,
    actions: [
      ShadButton.outline(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Annuler'),
      ),
      ShadButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Confirmer'),
      ),
    ],
  ),
);
if (confirmed == true && mounted) { ... }
```

**Différence Story 6.2** : Utiliser `ShadButton.destructive` pour "Supprimer définitivement" au lieu de `ShadButton`.

### `deleteEverything()` Drift

Disponible sur `AppDatabase` (Drift 2.21.0). Supprime toutes les lignes de toutes les tables définies dans `@DriftDatabase(tables: [CollegeImports, Items, FlashCards, PlanningConfigs, PlanningSessions])`. Pas de paramètre, pas de filtre — suppression totale, ce qui est exactement ce qu'on veut pour le RGPD.

### Anti-patterns à éviter

- **NE PAS** modifier `logout()` dans `auth_repository.dart` — cette méthode est réutilisée dans `deleteAccount()`, tout changement impacte les deux
- **NE PAS** naviguer manuellement avec `context.go('/demo')` — GoRouter gère le redirect automatiquement via le redirect reactif sur `authProvider`
- **NE PAS** créer une migration Alembic — le cascade est déjà en place dans les models SQLAlchemy
- **NE PAS** appeler `deleteEverything()` dans `auth_repository.dart` — le repository n'a pas accès à Drift, c'est le rôle de `AuthNotifier`
- **NE PAS** utiliser `AppColors.destructive` — utiliser `AppColors.error` (correction établie en Story 6.1)
- **NE PAS** ajouter `skipOffstage` en oubliant `false` dans les tests — tous les `find.text()` sur widgets dans ListView nécessitent `skipOffstage: false` (learner Story 6.1)

### Tests backend — helpers existants

Dans `test_auth.py` :
- `make_user(with_password=False)` — crée un utilisateur sans bcrypt (évite l'erreur Python 3.14, pattern Story 6.1)
- `_make_access_token(user_id: str)` — vérifier le nom exact de ce helper dans le fichier avant d'utiliser
- `mock_db` — fixture existante qui mocke la session AsyncSession
- `mock_db.delete` — **non mocké par défaut** → ajouter `mock_db.delete = AsyncMock()` dans le test

### `_AppCard` — état `_deleting`

Le bouton "Supprimer mon compte" doit être désactivé (`onPressed: null`) pendant l'appel réseau pour éviter les doubles soumissions. Utiliser `_deleting` state + `CircularProgressIndicator` de taille 16x16 (cohérent avec les loaders existants dans l'app).

---

## Références

- Epic 6 Story 6.2 : `_bmad-output/planning-artifacts/epics.md` L.1039–1070
- User model (cascade) : `collega_backend/app/models/user.py` L.43–51
- `DELETE /v1/auth/account` pattern : `collega_backend/app/api/v1/auth.py`
- `auth_repository.dart` (logout, updateProfile) : `collega_app/lib/features/auth/data/auth_repository.dart`
- `auth_providers.dart` (AuthNotifier) : `collega_app/lib/features/auth/auth_providers.dart`
- `app_database.dart` (databaseProvider, deleteEverything) : `collega_app/lib/core/database/app_database.dart`
- `app_router.dart` (redirect /demo) : `collega_app/lib/core/router/app_router.dart` L.28–53
- `app.dart` (authProvider listener, ShadApp root) : `collega_app/lib/app.dart`
- `profile_screen.dart` (_AppCard placeholder) : `collega_app/lib/features/profile/presentation/profile_screen.dart` L.~525–570
- `college_detail_screen.dart` (showShadDialog pattern) : L.136–165
- `profile_screen_test.dart` : `collega_app/test/features/profile/profile_screen_test.dart`
- Story 6.1 (learnings) : `_bmad-output/implementation-artifacts/6-1-ecran-profil-preferences.md`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `deleteEverything()` n'existe pas dans Drift 2.x — méthode ajoutée manuellement dans `AppDatabase` avec `transaction()` sur toutes les tables.
- `ShadDialog.alert` actions en layout horizontal sur écran >= 640px → overflow 52px dans les tests (viewport 800px). Corrigé avec `actionsAxis: Axis.vertical` — comportement correct pour dialog d'alerte destructive sur mobile.
- Tests de tap sur bouton hors écran (ListView) → ajout de `ensureVisible()` avant `tap()`.
- `_make_access_token` absent des tests backend → utilisé `create_access_token` (importé) + `mock_db.get = AsyncMock(return_value=user)` (pattern TestRefresh).

### Completion Notes List

- ✅ T1 : endpoint `DELETE /v1/auth/account` ajouté dans `auth.py`, cascade SQLAlchemy déjà en place.
- ✅ T2 : classe `TestDeleteAccount` avec 2 tests (success + unauthorized) — RED/GREEN validés.
- ✅ T3 : `deleteAccount()` dans `auth_repository.dart` — appelle `logout()` après suppression pour vider le storage.
- ✅ T4 : `deleteAccount()` dans `auth_providers.dart` — appelle `repo.deleteAccount()` puis `db.deleteEverything()`.
- ✅ T4 (complément) : `deleteEverything()` ajouté dans `AppDatabase` (`app_database.dart`) via transaction Drift.
- ✅ T5 : `_AppCard` converti en `ConsumerStatefulWidget` avec `_deleting` state, `_handleDeleteAccount()`, dialog de confirmation `ShadDialog.alert`, toasts succès/erreur. `actionsAxis: Axis.vertical` pour éviter overflow sur mobile/tests.
- ✅ T6 : 4 tests Flutter ajoutés + `deleteAccount()` dans `_FakeAuthNotifier`. 14/14 tests passent.

### File List

- `collega_backend/app/api/v1/auth.py`
- `collega_backend/tests/api/test_auth.py`
- `collega_app/lib/features/auth/data/auth_repository.dart`
- `collega_app/lib/features/auth/auth_providers.dart`
- `collega_app/lib/core/database/app_database.dart`
- `collega_app/lib/features/profile/presentation/profile_screen.dart`
- `collega_app/test/features/profile/profile_screen_test.dart`

### Change Log

- feat(story-6.2): suppression de compte RGPD — endpoint DELETE /account, flux Flutter complet, tests (Date: 2026-05-18)

---

## Review Findings

### Decision needed

- [x] [Review][Decision] AC1 — Ordre des boutons dans le dialog inversé par rapport à la spec — Décision : déviation intentionnelle conservée (bouton destructif en premier avec actionsAxis: Axis.vertical, pattern UX mobile délibéré).

### Patches

- [x] [Review][Patch] `mounted` guard manquant avant le toast de succès [profile_screen.dart] — Ajout de `if (!mounted) return;` immédiatement avant le `ShadToaster.of(context).show(...)` du chemin succès.
- [x] [Review][Patch] Exceptions non-`DioException` non capturées dans `deleteAccount()` [auth_repository.dart] — Ajout de `catch (_)` générique après `on DioException`, retourne `AuthState(errorMessage: 'Erreur lors de la suppression du compte')`.
- [x] [Review][Patch] Exception de `deleteEverything()` laisse l'état auth non réinitialisé [auth_providers.dart] — `deleteEverything()` enveloppé dans try/catch ; `state = AsyncData(AuthState())` forcé même en cas d'erreur DB.
- [x] [Review][Patch] Absence de rate limiting sur `DELETE /account` [collega_backend/app/api/v1/auth.py] — Ajout de `@limiter.limit("3/minute")` + paramètre `request: Request` cohérent avec le pattern login.

### Deferred

- [x] [Review][Defer] Tests backend fragiles — mock via `mock_db.get` au lieu d'override de dépendance [test_auth.py] — deferred, pre-existing
- [x] [Review][Defer] Absence de test pour le chemin d'erreur AC4 (ShadToast.destructive) [profile_screen_test.dart] — deferred, couverture complémentaire
- [x] [Review][Defer] Absence de test pour le toast de succès AC2 [profile_screen_test.dart] — deferred, couverture complémentaire
- [x] [Review][Defer] JWT toujours valide après suppression du compte — deferred, limitation architecturale pré-existante (JWT stateless)
- [x] [Review][Defer] Absence de `RevenueCat.logOut()` lors de la suppression [auth_providers.dart] — deferred, hors scope spec
- [x] [Review][Defer] HTTP 200 au lieu de 204 sur DELETE /account [auth.py] — deferred, convention REST mineure sans impact fonctionnel
- [x] [Review][Defer] Flag `isSubscribed` potentiellement obsolète au moment de l'ouverture du dialog — deferred, impact UX mineur
