import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/card_type.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/domain/item_title.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/search/presentation/search_sheet.dart';

/// Détail d'un item (story 8.11) : les fiches à relire (question → réponse),
/// signaler une fiche sans risquer de la supprimer, réviser l'item d'un geste.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({
    super.key,
    required this.refId,
    required this.itemId,
    this.origin = CollegeDetailOrigin.library,
    this.fromSearch = false,
  });

  final int refId;
  final String itemId;
  final CollegeDetailOrigin origin;

  /// Ouvert depuis la recherche : « ‹ Recherche » la rouvre.
  final bool fromSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collegeName = collegeCatalogEntry(refId)?.name ?? 'Collège';
    final async = ref.watch(collegesProvider);
    final entries = async.valueOrNull;

    Widget page(String title, List<Widget> children, {String? subtitle, Widget? bottomAction}) => PopScope(
          // Tout retour (bouton, balayage iOS) depuis la recherche la rouvre.
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && fromSearch) _reopenSearch(context);
          },
          child: CgPage(
            title: title,
            subtitle: subtitle,
            backLabel: fromSearch ? 'Recherche' : collegeName,
            onBack: () => _back(context),
            bottomAction: bottomAction,
            reserveTabBar: true,
            children: children,
          ),
        );

    if (entries == null) {
      if (async.hasError && !async.isLoading) return page('Item', [_errorFor(async.error!, () => ref.invalidate(collegesProvider))]);
      return page('Item', const [_ItemSkeleton()]);
    }
    String? collegeId;
    var importing = false;
    for (final e in entries) {
      if (e.catalog.refId != refId || e.userStatus == null) continue;
      if (e.isGenerationComplete) {
        collegeId = e.userStatus!.collegeId;
      } else {
        importing = e.userStatus!.status != 'failed';
      }
    }
    if (collegeId == null && importing) {
      // Réimport en cours : les fiches reviennent, rien n'est « introuvable ».
      return page('Item', [
        _centered(const CgState.empty(
          title: 'Les fiches arrivent',
          message: 'Ce collège est en cours d’import. Ses items reviennent dans quelques minutes.',
          illustration: CgIllustration.sheets,
        )),
      ]);
    }
    if (collegeId == null) {
      return page('Item', [
        _centered(CgState.error(
          title: 'Cet item est introuvable',
          message: 'Son collège n’est pas (ou plus) importé.',
          actionLabel: 'Retour',
          onAction: () => _back(context),
        )),
      ]);
    }
    return _ItemBody(
      collegeId: collegeId,
      collegeName: collegeName,
      itemId: itemId,
      page: page,
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop(); // PopScope rouvre la recherche
    } else {
      if (fromSearch) _reopenSearch(context);
      context.go('${origin.base}/$refId');
    }
  }

  /// Rouvre la sheet de recherche (qui a gardé la dernière requête) une fois la
  /// page fermée, depuis un contexte qui lui survit.
  void _reopenSearch(BuildContext context) {
    final overlay = Navigator.of(context, rootNavigator: true).overlay?.context;
    if (overlay == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (overlay.mounted) showSearchSheet(overlay, origin: origin);
    });
  }
}

typedef _PageBuilder = Widget Function(String title, List<Widget> children, {String? subtitle, Widget? bottomAction});

Widget _centered(Widget state) => Padding(
      padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
      child: state,
    );

Widget _errorFor(Object error, VoidCallback retry) => _centered(isNetworkUnreachable(error)
    ? CgState.offline(
        title: 'Pas de connexion pour l’instant',
        message: 'Les fiches de cet item s’affichent dès que Collega joint le serveur.',
        actionLabel: 'Réessayer',
        onAction: retry,
      )
    : CgState.error(
        title: 'Cet item n’a pas pu s’ouvrir',
        message: 'Rien n’est perdu. Réessaie dans un instant.',
        actionLabel: 'Réessayer',
        onAction: retry,
      ));

/// « 1 fiche », « 3 fiches ».
String _count(int n, String noun) => '$n ${n > 1 ? '${noun}s' : noun}';

class _ItemBody extends ConsumerStatefulWidget {
  const _ItemBody({required this.collegeId, required this.collegeName, required this.itemId, required this.page});

  final String collegeId;
  final String collegeName;
  final String itemId;
  final _PageBuilder page;

  @override
  ConsumerState<_ItemBody> createState() => _ItemBodyState();
}

class _ItemBodyState extends ConsumerState<_ItemBody> {
  /// Filtre de rang (seulement si l'item a des fiches de plusieurs rangs).
  String? _rang;
  final _expanded = <String>{};
  final _busy = <String>{};

  String get _key => '${widget.collegeId}:${widget.itemId}';
  ItemDetailNotifier get _notifier => ref.read(itemDetailProvider(_key).notifier);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemDetailProvider(_key));
    final item = ref.watch(itemInfoProvider(widget.itemId)).valueOrNull;
    final title = item == null ? 'Item' : itemDisplayTitle(item.itemNumber, item.chapterTitle);
    // Classique, cas clinique, définition ; puis par rang de la fiche.
    final cards = switch (async.valueOrNull) { final list? => sortCardsForList(list), null => null };

    if (cards == null) {
      if (async.hasError && !async.isLoading) {
        return widget.page(title, [_errorFor(async.error!, () => ref.invalidate(itemDetailProvider(_key)))]);
      }
      return widget.page(title, const [_ItemSkeleton()]);
    }

    final subtitle = [
      if (item != null) 'Item ${item.itemNumber}',
      widget.collegeName,
      _count(cards.length, 'fiche'),
    ].join(' · ');

    if (cards.isEmpty) {
      return widget.page(title, subtitle: subtitle, [
        _centered(const CgState.empty(
          title: 'Aucune fiche pour cet item',
          message: 'Ses fiches ont peut-être été supprimées. Tu peux réimporter le collège depuis sa page.',
        )),
      ]);
    }

    // Vivant (Drift) ; non-vu recalé sur les fiches de l'item.
    final stats = (ref.watch(collegeDrillStatsByItemProvider(widget.collegeId)).valueOrNull?[widget.itemId] ??
            const DrillStats())
        .withTotal(cards.length);
    final rangs = (cards.map((c) => c.rang).toSet().toList()..sort());
    // Rang filtré disparu (fiche supprimée, régénérée) : retour à « Toutes ».
    final rang = rangs.length > 1 && rangs.contains(_rang) ? _rang : null;
    final shown = rang == null ? cards : cards.where((c) => c.rang == rang).toList();
    final c = CgTheme.of(context).colors;

    return widget.page(
      title,
      subtitle: subtitle,
      bottomAction: CgButton(
        label: 'Réviser cet item · ${_count(cards.length, 'fiche')}',
        onPressed: () => launchDrill(
          context,
          ref,
          DrillSessionParams(collegeId: widget.collegeId, itemId: widget.itemId, itemName: title),
        ),
      ),
      [
        const SizedBox(height: CgSpace.s4),
        CgRankBar(
          mastered: stats.maitrise,
          good: stats.bien,
          review: stats.aRevoir,
          unseen: stats.notSeen,
          size: CgRankBarSize.header,
          legend: true,
        ),
        const SizedBox(height: CgSpace.s4),
        if (rangs.length > 1)
          CgSegmented<String?>(
            values: [null, ...rangs],
            labelOf: (r) => r == null ? 'Toutes' : 'Rang $r',
            selected: rang,
            onChanged: (r) => setState(() => _rang = r),
          )
        else if (const {'A', 'B', 'C'}.contains(rangs.single))
          Align(alignment: Alignment.centerLeft, child: CgBadge.rank(rangs.single)),
        const CgSectionTitle('Fiches'),
        CgListGroup(children: [
          for (final card in shown)
            _CardTile(
              card: card,
              // Rang de la fiche sur chaque ligne quand la liste en mélange plusieurs
              // (sinon le badge unique ou le filtre au-dessus de la liste suffit).
              showRank: rang == null && rangs.length > 1 && const {'A', 'B', 'C'}.contains(card.rang),
              expanded: _expanded.contains(card.id),
              busy: _busy.contains(card.id),
              onToggle: () => setState(() => _expanded.contains(card.id) ? _expanded.remove(card.id) : _expanded.add(card.id)),
              onUseful: () => _useful(card),
              onReport: () => _report(card),
              onMore: () => _more(card),
              onOcr: () => _explainOcr(),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.s3),
          child: Text(
            'Touche une question pour voir sa réponse.',
            style: CgType.meta.copyWith(color: c.ink3),
          ),
        ),
      ],
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _useful(FlashCardModel card) async {
    CgHaptics.selection();
    try {
      await _notifier.submitPositiveFeedback(card.id);
    } catch (_) {
      if (mounted) showCgToast(context, 'Ton retour n’a pas pu s’enregistrer. Réessaie.');
    }
  }

  /// Pouce bas = signaler (spec v2) : le signalement est enregistré tout de
  /// suite ; régénérer est proposé, jamais supprimer.
  Future<void> _report(FlashCardModel card) async {
    CgHaptics.selection();
    // Envoyé tout de suite ; le résultat n'est dit qu'une fois connu.
    final sent = _notifier.submitNegativeFeedback(card.id).then((_) => true, onError: (Object _) => false);
    var note = '';
    final choice = await showCgSheet<String>(
      context,
      title: 'Signaler cette fiche',
      builder: (_) => _NoteBody(
        message: 'Dis ce qui ne va pas : la fiche peut être régénérée en tenant compte de ta remarque.',
        onNote: (v) => note = v,
      ),
      primary: Builder(
        builder: (s) => CgButton(
          label: 'Régénérer la fiche',
          onPressed: () => Navigator.of(s, rootNavigator: true).pop('regenerate'),
        ),
      ),
      secondary: Builder(
        builder: (s) => CgButton(
          label: 'Plus tard',
          variant: CgButtonVariant.quiet,
          onPressed: () => Navigator.of(s, rootNavigator: true).pop('later'),
        ),
      ),
    );
    final text = note.trim();
    final ok = await sent;
    if (!mounted) return;
    if (!ok) showCgToast(context, 'Le signalement n’a pas pu s’enregistrer. Réessaie.');
    if (choice == 'regenerate') {
      await _regenerate(card, text.isEmpty ? null : text);
    } else if (ok) {
      showCgToast(context, 'Fiche signalée');
    }
  }

  Future<void> _more(FlashCardModel card) => showCgActionSheet(
        context,
        actions: [
          CgSheetAction(label: 'Régénérer la fiche', onPressed: () => _askRegenerate(card)),
          CgSheetAction(label: 'Supprimer la fiche', destructive: true, onPressed: () => _askDelete(card)),
        ],
      );

  Future<void> _askRegenerate(FlashCardModel card) async {
    var note = '';
    final go = await showCgSheet<bool>(
      context,
      title: 'Régénérer la fiche',
      builder: (_) => _NoteBody(
        message: 'Une nouvelle fiche remplacera celle-ci. Précise ce qui ne va pas : elle en tiendra compte.',
        onNote: (v) => note = v,
      ),
      primary: Builder(
        builder: (s) => CgButton(label: 'Régénérer', onPressed: () => Navigator.of(s, rootNavigator: true).pop(true)),
      ),
      secondary: Builder(
        builder: (s) => CgButton(
          label: 'Annuler',
          variant: CgButtonVariant.quiet,
          onPressed: () => Navigator.of(s, rootNavigator: true).pop(false),
        ),
      ),
    );
    final text = note.trim();
    if (go == true && mounted) await _regenerate(card, text.isEmpty ? null : text);
  }

  Future<void> _regenerate(FlashCardModel card, String? note) async {
    setState(() => _busy.add(card.id));
    try {
      await _notifier.regenerateCard(card.id, userNote: note);
    } catch (_) {
      if (mounted) showCgToast(context, 'La régénération a échoué. Réessaie plus tard.');
    } finally {
      if (mounted) setState(() => _busy.remove(card.id));
    }
  }

  Future<void> _askDelete(FlashCardModel card) async {
    final confirmed = await showCgDialogSheet(
      context,
      title: 'Supprimer cette fiche ?',
      message: 'Elle disparaît de tes révisions et de ta progression. C’est définitif.',
      confirmLabel: 'Supprimer',
      cancelLabel: 'Annuler',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(card.id));
    try {
      await _notifier.deleteCard(card.id);
    } catch (_) {
      if (mounted) showCgToast(context, 'La fiche n’a pas pu être supprimée. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy.remove(card.id));
    }
  }

  Future<void> _explainOcr() => showCgSheet<void>(
        context,
        title: 'Source à vérifier',
        builder: (_) => const _NoteBody(
          message: 'Ce passage du PDF était difficile à lire : la fiche peut contenir une erreur. '
              'Vérifie-la avec ton cours, et signale-la si besoin.',
        ),
        primary: Builder(
          builder: (s) => CgButton(label: 'Compris', onPressed: () => Navigator.of(s, rootNavigator: true).pop()),
        ),
      );
}

/// Texte d'une sheet, avec une note facultative (le champ gère son texte : rien
/// à libérer pendant l'animation de fermeture).
class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.message, this.onNote});

  final String message;
  final ValueChanged<String>? onNote;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: CgSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(message, style: CgType.body.copyWith(color: c.ink2)),
        if (onNote != null) ...[
          const SizedBox(height: CgSpace.s4),
          CgField(
            label: 'Qu’est-ce qui ne va pas ? (facultatif)',
            kind: CgFieldKind.multiline,
            onChanged: onNote,
          ),
        ],
      ]),
    );
  }
}

/// Fiche dépliable : la question, puis la réponse et les retours.
class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.showRank,
    required this.expanded,
    required this.busy,
    required this.onToggle,
    required this.onUseful,
    required this.onReport,
    required this.onMore,
    required this.onOcr,
  });

  final FlashCardModel card;
  final bool showRank;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onUseful;
  final VoidCallback onReport;
  final VoidCallback onMore;
  final VoidCallback onOcr;

  static const _chevron = 18.0;
  static const _lowOcr = 0.7;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final typeLabel = CardType.parse(card.cardType).label;
    // Rang et type de la fiche, lus avant la question (« Rang B, cas clinique. … »).
    final tags = [if (showRank) 'Rang ${card.rang}', if (typeLabel != null) typeLabel.toLowerCase()];
    final question = Semantics(
      key: ValueKey('item-card-${card.id}'),
      container: true,
      button: true,
      expanded: expanded,
      label: tags.isEmpty ? card.recto : '${tags.join(', ')}. ${card.recto}',
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CgSpace.s3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: tags.isEmpty
                    ? Text(card.recto, style: CgType.head.copyWith(color: c.ink))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: CgSpace.s2, runSpacing: CgSpace.s1, children: [
                          if (showRank) CgBadge.rank(card.rang, short: true),
                          CgCardTypeTag(typeLabel),
                        ]),
                        const SizedBox(height: CgSpace.s2),
                        Text(card.recto, style: CgType.head.copyWith(color: c.ink)),
                      ]),
              ),
              const SizedBox(width: CgSpace.s3),
              Padding(
                padding: const EdgeInsets.only(top: CgSpace.s1),
                child: RotatedBox(
                  quarterTurns: expanded ? 2 : 0,
                  child: CgIcon(CgIcons.chevronDown, size: _chevron, color: c.ink3),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (!expanded) return question;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      question,
      Text(card.verso, style: CgType.body.copyWith(color: c.ink2)),
      const SizedBox(height: CgSpace.s3),
      if (busy)
        Padding(
          padding: const EdgeInsets.only(bottom: CgSpace.s3),
          child: Text('Un instant…', style: CgType.meta.copyWith(color: c.ink3)),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: CgSpace.s2),
          child: Wrap(
            spacing: CgSpace.s2,
            runSpacing: CgSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FeedbackButton(
                icon: CgIcons.thumbUp,
                label: 'Utile',
                semanticLabel: 'Fiche utile',
                selected: card.userFeedback == 'positive',
                onTap: onUseful,
              ),
              _FeedbackButton(
                icon: CgIcons.thumbDown,
                label: 'À corriger',
                semanticLabel: 'Signaler la fiche',
                selected: card.userFeedback == 'negative',
                onTap: onReport,
              ),
              if (card.ocrConfidenceScore < _lowOcr) CgBadge.ocr(onTap: onOcr),
              _IconAction(icon: CgIcons.more, semanticLabel: 'Plus d’actions sur la fiche', onTap: onMore),
            ],
          ),
        ),
    ]);
  }
}

/// Pouce avec libellé : l'état choisi se lit (pastille + coche), pas seulement
/// à la couleur (spec v2 § Accessibilité).
class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final color = selected ? c.accent : c.ink2;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CgSpace.tapTarget, minWidth: CgSpace.tapTarget),
          // Largeur du contenu (dans un Wrap, Center prendrait toute la ligne).
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3, vertical: CgSpace.s1 + 2),
              decoration: BoxDecoration(
                color: selected ? c.accentSoft : null,
                borderRadius: CgRadius.pill,
                border: Border.all(color: selected ? c.accentSoft : c.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CgIcon(selected ? CgIcons.check : icon, size: _iconSize, color: color),
                const SizedBox(width: CgSpace.s1),
                Text(label, style: CgType.meta.copyWith(color: color, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.semanticLabel, required this.onTap});

  final String icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CgSpace.tapTarget,
          child: Center(child: CgIcon(icon, color: c.ink2)),
        ),
      ),
    );
  }
}

class _ItemSkeleton extends StatelessWidget {
  const _ItemSkeleton();

  static const _barHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: CgSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CgSkeleton.block(height: _barHeight, radius: CgRadius.badge),
        SizedBox(height: CgSpace.section),
        CgSkeletonList(rows: 4),
      ]),
    );
  }
}
