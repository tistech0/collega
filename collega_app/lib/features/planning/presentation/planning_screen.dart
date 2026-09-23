import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/fr_dates.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/planning/domain/planning_summary.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/env.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/today_providers.dart';

/// Jours du planning dont la session du jour a été faite (calendrier), et si la
/// session d'aujourd'hui est commencée (on ne décale plus une session entamée).
final planningDaysProvider = FutureProvider.autoDispose<({Set<int> done, bool todayStarted})>((ref) async {
  final planning = await ref.watch(planningProvider.future);
  final config = planning.config;
  if (config == null) return (done: const <int>{}, todayStarted: false);
  final repo = DailySessionRepository(ref.watch(databaseProvider));
  final done = await repo.completedDays(from: epochDayOf(config.startDate), to: epochDayOf(config.endDate));
  final today = await repo.find(planning.today);
  return (done: done, todayStarted: today?.isStarted ?? false);
});

/// Planning (story 8.9) : formulaire avec aperçu vivant tant qu'il n'y a pas de
/// planning (ou pour planifier à nouveau), sinon la vue du planning — période,
/// calendrier, « Décaler aujourd'hui ».
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  // Après minuit (app en arrière-plan) : le calendrier et « Décaler » suivent le nouveau jour.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(planningProvider.notifier).refreshIfNewDay(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // écoute le retour au premier plan
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static const minuteOptions = [15, 30, 45, 60];
  static const _defaultMinutes = 30;
  static const _defaultDays = 30;
  static const _maxDays = 730;

  /// Formulaire affiché alors qu'un planning existe (« Planifier à nouveau »).
  bool _replanning = false;

  /// Valeurs du formulaire ; `null` tant qu'il n'a pas été initialisé.
  Set<String>? _collegeIds;
  late DateTime _start;
  late DateTime _end;
  int _minutes = _defaultMinutes;
  bool _saving = false;
  bool _busy = false;

  DateTime get _today {
    final now = ref.read(planningClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  /// Formulaire prérempli : le planning existant, sinon tous les collèges prêts
  /// sur 30 jours à partir d'aujourd'hui.
  void _initForm(List<CollegeListEntry> ready, PlanningConfig? config) {
    final readyIds = {for (final e in ready) e.userStatus!.collegeId};
    final today = _today;
    if (config != null) {
      final kept = config.collegeIds.toSet().intersection(readyIds);
      _collegeIds = kept.isEmpty ? readyIds : kept;
      _start = config.startDate.isBefore(today) ? today : config.startDate;
      _end = config.endDate.isBefore(_start) ? _start : config.endDate;
      _minutes = minuteOptions.contains(config.dailyMinutes) ? config.dailyMinutes : _nearest(config.dailyMinutes);
    } else {
      _collegeIds = readyIds;
      _start = today;
      // Jours civils (jamais + n × 24 h : dérive au changement d'heure).
      _end = DateTime(today.year, today.month, today.day + _defaultDays - 1);
      _minutes = _defaultMinutes;
    }
  }

  static int _nearest(int minutes) =>
      minuteOptions.reduce((a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b);

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/progress');
    }
  }

  Future<void> _plan() async {
    final ids = _collegeIds;
    if (_saving || ids == null || ids.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(planningProvider.notifier).plan(
            collegeIds: ids.toList(),
            startDate: _start,
            endDate: _end,
            dailyMinutes: _minutes,
          );
      CgHaptics.success();
      if (mounted) setState(() => _replanning = false);
    } catch (_) {
      if (mounted) showCgToast(context, 'Le planning n’a pas pu s’enregistrer. Réessaie.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      CgHaptics.selection();
    } catch (_) {
      if (mounted) showCgToast(context, 'Le planning n’a pas pu être mis à jour. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({required bool exam}) async {
    final today = _today;
    final first = exam ? _start : today;
    final last = DateTime(today.year, today.month, today.day + _maxDays);
    var picked = exam ? _end : _start;
    if (picked.isBefore(first)) picked = first;
    if (picked.isAfter(last)) picked = last;
    final result = await showCgSheet<DateTime>(
      context,
      title: exam ? 'Date d’examen' : 'Début du planning',
      builder: (_) => _DatePickerBody(initial: picked, first: first, last: last, onChanged: (d) => picked = d),
      primary: Builder(
        builder: (sheetContext) => CgButton(
          label: 'Valider',
          onPressed: () => Navigator.of(sheetContext, rootNavigator: true).pop(picked),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final day = DateTime(result.year, result.month, result.day);
    setState(() {
      if (exam) {
        _end = day;
      } else {
        _start = day;
        if (_end.isBefore(_start)) _end = _start;
      }
    });
  }

  Future<void> _openActions() => showCgActionSheet(
        context,
        actions: [
          CgSheetAction(
            label: 'Supprimer le planning',
            destructive: true,
            onPressed: () async {
              final confirmed = await showCgDialogSheet(
                context,
                title: 'Supprimer le planning ?',
                message: 'Tes fiches et ta progression restent. La session du jour reprendra tous tes collèges '
                    'et ton réglage de fiches par session.',
                confirmLabel: 'Supprimer',
                cancelLabel: 'Annuler',
                destructive: true,
              );
              if (!confirmed || !mounted) return;
              try {
                await ref.read(planningProvider.notifier).clear();
                if (mounted) setState(() => _collegeIds = null);
              } catch (_) {
                if (mounted) showCgToast(context, 'Le planning n’a pas pu être supprimé. Réessaie.');
              }
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final planningAsync = ref.watch(planningProvider);
    final collegesAsync = ref.watch(collegesProvider);
    final planning = planningAsync.valueOrNull;
    final entries = collegesAsync.valueOrNull;

    if (planning == null || entries == null) {
      final error = planningAsync.error ?? collegesAsync.error;
      if (error != null && !planningAsync.isLoading && !collegesAsync.isLoading) {
        void retry() {
          ref.invalidate(planningProvider);
          ref.invalidate(collegesProvider);
        }

        return _page(title: 'Planning', children: [
          _centered(isNetworkUnreachable(error)
              ? CgState.offline(
                  title: 'Pas de connexion pour l’instant',
                  message: 'Le planning s’ouvre dès que Collega joint le serveur.',
                  actionLabel: 'Réessayer',
                  onAction: retry,
                )
              : CgState.error(
                  title: 'Le planning n’a pas pu se charger',
                  message: 'Rien n’est perdu. Réessaie dans un instant.',
                  actionLabel: 'Réessayer',
                  onAction: retry,
                )),
        ]);
      }
      return _page(title: 'Planning', children: const [
        SizedBox(height: CgSpace.section),
        CgSkeletonList(rows: 4),
      ]);
    }

    final ready = entries.where((e) => e.isGenerationComplete).toList();
    final config = planning.config;
    if (config != null && !_replanning) return _view(planning, config, ready);
    if (ready.isEmpty) {
      return _page(title: 'Planifier', children: [
        _centered(CgState.empty(
          title: 'Importe un collège pour planifier',
          message: 'Le planning répartit les fiches de tes collèges jusqu’à ton examen.',
          actionLabel: 'Aller à la Bibliothèque',
          onAction: () => context.go('/colleges'),
        )),
      ]);
    }
    if (_collegeIds == null) _initForm(ready, config);
    return _form(ready);
  }

  Widget _page({
    required String title,
    String? subtitle,
    Widget? trailing,
    Widget? bottomAction,
    required List<Widget> children,
  }) =>
      CgPage(
        title: title,
        subtitle: subtitle,
        backLabel: 'Progression',
        onBack: _back,
        trailing: trailing,
        bottomAction: bottomAction,
        reserveTabBar: true,
        children: children,
      );

  // ─── Formulaire ─────────────────────────────────────────────────────────────

  Widget _form(List<CollegeListEntry> ready) {
    final ids = _collegeIds!;
    final cards = ready
        .where((e) => ids.contains(e.userStatus!.collegeId))
        .fold(0, (sum, e) => sum + e.userStatus!.totalCards);
    final preview = PlanningPreview.of(cards: cards, startDate: _start, endDate: _end, dailyMinutes: _minutes);
    final today = _today;
    return _page(
      title: 'Planifier',
      bottomAction: CgButton(
        label: 'Planifier',
        loading: _saving,
        onPressed: ids.isEmpty ? null : _plan,
      ),
      children: [
        const CgSectionTitle('Collèges'),
        CgListGroup(variant: CgListVariant.inset, children: [
          for (final e in ready)
            CgListRow(
              title: e.catalog.name,
              subtitle: _count(e.userStatus!.totalCards, 'fiche'),
              leading: CgRowIcon(e.catalog.icon),
              trailing: CgRowTrailing.check,
              selected: ids.contains(e.userStatus!.collegeId),
              onTap: () => setState(() {
                final id = e.userStatus!.collegeId;
                ids.contains(id) ? ids.remove(id) : ids.add(id);
              }),
            ),
        ]),
        const CgSectionTitle('Période'),
        CgListGroup(variant: CgListVariant.inset, children: [
          CgListRow(
            title: 'Début',
            trailing: CgRowTrailing.value,
            value: epochDayOf(_start) == epochDayOf(today) ? 'aujourd’hui' : frShortDate(_start),
            onTap: () => _pickDate(exam: false),
          ),
          CgListRow(
            title: 'Examen',
            trailing: CgRowTrailing.value,
            value: frShortDate(_end),
            onTap: () => _pickDate(exam: true),
          ),
        ]),
        const CgSectionTitle('Temps par jour'),
        CgSegmented<int>(
          values: minuteOptions,
          labelOf: (m) => '$m min',
          selected: _minutes,
          onChanged: (m) => setState(() => _minutes = m),
        ),
        const SizedBox(height: CgSpace.section),
        _PreviewCard(preview: ids.isEmpty ? null : preview),
        if (_replanning) ...[
          const SizedBox(height: CgSpace.s4),
          CgButton(
            label: 'Annuler',
            variant: CgButtonVariant.quiet,
            onPressed: () => setState(() {
              _replanning = false;
              _collegeIds = null;
            }),
          ),
        ],
      ],
    );
  }

  // ─── Vue du planning ────────────────────────────────────────────────────────

  Widget _view(PlanningState planning, PlanningConfig config, List<CollegeListEntry> ready) {
    final today = planning.today;
    final start = epochDayOf(config.startDate);
    final end = epochDayOf(config.endDate);
    final days = ref.watch(planningDaysProvider).valueOrNull;
    final done = days?.done ?? const <int>{};
    final inPeriod = today >= start && today <= end;
    final names = [
      for (final e in ready)
        if (config.collegeIds.contains(e.userStatus!.collegeId)) e.catalog.name,
    ];
    final c = CgTheme.of(context).colors;
    return _page(
      title: 'Planning',
      subtitle: '${frShortDate(config.startDate)} → ${frShortDate(config.endDate)}',
      trailing: _MoreAction(onTap: _openActions),
      children: [
        const SizedBox(height: CgSpace.s4),
        Text(planningSummary(config, planning, today: today), style: CgType.body.copyWith(color: c.ink2)),
        const CgSectionTitle('Collèges'),
        Text(
          names.isEmpty ? 'Aucun collège prêt dans ce planning' : names.join(' · '),
          style: CgType.body.copyWith(color: c.ink),
        ),
        const CgSectionTitle('Calendrier'),
        _PlanningCalendar(
          startDay: start,
          endDay: end,
          today: today,
          done: done,
          postponed: planning.postponedDays,
        ),
        const SizedBox(height: CgSpace.section),
        if (planning.postponedToday)
          CgButton(
            label: 'Annuler le décalage',
            variant: CgButtonVariant.quiet,
            onPressed: _busy ? null : () => _run(ref.read(planningProvider.notifier).cancelPostpone),
          )
        // Rien tant que les jours ne sont pas lus (pas de bouton qui disparaît).
        else if (days != null && inPeriod && !done.contains(today) && !days.todayStarted)
          CgButton(
            label: 'Décaler aujourd’hui',
            variant: CgButtonVariant.quiet,
            onPressed: _busy ? null : () => _run(ref.read(planningProvider.notifier).postponeToday),
          ),
        if (kTestTools)
          CgButton(
            label: 'Test : réinitialiser la session du jour',
            variant: CgButtonVariant.quiet,
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await DailySessionRepository(ref.read(databaseProvider)).resetDay(today);
                      ref.invalidate(planningDaysProvider);
                      ref.invalidate(todayProvider);
                    }),
          ),
        CgButton(
          label: 'Planifier à nouveau',
          variant: CgButtonVariant.quiet,
          onPressed: () => setState(() {
            _replanning = true;
            _collegeIds = null;
          }),
        ),
      ],
    );
  }
}

/// « 1 fiche », « 341 fiches ».
String _count(int n, String noun) => '$n ${n > 1 ? '${noun}s' : noun}';

Widget _centered(Widget state) => Padding(
      padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
      child: state,
    );

/// Aperçu vivant : fiches, jours, fiches par jour, faisable ou non.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  /// `null` : aucun collège choisi.
  final PlanningPreview? preview;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final p = preview;
    final List<Widget> lines;
    if (p == null) {
      lines = [Text('Choisis au moins un collège', style: CgType.body.copyWith(color: c.ink2))];
    } else {
      final feasible = p.feasible;
      lines = [
        Text(
          '${_count(p.cards, 'fiche')} · ${_count(p.days, 'jour')} · ~${p.perDay} par jour',
          style: CgType.head.copyWith(color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: CgSpace.s2),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CgIcon(feasible ? CgIcons.check : CgIcons.warning,
              size: _iconSize, color: feasible ? c.accent : c.warningInk),
          const SizedBox(width: CgSpace.s2),
          Expanded(
            child: Text(
              feasible
                  ? 'Faisable en ${p.dailyMinutes} min par jour'
                  : 'Trop court : ${p.perDay} fiches par jour, ~${p.minutesNeeded} min. '
                      'Allonge la période ou le temps par jour.',
              style: CgType.bodyS.copyWith(color: feasible ? c.ink : c.warningInk),
            ),
          ),
        ]),
      ];
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(CgSpace.s4),
        decoration: BoxDecoration(color: c.surface, borderRadius: CgRadius.lAll),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines),
      ),
    );
  }
}

/// Sélecteur de date iOS (spec v2 § Composants natifs), en français.
class _DatePickerBody extends StatelessWidget {
  const _DatePickerBody({required this.initial, required this.first, required this.last, required this.onChanged});

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onChanged;

  static const _height = 216.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initial,
        minimumDate: first,
        maximumDate: last,
        dateOrder: DatePickerDateOrder.dmy,
        onDateTimeChanged: onChanged,
      ),
    );
  }
}

/// Calendrier de la période, mois par mois (lundi en tête) : faits pleins,
/// aujourd'hui cerclé, décalés barrés, à venir en creux. Pas de compteur de
/// jours manqués (spec v2 § Émotions : jamais de culpabilité).
class _PlanningCalendar extends StatelessWidget {
  const _PlanningCalendar({
    required this.startDay,
    required this.endDay,
    required this.today,
    required this.done,
    required this.postponed,
  });

  final int startDay;
  final int endDay;
  final int today;
  final Set<int> done;
  final Set<int> postponed;

  static const _cell = 36.0;
  static const _border = 1.5;
  static const _todayBorder = 2.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    // L'année n'apparaît que si le planning n'est pas tout entier dans l'année en cours.
    final showYear = dateOfEpochDay(startDay).year != dateOfEpochDay(endDay).year ||
        dateOfEpochDay(startDay).year != dateOfEpochDay(today).year;
    final months = <List<int>>[];
    for (var d = startDay; d <= endDay; d++) {
      final date = dateOfEpochDay(d);
      if (months.isEmpty || date.day == 1) months.add([]);
      months.last.add(d);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // L M M J V S D (les jours sont lus en entier par VoiceOver, case par case).
      ExcludeSemantics(
        child: Row(children: [
          for (final d in kFrWeekdays)
            Expanded(
              child: Center(
                child: Text(d[0].toUpperCase(), style: CgType.label.copyWith(color: c.ink3)),
              ),
            ),
        ]),
      ),
      for (final month in months) ...[
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.s3, bottom: CgSpace.s2),
          child: Text(
            showYear
                ? '${frMonth(dateOfEpochDay(month.first))} ${dateOfEpochDay(month.first).year}'
                : frMonth(dateOfEpochDay(month.first)),
            style: CgType.label.copyWith(color: c.ink2, fontWeight: FontWeight.w600),
          ),
        ),
        ..._weeks(month).map((week) => Row(children: [
              for (final d in week) Expanded(child: d == null ? const SizedBox(height: _cell) : _day(c, d)),
            ])),
      ],
    ]);
  }

  /// Semaines du mois (lundi → dimanche), cases vides hors période.
  List<List<int?>> _weeks(List<int> days) {
    final weeks = <List<int?>>[];
    var week = List<int?>.filled(7, null);
    for (final d in days) {
      final wd = dateOfEpochDay(d).weekday - 1;
      if (wd == 0 && week.any((x) => x != null)) {
        weeks.add(week);
        week = List<int?>.filled(7, null);
      }
      week[wd] = d;
    }
    weeks.add(week);
    return weeks;
  }

  Widget _day(CgColors c, int day) {
    final date = dateOfEpochDay(day);
    final isDone = done.contains(day);
    final isToday = day == today;
    final isPostponed = postponed.contains(day);
    final status = isDone
        ? 'session faite'
        : isPostponed
            ? 'décalé'
            : isToday
                ? 'aujourd’hui'
                : day > today
                    ? 'à venir'
                    : 'passé';
    return Semantics(
      container: true,
      label: '${frLongDate(date)}, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CgSpace.s1 / 2),
        child: Center(
          child: Container(
            width: _cell,
            height: _cell,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? c.accent : null,
              border: isDone
                  ? null
                  : Border.all(
                      color: isToday ? c.accent : (day > today ? c.line : c.ground),
                      width: isToday ? _todayBorder : _border,
                    ),
            ),
            child: Text(
              '${date.day}',
              style: CgType.label.copyWith(
                color: isDone ? c.accentInk : (day < today ? c.ink3 : c.ink),
                fontWeight: isToday ? FontWeight.w700 : null,
                decoration: isPostponed ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: c.ink3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « … » de l'en-tête : actions du planning.
class _MoreAction extends StatelessWidget {
  const _MoreAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      container: true,
      button: true,
      label: 'Plus d’actions',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CgSpace.tapTarget,
          child: Center(child: CgIcon(CgIcons.more, color: c.accent)),
        ),
      ),
    );
  }
}
