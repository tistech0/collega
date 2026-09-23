import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart' show leaveDrill;
import 'package:collega_app/features/today/domain/daily_session_builder.dart';
import 'package:collega_app/features/today/today_providers.dart';

/// Fin de session (story 8.5, maquette écran 3 : haut Bloc, bas Feuille) — le pic
/// de la Peak-end rule : un score, ce qui est consolidé, la prochaine session,
/// une seule action. Rien à déclarer : la session du jour est déjà close.
class DrillEndScreen extends ConsumerStatefulWidget {
  const DrillEndScreen({super.key, required this.session, required this.notifier, required this.params});

  final DrillSessionState session;
  final DrillSessionNotifier notifier;
  final DrillSessionParams params;

  @override
  ConsumerState<DrillEndScreen> createState() => _DrillEndScreenState();
}

class _DrillEndScreenState extends ConsumerState<DrillEndScreen> {
  static const _maxConsolidated = 3;

  late final Future<List<String>> _consolidated = ref.read(drillRepositoryProvider).itemTitles([
    for (final card in widget.session.cards)
      if (widget.session.evaluations[card.id] == DrillEvaluationResult.maitrise) card.itemId,
  ]);

  /// Calculée une fois à l'apparition (pas à chaque reconstruction).
  late final String _duration = formatSessionDuration(
    widget.session.startedAt == null ? Duration.zero : DateTime.now().difference(widget.session.startedAt!),
  );

  @override
  void initState() {
    super.initState();
    // Succès seulement s'il y a eu quelque chose à juger.
    if (widget.session.evaluations.isNotEmpty) CgHaptics.success();
  }

  void _finish() {
    if (widget.params.fromSearch) {
      // Retour à Aujourd'hui, recalculé. La sheet de recherche (route sans page,
      // restée sous le drill) se ferme d'abord : `go` garderait la page du shell
      // à laquelle elle est accrochée (revue 8.10).
      ref.invalidate(todayProvider);
      final router = GoRouter.of(context);
      var drillPopped = false;
      // Le drill (au sommet), puis toutes les routes sans page jusqu'à la page du shell.
      Navigator.of(context, rootNavigator: true).popUntil((route) {
        if (!drillPopped) {
          drillPopped = true;
          return false;
        }
        return route.settings is Page;
      });
      router.go('/home');
    } else {
      leaveDrill(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final summary = DrillSessionSummary.fromEvaluations(widget.session.evaluations);
    final review = summary.aRevoirCount;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (summary.total == 0) return _NothingJudged(onFinish: _finish, bottom: bottom);
    // Aujourd'hui n'est lu que pour la session du jour (budget de demain).
    final today = widget.params.isDailySession ? ref.watch(todayProvider).valueOrNull : null;
    final budget = today is TodayReady ? today.tomorrowBudget : kDefaultSessionCards;

    return ColoredBox(
      color: c.ground,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ScoreBlock(summary: summary, duration: _duration),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: CgSpace.s6),
                  _Stats(summary: summary),
                  FutureBuilder<List<String>>(
                    future: _consolidated,
                    builder: (context, snapshot) {
                      final titles = snapshot.data ?? const [];
                      if (titles.isEmpty) return const SizedBox.shrink();
                      final shown = titles.take(_maxConsolidated).join(', ');
                      final hidden = titles.length - _maxConsolidated;
                      // Espaces insécables : « et 1 autre » ne se coupe jamais.
                      final more = hidden <= 0 ? '' : ', et\u00A0$hidden\u00A0${hidden == 1 ? 'autre' : 'autres'}';
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const CgSectionTitle('Ce que tu as consolidé'),
                        Text('$shown$more.', style: CgType.bodyS.copyWith(color: c.ink2)),
                      ]);
                    },
                  ),
                  if (widget.params.isDailySession) ...[
                    const CgSectionTitle('Prochaine session'),
                    Text(
                      'Demain · $budget fiches${review > 0 ? ' · à revoir en priorité' : ''}',
                      style: CgType.bodyS.copyWith(color: c.ink2),
                    ),
                  ],
                  const SizedBox(height: CgSpace.s6),
                ]),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.s3, CgSpace.gutter, bottom + CgSpace.s3),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CgButton(label: 'Terminer', onPressed: _finish),
            if (review > 0)
              CgButton(
                label: review == 1 ? 'Refaire la fiche à revoir' : 'Refaire les $review à revoir',
                variant: CgButtonVariant.quiet,
                onPressed: widget.notifier.restartWithErrors,
              ),
            if (widget.params.fromSearch)
              CgButton(
                label: 'Retour à la recherche',
                variant: CgButtonVariant.quiet,
                onPressed: () => leaveDrill(context),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Haut Bloc : score qui s'incrémente, barre blanche segmentée.
class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.summary, required this.duration});

  final DrillSessionSummary summary;
  final String duration;

  static const _topGap = 56.0;
  static const _barHeight = 10.0;
  static const _barGap = 3.0;
  static const _mutedAlpha = 0.72;
  static const _totalAlpha = 0.6;
  static const _goodAlpha = 0.5;
  static const _totalSize = 34.0;
  static const _labelSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final top = MediaQuery.paddingOf(context).top;
    final total = summary.total;
    final muted = c.accentInk.withValues(alpha: _mutedAlpha);
    return Container(
      padding: EdgeInsets.fromLTRB(CgSpace.gutter, top + _topGap - CgSpace.s6, CgSpace.gutter, CgSpace.s6),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(CgRadius.l)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Session terminée · $duration', style: CgType.bodyS.copyWith(color: muted)),
        const SizedBox(height: CgSpace.s3),
        Semantics(
          container: true,
          label: summary.maitrisCount == 1
              ? '1 fiche maîtrisée sur $total'
              : '${summary.maitrisCount} fiches maîtrisées sur $total',
          excludeSemantics: true,
          child: CgTextScaleCap(
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              _CountUp(value: summary.maitrisCount, style: CgType.score.copyWith(color: c.accentInk)),
              Text(
                '/$total',
                style: CgType.score.copyWith(
                  fontSize: _totalSize,
                  letterSpacing: 0,
                  color: c.accentInk.withValues(alpha: _totalAlpha),
                ),
              ),
            ]),
          ),
        ),
        // Déjà dit par le libellé VoiceOver du score : lu une seule fois.
        ExcludeSemantics(
          child: Text(
            summary.maitrisCount == 1 ? 'maîtrisée' : 'maîtrisées',
            style: CgType.title.copyWith(fontSize: _labelSize, color: c.accentInk),
          ),
        ),
        const SizedBox(height: CgSpace.s5),
        // La barre s'étend à l'apparition (spec § Mouvement : fin de session).
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: CgMotion.resolve(context, CgMotion.ringFill),
          curve: CgMotion.out,
          builder: (context, t, child) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: t, child: child),
          ),
          child: ClipRRect(
          key: const Key('end-score-bar'),
          borderRadius: BorderRadius.circular(_barHeight / 2),
          child: SizedBox(
            height: _barHeight,
            // stretch : sans enfant, une ColoredBox prendrait une hauteur nulle.
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (count, color) in [
                (summary.maitrisCount, c.accentInk),
                (summary.bienCount, c.accentInk.withValues(alpha: _goodAlpha)),
                (summary.aRevoirCount, c.review),
              ])
                if (count > 0)
                  Expanded(
                    flex: count,
                    child: Padding(
                      padding: const EdgeInsets.only(right: _barGap),
                      child: ColoredBox(color: color),
                    ),
                  ),
            ]),
          ),
        ),
        ),
      ]),
    );
  }
}

/// Chiffre qui roule de 0 à la valeur (une fois) ; valeur directe en mouvement réduit.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: CgMotion.resolve(context, CgMotion.ringFill),
      curve: CgMotion.out,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// Bas Feuille : trois chiffres à filet coloré (couleur + mot, jamais la couleur seule).
class _Stats extends StatelessWidget {
  const _Stats({required this.summary});

  final DrillSessionSummary summary;

  static const _ruleWidth = 2.0;
  static const _valueSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Row(children: [
      for (final (value, label, color) in [
        (summary.maitrisCount, summary.maitrisCount == 1 ? 'maîtrisée' : 'maîtrisées', c.mastered),
        (summary.bienCount, 'bien', c.good),
        (summary.aRevoirCount, 'à revoir', c.review),
      ]) ...[
        Expanded(
          child: MergeSemantics(
            child: Container(
              padding: const EdgeInsets.only(top: CgSpace.s3),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: color, width: _ruleWidth))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$value', style: CgType.display.copyWith(fontSize: _valueSize, color: c.ink)),
                Text(label, style: CgType.label.copyWith(color: c.ink2)),
              ]),
            ),
          ),
        ),
        if (label != 'à revoir') const SizedBox(width: CgSpace.s2),
      ],
    ]);
  }
}

/// « 19 min », « 1 h 12 », « moins d'une minute ».
String formatSessionDuration(Duration d) {
  if (d.inMinutes < 1) return 'moins d’une minute';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  return '${d.inHours} h $minutes';
}

/// Rien de jugé (session vidée par un réimport) : pas de score 0/0, pas de succès.
class _NothingJudged extends StatelessWidget {
  const _NothingJudged({required this.onFinish, required this.bottom});

  final VoidCallback onFinish;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ColoredBox(
      color: c.ground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(CgSpace.gutter, 0, CgSpace.gutter, bottom + CgSpace.s3),
        child: Column(children: [
          const Expanded(
            child: Center(
              child: CgState.empty(
                title: 'Aucune fiche à réviser',
                message: 'Les fiches de cette session ont été renouvelées. Ta prochaine session les reprendra.',
                illustration: CgIllustration.done,
              ),
            ),
          ),
          CgButton(label: 'Terminer', onPressed: onFinish),
        ]),
      ),
    );
  }
}
