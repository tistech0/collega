import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/demo/demo_providers.dart';
import 'package:collega_app/features/demo/domain/demo_data.dart';

/// Démo (story 8.12, spec v2 § Parcours 1) : les fiches d'exemple dans le vrai
/// drill (gestes + boutons), puis un récap qui invite à se connecter.
class DemoScreen extends ConsumerWidget {
  const DemoScreen({super.key});

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoDrillProvider);
    final notifier = ref.read(demoDrillProvider.notifier);
    final cards = demoCollege.item.cards;
    final c = CgTheme.of(context).colors;

    if (state.isComplete) return _Recap(state: state, onRestart: notifier.restart, onClose: () => _leave(context));

    final card = cards[state.currentIndex];
    return ColoredBox(
      color: c.accent,
      child: CgDrillCard(
        cardKey: '${card.id}#${state.currentIndex}',
        question: card.front,
        answer: card.back,
        rank: card.rang,
        collegeName: demoCollege.name,
        index: state.currentIndex + 1,
        total: cards.length,
        contextLabel: 'Démo',
        showFlipHint: state.currentIndex == 0,
        onVerdict: notifier.judge,
        onClose: () => _leave(context),
      ),
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({required this.state, required this.onRestart, required this.onClose});

  final DemoDrillState state;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final mastered = state.count(CgVerdict.mastered);
    final good = state.count(CgVerdict.good);
    final review = state.count(CgVerdict.review);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: c.ground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(CgSpace.gutter, 0, CgSpace.gutter, bottom + CgSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Semantics(
                    header: true,
                    child: Text('Démo terminée', style: CgType.titleL.copyWith(color: c.ink)),
                  ),
                  const SizedBox(height: CgSpace.s2),
                  Text(
                    '$mastered ${mastered > 1 ? 'maîtrisées' : 'maîtrisée'} · $good bien · $review à revoir',
                    style: CgType.body.copyWith(color: c.ink2),
                  ),
                  const SizedBox(height: CgSpace.s4),
                  CgRankBar(mastered: mastered, good: good, review: review, unseen: 0, size: CgRankBarSize.header),
                  const SizedBox(height: CgSpace.section),
                  Text(
                    'Avec ton compte, Collega transforme les PDF de tes collèges en fiches comme celles-ci '
                    'et te prépare une session chaque jour.',
                    style: CgType.body.copyWith(color: c.ink),
                  ),
                ]),
              ),
            ),
            CgButton(label: 'Se connecter', onPressed: () => context.go('/auth/login')),
            CgButton(label: 'Recommencer', variant: CgButtonVariant.quiet, onPressed: onRestart),
            CgButton(label: 'Fermer', variant: CgButtonVariant.quiet, onPressed: onClose),
          ]),
        ),
      ),
    );
  }
}
