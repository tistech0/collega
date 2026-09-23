import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/fr_dates.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';
import 'package:collega_app/features/today/presentation/today_customize_sheet.dart';
import 'package:collega_app/features/today/today_providers.dart';

/// Onglet Aujourd'hui (story 8.3, maquette `direction-d-fusion.html` écran 1) :
/// la session du jour prête, la semaine, mes collèges. Un seul bouton primaire.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.now = DateTime.now});

  /// Horloge (injectée pour les tests et les goldens).
  final DateTime Function() now;

  static const tabIndex = 0;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _scroll = ScrollController();
  TabReselect? _reselect;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _refreshIfNewDay);

  @override
  void initState() {
    super.initState();
    _lifecycle; // écoute le retour au premier plan
  }

  /// App restée ouverte ou en arrière-plan après minuit : la session affichée est
  /// celle de la veille → Aujourd'hui se recalcule pour le nouveau jour.
  void _refreshIfNewDay() {
    final state = ref.read(todayProvider).valueOrNull;
    if (state is TodayReady && state.session.day != epochDayOf(widget.now())) {
      ref.invalidate(todayProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reselect = TabReselectScope.maybeOf(context);
    if (reselect != _reselect) {
      _reselect?.removeListener(_onReselect);
      _reselect = reselect?..addListener(_onReselect);
    }
  }

  void _onReselect() {
    if (_reselect?.index == TodayScreen.tabIndex && _scroll.hasClients) {
      _scroll.animateTo(0, duration: CgMotion.resolve(context, CgMotion.base), curve: CgMotion.out);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _reselect?.removeListener(_onReselect);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start(TodayReady state) async {
    await launchDrill(context, ref, DrillSessionParams.daily(state.session.day));
    // Au retour : progression, semaine et collèges ont pu changer.
    if (mounted) ref.invalidate(todayProvider);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final async = ref.watch(todayProvider);
    final state = async.valueOrNull;
    final ready = state is TodayReady ? state : null;
    final date = ready?.date ?? now;
    if (ready != null && ready.session.day != epochDayOf(now)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshIfNewDay();
      });
    }

    final List<Widget> children;
    if (state == null && async.hasError) {
      final offline = async.error is DioException;
      children = [_centered(offline
          ? CgState.offline(
              title: 'Pas de connexion pour l’instant',
              message: 'Rien n’est perdu : ta session se charge dès que Collega joint le serveur.',
              actionLabel: 'Réessayer',
              onAction: () => ref.read(todayProvider.notifier).refresh(),
            )
          : CgState.error(
              title: 'Ta session n’a pas pu se préparer',
              message: 'Rien n’est perdu. Réessaie dans un instant.',
              actionLabel: 'Réessayer',
              onAction: () => ref.read(todayProvider.notifier).refresh(),
            ))];
    } else if (state == null) {
      children = const [_TodaySkeleton()];
    } else {
      children = switch (state) {
        TodayNoCollege() => [_centered(CgState.empty(
            title: 'Importe ton premier collège',
            message: 'Choisis un collège dans la Bibliothèque : ses fiches arrivent en quelques minutes.',
            actionLabel: 'Aller à la Bibliothèque',
            onAction: () => context.go('/colleges'),
          ))],
        TodayPreparing(:final collegeName) => [_centered(CgState.empty(
            title: 'Ton premier collège est en préparation',
            message: '$collegeName : les fiches arrivent. Tu peux fermer Collega, on te prévient.',
            illustration: CgIllustration.done,
          ))],
        TodayReady() => _readyChildren(context, state),
      };
    }

    return CgPage(
      title: frDayTitle(date),
      subtitle: _subtitle(date, ready),
      controller: _scroll,
      reserveTabBar: true,
      trailing: _SearchAction(onTap: () => context.push('/search')),
      onRefresh: () => ref.read(todayProvider.notifier).refresh(),
      children: children,
    );
  }

  String _subtitle(DateTime date, TodayReady? ready) {
    final month = frMonth(date);
    if (ready?.planningDay == null) return month;
    return '$month · jour ${ready!.planningDay} sur ${ready.planningDays} du planning';
  }

  Widget _centered(Widget state) => Padding(
        padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
        child: state,
      );

  List<Widget> _readyChildren(BuildContext context, TodayReady s) => [
        const SizedBox(height: _TodayScreenLayout.heroGap),
        _Hero(
          state: s,
          onStart: () => _start(s),
          onCustomize: () => showTodayCustomizeSheet(context, s),
        ),
        const CgSectionTitle('Cette semaine'),
        _Week(days: s.week),
        if (s.colleges.isNotEmpty) ...[
          const CgSectionTitle('Mes collèges'),
          CgListGroup(children: [
            for (final college in s.colleges)
              CgListRow(
                title: college.name,
                subtitle: _collegeSubtitle(college),
                leading: CgRowIcon(collegeCatalogEntry(college.refId)?.icon ?? CgIcons.library),
                trailing: CgRowTrailing.chevron,
                progress: CgRankBar(
                  mastered: college.stats.maitrise,
                  good: college.stats.bien,
                  review: college.stats.aRevoir,
                  unseen: college.stats.notSeen,
                ),
                // push : le détail garde son retour vers Aujourd'hui.
                onTap: () => context.push('/home/colleges/${college.refId}'),
              ),
          ]),
        ],
      ];

}

String _collegeSubtitle(TodayCollege c) {
  final total = c.stats.total;
  if (c.stats.drilled == 0) return '$total fiches à découvrir';
  // Espace fine insécable : « 42 % » ne se coupe jamais.
  return '$total fiches · ${c.stats.masteryPercent}\u202F% maîtrisées';
}

/// « rang A », « rangs A–B », « rangs A, C ».
String _rangsLabel(List<String> rangs) {
  if (rangs.length == 1) return 'rang ${rangs.single}';
  const order = 'ABC';
  final contiguous = order.contains(rangs.join());
  return contiguous ? 'rangs ${rangs.first}–${rangs.last}' : 'rangs ${rangs.join(', ')}';
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      container: true,
      button: true,
      label: 'Rechercher',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CgSpace.tapTarget,
          child: Center(child: CgIcon(CgIcons.search, color: c.accent)),
        ),
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.state, required this.onStart, required this.onCustomize});

  final TodayReady state;
  final VoidCallback onStart;
  final VoidCallback onCustomize;

  static const _maxMixRows = 3;
  static const _compactWidth = 390.0;
  static const _numeralCompactSize = 52.0;
  static const _numeralGap = 10.0;
  static const _mixGap = 14.0;
  static const _actionsGap = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final session = state.session;
    if (session.isCompleted) return _Done(state: state);
    if (state.cardCount == 0) {
      return _Message(
        title: 'Tout est à jour',
        message: 'Aucune fiche n’est à revoir aujourd’hui. Reviens demain, ou importe un autre collège.',
      );
    }

    if (state.postponedToday && !session.isStarted) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Message(
          title: 'Session décalée à demain',
          message: 'Ton planning a été prolongé d’un jour, sans rien perdre. Tu peux quand même réviser.',
        ),
        const SizedBox(height: _actionsGap),
        CgButton(label: 'Réviser quand même', onPressed: onStart),
      ]);
    }

    final compact = MediaQuery.sizeOf(context).width < _compactWidth;
    final numeralStyle = CgType.numeral.copyWith(
      color: c.ink,
      fontSize: compact ? _numeralCompactSize : null,
    );
    final started = session.isStarted;
    final total = session.cardIds.length;
    final remaining = total - session.position;

    final number = CgTextScaleCap(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: _numeralGap,
        children: [
          Text(started ? '${session.position}' : '${state.cardCount}', style: numeralStyle),
          Padding(
            padding: const EdgeInsets.only(bottom: CgSpace.s2),
            child: Text(
              started ? 'sur $total fiches' : 'fiches · ${state.minutes} min',
              style: CgType.body.copyWith(color: c.ink2),
            ),
          ),
        ],
      ),
    );

    final shown = state.mix.take(_maxMixRows).toList();
    final hidden = state.mix.length - shown.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        label: started
            ? '${session.position} fiches sur $total, $remaining restantes'
            : '${state.cardCount} fiches, ${state.minutes} minutes',
        excludeSemantics: true,
        child: number,
      ),
      if (started)
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.s1),
          child: Text(
            'Il reste $remaining fiches · ${estimatedMinutesLabel(remaining)}',
            style: CgType.bodyS.copyWith(color: c.ink2),
          ),
        ),
      const SizedBox(height: _mixGap),
      for (final m in shown) _MixRow(label: m.collegeName, value: '${m.count} · ${_rangsLabel(m.rangs)}'),
      if (hidden > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: CgSpace.s2),
          child: Text('et $hidden autres', style: CgType.bodyS.copyWith(color: c.ink2)),
        ),
      if (state.toReview > 0) _MixRow(label: 'dont à revoir', value: '${state.toReview}'),
      const SizedBox(height: _actionsGap),
      CgButton(label: started ? 'Reprendre' : 'Commencer', onPressed: onStart),
      if (!started)
        CgButton(label: 'Personnaliser la session', onPressed: onCustomize, variant: CgButtonVariant.quiet),
    ]);
  }
}

/// « 8 min » restantes (même convention que le moteur : 1 fiche ≈ 50 s).
String estimatedMinutesLabel(int cards) => '${estimatedMinutes(cards)} min';

class _MixRow extends StatelessWidget {
  const _MixRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: CgSpace.s2),
      child: MergeSemantics(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: CgSpace.s3,
          children: [
            Text(label, style: CgType.bodyS.copyWith(color: c.ink, fontWeight: FontWeight.w600)),
            Text(value, style: CgType.bodyS.copyWith(color: c.ink2)),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.state});

  final TodayReady state;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final mastered = state.verdicts['maitrise'] ?? 0;
    final good = state.verdicts['bien'] ?? 0;
    final review = state.verdicts['a_revoir'] ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('Session faite', style: CgType.title.copyWith(color: c.ink))),
      const SizedBox(height: CgSpace.s2),
      Text(
        '$mastered maîtrisées · $good bien · $review à revoir',
        style: CgType.bodyS.copyWith(color: c.ink2),
      ),
      const SizedBox(height: CgSpace.s3),
      CgRankBar(mastered: mastered, good: good, review: review, unseen: 0, size: CgRankBarSize.header),
      const SizedBox(height: CgSpace.s4),
      Text('Prochaine session demain', style: CgType.bodyS.copyWith(color: c.ink2)),
    ]);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(title, style: CgType.title.copyWith(color: c.ink))),
      const SizedBox(height: CgSpace.s2),
      Text(message, style: CgType.bodyS.copyWith(color: c.ink2)),
    ]);
  }
}

// ─── Semaine ──────────────────────────────────────────────────────────────────

class _Week extends StatelessWidget {
  const _Week({required this.days});

  final List<TodayWeekDay> days;

  static const _dotMaxSize = 40.0;
  static const _dotBorder = 1.5;
  static const _todayBorder = 2.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(top: CgSpace.s2),
      child: Row(children: [
        for (final d in days)
          Expanded(
            child: Semantics(
              container: true,
              label: [
                frWeekday(d.date),
                if (d.isToday) 'aujourd’hui',
                if (d.done) 'session faite',
              ].join(', '),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CgSpace.s1 - 1),
                child: Column(children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _dotMaxSize),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d.done ? c.accent : c.surface,
                          border: Border.all(
                            color: d.done || d.isToday ? c.accent : c.line,
                            width: d.isToday ? _todayBorder : _dotBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CgSpace.s1),
                  Text(frWeekdayInitial(d.date), style: CgType.label.copyWith(color: c.ink3)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─── Chargement ───────────────────────────────────────────────────────────────

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  static const _heroHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: _TodayScreenLayout.heroGap),
      // Chaque forme pulse elle-même (CgSkeleton / CgSkeletonList).
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CgSkeleton.block(height: _heroHeight),
        SizedBox(height: CgSpace.section),
        CgSkeletonList(rows: 2),
      ]),
    );
  }
}

abstract final class _TodayScreenLayout {
  static const heroGap = 28.0;
}
