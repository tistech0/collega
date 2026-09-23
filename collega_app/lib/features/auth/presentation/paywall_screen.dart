import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/paywall_providers.dart';

/// Ce que l'abonnement donne (spec v2 § Paywall : bénéfices avant le prix).
const _benefits = [
  (CgIcons.document, 'Tes collèges en fiches', 'Importe les PDF officiels\u00A0: les fiches se font seules'),
  (CgIcons.calendar, 'Une session par jour', 'Réglée sur ton planning, jusqu’à l’examen'),
  (CgIcons.search, 'Recherche dans tes collèges', 'Retrouve la phrase exacte et son item'),
  (CgIcons.cloudOff, 'Révision hors-ligne', 'Tes fiches restent sur ton iPhone'),
];

/// Paywall (story 8.14) : compte connecté sans accès. Bloc de marque, bénéfices,
/// prix du Store (jamais inventé), un seul primaire ; on peut toujours se déconnecter.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static const errorKey = ValueKey('paywall-error');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CgTheme.of(context).colors;
    final async = ref.watch(paywallProvider);
    final state = async.valueOrNull;
    final notifier = ref.read(paywallProvider.notifier);
    final price = state?.package?.storeProduct.priceString;
    final loadingOffer = state == null && async.isLoading;
    final busy = state?.isLoading ?? false;
    final unavailable = !loadingOffer && price == null;

    final primary = unavailable
        ? CgButton(label: 'Réessayer', loading: async.isLoading, onPressed: notifier.retry)
        : CgButton(label: 'S’abonner', loading: busy || loadingOffer, onPressed: notifier.purchase);

    return ColoredBox(
      color: c.ground,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.s4, CgSpace.gutter, CgSpace.s4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _BrandBlock(),
                const CgSectionTitle('Ce que tu débloques'),
                CgListGroup(variant: CgListVariant.inset, children: [
                  for (final (icon, title, subtitle) in _benefits)
                    CgListRow(title: title, subtitle: subtitle, leading: CgRowIcon(icon)),
                ]),
                const SizedBox(height: CgSpace.section),
                if (loadingOffer)
                  const CgSkeletonList(rows: 1)
                else if (price != null)
                  _Price(price: price)
                else
                  Text(
                    'L’abonnement n’est pas disponible pour l’instant. Vérifie ta connexion et réessaie.',
                    style: CgType.body.copyWith(color: c.ink2),
                  ),
                if (state?.errorMessage != null) ...[
                  const SizedBox(height: CgSpace.s4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state!.errorMessage!,
                      key: errorKey,
                      style: CgType.bodyS.copyWith(color: c.danger),
                    ),
                  ),
                ],
                const SizedBox(height: CgSpace.section),
                CgButton(
                  label: 'Restaurer mes achats',
                  variant: CgButtonVariant.quiet,
                  onPressed: busy || loadingOffer ? null : notifier.restorePurchases,
                ),
                CgButton(
                  label: 'Se déconnecter',
                  variant: CgButtonVariant.quiet,
                  onPressed: busy ? null : () => ref.read(authProvider.notifier).logout(),
                ),
                const _LegalLinks(),
              ]),
            ),
          ),
          // Un seul bouton ancré : les actions secondaires suivent le contenu
          // (Dynamic Type : le pied ne mange jamais l'écran).
          Padding(
            padding: const EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.s2, CgSpace.gutter, CgSpace.s2),
            child: primary,
          ),
        ]),
      ),
    );
  }
}

/// Bloc `accent` : wordmark, nom de l'offre, promesse.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  static const _wordmarkHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.all(CgSpace.s6),
      decoration: BoxDecoration(color: c.accent, borderRadius: CgRadius.lAll),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          label: 'Collega',
          excludeSemantics: true,
          child: CgWordmark(height: _wordmarkHeight, color: c.accentInk),
        ),
        const SizedBox(height: CgSpace.s5),
        Semantics(
          header: true,
          child: Text('Collega Premium', style: CgType.title.copyWith(color: c.accentInk)),
        ),
        const SizedBox(height: CgSpace.s2),
        Text(
          'Tes collèges deviennent des fiches à réviser, un peu chaque jour.',
          style: CgType.body.copyWith(color: c.accentInk),
        ),
      ]),
    );
  }
}

/// Prix du Store, lu en entier (« 9,99 € par mois, sans engagement… »).
class _Price extends StatelessWidget {
  const _Price({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return MergeSemantics(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CgTextScaleCap(child: Text(price, style: CgType.numeral.copyWith(color: c.ink))),
        Text(
          'par mois · sans engagement, résiliable dans Réglages',
          style: CgType.bodyS.copyWith(color: c.ink2),
        ),
      ]),
    );
  }
}

/// CGU et confidentialité, accessibles avant l'achat (App Store 3.1.2).
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    Widget link(String label, String path) => Semantics(
          button: true,
          link: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(path),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: CgType.meta.copyWith(color: c.ink2, decoration: TextDecoration.underline)),
              ),
            ),
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: CgSpace.s5,
      children: [
        link('Conditions d’utilisation', '/legal/cgu'),
        link('Confidentialité', '/legal/privacy'),
      ],
    );
  }
}
