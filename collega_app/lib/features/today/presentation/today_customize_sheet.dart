import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';
import 'package:collega_app/features/today/today_providers.dart';

/// « Personnaliser la session » (spec § Parcours 2) : collèges, rangs, nombre,
/// statut, avec l'aperçu vivant avant d'enregistrer.
Future<void> showTodayCustomizeSheet(BuildContext context, TodayReady state) {
  return showCgSheet<void>(
    context,
    title: 'Personnaliser la session',
    detent: CgSheetDetent.full,
    builder: (_) => TodayCustomizePanel(state: state),
  );
}

class TodayCustomizePanel extends ConsumerStatefulWidget {
  const TodayCustomizePanel({super.key, required this.state});

  final TodayReady state;

  @override
  ConsumerState<TodayCustomizePanel> createState() => _TodayCustomizePanelState();
}

class _TodayCustomizePanelState extends ConsumerState<TodayCustomizePanel> {
  static const _counts = [12, 24, 36, 48];

  // Réglages actuels de la session : personnalisés s'il y en a, sinon ceux par défaut.
  late final Set<String> _colleges = {...widget.state.sessionCollegeIds};
  late String? _rang = widget.state.session.settings?.rangs?.singleOrNull;
  late SessionStatusFilter _status = widget.state.session.settings?.status ?? SessionStatusFilter.all;
  late int _count = widget.state.budget;
  int? _preview;
  bool _saving = false;

  /// Numéro de la dernière demande d'aperçu : une réponse plus ancienne est ignorée.
  int _previewRequest = 0;

  List<int> get _countOptions {
    final options = {..._counts, widget.state.budget}.toList()..sort();
    // CgSegmented prend 4 valeurs au plus : on garde le budget du jour et ses voisines.
    if (options.length <= 4) return options;
    final i = options.indexOf(widget.state.budget);
    final start = (i - 1).clamp(0, options.length - 4);
    return options.sublist(start, start + 4);
  }

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    final request = ++_previewRequest;
    final count = _colleges.isEmpty
        ? 0
        : await ref.read(dailySessionRepositoryProvider).preview(
              budget: _count,
              collegeIds: _colleges,
              rangs: _rang == null ? null : {_rang!},
              status: _status,
            );
    if (mounted && request == _previewRequest) setState(() => _preview = count);
  }

  void _update(VoidCallback change) {
    setState(change);
    _refreshPreview();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(todayProvider.notifier).customize(
            collegeIds: _colleges,
            rangs: _rang == null ? null : {_rang!},
            status: _status,
            maxCards: _count,
          );
    } on StateError {
      if (!mounted) return;
      setState(() => _saving = false);
      showCgToast(context, 'Ta session est déjà commencée : elle ne se personnalise plus.');
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showCgToast(context, 'Tes réglages n’ont pas pu être enregistrés. Réessaie.');
      return;
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final preview = _preview;
    final canSave = _colleges.isNotEmpty && (preview ?? 0) > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
          children: [
            const CgSectionTitle('Collèges'),
            CgListGroup(children: [
              for (final college in widget.state.colleges)
                CgListRow(
                  title: college.name,
                  trailing: CgRowTrailing.check,
                  selected: _colleges.contains(college.collegeId),
                  onTap: () => _update(() {
                    if (!_colleges.remove(college.collegeId)) _colleges.add(college.collegeId);
                  }),
                ),
            ]),
            const CgSectionTitle('Rangs'),
            CgSegmented<String?>(
              values: const [null, 'A', 'B', 'C'],
              labelOf: (r) => r ?? 'Tous',
              selected: _rang,
              onChanged: (r) => _update(() => _rang = r),
            ),
            const CgSectionTitle('Fiches'),
            CgSegmented<int>(
              values: _countOptions,
              labelOf: (n) => '$n',
              selected: _count,
              onChanged: (n) => _update(() => _count = n),
            ),
            const CgSectionTitle('Statut'),
            CgSegmented<SessionStatusFilter>(
              values: SessionStatusFilter.values,
              labelOf: (s) => switch (s) {
                SessionStatusFilter.all => 'Toutes',
                SessionStatusFilter.toReview => 'À revoir',
                SessionStatusFilter.unseen => 'Non vues',
              },
              selected: _status,
              onChanged: (s) => _update(() => _status = s),
            ),
            const SizedBox(height: CgSpace.section),
            Semantics(
              liveRegion: true,
              child: Text(
                preview == null
                    ? ' '
                    : preview == 0
                        ? 'Aucune fiche avec ces réglages'
                        : '$preview fiches · ${estimatedMinutes(preview)} min',
                style: CgType.head.copyWith(color: preview == 0 ? c.ink2 : c.ink),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      CgSheetFooter(
        primary: CgButton(label: 'Enregistrer', loading: _saving, onPressed: canSave ? _save : null),
        secondary: CgButton(
          label: 'Annuler',
          variant: CgButtonVariant.quiet,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
    ]);
  }
}
