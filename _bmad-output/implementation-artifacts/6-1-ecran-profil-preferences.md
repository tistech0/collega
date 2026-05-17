# Story 6.1 : Écran Profil & Préférences

Status: done

## Story

En tant qu'**étudiant**,
je veux gérer mon identité, consulter mon quota d'import et mon abonnement, et configurer mes préférences de révision depuis un écran centralisé,
afin d'avoir une vue complète de mon compte et de personnaliser l'expérience selon mon usage.

## Acceptance Criteria

1. **AC1 — IdentityCard lecture/édition inline**
   - Étant donné l'onglet Profil du bottom nav, quand je l'ouvre
   - Alors l'écran affiche dans l'ordre : IdentityCard, SubscriptionCard, RevisionPrefsCard, NotifCard, AppCard
   - Étant donné l'IdentityCard, quand elle s'affiche
   - Alors prénom (obligatoire), année et faculté (facultatifs) sont visibles en mode lecture
   - Et un tap sur la carte ouvre les champs en mode édition inline (pas de navigation vers un écran séparé)
   - Et un bouton "Sauvegarder" appelle PATCH /v1/auth/profile et met à jour l'état local

2. **AC2 — SubscriptionCard avec quota et deep link**
   - Étant donné la SubscriptionCard, quand l'abonnement est actif
   - Alors le badge "Actif" (discret) s'affiche avec la date de prochain renouvellement formatée "JJ/MM/AAAA"
   - Et la barre de quota d'import indique "X/3 reimports utilisés ce mois" (LinearProgressIndicator)
   - Et si willRenew == false, un bandeau error-container s'affiche : "Résiliation en cours — accès jusqu'au JJ/MM/AAAA"
   - Et le bouton "Gérer mon abonnement" appelle RevenueCatService.openSubscriptionManagement()

3. **AC3 — RevisionPrefsCard synchronisée**
   - Étant donné la RevisionPrefsCard, quand je la consulte
   - Alors des chips A / B / C toggleables définissent les rangs inclus par défaut dans les sessions
   - Et un stepper "Fiches max par session" est disponible (0 = toutes)
   - Et ces préférences sont persistées (flutter_secure_storage) et rechargées au démarrage
   - Et elles sont synchronisées avec les valeurs par défaut du bottom sheet de personnalisation de session

4. **AC4 — Section App avec CGU et politique de confidentialité (FR40)**
   - Étant donné la section App, quand je tape sur "CGU" ou "Politique de confidentialité"
   - Alors le document correspondant s'affiche dans l'app sans quitter l'app (LaunchMode.inAppBrowserView)

5. **AC5 — NotifCard inchangée**
   - La NotifCard (rappel quotidien) implémentée en Story 4.5 reste intacte et fonctionnelle

---

## Périmètre & Contraintes

- **Backend :** ajouter first_name/year_group/faculty à User, étendre /me, ajouter PATCH /v1/auth/profile
- **Flutter :** étendre AuthUser, réécrire profile_screen.dart, créer revision_prefs_* files
- **Pas de suppression de compte** — c'est Story 6.2 (juste ajouter le bouton placeholder dans l'AppCard)
- **Pas de nouvelle dépendance** — utiliser flutter_secure_storage (déjà présent) pour RevisionPrefs
- **intl non disponible** — utiliser un helper de formatage de date maison
- **url_launcher déjà dans pubspec** — ne pas ré-ajouter

---

## Tasks / Subtasks

### Backend

- [x] **T1 — Migration Alembic 011 : colonnes profil** (AC: #1)
  - [x] Créer `collega_backend/alembic/versions/011_add_profile_fields_to_users.py`
  - [x] Ajouter les 3 colonnes nullable sur la table `users` :
    ```python
    op.add_column('users', sa.Column('first_name', sa.String(100), nullable=True))
    op.add_column('users', sa.Column('year_group', sa.String(50), nullable=True))
    op.add_column('users', sa.Column('faculty', sa.String(150), nullable=True))
    ```
  - [x] Ajouter la fonction `downgrade()` correspondante (`op.drop_column(...)`)

- [x] **T2 — Modèle User : nouveaux champs** (AC: #1)
  - [x] Fichier : `collega_backend/app/models/user.py`
  - [x] Ajouter après `is_subscribed` :
    ```python
    first_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    year_group: Mapped[str | None] = mapped_column(String(50), nullable=True)
    faculty: Mapped[str | None] = mapped_column(String(150), nullable=True)
    ```

- [x] **T3 — Schémas Pydantic** (AC: #1, #2)
  - [x] Fichier : `collega_backend/app/schemas/auth.py`
  - [x] Ajouter `ProfileUpdateRequest` :
    ```python
    class ProfileUpdateRequest(BaseModel):
        first_name: str | None = None
        year_group: str | None = None
        faculty: str | None = None
    ```
  - [x] Ajouter `MeResponse` :
    ```python
    class MeResponse(BaseModel):
        id: str
        email: str
        is_beta: bool
        is_subscribed: bool
        first_name: str | None
        year_group: str | None
        faculty: str | None
        monthly_reloads: int
        monthly_reloads_max: int
    ```

- [x] **T4 — Endpoints auth.py** (AC: #1, #2)
  - [x] Fichier : `collega_backend/app/api/v1/auth.py`
  - [x] Modifier `GET /me` pour retourner les nouveaux champs + monthly_reloads + monthly_reloads_max :
    ```python
    @router.get("/me")
    async def get_me(current_user: User = Depends(get_current_user)):
        return {
            "data": {
                "id": str(current_user.id),
                "email": current_user.email,
                "is_beta": current_user.is_beta,
                "is_subscribed": current_user.is_subscribed,
                "first_name": current_user.first_name,
                "year_group": current_user.year_group,
                "faculty": current_user.faculty,
                "monthly_reloads": current_user.monthly_reloads,
                "monthly_reloads_max": settings.monthly_reloads_max,
            }
        }
    ```
  - [x] Ajouter `PATCH /profile` endpoint (après `GET /me`) :
    ```python
    @router.patch("/profile")
    async def update_profile(
        body: ProfileUpdateRequest,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ):
        if body.first_name is not None:
            current_user.first_name = body.first_name.strip() or None
        if body.year_group is not None:
            current_user.year_group = body.year_group.strip() or None
        if body.faculty is not None:
            current_user.faculty = body.faculty.strip() or None
        await db.commit()
        return {"data": {"first_name": current_user.first_name, "year_group": current_user.year_group, "faculty": current_user.faculty}}
    ```
  - [x] Importer `ProfileUpdateRequest` et `settings` si pas déjà présents :
    ```python
    from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse, ProfileUpdateRequest
    from app.core.config import settings
    ```

### Flutter — Auth (extension du modèle)

- [x] **T5 — `AuthUser` : nouveaux champs** (AC: #1, #2)
  - [x] Fichier : `collega_app/lib/features/auth/domain/auth_state.dart`
  - [x] Étendre `AuthUser` :
    ```dart
    @immutable
    class AuthUser {
      const AuthUser({
        required this.id,
        required this.email,
        required this.isBeta,
        required this.isSubscribed,
        this.firstName,
        this.yearGroup,
        this.faculty,
        this.monthlyReloads = 0,
        this.monthlyMax = 3,
      });

      final String id;
      final String email;
      final bool isBeta;
      final bool isSubscribed;
      final String? firstName;
      final String? yearGroup;
      final String? faculty;
      final int monthlyReloads;
      final int monthlyMax;

      AuthUser copyWith({
        String? id,
        String? email,
        bool? isBeta,
        bool? isSubscribed,
        Object? firstName = _absent,
        Object? yearGroup = _absent,
        Object? faculty = _absent,
        int? monthlyReloads,
        int? monthlyMax,
      }) {
        return AuthUser(
          id: id ?? this.id,
          email: email ?? this.email,
          isBeta: isBeta ?? this.isBeta,
          isSubscribed: isSubscribed ?? this.isSubscribed,
          firstName: identical(firstName, _absent) ? this.firstName : firstName as String?,
          yearGroup: identical(yearGroup, _absent) ? this.yearGroup : yearGroup as String?,
          faculty: identical(faculty, _absent) ? this.faculty : faculty as String?,
          monthlyReloads: monthlyReloads ?? this.monthlyReloads,
          monthlyMax: monthlyMax ?? this.monthlyMax,
        );
      }

      static const _absent = Object();
    }
    ```
  - [x] **CRITIQUE :** Mettre à jour `profile_screen_test.dart` — `const _testUser = AuthUser(...)` — les nouveaux champs ont des valeurs par défaut donc le constructeur reste valide, mais vérifier que les tests compilent.

- [x] **T6 — `AuthRepository` : storage keys + updateProfile()** (AC: #1)
  - [x] Fichier : `collega_app/lib/features/auth/data/auth_repository.dart`
  - [x] Ajouter les nouvelles clés de stockage :
    ```dart
    const _kFirstName = 'first_name';
    const _kYearGroup = 'year_group';
    const _kFaculty = 'faculty';
    const _kMonthlyReloads = 'monthly_reloads';
    const _kMonthlyMax = 'monthly_max';
    ```
  - [x] Mettre à jour `loadStoredUser()` pour lire les nouveaux champs :
    ```dart
    final firstName = await _storage.read(key: _kFirstName);
    final yearGroup = await _storage.read(key: _kYearGroup);
    final faculty = await _storage.read(key: _kFaculty);
    final monthlyReloadsStr = await _storage.read(key: _kMonthlyReloads);
    final monthlyMaxStr = await _storage.read(key: _kMonthlyMax);
    // Dans AuthUser(...) ajouter :
    // firstName: firstName,
    // yearGroup: yearGroup,
    // faculty: faculty,
    // monthlyReloads: int.tryParse(monthlyReloadsStr ?? '0') ?? 0,
    // monthlyMax: int.tryParse(monthlyMaxStr ?? '3') ?? 3,
    ```
  - [x] Mettre à jour `logout()` pour effacer les nouveaux champs :
    ```dart
    _storage.delete(key: _kFirstName),
    _storage.delete(key: _kYearGroup),
    _storage.delete(key: _kFaculty),
    _storage.delete(key: _kMonthlyReloads),
    _storage.delete(key: _kMonthlyMax),
    ```
  - [x] Mettre à jour `refreshFromMe()` pour parser et persister les nouveaux champs du /me étendu
  - [x] Mettre à jour `_handleTokenResponse()` — l'appel à /me retourne maintenant plus de champs, les parser et persister
  - [x] Ajouter `updateProfile()` :
    ```dart
    Future<AuthState> updateProfile({
      String? firstName,
      String? yearGroup,
      String? faculty,
    }) async {
      try {
        final accessToken = await _storage.read(key: _kAccessToken);
        if (accessToken == null) return const AuthState();
        await _dio.patch<Map<String, dynamic>>(
          '/v1/auth/profile',
          data: {
            if (firstName != null) 'first_name': firstName,
            if (yearGroup != null) 'year_group': yearGroup,
            if (faculty != null) 'faculty': faculty,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        // Persist localement
        if (firstName != null) {
          await _storage.write(key: _kFirstName, value: firstName.isEmpty ? null : firstName);
        }
        if (yearGroup != null) {
          await _storage.write(key: _kYearGroup, value: yearGroup.isEmpty ? null : yearGroup);
        }
        if (faculty != null) {
          await _storage.write(key: _kFaculty, value: faculty.isEmpty ? null : faculty);
        }
        // Recharger l'état complet
        return loadStoredUser();
      } on DioException catch (e) {
        return AuthState(errorMessage: _extractError(e));
      }
    }
    ```

- [x] **T7 — `AuthNotifier` : méthode updateProfile()** (AC: #1)
  - [x] Fichier : `collega_app/lib/features/auth/auth_providers.dart`
  - [x] Ajouter après `refreshSubscription()` :
    ```dart
    Future<void> updateProfile({
      String? firstName,
      String? yearGroup,
      String? faculty,
    }) async {
      final result = await ref.read(authRepositoryProvider).updateProfile(
        firstName: firstName,
        yearGroup: yearGroup,
        faculty: faculty,
      );
      if (result.user != null) {
        state = AsyncData(result);
      } else if (result.errorMessage != null) {
        AppLogger.warning('updateProfile error: ${result.errorMessage}', tag: 'AuthNotifier');
      }
    }
    ```

- [x] **T8 — `RevenueCatService` : getSubscriptionInfo()** (AC: #2)
  - [x] Fichier : `collega_app/lib/features/auth/data/revenuecat_service.dart`
  - [x] Ajouter une classe `RevenueCatSubscriptionInfo` (en haut du fichier, avant `RevenueCatService`) :
    ```dart
    class RevenueCatSubscriptionInfo {
      const RevenueCatSubscriptionInfo({
        required this.expirationDate,
        required this.willRenew,
      });
      final DateTime? expirationDate;
      final bool willRenew;
    }
    ```
  - [x] Ajouter la méthode dans `RevenueCatService` :
    ```dart
    Future<RevenueCatSubscriptionInfo?> getSubscriptionInfo() async {
      try {
        final info = await Purchases.getCustomerInfo();
        final active = info.entitlements.active;
        if (active.isEmpty) return null;
        final entitlement = active.values.first;
        return RevenueCatSubscriptionInfo(
          expirationDate: entitlement.expirationDate,
          willRenew: entitlement.willRenew,
        );
      } catch (_) {
        return null;
      }
    }
    ```
  - [x] Ne pas importer de nouvelle dépendance — `purchases_flutter` déjà importé

### Flutter — Profile Feature (nouveaux fichiers)

- [x] **T9 — `RevisionPrefs` domain model** (AC: #3)
  - [x] Créer `collega_app/lib/features/profile/domain/revision_prefs.dart` :
    ```dart
    import 'package:flutter/foundation.dart';

    @immutable
    class RevisionPrefs {
      const RevisionPrefs({
        this.defaultRangs,
        this.defaultMaxCards = 0,
      });

      final List<String>? defaultRangs;  // null = tous les rangs
      final int defaultMaxCards;         // 0 = toutes les fiches

      RevisionPrefs copyWith({
        Object? defaultRangs = _absent,
        int? defaultMaxCards,
      }) {
        return RevisionPrefs(
          defaultRangs: identical(defaultRangs, _absent)
              ? this.defaultRangs
              : defaultRangs as List<String>?,
          defaultMaxCards: defaultMaxCards ?? this.defaultMaxCards,
        );
      }

      static const _absent = Object();
      static const RevisionPrefs defaults = RevisionPrefs();
    }
    ```

- [x] **T10 — `RevisionPrefsRepository` : persistence flutter_secure_storage** (AC: #3)
  - [x] Créer `collega_app/lib/features/profile/data/revision_prefs_repository.dart` :
    ```dart
    import 'package:flutter_secure_storage/flutter_secure_storage.dart';
    import 'package:collega_app/features/profile/domain/revision_prefs.dart';

    const _kRevisionRangs = 'revision_prefs_rangs';
    const _kRevisionMaxCards = 'revision_prefs_max_cards';

    class RevisionPrefsRepository {
      RevisionPrefsRepository({required FlutterSecureStorage storage})
          : _storage = storage;

      final FlutterSecureStorage _storage;

      Future<RevisionPrefs> load() async {
        final rangsStr = await _storage.read(key: _kRevisionRangs);
        final maxCardsStr = await _storage.read(key: _kRevisionMaxCards);
        final rangs = rangsStr != null && rangsStr.isNotEmpty
            ? rangsStr.split(',').where((r) => r.isNotEmpty).toList()
            : null;
        final maxCards = int.tryParse(maxCardsStr ?? '0') ?? 0;
        return RevisionPrefs(defaultRangs: rangs, defaultMaxCards: maxCards);
      }

      Future<void> save(RevisionPrefs prefs) async {
        final rangsStr = prefs.defaultRangs?.join(',') ?? '';
        await Future.wait([
          _storage.write(key: _kRevisionRangs, value: rangsStr),
          _storage.write(key: _kRevisionMaxCards, value: prefs.defaultMaxCards.toString()),
        ]);
      }
    }
    ```

- [x] **T11 — `RevisionPrefsNotifier` et provider** (AC: #3)
  - [x] Créer `collega_app/lib/features/profile/profile_providers.dart` :
    ```dart
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:collega_app/core/network/api_providers.dart';
    import 'package:collega_app/features/profile/data/revision_prefs_repository.dart';
    import 'package:collega_app/features/profile/domain/revision_prefs.dart';

    final revisionPrefsRepositoryProvider = Provider<RevisionPrefsRepository>(
      (ref) => RevisionPrefsRepository(storage: ref.read(secureStorageProvider)),
    );

    class RevisionPrefsNotifier extends AsyncNotifier<RevisionPrefs> {
      @override
      Future<RevisionPrefs> build() async {
        return ref.read(revisionPrefsRepositoryProvider).load();
      }

      Future<void> update(RevisionPrefs prefs) async {
        await ref.read(revisionPrefsRepositoryProvider).save(prefs);
        state = AsyncData(prefs);
      }
    }

    final revisionPrefsProvider =
        AsyncNotifierProvider<RevisionPrefsNotifier, RevisionPrefs>(
      RevisionPrefsNotifier.new,
    );
    ```
  - [x] `secureStorageProvider` se trouve dans `collega_app/lib/core/network/api_providers.dart` — vérifier le nom exact avant d'importer

- [x] **T12 — `HomeNotifier` : lire les revision prefs comme défaut** (AC: #3)
  - [x] Fichier : `collega_app/lib/features/home/home_providers.dart`
  - [x] Ajouter l'import : `import 'package:collega_app/features/profile/profile_providers.dart';`
  - [x] Dans `HomeNotifier.build()`, remplacer l'appel `applyDefault` actuel :
    ```dart
    // AVANT (ligne ~87-92) :
    ref.read(homeSessionConfigProvider.notifier).applyDefault(
      HomeSessionConfig(
        collegeId: defaultCollegeId,
        collegeName: defaultCollege.catalog.name,
      ),
    );

    // APRÈS :
    final revisionPrefs = await ref.watch(revisionPrefsProvider.future);
    ref.read(homeSessionConfigProvider.notifier).applyDefault(
      HomeSessionConfig(
        collegeId: defaultCollegeId,
        collegeName: defaultCollege.catalog.name,
        rangs: revisionPrefs.defaultRangs,
        maxCards: revisionPrefs.defaultMaxCards,
      ),
    );
    ```
  - [x] **IMPORTANT :** `revisionPrefsProvider.future` est `async` — utiliser `await ref.watch(...)` dans le `build()` qui est déjà `async`, ce qui est correct

### Flutter — ProfileScreen (réécriture)

- [x] **T13 — Réécrire `profile_screen.dart`** (AC: #1, #2, #3, #4, #5)
  - [x] Fichier : `collega_app/lib/features/profile/presentation/profile_screen.dart`
  - [x] Imports nécessaires :
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:shadcn_ui/shadcn_ui.dart';
    import 'package:url_launcher/url_launcher.dart';

    import 'package:collega_app/core/notifications/notifications_service.dart';
    import 'package:collega_app/core/theme/app_theme.dart';
    import 'package:collega_app/core/utils/logger.dart';
    import 'package:collega_app/features/auth/auth_providers.dart';
    import 'package:collega_app/features/auth/domain/auth_state.dart';
    import 'package:collega_app/features/auth/data/revenuecat_service.dart';
    import 'package:collega_app/features/auth/paywall_providers.dart';
    import 'package:collega_app/features/profile/domain/revision_prefs.dart';
    import 'package:collega_app/features/profile/profile_providers.dart';
    ```

  - [x] `ProfileScreen` (top-level) — reste `ConsumerWidget`, construit le `ListView` avec l'ordre :
    1. `_IdentityCard(user: user)`
    2. `_SubscriptionCard(user: user)`
    3. `const _RevisionPrefsCard()`
    4. `const _NotifCard()`
    5. `const _AppCard()`
    - Si `user == null` → `SizedBox.shrink()`

  - [x] `_IdentityCard` — `ConsumerStatefulWidget` (état local pour edit mode) :
    - Champs : `_editing = false`, `TextEditingController` x3 (prénom, année, faculté), `_saving = false`
    - `initState` : initialise les controllers avec `user.firstName ?? ''`, `user.yearGroup ?? ''`, `user.faculty ?? ''`
    - Mode lecture : affiche `Text(firstName)` ou `Text('—')` si null, `Text(yearGroup)`, `Text(faculty)` + bouton "Modifier" (ShadButton.outline sm)
    - Mode édition : 3 `TextFormField` (prénom required, année/faculté optional) + `ShadButton` "Sauvegarder" + `ShadButton.outline` "Annuler"
    - Sauvegarder : appelle `ref.read(authProvider.notifier).updateProfile(...)`, gère `_saving = true/false`
    - En cas d'erreur : `ShadToaster.of(context).show(ShadToast.destructive(...))`
    - Ne pas utiliser `Navigator.pop` — juste toggler `_editing = false`

  - [x] `_SubscriptionCard` — `ConsumerStatefulWidget` (charge subscription info depuis RC) :
    - `initState` → appel asynchrone à `revenueCatServiceProvider.getSubscriptionInfo()`, stocker dans `_subInfo`
    - Structure :
      - Row : `Text('Abonnement')` + `ShadBadge('Actif')` ou `ShadBadge.secondary('Inactif')`
      - Si `user.isSubscribed && _subInfo?.willRenew == false` → bandeau Container avec `AppColors.destructive.withValues(alpha: 0.1)` + texte "Résiliation en cours..."
      - `LinearProgressIndicator` : `value: user.monthlyReloads / user.monthlyMax.clamp(1, 999)`, label "X/Y reimports utilisés ce mois"
      - Si `user.isSubscribed && _subInfo?.expirationDate != null` → `Text('Renouvellement le ${_formatDate(_subInfo!.expirationDate!)}')`
      - Bouton "Gérer mon abonnement" : `ref.read(revenueCatServiceProvider).openSubscriptionManagement()`
    - Helper `_formatDate(DateTime dt)` :
      ```dart
      String _formatDate(DateTime dt) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
      ```

  - [x] `_RevisionPrefsCard` — `ConsumerWidget` (lit `revisionPrefsProvider`) :
    - `ref.watch(revisionPrefsProvider)` → `.when(loading: ..., error: ..., data: (prefs) => ...)`
    - Même pattern `FilterChip` que `_RangChips` dans `session_config_sheet.dart` pour A/B/C
    - Même pattern `IconButton` +/- que `_CardCountStepper` pour maxCards (0 = toutes)
    - À chaque changement : `ref.read(revisionPrefsProvider.notifier).update(prefs.copyWith(...))`
    - **Important :** invalider `homeProvider` après chaque update pour que les défauts se mettent à jour : `ref.invalidate(homeProvider)`
    - Import `homeProvider` depuis `package:collega_app/features/home/home_providers.dart`

  - [x] `_NotifCard` — **copier sans modification depuis le code existant** (ConsumerStatefulWidget déjà complet)

  - [x] `_AppCard` — `StatelessWidget`, ajouter :
    - Liens CGU et politique de confidentialité :
      ```dart
      // TODO: Remplacer par les URLs réelles avant déploiement
      const _kCguUrl = 'https://appmedecine.fr/cgu';
      const _kPrivacyUrl = 'https://appmedecine.fr/politique-confidentialite';
      ```
      ```dart
      ShadButton.link(
        onPressed: () => _launchUrl(_kCguUrl),
        child: const Text('Conditions générales d\'utilisation'),
      ),
      ShadButton.link(
        onPressed: () => _launchUrl(_kPrivacyUrl),
        child: const Text('Politique de confidentialité'),
      ),
      ```
    - Helper `_launchUrl` :
      ```dart
      Future<void> _launchUrl(String url) async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      }
      ```
    - Bouton "Supprimer mon compte" (placeholder pour Story 6.2) :
      ```dart
      ShadButton.outline(
        onPressed: () {
          // TODO Story 6.2 : implémenter flux suppression compte
        },
        child: const Text('Supprimer mon compte'),
      ),
      ```
    - Conserver le bouton "Se déconnecter" existant (ShadButton.destructive avec icône logout)

### Tests

- [x] **T14 — Mettre à jour `profile_screen_test.dart`** (AC: #1, #2, #3, #4, #5)
  - [x] Fichier : `collega_app/test/features/profile/profile_screen_test.dart`
  - [x] Mettre à jour `_testUser` — `AuthUser` a de nouveaux champs avec valeurs par défaut, vérifier que la const compilation reste valide. Si `monthlyReloads`/`monthlyMax` ne sont pas const-safe, retirer `const` :
    ```dart
    final _testUser = AuthUser(
      id: 'user-1',
      email: 'test@example.com',
      isBeta: false,
      isSubscribed: true,
      firstName: 'Marie',
      yearGroup: '4e année',
      faculty: 'Paris 6',
      monthlyReloads: 2,
      monthlyMax: 3,
    );
    ```
  - [x] Ajouter override `revisionPrefsProvider` dans `_buildScreen()` :
    ```dart
    revisionPrefsProvider.overrideWith(
      () => _FakeRevisionPrefsNotifier(),
    ),
    ```
  - [x] Créer `_FakeRevisionPrefsNotifier` :
    ```dart
    class _FakeRevisionPrefsNotifier extends RevisionPrefsNotifier {
      @override
      Future<RevisionPrefs> build() async => const RevisionPrefs();
    }
    ```
  - [x] Ajouter override `revisionPrefsRepositoryProvider` pour éviter l'accès au storage :
    ```dart
    revisionPrefsRepositoryProvider.overrideWithValue(
      _FakeRevisionPrefsRepository(),
    ),
    ```
  - [x] Mettre à jour les tests existants si les textes affichés changent (email → firstName, "Inactif" → vérifier)
  - [x] Ajouter test : `_IdentityCard affiche le prénom` — `expect(find.text('Marie'), findsOneWidget)`
  - [x] Ajouter test : `_IdentityCard mode édition sur tap` — tap sur le card, vérifier TextField visible
  - [x] Ajouter test : `_SubscriptionCard affiche la barre de quota` — `expect(find.byType(LinearProgressIndicator), findsOneWidget)`
  - [x] Ajouter test : `_RevisionPrefsCard affiche les chips A/B/C` — `expect(find.text('A'), findsOneWidget)`
  - [x] Ajouter test : `_AppCard affiche les liens CGU et politique` — `expect(find.textContaining('CGU'), findsOneWidget)`

---

## Dev Notes — Contexte Technique Exhaustif

### État actuel de `profile_screen.dart` (AVANT cette story)

```dart
// _IdentityCard : affiche email + badge beta (PAS prénom/année/faculté)
// _SubscriptionCard : badge Actif/Inactif UNIQUEMENT (PAS quota, PAS date, PAS deep link)
// _NotifCard : toggle rappel quotidien — COMPLET, ne pas modifier
// _AppCard : version + Se déconnecter — AJOUTER CGU + delete placeholder
// MANQUE : _RevisionPrefsCard
```

### Architecture des fichiers

```
collega_backend/
├── alembic/versions/
│   └── 011_add_profile_fields_to_users.py      # NOUVEAU
├── app/
│   ├── models/user.py                          # UPDATE (3 colonnes)
│   ├── api/v1/auth.py                          # UPDATE (GET /me étendu + PATCH /profile)
│   └── schemas/auth.py                         # UPDATE (ProfileUpdateRequest, MeResponse)

collega_app/lib/
├── features/
│   ├── auth/
│   │   ├── domain/auth_state.dart              # UPDATE (AuthUser nouveaux champs + copyWith)
│   │   ├── data/auth_repository.dart           # UPDATE (storage keys + updateProfile)
│   │   ├── data/revenuecat_service.dart        # UPDATE (RevenueCatSubscriptionInfo + getSubscriptionInfo)
│   │   └── auth_providers.dart                 # UPDATE (AuthNotifier.updateProfile)
│   ├── home/
│   │   └── home_providers.dart                 # UPDATE (revisionPrefs dans applyDefault)
│   └── profile/
│       ├── data/
│       │   └── revision_prefs_repository.dart  # NOUVEAU
│       ├── domain/
│       │   └── revision_prefs.dart             # NOUVEAU
│       ├── presentation/
│       │   └── profile_screen.dart             # UPDATE complet (réécriture)
│       └── profile_providers.dart              # NOUVEAU

collega_app/test/features/profile/
└── profile_screen_test.dart                    # UPDATE
```

### Providers et dépendances

**Providers existants réutilisés (ne pas recréer) :**
- `authProvider` → `features/auth/auth_providers.dart`
- `notificationsServiceProvider` → `core/notifications/notifications_service.dart`
- `revenueCatServiceProvider` → `features/auth/paywall_providers.dart`
- `secureStorageProvider` → `core/network/api_providers.dart`
- `homeProvider` → `features/home/home_providers.dart`
- `homeSessionConfigProvider` → `features/home/home_providers.dart`

**Nouveau provider :**
- `revisionPrefsProvider` → `features/profile/profile_providers.dart`
- `revisionPrefsRepositoryProvider` → `features/profile/profile_providers.dart`

### Patterns établis à réutiliser impérativement

**FilterChip pour rangs (copier de `session_config_sheet.dart`) :**
```dart
Wrap(
  spacing: 8,
  children: ['A', 'B', 'C'].map((r) {
    final isSelected = selected.contains(r);
    return FilterChip(
      label: Text(r),
      selected: isSelected,
      onSelected: (on) { /* update prefs */ },
    );
  }).toList(),
)
```

**Stepper pour maxCards (copier de `session_config_sheet.dart`) :**
```dart
Row(
  children: [
    IconButton(icon: const Icon(Icons.remove), onPressed: value > 0 ? () => onChanged(value - 1) : null),
    SizedBox(width: 48, child: Text(value == 0 ? 'Toutes' : '$value', textAlign: TextAlign.center)),
    IconButton(icon: const Icon(Icons.add), onPressed: () => onChanged(value + 1)),
  ],
)
```

**ShadToast pour feedback :**
```dart
ShadToaster.of(context).show(
  ShadToast.destructive(title: const Text('Titre'), description: Text(message)),
);
```

**AppBar style existant :**
```dart
appBar: AppBar(title: const Text('Profil'), centerTitle: false)
```

**ShadCard + spacing :**
```dart
ShadCard(
  padding: const EdgeInsets.all(AppSpacing.cardPadding),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...]),
)
```

### Pattern `_handleTokenResponse()` — impact étendu

Actuellement, `_handleTokenResponse()` dans `auth_repository.dart` appelle `/v1/auth/me` pour récupérer `userId`. Après T4, `/me` retourne aussi `first_name`, `year_group`, `faculty`, `monthly_reloads`, `monthly_reloads_max`. **Mettre à jour `_handleTokenResponse()` pour parser et persister ces nouveaux champs.**

```dart
// Dans _handleTokenResponse(), après le `meResponse` :
final meData = meResponse.data!['data'] as Map<String, dynamic>;
userId = meData['id'] as String;
final firstName = meData['first_name'] as String?;
final yearGroup = meData['year_group'] as String?;
final faculty = meData['faculty'] as String?;
final monthlyReloads = meData['monthly_reloads'] as int? ?? 0;
final monthlyMax = meData['monthly_reloads_max'] as int? ?? 3;
// Ajouter à Future.wait([...]) :
_storage.write(key: _kFirstName, value: firstName),
_storage.write(key: _kYearGroup, value: yearGroup),
_storage.write(key: _kFaculty, value: faculty),
_storage.write(key: _kMonthlyReloads, value: monthlyReloads.toString()),
_storage.write(key: _kMonthlyMax, value: monthlyMax.toString()),
```

### Alembic — convention projet

La numérotation des migrations est `XXX_description.py`. La dernière est `010_add_gin_index_flash_cards_fts.py`. La nouvelle doit être `011_add_profile_fields_to_users.py`.

Pattern des migrations existantes — utiliser `op.execute` si nécessaire mais ici `op.add_column` suffit. Inclure `down_revision` qui pointe vers `010_...`.

### Tests — pattern de mock RevisionPrefs

Le `revisionPrefsProvider` est un `AsyncNotifierProvider` → utiliser `.overrideWith()` :
```dart
class _FakeRevisionPrefsNotifier extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();

  @override
  Future<void> update(RevisionPrefs prefs) async {}
}
```

Le `revisionPrefsRepositoryProvider` est un `Provider` simple → utiliser `.overrideWithValue()`.

### `_IdentityCard` — gestion du prénom obligatoire

- `first_name` est le seul champ requis dans le modèle UX ("obligatoire")
- Validation : refuser la sauvegarde si `firstName.isEmpty` → `ShadToast` avertissement
- `year_group` et `faculty` sont facultatifs — chaîne vide → persister comme `null` côté backend (le PATCH convertit `''.strip() or None` en Python)

### `_SubscriptionCard` — gestion des cas null de RevenueCat

- `getSubscriptionInfo()` peut retourner `null` (ex. MethodChannel mock en test, RC indisponible)
- Dans ce cas : ne pas afficher la date de renouvellement, ne pas afficher le bandeau résiliation
- Toujours afficher le quota (données provenant de `AuthUser.monthlyReloads/monthlyMax`)
- Toujours afficher le bouton "Gérer mon abonnement" (même si RC est indisponible)

### Flux d'invalidation après update RevisionPrefs

Quand `_RevisionPrefsCard` met à jour les prefs via `revisionPrefsProvider.notifier.update(...)` :
1. `revisionPrefsProvider` se met à jour
2. `ref.invalidate(homeProvider)` force la reconstruction de `homeProvider`
3. `homeProvider.build()` re-lit `revisionPrefsProvider` et applique les nouvelles valeurs comme défaut
4. L'écran d'accueil affiche les nouvelles valeurs si aucune session config manuelle n'a été définie

### Anti-patterns à éviter absolument

- **NE PAS** ajouter `shared_preferences` ni `hive` — utiliser `flutter_secure_storage` déjà présent
- **NE PAS** créer une nouvelle table Drift pour les prefs — overkill pour 2 valeurs simples
- **NE PAS** modifier `app_router.dart` — la route `/profile` existe déjà (ligne 116)
- **NE PAS** implémenter la suppression de compte — c'est Story 6.2 (placeholder uniquement)
- **NE PAS** créer un `RevisionPrefsNotifier` qui appelle le réseau — tout est local (secure_storage)
- **NE PAS** réimplémenter `FilterChip` avec `ShadBadge` — `FilterChip` est déjà utilisé dans `session_config_sheet.dart` et c'est le pattern établi
- **NE PAS** utiliser `LaunchMode.externalApplication` — utiliser `LaunchMode.inAppBrowserView` pour rester dans l'app (AC4)
- **NE PAS** dupliquer `_NotifCard` — copier tel quel depuis l'implémentation actuelle
- **NE PAS** casser les tests existants (`affiche badge Actif si abonné`, `affiche le toggle Rappel quotidien`, etc.) — les mettre à jour si nécessaire

### Questions en suspens pour le dev agent

1. **URLs CGU/privacy** : les URLs `https://appmedecine.fr/cgu` et `https://appmedecine.fr/politique-confidentialite` utilisées dans le code sont des placeholders. Confirmer les URLs réelles avec le product owner avant déploiement. Les laisser dans des constantes facilement modifiables.

2. **Entitlement RevenueCat** : `active.values.first` prend le premier entitlement actif. Si l'app a plusieurs entitlements, préciser lequel utiliser. Pour l'instant, `values.first` est correct pour un abonnement unique.

## Change Log

- Story 6.1 implémentée — Backend : migration Alembic 011, User model, schémas Pydantic, GET /me étendu + PATCH /profile. Flutter : AuthUser + AuthRepository + AuthNotifier étendus, RevenueCatService avec getSubscriptionInfo, RevisionPrefs domain + repository + provider, HomeNotifier intègre les prefs, ProfileScreen réécrit avec 5 cartes, 10 tests Flutter passent. (Date: 2026-05-17)

---

## Références

- Epic 6 complet : `_bmad-output/planning-artifacts/epics.md` L.994–1070
- UX Profil : `_bmad-output/planning-artifacts/ux-design-specification.md` L.935–954
- Story 5.2 (patterns de test GoRouter) : `_bmad-output/implementation-artifacts/5-2-lancement-session-depuis-resultat-recherche.md`
- `ProfileScreen` actuel : `collega_app/lib/features/profile/presentation/profile_screen.dart`
- `AuthUser` / `AuthState` : `collega_app/lib/features/auth/domain/auth_state.dart`
- `AuthRepository` : `collega_app/lib/features/auth/data/auth_repository.dart`
- `AuthNotifier` : `collega_app/lib/features/auth/auth_providers.dart`
- `RevenueCatService` : `collega_app/lib/features/auth/data/revenuecat_service.dart`
- `revenueCatServiceProvider` : `collega_app/lib/features/auth/paywall_providers.dart`
- `HomeNotifier` + `applyDefault` : `collega_app/lib/features/home/home_providers.dart` L.87–92
- `HomeSessionConfig` : `collega_app/lib/features/home/domain/home_session_config.dart`
- `FilterChip` + stepper pattern : `collega_app/lib/features/home/presentation/widgets/session_config_sheet.dart`
- `secureStorageProvider` : `collega_app/lib/core/network/api_providers.dart`
- Tests existants : `collega_app/test/features/profile/profile_screen_test.dart`
- Migration précédente : `collega_backend/alembic/versions/010_add_gin_index_flash_cards_fts.py`
- Backend User model : `collega_backend/app/models/user.py`
- Backend auth endpoints : `collega_backend/app/api/v1/auth.py`

---

## Review Findings

### Decision Needed

- [x] [Review][Decision] AC1 — La spec dit "un tap sur la carte ouvre les champs en mode édition inline" mais l'implémentation utilise un bouton "Modifier" — **Résolu : bouton "Modifier" conservé (UX plus accessible), déviation spec acceptée**

### Patches

- [x] [Review][Patch] `updateProfile` avale silencieusement les erreurs — `_editing` se ferme même en cas d'échec, `_saving` non réinitialisé si exception non catchée [auth_providers.dart + profile_screen.dart]
- [x] [Review][Patch] `applyDefault` utilise `state ??=` — les révision prefs ne se propagent JAMAIS au session config après le premier build (bug fonctionnel critique) [home_providers.dart:54]
- [x] [Review][Patch] `_IdentityCardState` controllers non synchronisés via `didUpdateWidget` — texte périmé dans le formulaire d'édition après rebuild parent [profile_screen.dart]
- [x] [Review][Patch] Double rebuild de `homeProvider` — `ref.watch` dans `build()` + `ref.invalidate` explicite déclenchent tous les deux un rebuild [home_providers.dart:88 + profile_screen.dart]
- [x] [Review][Patch] `updateProfile` envoie un corps PATCH vide si tous les params sont null — aucune guard [auth_repository.dart]
- [x] [Review][Patch] `ProfileUpdateRequest` sans `max_length` Pydantic — chaînes sans borne causent un 500 DB [schemas/auth.py]
- [x] [Review][Patch] Déduplication des rangs absente — double-tap rapide peut ajouter le même rang deux fois [profile_screen.dart updateRangs]
- [x] [Review][Patch] `_launchUrl` échoue silencieusement si `canLaunchUrl` retourne false — aucun feedback utilisateur [profile_screen.dart]
- [x] [Review][Patch] `update_profile` backend sans `db.refresh(current_user)` après commit [api/v1/auth.py]

### Deferred

- [x] [Review][Defer] Corps de réponse PATCH ignoré — risque mineur de désynchronisation serveur/client (normalisations identiques en pratique) [auth_repository.dart] — deferred, impact minimal
- [x] [Review][Defer] `getSubscriptionInfo` broad `catch(_)` — masque les erreurs d'init du SDK RevenueCat [revenuecat_service.dart] — deferred, comportement intentionnel
- [x] [Review][Defer] `_subInfo` non rafraîchi après changement d'abonnement en cours de session [profile_screen.dart] — deferred, cas limite rare

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

Aucun blocage majeur. Corrections effectuées :
- `RevisionPrefsNotifier.update()` → renommé `save()` car `AsyncNotifierBase` a déjà un `update()` avec une signature différente.
- `AppColors.destructive` → corrigé en `AppColors.error` (constant disponible dans le thème).
- Tests `find.text()` → `skipOffstage: false` pour les widgets hors viewport dans le ListView.
- Tests backend avec `make_user()` → ajout paramètre `with_password=False` pour éviter l'erreur bcrypt pré-existante (Python 3.14 incompatibilité).

### Completion Notes List

- T1 : Migration Alembic 011 créée, ajoute `first_name`, `year_group`, `faculty` à `users`.
- T2 : Modèle SQLAlchemy `User` étendu avec 3 colonnes nullable.
- T3 : Schémas Pydantic `ProfileUpdateRequest` et `MeResponse` ajoutés dans `auth.py`.
- T4 : `GET /me` retourne désormais 8 champs (+ profil + quota). `PATCH /profile` ajouté. 7 tests backend passent.
- T5 : `AuthUser` étendu avec `firstName`, `yearGroup`, `faculty`, `monthlyReloads`, `monthlyMax` + `copyWith` sentinel pattern.
- T6 : `AuthRepository` — 5 nouvelles clés storage, `loadStoredUser()` étendu, `logout()` étendu, `refreshFromMe()` parse et persiste les nouveaux champs, `_handleTokenResponse()` pareil, `updateProfile()` ajouté.
- T7 : `AuthNotifier.updateProfile()` ajouté dans `auth_providers.dart`.
- T8 : `RevenueCatSubscriptionInfo` + `getSubscriptionInfo()` ajoutés dans `revenuecat_service.dart`.
- T9 : `RevisionPrefs` domain model créé avec `copyWith` sentinel.
- T10 : `RevisionPrefsRepository` créé avec `load()`/`save()` via flutter_secure_storage.
- T11 : `RevisionPrefsNotifier` (méthode `save()`) + `revisionPrefsProvider` créés dans `profile_providers.dart`.
- T12 : `HomeNotifier.build()` lit `revisionPrefsProvider` et applique rangs/maxCards comme défaut.
- T13 : `profile_screen.dart` réécrit — `_IdentityCard` (édition inline), `_SubscriptionCard` (quota + RC info), `_RevisionPrefsCard` (chips A/B/C + stepper), `_NotifCard` (inchangé), `_AppCard` (CGU + placeholder suppression).
- T14 : `profile_screen_test.dart` mis à jour — 10 tests passent, zéro régression.

### File List

- `collega_backend/alembic/versions/011_add_profile_fields_to_users.py` (NOUVEAU)
- `collega_backend/app/models/user.py` (MODIFIÉ)
- `collega_backend/app/schemas/auth.py` (MODIFIÉ)
- `collega_backend/app/api/v1/auth.py` (MODIFIÉ)
- `collega_backend/tests/api/test_auth.py` (MODIFIÉ)
- `collega_app/lib/features/auth/domain/auth_state.dart` (MODIFIÉ)
- `collega_app/lib/features/auth/data/auth_repository.dart` (MODIFIÉ)
- `collega_app/lib/features/auth/data/revenuecat_service.dart` (MODIFIÉ)
- `collega_app/lib/features/auth/auth_providers.dart` (MODIFIÉ)
- `collega_app/lib/features/home/home_providers.dart` (MODIFIÉ)
- `collega_app/lib/features/profile/domain/revision_prefs.dart` (NOUVEAU)
- `collega_app/lib/features/profile/data/revision_prefs_repository.dart` (NOUVEAU)
- `collega_app/lib/features/profile/profile_providers.dart` (NOUVEAU)
- `collega_app/lib/features/profile/presentation/profile_screen.dart` (MODIFIÉ)
- `collega_app/test/features/profile/profile_screen_test.dart` (MODIFIÉ)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIÉ)
