import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';
import 'package:collega_app/features/auth/data/local_data_owner.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/search/search_providers.dart';
import 'package:collega_app/features/today/today_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio: ref.read(apiClientProvider).dio,
    storage: ref.read(secureStorageProvider),
  ),
);

/// Timeout appliqué aux étapes locales du wipe (RC, Drift) — au-delà, on
/// considère l'étape comme échouée et on continue vers le state reset, pour
/// éviter qu'un SDK qui hang ne piège l'utilisateur dans un spinner infini.
const Duration _kLocalWipeStepTimeout = Duration(seconds: 5);

class AuthNotifier extends AsyncNotifier<AuthState> {
  /// Guard de réentrance pour `deleteAccount` — un double-tap sur le bouton
  /// « Supprimer définitivement » ne déclenche qu'UN seul DELETE serveur ;
  /// les appels concurrents attendent le même résultat.
  Completer<String?>? _deleteInFlight;

  /// Riverpod 2.6 ne fournit pas de `ref.mounted` sur les AsyncNotifiers ;
  /// on suit la disposition manuellement via `ref.onDispose` pour éviter de
  /// muter `state` après que le provider ait été détruit (StateError).
  bool _disposed = false;

  @override
  Future<AuthState> build() async {
    ref.onDispose(() {
      _disposed = true;
    });
    ref.listen(forceLogoutSignalProvider, (_, __) {
      if (_disposed) return;
      state = const AsyncData(AuthState());
    });
    return ref.read(authRepositoryProvider).loadStoredUser();
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).register(email, password);
    if (result.user != null) await _claimLocalData(result.user!.id);
    state = AsyncData(result);
    if (result.errorMessage != null) {
      AppLogger.warning('Register error: ${result.errorMessage}', tag: 'AuthNotifier');
    }
    if (result.user != null) {
      _rcLogIn(result.user!.id);
    }
  }

  Future<void> login(String email, String password) async {
    // La valeur précédente reste lisible pendant la requête (routeur, écrans).
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    final result = await ref.read(authRepositoryProvider).login(email, password);
    if (result.user != null) await _claimLocalData(result.user!.id);
    state = AsyncData(result);
    if (result.errorMessage != null) {
      AppLogger.warning('Login error: ${result.errorMessage}', tag: 'AuthNotifier');
    }
    if (result.user != null) {
      _rcLogIn(result.user!.id);
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).logout();
    _rcLogOut();
    // Données en mémoire oubliées (le compte suivant ne les voit jamais) ; la base
    // locale, elle, n'est vidée que si un autre compte se connecte (LocalDataOwner).
    ref.invalidate(collegesProvider);
    ref.invalidate(todayProvider);
    ref.invalidate(searchNotifierProvider);
    ref.invalidate(searchRecentsProvider);
    // Message d'achat d'une session passée : jamais montré au compte suivant.
    ref.invalidate(paywallProvider);
    state = const AsyncData(AuthState());
  }

  /// Revue 8.3 : un autre compte sur l'appareil → base locale vidée avant d'afficher
  /// quoi que ce soit. Borné dans le temps : la connexion n'est jamais bloquée.
  Future<void> _claimLocalData(String userId) async {
    try {
      await LocalDataOwner(storage: ref.read(secureStorageProvider), db: ref.read(databaseProvider))
          .claim(userId)
          .timeout(_kLocalWipeStepTimeout);
    } catch (e) {
      AppLogger.error('LocalDataOwner.claim failed', tag: 'AuthNotifier', error: e);
    }
  }

  Future<String?> updateProfile({
    String? firstName,
    String? yearGroup,
    String? faculty,
  }) async {
    _localWrites++;
    final result = await ref.read(authRepositoryProvider).updateProfile(
      firstName: firstName,
      yearGroup: yearGroup,
      faculty: faculty,
    );
    if (result.user != null) {
      state = AsyncData(result);
      return null;
    } else if (result.errorMessage != null) {
      AppLogger.warning('updateProfile error: ${result.errorMessage}', tag: 'AuthNotifier');
      return result.errorMessage;
    }
    return null;
  }

  /// Écritures locales du compte (profil, rappel) : un `/me` parti avant l'une
  /// d'elles rapporterait l'ancien état.
  int _localWrites = 0;

  /// Profil ouvert ou tiré pour rafraîchir (story 8.14) : relit `/me` (quota du
  /// mois, rappel). Un échec ne touche à rien : jamais de déconnexion ici.
  Future<void> refreshProfile() async {
    final startedFor = state.valueOrNull?.user?.id;
    final writes = _localWrites;
    if (startedFor == null) return;
    final result = await ref.read(authRepositoryProvider).refreshFromMe();
    final current = state.valueOrNull?.user;
    if (_disposed || result.user == null || current == null) return;
    // Autre compte entre-temps, ou modification locale plus récente : on garde l'affiché.
    if (current.id != startedFor || result.user!.id != startedFor || writes != _localWrites) return;
    state = AsyncData(result);
  }

  /// Rappel quotidien réglé côté serveur : mémorisé pour le prochain démarrage.
  Future<void> setReminderHour(int? hourUtc, {int? localHour}) async {
    _localWrites++;
    await ref.read(authRepositoryProvider).saveReminderHour(hourUtc, localHour: localHour);
    final current = state.valueOrNull;
    final user = current?.user;
    if (_disposed || current == null || user == null) return;
    state = AsyncData(current.copyWith(
      user: user.copyWith(reminderHourUtc: hourUtc, reminderLocalHour: hourUtc == null ? null : localHour),
    ));
  }

  /// Supprime le compte (backend) puis exécute le wipe local **dans l'ordre** :
  ///   1. `Purchases.logOut()` — RevenueCat (best-effort, try/catch + timeout)
  ///   2. `AppDatabase.deleteEverything()` — Drift (best-effort, try/catch + timeout)
  ///   3. `AuthRepository.logout()` — vide `flutter_secure_storage` (best-effort, try/catch)
  ///   4. `state = AsyncData(AuthState())` — TOUJOURS exécuté en dernier
  ///
  /// Si le DELETE serveur échoue, **rien** n'est wipé localement et le message
  /// d'erreur est retourné (toast destructive côté UI, session intacte).
  ///
  /// Réentrance : un appel concurrent (double-tap rapide sur « Supprimer
  /// définitivement ») attend le même résultat que le premier appel — pas de
  /// second DELETE serveur, pas de toast trompeur « Session expirée ».
  Future<String?> deleteAccount() async {
    final inFlight = _deleteInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }
    final completer = Completer<String?>();
    _deleteInFlight = completer;
    try {
      final result = await _performDeleteAccount();
      completer.complete(result);
      return result;
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    } finally {
      _deleteInFlight = null;
    }
  }

  Future<String?> _performDeleteAccount() async {
    final result = await ref.read(authRepositoryProvider).deleteAccount();
    if (result.errorMessage != null) {
      AppLogger.warning(
        'deleteAccount: server DELETE refused — session may be force-logged by '
        'interceptor depending on status (${result.errorMessage})',
        tag: 'AuthNotifier',
      );
      return result.errorMessage;
    }

    // Serveur OK → wipe local séquentiel, best-effort sur chaque étape, avec
    // timeout pour éviter qu'un SDK qui hang ne bloque indéfiniment l'UI.
    // RC d'abord car le SDK peut lire le user_id Apple persisté avant qu'on
    // vide le storage.
    try {
      await Purchases.logOut().timeout(_kLocalWipeStepTimeout);
    } on TimeoutException catch (e) {
      AppLogger.warning('RevenueCat logOut timed out during deleteAccount',
          tag: 'AuthNotifier', error: e);
    } catch (e) {
      AppLogger.warning('RevenueCat logOut failed during deleteAccount',
          tag: 'AuthNotifier', error: e);
    }

    try {
      await ref
          .read(databaseProvider)
          .deleteEverything()
          .timeout(_kLocalWipeStepTimeout);
    } on TimeoutException catch (e) {
      AppLogger.warning('Drift deleteEverything timed out during deleteAccount',
          tag: 'AuthNotifier', error: e);
    } catch (e) {
      AppLogger.warning('Drift deleteEverything failed during deleteAccount',
          tag: 'AuthNotifier', error: e);
    }

    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (e) {
      AppLogger.warning('secureStorage wipe failed during deleteAccount',
          tag: 'AuthNotifier', error: e);
    }

    // Toujours exécuté, même si une étape locale a échoué : le serveur a déjà
    // supprimé le compte, on doit sortir de la session pour éviter une boucle
    // 401. Guard `_disposed` : si le provider a été détruit pendant les awaits,
    // on évite un `StateError("...has been disposed")`.
    if (!_disposed) {
      state = const AsyncData(AuthState());
    }
    return null;
  }

  Future<void> refreshSubscription() async {
    final current = state.valueOrNull;
    if (current?.user == null) return;
    try {
      final response = await ref.read(authRepositoryProvider).refreshSubscriptionStatus();
      if (response.user != null) {
        state = AsyncData(response);
      }
    } catch (e) {
      AppLogger.error('Failed to refresh subscription', tag: 'AuthNotifier', error: e);
    }
  }

  // Fire-and-forget — non-bloquant par design (achat possible même si logIn échoue)
  void _rcLogIn(String userId) {
    () async {
      try {
        await Purchases.logIn(userId);
      } catch (e) {
        AppLogger.warning('RevenueCat logIn failed', tag: 'AuthNotifier', error: e);
      }
    }();
  }

  void _rcLogOut() {
    () async {
      try {
        await Purchases.logOut();
      } catch (e) {
        AppLogger.warning('RevenueCat logOut failed', tag: 'AuthNotifier', error: e);
      }
    }();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
