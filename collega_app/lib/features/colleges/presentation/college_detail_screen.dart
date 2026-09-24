import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/fr_dates.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/domain/item_title.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';

/// D'où le détail a été ouvert : fixe le retour, l'onglet actif et les routes
/// des items (`/colleges`, `/home/colleges`, `/progress/colleges`).
enum CollegeDetailOrigin {
  library('/colleges', '/colleges', 'Bibliothèque'),
  today('/home/colleges', '/home', 'Aujourd’hui'),
  progress('/progress/colleges', '/progress', 'Progression');

  const CollegeDetailOrigin(this.base, this.tabRoot, this.backLabel);

  /// Préfixe des routes du détail (`$base/:id`, `$base/:id/items/:item`).
  final String base;

  /// Racine de l'onglet (retour sans historique).
  final String tabRoot;
  final String backLabel;
}

/// Détail d'un collège (story 8.7, maquette `direction-d-fusion.html` écran 6) :
/// progression du collège, items titrés filtrables par rang, « Réviser ce
/// collège » ancré ; le réimport vit dans une action sheet.
class CollegeDetailScreen extends ConsumerWidget {
  const CollegeDetailScreen({super.key, required this.refId, this.origin = CollegeDetailOrigin.library});

  final int refId;
  final CollegeDetailOrigin origin;

  /// Racine des routes de ce détail (items poussés dessous).
  String get basePath => '${origin.base}/$refId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = collegeCatalogEntry(refId);
    final title = catalog?.name ?? 'Collège';
    final async = ref.watch(collegesProvider);
    final entries = async.valueOrNull;

    Widget page(List<Widget> children, {Widget? trailing, String? subtitle, Widget? bottomAction}) => CgPage(
          title: title,
          subtitle: subtitle,
          backLabel: origin.backLabel,
          onBack: () => _back(context),
          trailing: trailing,
          bottomAction: bottomAction,
          reserveTabBar: true,
          onRefresh: () => _refresh(ref),
          children: children,
        );

    if (entries == null) {
      if (async.hasError && !async.isLoading) return page([_errorFor(async.error!, onRetry: () => _refresh(ref))]);
      return page(const [_DetailSkeleton()]);
    }

    CollegeListEntry? entry;
    for (final e in entries) {
      if (e.catalog.refId == refId) entry = e;
    }
    if (entry == null || catalog == null) {
      return page([
        _centered(CgState.error(
          title: 'Ce collège est introuvable',
          message: 'Le lien ne mène à aucun collège du catalogue.',
          actionLabel: 'Retour',
          onAction: () => _back(context),
        )),
      ]);
    }

    final status = entry.userStatus;
    if (status == null && async.isLoading) {
      // Liste en rechargement (fin d'un premier import) : l'ancienne valeur dit
      // « pas importé » ; on attend la nouvelle au lieu de renvoyer à l'import.
      return page(const [_DetailSkeleton()]);
    }
    if (status == null) {
      // Pas encore importé : l'écran utile est celui de l'import.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (context.canPop()) {
          context.pushReplacement('/colleges/$refId/import');
        } else {
          // Lien direct : l'import garde un retour vers la Bibliothèque.
          final router = GoRouter.of(context);
          router.go('/colleges');
          WidgetsBinding.instance.addPostFrameCallback((_) => router.push('/colleges/$refId/import'));
        }
      });
      return page(const []);
    }

    return switch (status.status) {
      'generation_complete' => _LoadedDetail(entry: entry, basePath: basePath, page: page),
      'failed' => page([
          _centered(CgState.error(
            title: 'L’import n’a pas abouti',
            message: 'Tes autres collèges ne sont pas touchés. Relance l’import de ce PDF.',
            actionLabel: 'Relancer l’import',
            onAction: () => context.push('/colleges/$refId/import'),
          )),
        ]),
      _ => page([
          _centered(CgState.empty(
            title: 'Les fiches arrivent',
            message: 'L’import de ce collège est en cours. Tu peux fermer Collega : tes fiches t’attendront.',
            illustration: CgIllustration.sheets,
            actionLabel: 'Suivre l’import',
            onAction: () => context.push(
              '/colleges/$refId/import/progress',
              extra: {'collegeId': status.collegeId, 'refId': refId, 'reimport': false},
            ),
          )),
        ]),
    };
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(origin.tabRoot);
    }
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(collegesProvider);
    try {
      final entries = await ref.read(collegesProvider.future);
      for (final e in entries) {
        if (e.catalog.refId == refId && e.isGenerationComplete) {
          final id = e.userStatus!.collegeId;
          ref.invalidate(collegeDetailProvider(id));
          // Le spinner tient jusqu'à l'arrivée des items.
          await ref.read(collegeDetailProvider(id).future);
        }
      }
    } catch (_) {
      // L'état d'erreur s'affiche dans la page.
    }
  }
}

typedef _PageBuilder = Widget Function(
  List<Widget> children, {
  Widget? trailing,
  String? subtitle,
  Widget? bottomAction,
});

Widget _centered(Widget state) => Padding(
      padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
      child: state,
    );

Widget _errorFor(Object error, {required VoidCallback onRetry}) => _centered(isNetworkUnreachable(error)
    ? CgState.offline(
        title: 'Pas de connexion pour l’instant',
        message: 'Ce collège s’ouvre dès que Collega joint le serveur.',
        actionLabel: 'Réessayer',
        onAction: onRetry,
      )
    : CgState.error(
        title: 'Ce collège n’a pas pu s’ouvrir',
        message: 'Rien n’est perdu. Réessaie dans un instant.',
        actionLabel: 'Réessayer',
        onAction: onRetry,
      ));

/// Collège prêt : items, progression, révision, réimport.
class _LoadedDetail extends ConsumerStatefulWidget {
  const _LoadedDetail({required this.entry, required this.basePath, required this.page});

  final CollegeListEntry entry;
  final String basePath;
  final _PageBuilder page;

  @override
  ConsumerState<_LoadedDetail> createState() => _LoadedDetailState();
}

class _LoadedDetailState extends ConsumerState<_LoadedDetail> {
  bool _checkingLimits = false;

  /// Filtre de rang : état de l'écran, pas du chargement — il survit au
  /// tirer-pour-rafraîchir et au rechargement après un réimport (revue 8.7).
  String? _rang;

  String get _collegeId => widget.entry.userStatus!.collegeId;
  int get _refId => widget.entry.catalog.refId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collegeDetailProvider(_collegeId));
    // Stats vivantes (watch Drift) : elles suivent les drills sans invalidation.
    // Filtre de rang : seulement les fiches de ce rang (rang de la fiche, chantier 4).
    final rang = _rang;
    final statsByItem = (rang == null
            ? ref.watch(collegeDrillStatsByItemProvider(_collegeId))
            : ref.watch(collegeDrillStatsByItemForRangProvider((_collegeId, rang))))
        .valueOrNull ??
        const {};
    final more = _MoreAction(onTap: _openActions);
    final state = async.valueOrNull;

    if (state == null) {
      if (async.hasError && !async.isLoading) {
        return widget.page([
          _errorFor(async.error!, onRetry: () => ref.invalidate(collegeDetailProvider(_collegeId))),
        ]);
      }
      return widget.page(const [_DetailSkeleton()], trailing: more);
    }

    return switch (state) {
      CollegeDetailLoaded() => _loaded(state, statsByItem, more),
      CollegeDetailEmpty() => widget.page([
          _centered(CgState.empty(
            title: 'Aucune fiche dans ce collège',
            message: 'Le PDF n’a donné aucun item exploitable. Tu peux le réimporter.',
            actionLabel: 'Réimporter',
            onAction: _reimport,
          )),
        ], trailing: more),
      CollegeDetailError() => widget.page([
          _errorFor(StateError('détail'), onRetry: () => ref.invalidate(collegeDetailProvider(_collegeId))),
        ]),
      CollegeDetailLoading() => widget.page(const [_DetailSkeleton()], trailing: more),
    };
  }

  Widget _loaded(CollegeDetailLoaded state, Map<String, DrillStats> statsByItem, Widget more) {
    final all = [...state.items]..sort((a, b) => a.itemNumber.compareTo(b.itemNumber));
    final rang = _rang;
    // Rang des FICHES (chantier 4) : un item figure sous le rang X s'il a au moins
    // une fiche de rang X, quel que soit son propre rang (badge inchangé).
    int cardsOf(ItemModel i) => rang == null ? i.totalCards : i.cardCountFor(rang);
    final shown = rang == null ? all : all.where((i) => cardsOf(i) > 0).toList();
    // Non-vu recalé sur le total serveur de chaque item (du rang filtré).
    DrillStats statsOf(ItemModel i) => (statsByItem[i.id] ?? const DrillStats()).withTotal(cardsOf(i));
    final header = shown.fold(const DrillStats(), (sum, i) {
      final s = statsOf(i);
      return DrillStats(
        maitrise: sum.maitrise + s.maitrise,
        bien: sum.bien + s.bien,
        aRevoir: sum.aRevoir + s.aRevoir,
        notSeen: sum.notSeen + s.notSeen,
      );
    });
    final allCards = all.fold(0, (sum, i) => sum + i.totalCards);
    final shownCards = shown.fold(0, (sum, i) => sum + cardsOf(i));
    // Le drill lit les fiches de l'iPhone (du rang filtré) : le bouton compte celles-là.
    final localCards = shown.fold(0, (sum, i) => sum + (statsByItem[i.id]?.total ?? 0));
    final drillCards = math.min(kDefaultSessionCards, localCards);

    return widget.page(
      subtitle: '${widget.entry.catalog.editor} · ${_count(allCards, 'fiche')} · ${_count(all.length, 'item')}',
      trailing: more,
      bottomAction: shownCards == 0
          ? null
          : drillCards == 0
              ? const CgButton(label: 'Fiches en cours de téléchargement', onPressed: null)
              : CgButton(
                  label: rang == null
                      ? 'Réviser ce collège · ${_count(drillCards, 'fiche')}'
                      : 'Réviser le rang $rang · ${_count(drillCards, 'fiche')}',
                  onPressed: () => launchDrill(
                    context,
                    ref,
                    DrillSessionParams(
                      collegeId: _collegeId,
                      rangs: rang == null ? null : [rang],
                      maxCards: kDefaultSessionCards,
                    ),
                  ),
                ),
      [
        const SizedBox(height: CgSpace.s4),
        CgRankBar(
          mastered: header.maitrise,
          good: header.bien,
          review: header.aRevoir,
          unseen: header.notSeen,
          size: CgRankBarSize.header,
          legend: true,
        ),
        const SizedBox(height: CgSpace.s4),
        CgSegmented<String?>(
          values: const [null, 'A', 'B', 'C'],
          labelOf: (r) => r == null ? 'Tous' : 'Rang $r',
          selected: rang,
          onChanged: (r) => setState(() => _rang = r),
        ),
        const CgSectionTitle('Items'),
        if (shown.isEmpty)
          _NoItemForRang(rang: rang!)
        else
          CgListGroup(children: [
            for (final item in shown)
              CgListRow(
                title: itemDisplayTitle(item.itemNumber, item.chapterTitle),
                subtitle: [
                  'Item ${item.itemNumber}',
                  rang == null ? _count(item.totalCards, 'fiche') : '${_count(cardsOf(item), 'fiche')} de rang $rang',
                  if (item.lowConfidence) 'OCR à vérifier',
                ].join(' · '),
                leading: _RankLeading(rang: item.rang),
                trailing: CgRowTrailing.chevron,
                progress: Builder(builder: (context) {
                  final s = statsOf(item);
                  return CgRankBar(mastered: s.maitrise, good: s.bien, review: s.aRevoir, unseen: s.notSeen);
                }),
                onTap: () => context.push('${widget.basePath}/items/${item.id}'),
              ),
          ]),
      ],
    );
  }

  Future<void> _openActions() => showCgActionSheet(
        context,
        title: widget.entry.catalog.name,
        actions: [CgSheetAction(label: 'Réimporter le PDF', onPressed: _reimport)],
      );

  /// Réimport (spec v2 § Feedback — Décision) : les limites d'abord, puis la
  /// conséquence écrite avant de confirmer.
  Future<void> _reimport() async {
    if (_checkingLimits) return;
    _checkingLimits = true;
    ReloadLimits limits;
    try {
      limits = await ref.read(collegeImportRepositoryProvider).getReloadLimits(_refId);
    } catch (_) {
      if (mounted) showCgToast(context, 'Impossible de vérifier tes réimports. Réessaie dans un instant.');
      return;
    } finally {
      _checkingLimits = false;
    }
    if (!mounted) return;

    if (limits.isCollegeLimitReached) {
      return _explain(
        title: 'Ce collège ne peut plus être réimporté',
        message: 'Tu as utilisé tes ${limits.collegeReloadMax} réimports pour ce collège. '
            'Tes fiches restent disponibles.',
      );
    }
    if (limits.isMonthlyLimitReached) {
      final reset = _resetLabel(limits.monthlyResetAt);
      return _explain(
        title: 'Plus de réimport ce mois-ci',
        message: 'Tu as utilisé tes ${limits.monthlyMax} réimports du mois'
            '${reset == null ? '' : ' ; le compteur repart $reset'}. Tes fiches restent disponibles.',
      );
    }

    final confirmed = await showCgDialogSheet(
      context,
      title: 'Réimporter le PDF ?',
      message: 'Les nouvelles fiches remplaceront les fiches existantes.\n'
          'Réimports utilisés : ${limits.collegeReloadCount}/${limits.collegeReloadMax} pour ce collège · '
          '${limits.monthlyReloads}/${limits.monthlyMax} ce mois.',
      confirmLabel: 'Réimporter',
      cancelLabel: 'Annuler',
    );
    if (confirmed && mounted) context.push('/colleges/$_refId/import');
  }

  Future<void> _explain({required String title, required String message}) => showCgSheet<void>(
        context,
        title: title,
        builder: (_) => _SheetMessage(message),
        primary: Builder(
          builder: (sheetContext) => CgButton(
            label: 'Compris',
            onPressed: () => Navigator.of(sheetContext, rootNavigator: true).pop(),
          ),
        ),
      );
}

/// « 1 fiche », « 30 fiches ».
String _count(int n, String noun) => '$n ${n > 1 ? '${noun}s' : noun}';

/// « le 1er octobre », « le 12 novembre » ; `null` si la date est illisible.
String? _resetLabel(String iso) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return null;
  final day = date.day == 1 ? '1er' : '${date.day}';
  return 'le $day ${frMonth(date)}';
}

class _RankLeading extends StatelessWidget {
  const _RankLeading({required this.rang});

  final String rang;

  @override
  Widget build(BuildContext context) {
    const known = {'A', 'B', 'C'};
    return known.contains(rang) ? CgBadge.rank(rang, short: true) : const SizedBox.shrink();
  }
}

class _NoItemForRang extends StatelessWidget {
  const _NoItemForRang({required this.rang});

  final String rang;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CgSpace.s3),
      child: Text('Aucune fiche de rang $rang dans ce collège.', style: CgType.bodyS.copyWith(color: c.ink2)),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
      child: Text(message, style: CgType.body.copyWith(color: c.ink2)),
    );
  }
}

/// Bouton « … » de l'en-tête : ouvre les actions du collège.
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

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  static const _barHeight = 10.0;
  static const _segmentedHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: CgSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CgSkeleton.block(height: _barHeight, radius: CgRadius.badge),
        SizedBox(height: CgSpace.s4),
        CgSkeleton.block(height: _segmentedHeight, radius: CgRadius.s),
        SizedBox(height: CgSpace.section),
        CgSkeletonList(rows: 6),
      ]),
    );
  }
}
