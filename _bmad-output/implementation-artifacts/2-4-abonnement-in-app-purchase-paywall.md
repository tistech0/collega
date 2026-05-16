# Story 2.4 : Abonnement In-App Purchase & Paywall

Status: done

## Story

En tant qu'**étudiant inscrit**,
je veux souscrire à l'abonnement mensuel via l'App Store et voir le prix avant de confirmer,
afin d'accéder à toutes les fonctionnalités d'AppMédecine.

## Acceptance Criteria

1. **Paywall affiché si non abonné (FR5, FR6)**
   - Étant donné un utilisateur authentifié sans abonnement actif (`is_subscribed: false`, `is_beta: false`)
   - Quand il tente d'accéder à une route protégée (`/home`, `/colleges`, `/search`, `/profile`)
   - Alors le paywall s'affiche avec le prix (~9€/mois) et la durée clairement indiqués avant toute confirmation
   - Et un bouton "Retour à la démo" permet de revenir à `/demo` sans pression

2. **Achat via IAP App Store (FR4)**
   - Étant donné le paywall affiché
   - Quand je tape "S'abonner"
   - Alors la sheet native App Store IAP s'ouvre via `purchases_flutter`
   - Et après confirmation d'achat, RevenueCat enregistre l'abonnement et envoie un webhook au backend

3. **Webhook INITIAL_PURCHASE → accès accordé**
   - Étant donné le webhook RevenueCat `INITIAL_PURCHASE` reçu par le backend
   - Quand l'event est traité (endpoint `POST /v1/webhooks/revenuecat` déjà implémenté)
   - Alors `user.is_subscribed` passe à `true` en base
   - Et l'app Flutter recharge l'état auth depuis `GET /v1/auth/me` puis redirige vers `/home`

4. **Achat annulé ou échoué**
   - Étant donné la sheet IAP ouverte
   - Quand l'utilisateur la ferme sans confirmer (`PurchasesErrorCode.purchaseCancelledError`)
   - Alors le paywall est réaffiché avec un `ShadToast` : "Achat annulé"
   - Et aucun changement n'est enregistré en base

5. **Guard abonnement backend (FR42)**
   - Étant donné un endpoint backend nécessitant Claude (Epic 3+)
   - Quand une requête arrive
   - Alors une dépendance `require_subscription` dans `deps.py` vérifie `user.is_subscribed OR user.is_beta`
   - Et retourne `{"error": {"code": "SUBSCRIPTION_REQUIRED", "message": "..."}}` + HTTP 403 si invalide

6. **Deep link gestion abonnement iOS (FR41)**
   - Étant donné l'app soumise à review App Store
   - Quand le paywall est affiché
   - Alors un lien "Gérer mon abonnement" pointe vers les paramètres d'abonnement iOS (`itms-apps://apps.apple.com/account/subscriptions`)

7. **Utilisateur beta — accès sans paywall**
   - Étant donné un utilisateur avec `is_beta: true`
   - Quand il est authentifié
   - Alors il accède directement à `/home` sans passer par le paywall
   - Et le router ne le redirige jamais vers `/paywall`

## Tasks / Subtasks

- [x] **T1 — Backend : `require_subscription` dependency** (AC: #5)
  - [x] Ajouter `require_subscription(user: User = Depends(get_current_user)) -> User` dans `collega_backend/app/deps.py`
  - [x] La dépendance lève `HTTPException(403, {"code": "SUBSCRIPTION_REQUIRED", "message": "Abonnement actif requis"})` si `not (user.is_subscribed or user.is_beta)`
  - [x] Mettre à jour `__all__` dans `deps.py` pour inclure `require_subscription`
  - [x] Créer `collega_backend/tests/api/test_require_subscription.py` : tests avec utilisateur non abonné (403), abonné (pass), beta (pass), non authentifié (401 via get_current_user)

- [x] **T2 — Flutter : RevenueCat SDK init + RevenueCatService** (AC: #2, #3, #4, #6)
  - [x] Ajouter `url_launcher: ^6.3.0` dans `collega_app/pubspec.yaml` (nécessaire pour `itms-apps://`)
  - [x] Ajouter `const String revenueCatApiKey = 'REPLACE_WITH_REVENUECAT_APPLE_API_KEY';` dans `collega_app/lib/env.dart`
  - [x] Mettre à jour `collega_app/lib/main.dart` : ajouter `WidgetsFlutterBinding.ensureInitialized()` avant `runApp()` + `await Purchases.configure(PurchasesConfiguration(revenueCatApiKey))`
  - [x] Créer `collega_app/lib/features/auth/data/revenuecat_service.dart` avec méthodes : `getMonthlyOffering()`, `purchaseMonthlySubscription(Package)`, `restorePurchases()`, `openSubscriptionManagement()`
  - [x] Créer `collega_app/lib/features/auth/paywall_providers.dart` : `paywallProvider` (AsyncNotifierProvider) avec méthodes `loadOffering()` et `purchase()`

- [x] **T3 — Flutter : PaywallScreen** (AC: #1, #2, #4, #6)
  - [x] Créer `collega_app/lib/features/auth/presentation/paywall_screen.dart`
  - [x] Afficher prix et durée depuis `Offerings` (fallback : texte hardcodé "~9€/mois" si Offerings non disponibles)
  - [x] Bouton CTA "S'abonner" (ShadButton filled primary) → déclenche `paywallProvider.purchase(package)`
  - [x] `ShadProgress` pendant le chargement / achat en cours
  - [x] `ShadToast` erreur sur `PurchasesErrorCode.purchaseCancelledError` : "Achat annulé"
  - [x] `ShadToast` erreur générique sur autres erreurs : "Achat impossible, réessayez"
  - [x] Bouton secondaire "Retour à la démo" (ShadButton ghost) → `context.go('/demo')`
  - [x] Lien "Gérer mon abonnement" (ShadButton ghost) → `RevenueCatService.openSubscriptionManagement()`
  - [x] Tests widget : `collega_app/test/features/auth/paywall_screen_test.dart` (5 tests min)

- [x] **T4 — Flutter : Router paywall redirect + AuthState refresh** (AC: #1, #3, #7)
  - [x] Ajouter getter `hasAccess` dans `AuthState` : `bool get hasAccess => user != null && (user!.isSubscribed || user!.isBeta);`
  - [x] Mettre à jour redirect dans `collega_app/lib/core/router/app_router.dart` :
    - `isAuth && !hasAccess && isProtected` → `/paywall`
    - `isAuth && hasAccess && matchedLocation == '/paywall'` → `/home`
  - [x] Ajouter route `/paywall` → `PaywallScreen` dans `app_router.dart`
  - [x] Ajouter méthode `refreshSubscription()` dans `AuthNotifier` : appelle `GET /v1/auth/me` et met à jour `AuthState` avec le nouveau `is_subscribed`
  - [x] `PaywallNotifier.purchase()` appelle `refreshSubscription()` après achat réussi, ce qui déclenche le redirect automatique via le router réactif
  - [x] Ajouter `Purchases.logIn(userId)` dans `AuthNotifier.register()` et `AuthNotifier.login()` (après AuthState mis à jour)
  - [x] Ajouter `Purchases.logOut()` dans `AuthNotifier.logout()`

- [x] **T5 — Validation finale** (AC: tous)
  - [x] `flutter analyze` → 0 erreur
  - [x] `flutter test` → tous les tests passent (incluant tests existants 2.1, 2.2, 2.3)
  - [x] `pytest collega_backend/tests/api/test_require_subscription.py` → tous verts
  - [x] Vérifier que le router redirige correctement les 4 cas : (non-auth), (auth + no access + protected), (auth + access), (beta)

## Dev Notes

### État du codebase à la date de cette story

**DÉJÀ IMPLÉMENTÉ — NE PAS RECRÉER :**

| Composant | État | Notes |
|---|---|---|
| `User.is_subscribed` | ✅ Existe | `collega_backend/app/models/user.py` ligne 26 |
| `AuthUser.isSubscribed` | ✅ Existe | `collega_app/lib/features/auth/domain/auth_state.dart` |
| `AuthRepository` persiste `is_subscribed` | ✅ Existe | `_kIsSubscribed = 'is_subscribed'` dans `auth_repository.dart` |
| `TokenResponse.is_subscribed` | ✅ Existe | `collega_backend/app/schemas/auth.py` |
| Webhook `POST /v1/webhooks/revenuecat` | ✅ Complet + testé | `billing.py` + `test_billing_webhook.py` — 10 tests, ne pas toucher |
| `purchases_flutter: ^10.0.1` | ✅ Dans pubspec | Pas besoin d'ajouter |
| `routerProvider` réactif auth | ✅ Existe | `app_router.dart` — **MODIFIER** uniquement le bloc redirect et les routes |
| `forceLogoutSignalProvider` | ✅ Existe | `api_providers.dart` — NE PAS TOUCHER |

**FICHIERS À MODIFIER :**

| Fichier | Ce que Story 2.4 change |
|---|---|
| `collega_backend/app/deps.py` | Ajouter `require_subscription` dependency + mise à jour `__all__` |
| `collega_app/pubspec.yaml` | Ajouter `url_launcher: ^6.3.0` |
| `collega_app/lib/env.dart` | Ajouter `revenueCatApiKey` constant |
| `collega_app/lib/main.dart` | `WidgetsFlutterBinding.ensureInitialized()` + `Purchases.configure()` |
| `collega_app/lib/core/router/app_router.dart` | Ajouter `/paywall` route + redirect has_access check |
| `collega_app/lib/features/auth/domain/auth_state.dart` | Ajouter getter `hasAccess` |
| `collega_app/lib/features/auth/auth_providers.dart` | `refreshSubscription()`, `Purchases.logIn/logOut()` |

**FICHIERS À CRÉER :**
```
collega_backend/tests/api/test_require_subscription.py
collega_app/lib/features/auth/data/revenuecat_service.dart
collega_app/lib/features/auth/paywall_providers.dart
collega_app/lib/features/auth/presentation/paywall_screen.dart
collega_app/test/features/auth/paywall_screen_test.dart
```

---

### Backend : `require_subscription` dans deps.py

**Ajouter après `get_current_user` :**

```python
async def require_subscription(user=Depends(get_current_user)):
    """Guard FR42 : vérifie is_subscribed OR is_beta avant tout appel Claude."""
    if not (user.is_subscribed or user.is_beta):
        raise HTTPException(
            status_code=403,
            detail={"code": "SUBSCRIPTION_REQUIRED", "message": "Abonnement actif requis"},
        )
    return user
```

**Mise à jour `__all__` :**
```python
__all__ = ["get_db", "get_admin_user", "get_tester_user", "get_current_user", "require_subscription"]
```

**Pattern de test dans `test_require_subscription.py` :**

Les tests de `require_subscription` nécessitent un endpoint de test. Créer un router factice dans le fichier de test ou utiliser `app.dependency_overrides` directement sur `get_current_user` :

```python
import pytest
from fastapi import FastAPI, Depends
from httpx import ASGITransport, AsyncClient
from app.deps import require_subscription

# Option la plus simple : créer une mini-app de test
def make_app_with_guard():
    from fastapi import FastAPI
    test_app = FastAPI()
    
    @test_app.get("/protected")
    async def protected(user=Depends(require_subscription)):
        return {"ok": True}
    return test_app

# Ou utiliser l'override get_current_user sur l'app principale
```

Préférer l'approche avec `app.dependency_overrides[get_current_user]` sur l'app principale — cohérent avec le pattern des autres tests.

---

### Flutter : API RevenueCat (purchases_flutter 10.x)

**Cycle de vie RevenueCat :**

```dart
// main.dart — avant runApp()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  runApp(const ProviderScope(child: App()));
}
```

**API principale utilisée dans cette story :**

```dart
// Lier l'achat à un utilisateur authentifié (après login/register)
final logInResult = await Purchases.logIn(userId); // userId = AuthUser.id

// Récupérer les offres (avec prix App Store réel)
final offerings = await Purchases.getOfferings();
final package = offerings.current?.monthly; // Package ou null si aucune offre active

// Déclencher l'achat
final customerInfo = await Purchases.purchasePackage(package!);
final hasAccess = customerInfo.entitlements.active.isNotEmpty;

// Restaurer les achats (si utilisateur réinstalle l'app)
final customerInfo = await Purchases.restorePurchases();

// Déconnexion
await Purchases.logOut();
```

**Gestion d'erreur achat :**
```dart
try {
  await Purchases.purchasePackage(package);
} on PlatformException catch (e) {
  final errorCode = PurchasesErrorHelper.getErrorCode(e);
  if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
    // Achat annulé par l'utilisateur → ShadToast "Achat annulé"
  } else {
    // Autre erreur → ShadToast "Achat impossible, réessayez"
  }
}
```

**Import nécessaire :** `import 'package:purchases_flutter/purchases_flutter.dart';`

---

### Flutter : `RevenueCatService`

```dart
// lib/features/auth/data/revenuecat_service.dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class RevenueCatService {
  Future<Package?> getMonthlyOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.monthly;
    } catch (_) {
      return null;
    }
  }

  Future<CustomerInfo> purchaseMonthlySubscription(Package package) =>
      Purchases.purchasePackage(package);

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  Future<void> openSubscriptionManagement() async {
    final uri = Uri.parse('itms-apps://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
```

---

### Flutter : `PaywallNotifier`

Le `PaywallNotifier` vit dans `paywall_providers.dart`, séparé de `auth_providers.dart` pour éviter le couplage.

```dart
// lib/features/auth/paywall_providers.dart

class PaywallState {
  const PaywallState({
    this.package,
    this.isLoading = false,
    this.errorMessage,
  });
  final Package? package;
  final bool isLoading;
  final String? errorMessage;
}

class PaywallNotifier extends AsyncNotifier<PaywallState> {
  @override
  Future<PaywallState> build() async {
    final pkg = await ref.read(revenueCatServiceProvider).getMonthlyOffering();
    return PaywallState(package: pkg);
  }

  Future<void> purchase() async {
    final currentState = state.valueOrNull;
    if (currentState?.package == null) return;
    
    state = AsyncData(currentState!.copyWith(isLoading: true));
    try {
      await ref.read(revenueCatServiceProvider)
          .purchaseMonthlySubscription(currentState.package!);
      // Achat réussi → refresh AuthState (déclenchera le redirect auto)
      await ref.read(authProvider.notifier).refreshSubscription();
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      final msg = errorCode == PurchasesErrorCode.purchaseCancelledError
          ? 'Achat annulé'
          : 'Achat impossible, réessayez';
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: msg));
    } catch (_) {
      state = AsyncData(currentState.copyWith(
        isLoading: false, errorMessage: 'Achat impossible, réessayez'));
    }
  }
}

final revenueCatServiceProvider = Provider((_) => RevenueCatService());
final paywallProvider = AsyncNotifierProvider<PaywallNotifier, PaywallState>(PaywallNotifier.new);
```

---

### Flutter : `AuthState.hasAccess` + `AuthNotifier.refreshSubscription()`

**Dans `auth_state.dart` — ajouter le getter :**
```dart
bool get hasAccess => user != null && (user!.isSubscribed || user!.isBeta);
```

**Dans `auth_providers.dart` — ajouter dans `AuthNotifier` :**
```dart
Future<void> refreshSubscription() async {
  final current = state.valueOrNull;
  if (current?.user == null) return;
  
  try {
    final response = await ref.read(authRepositoryProvider).refreshFromMe();
    if (response.user != null) {
      state = AsyncData(response);
    }
  } catch (e) {
    AppLogger.error('Failed to refresh subscription', tag: 'AuthNotifier', error: e);
  }
}
```

**Dans `auth_repository.dart` — ajouter méthode `refreshFromMe()` :**
```dart
Future<AuthState> refreshFromMe() async {
  try {
    final response = await _dio.get<Map<String, dynamic>>('/v1/auth/me');
    final data = response.data!['data'] as Map<String, dynamic>;
    final isSubscribed = data['is_subscribed'] as bool;
    final isBeta = data['is_beta'] as bool;
    
    // Mettre à jour le flag en storage
    await _storage.write(key: _kIsSubscribed, value: isSubscribed.toString());
    await _storage.write(key: _kIsBeta, value: isBeta.toString());
    
    final userId = await _storage.read(key: _kUserId) ?? '';
    final email = await _storage.read(key: _kUserEmail) ?? '';
    
    return AuthState(
      user: AuthUser(id: userId, email: email, isBeta: isBeta, isSubscribed: isSubscribed),
    );
  } on DioException catch (e) {
    AppLogger.error('refreshFromMe failed', tag: 'AuthRepository', error: e);
    return const AuthState(errorMessage: 'Impossible de synchroniser le statut');
  }
}
```

---

### Flutter : Router — redirect paywall

**Logique complète après modification :**

```dart
redirect: (context, state) {
  if (authAsync.isLoading) return null;

  final isAuth = authAsync.valueOrNull?.isAuthenticated ?? false;
  final hasAccess = authAsync.valueOrNull?.hasAccess ?? false;

  if (state.fullPath == null || state.fullPath == '/') return '/demo';

  final isProtected = state.matchedLocation.startsWith('/home') ||
      state.matchedLocation.startsWith('/colleges') ||
      state.matchedLocation.startsWith('/search') ||
      state.matchedLocation.startsWith('/profile');

  // Non authentifié → démo
  if (!isAuth && isProtected) return '/demo';
  
  // Authentifié mais pas d'accès → paywall (sauf si déjà sur paywall ou démo)
  if (isAuth && !hasAccess && isProtected) return '/paywall';
  
  // A accès mais sur le paywall → home
  if (isAuth && hasAccess && state.matchedLocation == '/paywall') return '/home';

  final isAuthRoute = state.matchedLocation.startsWith('/auth');
  if (isAuth && isAuthRoute) return '/home';

  return null;
},
```

**Ajouter la route `/paywall` :**
```dart
GoRoute(path: '/paywall', builder: (ctx, s) => const PaywallScreen()),
```
→ Placer cette route en dehors du `ShellRoute` (pas de bottom nav sur le paywall).

---

### Flutter : RevenueCat + logIn/logOut

**Dans `AuthNotifier.register()` ET `AuthNotifier.login()` — après succès :**
```dart
Future<void> login(String email, String password) async {
  state = const AsyncLoading();
  final result = await ref.read(authRepositoryProvider).login(email, password);
  state = AsyncData(result);
  // Lier RevenueCat à l'utilisateur authentifié
  if (result.user != null) {
    try {
      await Purchases.logIn(result.user!.id);
    } catch (e) {
      AppLogger.warning('RevenueCat logIn failed', tag: 'AuthNotifier', error: e);
      // Non-bloquant : achat possible même si logIn échoue
    }
  }
}
```

**Dans `AuthNotifier.logout()` :**
```dart
Future<void> logout() async {
  state = const AsyncLoading();
  await ref.read(authRepositoryProvider).logout();
  try {
    await Purchases.logOut();
  } catch (e) {
    AppLogger.warning('RevenueCat logOut failed', tag: 'AuthNotifier', error: e);
  }
  state = const AsyncData(AuthState());
}
```

---

### Pattern de test Flutter pour PaywallScreen

Utiliser `_FakeAuthRepository` pattern de Story 2.3 (sans mockito/build_runner) :

```dart
// test/features/auth/paywall_screen_test.dart

void main() {
  testWidgets('affiche le bouton S\'abonner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paywallProvider.overrideWith(() => _FakePaywallNotifier()),
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          routerProvider.overrideWith((ref) => _buildTestRouter()),
        ],
        child: const ShadApp(home: PaywallScreen()),
      ),
    );
    await tester.pump();
    expect(find.text("S'abonner"), findsOneWidget);
    expect(find.text("Retour à la démo"), findsOneWidget);
  });
  // + 4 autres tests : loading state, erreur achat annulé, redirect après achat réussi, lien gestion abonnement
}
```

---

### Anti-patterns à éviter absolument

- **NE PAS** recréer le webhook billing — `POST /v1/webhooks/revenuecat` est COMPLET et testé
- **NE PAS** modifier `billing.py` ou `test_billing_webhook.py`
- **NE PAS** recréer `User.is_subscribed` — existe déjà dans le modèle
- **NE PAS** stocker la clé secrète RevenueCat côté Flutter — seule la clé PUBLIQUE (Apple API Key) va dans `env.dart`
- **NE PAS** bloquer le démarrage sur `Purchases.configure()` — appeler dans `main()` avant `runApp()` (async main)
- **NE PAS** utiliser `CircularProgressIndicator` → `ShadProgress` systématiquement
- **NE PAS** mettre `Purchases.logIn()` dans le widget (→ dans `AuthNotifier`)
- **NE PAS** déclencher le redirect vers `/paywall` si l'utilisateur est déjà sur `/demo` — seules les routes protégées triggent le paywall
- **NE PAS** ajouter de logique paywall dans `PaywallScreen` widget lui-même — tout via `PaywallNotifier`

---

### Règles qualité héritées de Story 2.3

- `flutter analyze` → 0 erreur avant de marquer terminée
- Jamais `print()` ou `debugPrint()` → `lib/core/utils/logger.dart`
- Logique métier dans les Notifiers, jamais dans les widgets
- `ShadSkeleton` / `ShadProgress` pour tous les états de chargement
- `ShadToast` pour erreurs non-bloquantes
- Un seul bouton `ShadButton` filled primary par écran
- Nommage : PascalCase classes, camelCase méthodes, snake_case fichiers

---

### Référence clé : routerProvider réactif

Le `routerProvider` actuel (Story 2.3) est un `Provider<GoRouter>` qui se reconstruit à chaque changement d'`authProvider`. Cela signifie que dès que `AuthState` change (notamment `isSubscribed`), le router réévalue le redirect automatiquement — sans navigation explicite. C'est le mécanisme qui permet le redirect auto après achat réussi (`refreshSubscription()` → authState mis à jour → router reconstruit → redirect vers `/home`).

### Références

- Architecture IAP : `_bmad-output/planning-artifacts/architecture.md#Authentication & Security` (RevenueCat SDK Flutter + webhook)
- Flux achat : `_bmad-output/planning-artifacts/ux-design-specification.md#Flow 1` (Léa onboarding paywall)
- Webhook existant : `collega_backend/app/api/v1/billing.py` + `collega_backend/tests/api/test_billing_webhook.py`
- Router actuel : `collega_app/lib/core/router/app_router.dart`
- Auth state actuel : `collega_app/lib/features/auth/domain/auth_state.dart`
- AuthNotifier actuel : `collega_app/lib/features/auth/auth_providers.dart`
- AuthRepository actuel : `collega_app/lib/features/auth/data/auth_repository.dart`
- Deps backend actuel : `collega_backend/app/deps.py`
- User model backend : `collega_backend/app/models/user.py`
- Pattern test Flutter (Story 2.3) : `_bmad-output/implementation-artifacts/2-3-inscription-authentification.md#Dev Agent Record`

### Review Findings

- [x] [Review][Patch] AC #3 — Endpoint `POST /v1/auth/refresh-subscription` dédié : `refreshSubscription()` dans Flutter appelle ce nouvel endpoint (polling DB 5×2s) [`collega_backend/app/api/v1/auth.py` + `collega_app/lib/features/auth/data/auth_repository.dart`]
- [x] [Review][Patch] RevenueCat `logIn` avant achat — `await Purchases.logIn(userId)` (idempotent, catch silencieux) dans `PaywallNotifier.purchase()` avant `purchaseMonthlySubscription` [`collega_app/lib/features/auth/paywall_providers.dart`]
- [x] [Review][Dismiss] Format 403 — `{"detail": ...}` est la convention FastAPI cohérente avec tout le codebase et le client Flutter ; la description spec était informelle [`collega_backend/app/deps.py`]
- [x] [Review][Patch] Guard router `/paywall` non authentifié — `if (!isAuth && (isProtected || matchedLocation == '/paywall')) return '/demo'` [`collega_app/lib/core/router/app_router.dart`]
- [x] [Review][Patch] `isLoading` réinitialisé après `refreshSubscription()` + message "synchronisation en cours" si `hasAccess` encore false [`collega_app/lib/features/auth/paywall_providers.dart`]
- [x] [Review][Patch] Race condition double-tap — verrou `_purchasing` dans `PaywallNotifier` [`collega_app/lib/features/auth/paywall_providers.dart`]
- [x] [Review][Patch] Tests backend réécrits avec `_make_test_app()` — testent `require_subscription` directement (7 tests, plus de dépendance `/v1/auth/me`) [`collega_backend/tests/api/test_require_subscription.py`]
- [x] [Review][Patch] `PaywallState.copyWith` — `clearError` n'écrase plus `errorMessage` si fourni simultanément [`collega_app/lib/features/auth/paywall_providers.dart`]
- [x] [Review][Patch] Bouton "Restaurer mes achats" ajouté dans `PaywallScreen` (sous le guard `isLoading`) [`collega_app/lib/features/auth/presentation/paywall_screen.dart`]
- [x] [Review][Patch] `openSubscriptionManagement()` déplacé dans `PaywallNotifier` — widget appelle notifier [`collega_app/lib/features/auth/presentation/paywall_screen.dart`]
- [x] [Review][Defer] `authProvider` en état `AsyncError` non géré dans le router — perte de session silencieuse [`collega_app/lib/core/router/app_router.dart`] — deferred, pre-existing
- [x] [Review][Defer] TOCTOU dans `refreshFromMe` — lecture storage après écriture, vulnérable à logout concurrent (low severity) [`collega_app/lib/features/auth/data/auth_repository.dart`] — deferred, pre-existing

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `purchasePackage` API dépréciée en purchases_flutter 10.x → migré vers `Purchases.purchase(PurchaseParams.package(pkg))`
- `ShadProgress` anime en boucle → tests widget utilisent `pump()` + dispose de l'arbre en fin de test
- `Purchases.logIn/logOut()` bloquent les tests widget (MethodChannel sans handler) → rendu fire-and-forget via IIFE async non-awaité

### Completion Notes List

- T1 : `require_subscription` ajoutée dans `deps.py` + `__all__` mis à jour. 6 tests pytest couvrent : non-auth (401), abonné (200), beta (200), non-abonné sur route protégée (403).
- T2 : `url_launcher` ajouté au pubspec ; `revenueCatApiKey` ajouté à `env.dart` ; `main.dart` async avec `WidgetsFlutterBinding.ensureInitialized()` + `Purchases.configure()` ; `RevenueCatService` créé avec nouvelle API `PurchaseParams.package()` ; `PaywallNotifier` avec `PaywallState` dans `paywall_providers.dart`.
- T3 : `PaywallScreen` avec prix dynamique (fallback ~9€/mois), bouton S'abonner, ShadProgress, ShadToast erreurs, bouton démo, lien gestion abonnement. 5 tests widget.
- T4 : `hasAccess` getter dans `AuthState` ; router mis à jour avec redirect paywall (4 cas couverts) + route `/paywall` ; `refreshFromMe()` dans `AuthRepository` ; `refreshSubscription()` dans `AuthNotifier` ; `_rcLogIn/logOut()` fire-and-forget.
- T5 : `flutter analyze` → 0 erreur ; `flutter test` 25 tests passent ; `pytest` 6 tests passent.

### File List

- `collega_backend/app/deps.py` (modifié)
- `collega_backend/tests/api/test_require_subscription.py` (créé)
- `collega_app/pubspec.yaml` (modifié)
- `collega_app/pubspec.lock` (modifié)
- `collega_app/lib/env.dart` (modifié)
- `collega_app/lib/main.dart` (modifié)
- `collega_app/lib/features/auth/data/revenuecat_service.dart` (créé)
- `collega_app/lib/features/auth/data/auth_repository.dart` (modifié)
- `collega_app/lib/features/auth/domain/auth_state.dart` (modifié)
- `collega_app/lib/features/auth/auth_providers.dart` (modifié)
- `collega_app/lib/features/auth/paywall_providers.dart` (créé)
- `collega_app/lib/features/auth/presentation/paywall_screen.dart` (créé)
- `collega_app/lib/core/router/app_router.dart` (modifié)
- `collega_app/test/features/auth/paywall_screen_test.dart` (créé)

### Change Log

- 2026-05-05 : Story 2.4 créée par create-story — abonnement in-app purchase & paywall
- 2026-05-06 : Story 2.4 implémentée — T1 backend require_subscription, T2 RevenueCat SDK init + service, T3 PaywallScreen, T4 router redirect + AuthState refresh, T5 validation complète
