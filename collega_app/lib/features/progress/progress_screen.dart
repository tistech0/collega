import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/fr_dates.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/planning/domain/planning_summary.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/progress/progress_providers.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';

/// Onglet Progression (story 8.8, maquette `direction-d-fusion.html` écran 4) :
/// la valeur en titre, la grande barre, la semaine, les collèges, les rangs et
/// le planning — une seule grammaire (barre segmentée + anneau + chiffres).
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  static const tabIndex = 2;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> with TabReselectScrollMixin {
  final _scroll = ScrollController();

  // Après minuit (app en arrière-plan) : semaine, « aujourd'hui » et planning suivent.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _refreshIfNewDay);

  void _refreshIfNewDay() {
    ref.read(planningProvider.notifier).refreshIfNewDay();
    final state = ref.read(progressProvider).valueOrNull;
    if (state is! ProgressReady) return;
    final today = epochDayOf(ref.read(progressClockProvider)());
    if (!state.week.any((d) => d.isToday && epochDayOf(d.date) == today)) ref.invalidate(progressProvider);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle; // écoute le retour au premier plan
  }

  @override
  int get tabIndex => ProgressScreen.tabIndex;
  @override
  ScrollController get scrollController => _scroll;
  @override
  Duration get reselectDuration => CgMotion.resolve(context, CgMotion.base);
  @override
  Curve get reselectCurve => CgMotion.out;

  @override
  void dispose() {
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(collegesProvider);
    ref.invalidate(planningProvider);
    try {
      await ref.read(progressProvider.future);
    } catch (_) {
      // L'état d'erreur s'affiche dans la page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(progressProvider);
    final state = async.valueOrNull;

    String title = 'Progression';
    String? subtitle;
    final List<Widget> children;
    if (state == null && async.hasError && !async.isLoading) {
      children = [_centered(_errorState(async.error!))];
    } else if (state == null) {
      children = const [_ProgressSkeleton()];
    } else {
      switch (state) {
        case ProgressEmpty():
          children = [
            _centered(CgState.empty(
              title: 'Ta première session remplira cette page',
              message: 'Importe un collège : tes collèges, tes rangs et ta semaine apparaîtront ici.',
              actionLabel: 'Aller à la Bibliothèque',
              onAction: () => context.go('/colleges'),
              illustration: CgIllustration.done,
            )),
          ];
        case ProgressReady():
          final overall = state.overall;
          if (overall.drilled == 0) {
            title = _count(overall.total, 'fiche');
            subtitle = 'à découvrir · ta première session remplira cette page';
          } else {
            title = _percent(overall.masteryPercent);
            subtitle = 'de tes ${_count(overall.total, 'fiche')} sont maîtrisées';
          }
          children = _readyChildren(state);
      }
    }

    return CgPage(
      title: title,
      subtitle: subtitle,
      controller: _scroll,
      reserveTabBar: true,
      onRefresh: _refresh,
      children: children,
    );
  }

  Widget _errorState(Object error) => isNetworkUnreachable(error)
      ? CgState.offline(
          title: 'Pas de connexion pour l’instant',
          message: 'Ta progression s’affiche dès que Collega joint le serveur.',
          actionLabel: 'Réessayer',
          onAction: _refresh,
        )
      : CgState.error(
          title: 'Ta progression n’a pas pu se charger',
          message: 'Rien n’est perdu. Réessaie dans un instant.',
          actionLabel: 'Réessayer',
          onAction: _refresh,
        );

  List<Widget> _readyChildren(ProgressReady s) => [
        const SizedBox(height: CgSpace.s5),
        CgRankBar(
          mastered: s.overall.maitrise,
          good: s.overall.bien,
          review: s.overall.aRevoir,
          unseen: s.overall.notSeen,
          size: CgRankBarSize.hero,
          legend: true,
        ),
        CgSectionTitle('Cette semaine · ${_count(s.weekTotal, 'fiche')}'),
        _WeekBars(days: s.week),
        const CgSectionTitle('Par collège'),
        CgListGroup(children: [
          for (final c in s.colleges)
            CgListRow(
              title: c.name,
              subtitle: _collegeLabel(c.stats),
              leading: CgRing(
                value: c.stats.total == 0 ? 0 : c.stats.maitrise / c.stats.total,
                semanticLabel: 'Maîtrise de ${c.name}',
              ),
              trailing: CgRowTrailing.chevron,
              progress: CgRankBar(
                mastered: c.stats.maitrise,
                good: c.stats.bien,
                review: c.stats.aRevoir,
                unseen: c.stats.notSeen,
              ),
              onTap: () => context.push('/progress/colleges/${c.refId}'),
            ),
        ]),
        if (s.byRang.isNotEmpty) ...[
          const CgSectionTitle('Par rang'),
          CgListGroup(children: [
            for (final e in s.byRang.entries) _RangRow(rang: e.key, stats: e.value),
          ]),
        ],
        const CgSectionTitle('Planning'),
        CgListGroup(children: [_planningRow(s.planning)]),
      ];

  Widget _planningRow(PlanningState p) {
    final config = p.config;
    void open() => context.push('/progress/planning');
    if (config == null) {
      return CgListRow(
        title: 'Planifier tes révisions',
        subtitle: 'Choisis ta date d’examen : Collega répartit tes fiches.',
        leading: const CgRowIcon(CgIcons.calendar),
        trailing: CgRowTrailing.chevron,
        onTap: open,
      );
    }
    return CgListRow(
      title: '${frShortDate(config.startDate)} → ${frShortDate(config.endDate)}',
      subtitle: planningSummary(config, p, today: p.today),
      leading: const CgRowIcon(CgIcons.calendar),
      trailing: CgRowTrailing.chevron,
      onTap: open,
    );
  }
}

/// « 1 fiche », « 341 fiches ».
String _count(int n, String noun) => '$n ${n > 1 ? '${noun}s' : noun}';

/// « 31 % » (espace fine insécable : jamais coupé).
String _percent(int value) => '$value %';

/// « 177 fiches · 74 maîtrisées », ou « 164 fiches à découvrir ».
String _collegeLabel(DrillStats s) {
  if (s.drilled == 0) return '${_count(s.total, 'fiche')} à découvrir';
  return '${_count(s.total, 'fiche')} · ${s.maitrise} ${s.maitrise > 1 ? 'maîtrisées' : 'maîtrisée'}';
}

Widget _centered(Widget state) => Padding(
      padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
      child: state,
    );

/// Fiches révisées par jour, lundi → dimanche (toutes révisions confondues).
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<ProgressDay> days;

  static const _height = 72.0;
  static const _minBar = 4.0;
  static const _barWidth = 22.0;
  static const _radius = Radius.circular(CgRadius.badge);

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final max = days.fold(0, (m, d) => d.count > m ? d.count : m);
    return Row(children: [
      for (final d in days)
        Expanded(
          child: Semantics(
            container: true,
            label: [
              frWeekday(d.date),
              if (d.isToday) 'aujourd’hui',
              d.count == 0 ? 'aucune fiche' : _count(d.count, 'fiche'),
            ].join(', '),
            excludeSemantics: true,
            child: Column(children: [
              SizedBox(
                height: _height,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: _barWidth,
                    height: max == 0 || d.count == 0 ? _minBar : _minBar + (_height - _minBar) * d.count / max,
                    decoration: BoxDecoration(
                      color: d.count == 0 ? c.unseen : c.accent,
                      borderRadius: const BorderRadius.vertical(top: _radius, bottom: _radius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CgSpace.s1),
              Text(
                frWeekdayInitial(d.date),
                style: CgType.label.copyWith(
                  color: d.isToday ? c.accent : c.ink3,
                  fontWeight: d.isToday ? FontWeight.w700 : null,
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Rang : badge, barre, part maîtrisée (« à découvrir » avant tout drill).
class _RangRow extends StatelessWidget {
  const _RangRow({required this.rang, required this.stats});

  final String rang;
  final DrillStats stats;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final value = stats.drilled == 0 ? 'à découvrir' : _percent(stats.masteryPercent);
    return Semantics(
      container: true,
      label: 'Rang $rang, ${stats.drilled == 0 ? '${_count(stats.total, 'fiche')} à découvrir' : '$value maîtrisées, '
          '${stats.maitrise} sur ${stats.total}'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CgSpace.s3),
        // Valeur au-dessus de la barre : toutes les barres ont la même longueur.
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (const {'A', 'B', 'C'}.contains(rang)) CgBadge.rank(rang),
            const SizedBox(width: CgSpace.s3),
            Expanded(
              child: Text(
                stats.drilled == 0 ? _count(stats.total, 'fiche') : '${stats.maitrise} sur ${stats.total}',
                style: CgType.meta.copyWith(color: c.ink2, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(width: CgSpace.s3),
            Text(
              value,
              style: CgType.bodyS.copyWith(color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ]),
          const SizedBox(height: CgSpace.s2),
          CgRankBar(
            mastered: stats.maitrise,
            good: stats.bien,
            review: stats.aRevoir,
            unseen: stats.notSeen,
          ),
        ]),
      ),
    );
  }
}

class _ProgressSkeleton extends StatelessWidget {
  const _ProgressSkeleton();

  static const _heroBar = 22.0;
  static const _week = 88.0;
  static const _rows = 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CgSpace.s5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CgSkeleton.block(height: _heroBar, radius: CgRadius.badge),
        const SizedBox(height: CgSpace.section),
        const CgSkeleton.block(height: _week, radius: CgRadius.s),
        const SizedBox(height: CgSpace.section),
        for (var i = 0; i < _rows; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: CgSpace.row),
            child: Row(children: [
              CgSkeleton.ring(),
              SizedBox(width: CgSpace.s4),
              Expanded(child: CgSkeleton.line()),
            ]),
          ),
      ]),
    );
  }
}
