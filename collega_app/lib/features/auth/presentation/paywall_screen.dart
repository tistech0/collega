import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywallAsync = ref.watch(paywallProvider);

    ref.listen<AsyncValue<PaywallState>>(paywallProvider, (_, next) {
      final errorMessage = next.valueOrNull?.errorMessage;
      if (errorMessage != null && context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur'),
            description: Text(errorMessage),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: paywallAsync.when(
          loading: () => const Center(child: ShadProgress()),
          error: (_, __) => _PaywallContent(state: const PaywallState()),
          data: (state) => _PaywallContent(state: state),
        ),
      ),
    );
  }
}

class _PaywallContent extends ConsumerWidget {
  const _PaywallContent({required this.state});

  final PaywallState state;

  String _priceLabel(Package? package) {
    final priceStr = package?.storeProduct.priceString;
    if (priceStr != null) return '$priceStr/mois';
    return '~9€/mois';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sectionSpacing * 2),
          Text(
            'AppMédecine Premium',
            style: AppTypography.displayMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Accédez à toutes les fonctionnalités pour préparer votre internat.',
            style: AppTypography.bodyMedium().copyWith(color: AppColors.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          _PriceCard(priceLabel: _priceLabel(state.package)),
          const SizedBox(height: AppSpacing.sectionSpacing),
          if (state.isLoading) ...[
            const ShadProgress(),
          ] else ...[
            ShadButton(
              onPressed: () => ref.read(paywallProvider.notifier).purchase(),
              child: const Text("S'abonner"),
            ),
            const SizedBox(height: 12),
            ShadButton.ghost(
              onPressed: () => ref.read(paywallProvider.notifier).restorePurchases(),
              child: const Text('Restaurer mes achats'),
            ),
          ],
          const SizedBox(height: 12),
          // Compte sans accès : jamais bloqué ici (le routeur ramène au paywall
          // depuis la démo) ; l'écran est refait en story 8.14.
          ShadButton.ghost(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('Se déconnecter'),
          ),
          const SizedBox(height: 4),
          ShadButton.ghost(
            onPressed: () => ref.read(paywallProvider.notifier).openSubscriptionManagement(),
            child: const Text('Gérer mon abonnement'),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.priceLabel});
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              priceLabel,
              style: AppTypography.displayMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Engagement mensuel — résiliable à tout moment',
              style: AppTypography.labelMedium().copyWith(color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
