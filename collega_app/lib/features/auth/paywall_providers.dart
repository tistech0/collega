import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';

const kPaywallPurchaseFailed = 'L’achat n’a pas abouti. Réessaie dans un instant.';
const kPaywallPurchaseSyncing =
    'Achat reçu\u00A0: ton accès s’active dans un instant. S’il tarde, touche « Restaurer mes achats ».';
const kPaywallNothingToRestore = 'Aucun abonnement actif à restaurer sur ce compte Apple.';
const kPaywallRestoreFailed = 'La restauration n’a pas abouti. Réessaie dans un instant.';

class PaywallState {
  const PaywallState({
    this.package,
    this.isLoading = false,
    this.errorMessage,
  });

  final Package? package;
  final bool isLoading;
  final String? errorMessage;

  PaywallState copyWith({
    Package? package,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      PaywallState(
        package: package ?? this.package,
        isLoading: isLoading ?? this.isLoading,
        // errorMessage prend la priorité ; clearError n'efface que si aucun nouveau message
        errorMessage: errorMessage ?? (clearError ? null : this.errorMessage),
      );
}

class PaywallNotifier extends AsyncNotifier<PaywallState> {
  bool _purchasing = false;

  @override
  Future<PaywallState> build() async {
    final pkg = await ref.read(revenueCatServiceProvider).getMonthlyOffering();
    return PaywallState(package: pkg);
  }

  Future<void> purchase() async {
    if (_purchasing) return;
    final currentState = state.valueOrNull;
    if (currentState?.package == null) return;

    _purchasing = true;
    state = AsyncData(currentState!.copyWith(isLoading: true, clearError: true));
    try {
      // Identification RevenueCat avant achat — idempotent, non-bloquant si échec
      final userId = ref.read(authProvider).valueOrNull?.user?.id;
      if (userId != null) {
        try {
          await Purchases.logIn(userId);
        } catch (_) {}
      }

      await ref
          .read(revenueCatServiceProvider)
          .purchaseMonthlySubscription(currentState.package!);
      await ref.read(authProvider.notifier).refreshSubscription();

      // Réinitialise le loading ; si is_subscribed=true le router redirige automatiquement
      final hasAccess = ref.read(authProvider).valueOrNull?.hasAccess ?? false;
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        errorMessage: hasAccess ? null : kPaywallPurchaseSyncing,
      ));
    } on PlatformException catch (e) {
      // Annuler n'est pas une erreur : rien à dire.
      final cancelled = PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError;
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: cancelled ? null : kPaywallPurchaseFailed));
    } catch (_) {
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: kPaywallPurchaseFailed));
    } finally {
      _purchasing = false;
    }
  }

  Future<void> restorePurchases() async {
    final currentState = state.valueOrNull ?? const PaywallState();
    state = AsyncData(currentState.copyWith(isLoading: true, clearError: true));
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
      await ref.read(authProvider.notifier).refreshSubscription();
      final hasAccess = ref.read(authProvider).valueOrNull?.hasAccess ?? false;
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        errorMessage: hasAccess ? null : kPaywallNothingToRestore,
      ));
    } catch (_) {
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: kPaywallRestoreFailed));
    }
  }

  /// Offre introuvable (réseau, Store) : on la redemande.
  Future<void> retry() async {
    state = const AsyncLoading<PaywallState>().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }

  Future<void> openSubscriptionManagement() =>
      ref.read(revenueCatServiceProvider).openSubscriptionManagement();
}

final revenueCatServiceProvider = Provider<RevenueCatService>((_) => RevenueCatService());

final paywallProvider =
    AsyncNotifierProvider<PaywallNotifier, PaywallState>(PaywallNotifier.new);
