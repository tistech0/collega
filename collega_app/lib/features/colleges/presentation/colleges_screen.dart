import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';

/// Onglet Bibliothèque (story 8.6, maquette `direction-d-fusion.html` écran 5) :
/// mes collèges en tête, puis le catalogue où importer.
class CollegesScreen extends ConsumerStatefulWidget {
  const CollegesScreen({super.key});

  static const tabIndex = 1;

  @override
  ConsumerState<CollegesScreen> createState() => _CollegesScreenState();
}

class _CollegesScreenState extends ConsumerState<CollegesScreen> with TabReselectScrollMixin {
  final _scroll = ScrollController();
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _onResume);

  @override
  int get tabIndex => CollegesScreen.tabIndex;
  @override
  ScrollController get scrollController => _scroll;
  @override
  Duration get reselectDuration => CgMotion.resolve(context, CgMotion.base);
  @override
  Curve get reselectCurve => CgMotion.out;

  @override
  void initState() {
    super.initState();
    // Story 7.11 : reprend un upload par morceaux interrompu (app tuée pendant
    // l'envoi) au montage et à chaque retour au premier plan.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumePendingUpload());
    _lifecycle; // écoute le retour au premier plan
  }

  void _onResume() {
    _resumePendingUpload();
    // Hors connexion : le retour au premier plan retente le réseau (le bandeau
    // ne reste pas affiché une fois la connexion revenue).
    if (mounted && _offline(ref.read(collegesProvider))) _refresh();
  }

  bool _offline(AsyncValue<List<CollegeListEntry>> async) =>
      async.hasValue &&
      (ref.read(collegesProvider.notifier).isOffline || (async.hasError && isNetworkUnreachable(async.error!)));

  void _resumePendingUpload() {
    if (!mounted) return;
    ref.read(collegeImportProvider.notifier).resumePendingUpload();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(collegesProvider);
    try {
      await ref.read(collegesProvider.future);
    } catch (_) {
      // L'état d'erreur s'affiche dans la page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collegesProvider);
    final entries = async.valueOrNull;

    final List<Widget> content;
    if (entries == null && async.hasError && !async.isLoading) {
      content = [_errorState(async.error!)];
    } else if (entries == null) {
      content = const [
        SizedBox(height: CgSpace.section),
        CgSkeletonList(rows: 8),
      ];
    } else {
      content = _libraryChildren(entries);
    }

    return CgPage(
      title: 'Bibliothèque',
      controller: _scroll,
      reserveTabBar: true,
      onRefresh: _refresh,
      children: [
        const SizedBox(height: CgSpace.s3),
        _SearchField(onTap: () => context.push('/search')),
        if (_offline(async)) const _OfflineBanner(),
        ...content,
      ],
    );
  }

  Widget _errorState(Object error) {
    final state = isNetworkUnreachable(error)
        ? CgState.offline(
            title: 'Pas de connexion pour l’instant',
            message: 'La Bibliothèque se charge dès que Collega joint le serveur.',
            actionLabel: 'Réessayer',
            onAction: _refresh,
          )
        : CgState.error(
            title: 'La Bibliothèque n’a pas pu se charger',
            message: 'Rien n’est perdu. Réessaie dans un instant.',
            actionLabel: 'Réessayer',
            onAction: _refresh,
          );
    return Padding(padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle), child: state);
  }

  List<Widget> _libraryChildren(List<CollegeListEntry> entries) {
    // Le catalogue est déjà alphabétique : l'ordre est conservé des deux côtés.
    final mine = entries.where((e) => e.isImported).toList();
    final catalog = entries.where((e) => !e.isImported).toList();
    return [
      const CgSectionTitle('Mes collèges'),
      if (mine.isEmpty)
        const _NoCollegeYet()
      else
        CgListGroup(children: [for (final e in mine) _MyCollegeRow(entry: e)]),
      if (catalog.isNotEmpty) ...[
        CgSectionTitle('Catalogue · ${catalog.length} ${catalog.length > 1 ? 'collèges' : 'collège'}'),
        CgListGroup(children: [
          for (final e in catalog)
            CgListRow(
              title: e.catalog.name,
              subtitle: e.catalog.editor,
              leading: CgRowIcon(e.catalog.icon, muted: true),
              enabled: false,
              trailing: CgRowTrailing.action,
              actionLabel: 'Importer',
              onAction: () => context.push('/colleges/${e.catalog.refId}/import'),
            ),
        ]),
      ],
    ];
  }
}

/// Collège importé : progression vivante (Drift) sous le titre.
class _MyCollegeRow extends ConsumerWidget {
  const _MyCollegeRow({required this.entry});

  final CollegeListEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = entry.userStatus!;
    final editor = entry.catalog.editor;
    final complete = entry.isGenerationComplete;
    DrillStats? stats;
    if (complete) {
      // Non-vu recalé sur le total serveur (fiches pas encore synchronisées).
      stats = (ref.watch(collegeDrillStatsProvider(status.collegeId)).valueOrNull ?? const DrillStats())
          .withTotal(status.totalCards);
    }
    final subtitle = switch (status.status) {
      'generation_complete' => '$editor · ${libraryProgressLabel(stats!)}',
      'failed' => '$editor · l’import n’a pas abouti',
      _ => '$editor · import en cours, les fiches arrivent',
    };
    return CgListRow(
      title: entry.catalog.name,
      subtitle: subtitle,
      leading: CgRowIcon(entry.catalog.icon),
      trailing: CgRowTrailing.chevron,
      progress: stats == null
          ? null
          : CgRankBar(mastered: stats.maitrise, good: stats.bien, review: stats.aRevoir, unseen: stats.notSeen),
      onTap: () => context.push('/colleges/${entry.catalog.refId}'),
    );
  }
}

/// « 177 fiches · 42 % maîtrisées », ou « · à découvrir » avant tout drill.
String libraryProgressLabel(DrillStats stats) {
  final cards = '${stats.total} ${stats.total > 1 ? 'fiches' : 'fiche'}';
  if (stats.drilled == 0) return '$cards · à découvrir';
  // Espace fine insécable : « 42 % » ne se coupe jamais.
  return '$cards · ${stats.masteryPercent}\u202F% maîtrisées';
}

class _NoCollegeYet extends StatelessWidget {
  const _NoCollegeYet();

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Choisis un collège dans le catalogue', style: CgType.head.copyWith(color: c.ink)),
      const SizedBox(height: CgSpace.s1),
      Text(
        'Touche « Importer » et envoie son PDF : les fiches arrivent en quelques minutes.',
        style: CgType.bodyS.copyWith(color: c.ink2),
      ),
    ]);
  }
}

/// Faux champ de recherche : il ouvre la recherche (sheet en story 8.10).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  static const _height = 40.0;
  static const _iconSize = 18.0;
  static const _iconMaxScale = 1.3;
  static const _placeholder = 'Un item, un signe, une dose…';

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      key: const Key('library-search'),
      container: true,
      button: true,
      label: 'Rechercher un item, un signe, une dose',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(minHeight: _height),
              padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3, vertical: CgSpace.s2),
              decoration: BoxDecoration(color: c.soft, borderRadius: CgRadius.sAll),
              child: Row(children: [
                CgIcon(
                  CgIcons.search,
                  size: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _iconMaxScale).scale(_iconSize),
                  color: c.ink3,
                ),
                const SizedBox(width: CgSpace.s2),
                Expanded(child: Text(_placeholder, style: CgType.body.copyWith(color: c.ink3))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau 32 pt `soft` (spec v2 § États — Hors-ligne) : la liste vient du cache.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  static const _minHeight = 32.0;
  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(top: CgSpace.s2),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: _minHeight),
          padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3, vertical: CgSpace.s1),
          decoration: BoxDecoration(color: c.soft, borderRadius: CgRadius.sAll),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            CgIcon(CgIcons.cloudOff, size: _iconSize, color: c.ink2),
            const SizedBox(width: CgSpace.s2),
            Flexible(child: Text('Hors connexion', style: CgType.meta.copyWith(color: c.ink2))),
          ]),
        ),
      ),
    );
  }
}
