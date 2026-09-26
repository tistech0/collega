import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/domain/item_title.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/search/domain/college_match.dart';
import 'package:collega_app/features/search/domain/search_result.dart';
import 'package:collega_app/features/search/presentation/college_search_row.dart';
import 'package:collega_app/features/search/search_providers.dart';

/// Recherche (story 8.10, spec v2 § Parcours 2) : sheet plein écran, clavier
/// ouvert, récentes et exemples, résultats dès 2 caractères. Garde la dernière
/// recherche d'une ouverture à l'autre.
///
/// [origin] : onglet d'où elle est ouverte — l'item touché s'y ouvre (onglet
/// actif et retour cohérents).
Future<void> showSearchSheet(BuildContext context, {CollegeDetailOrigin origin = CollegeDetailOrigin.library}) =>
    showCgSheet<void>(
      context,
      detent: CgSheetDetent.full,
      builder: (_) => SearchPanel(origin: origin),
    );

/// Extra de route du détail d'item ouvert depuis la recherche (« ‹ Recherche »).
const kFromSearch = 'search';

/// Exemples de l'accueil (spec v2 § États — Vide).
const kSearchExamples = ['BNP', 'Gardasil', 'dyspnée'];

/// Contenu de la sheet de recherche.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key, this.origin = CollegeDetailOrigin.library});

  final CollegeDetailOrigin origin;

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  late final TextEditingController _controller = TextEditingController(text: ref.read(searchNotifierProvider).query);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String query) {
    _controller.value = TextEditingValue(text: query, selection: TextSelection.collapsed(offset: query.length));
    ref.read(searchNotifierProvider.notifier).onQueryChanged(query);
  }

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  /// Ouvre l'item : la sheet se ferme (le détail vit dans les onglets).
  void _open(SearchResult r) {
    final router = GoRouter.of(context);
    ref.read(searchRecentsProvider.notifier).add(ref.read(searchNotifierProvider).query);
    _close();
    router.push('${widget.origin.base}/${r.collegeRefId}/items/${r.itemId}', extra: kFromSearch);
  }

  /// Drill de l'item par-dessus la sheet : « Retour à la recherche » y ramène.
  void _revise(SearchResult r) {
    ref.read(searchRecentsProvider.notifier).add(ref.read(searchNotifierProvider).query);
    launchDrill(
      context,
      ref,
      DrillSessionParams(
        collegeId: r.collegeId,
        itemId: r.itemId,
        itemName: itemDisplayTitle(r.itemNumber, r.chapterTitle),
        fromSearch: true,
      ),
    );
  }

  /// Collège importé : s'ouvre dans l'onglet d'origine, la sheet se ferme.
  void _openCollege(CollegeListEntry e) {
    final router = GoRouter.of(context);
    ref.read(searchRecentsProvider.notifier).add(ref.read(searchNotifierProvider).query);
    _close();
    router.push('${widget.origin.base}/${e.catalog.refId}');
  }

  /// À importer (ou envoi en cours) : l'écran d'import dit où on en est.
  void _importCollege(CollegeListEntry e) {
    final router = GoRouter.of(context);
    _close();
    router.push('/colleges/${e.catalog.refId}/import');
  }

  /// Section Items quand des collèges sont affichés au-dessus : les états
  /// réseau ne concernent qu'elle.
  List<Widget> _itemsSection(SearchState state) {
    if (state.isTooShort) return const [];
    if ((state.isLoading || state.isPending) && !state.hasResults) {
      return const [CgSectionTitle('Items'), CgSkeletonList(rows: 2)];
    }
    if (state.isOffline) {
      return const [
        CgSectionTitle('Items'),
        CgState.offline(title: 'Les items ont besoin d’une connexion', message: 'Les collèges restent accessibles.'),
      ];
    }
    if (state.hasError) {
      return [
        const CgSectionTitle('Items'),
        CgState.error(
          title: 'La recherche n’a pas abouti',
          message: 'Rien n’est perdu. Réessaie dans un instant.',
          actionLabel: 'Réessayer',
          onAction: () => ref.read(searchNotifierProvider.notifier).retry(),
        ),
      ];
    }
    final c = CgTheme.of(context).colors;
    if (state.results.isEmpty) {
      return [
        const CgSectionTitle('Items'),
        Text('Aucun item pour « ${state.query} »', style: CgType.bodyS.copyWith(color: c.ink2)),
      ];
    }
    return [
      Semantics(liveRegion: true, child: CgSectionTitle('Items · ${state.results.length}')),
      CgListGroup(children: [
        for (final r in state.results) _ResultRow(result: r, onOpen: () => _open(r), onRevise: () => _revise(r)),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);

    final query = state.query;
    // Liste pas encore là (ou en erreur) : pas de section Collèges plutôt
    // qu'un « Importer » sur un collège peut-être déjà importé.
    // Surveillée dès l'ouverture : la liste est prête au premier caractère.
    final entries = ref.watch(collegesProvider).valueOrNull ?? const <CollegeListEntry>[];
    final colleges = query.isEmpty ? const <CollegeListEntry>[] : matchColleges(query, entries);
    final upload = ref.watch(collegeImportProvider).valueOrNull;
    final uploadingRef = upload is ImportUploading ? upload.refId : null;
    final uploadProgress = upload is ImportUploading ? upload.progress : null;

    final Widget body;
    if (query.isEmpty || (state.isTooShort && colleges.isEmpty)) {
      body = _Home(onPick: _search);
    } else if (colleges.isNotEmpty) {
      body = ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + CgSpace.s4),
        children: [
          const CgSectionTitle('Collèges'),
          CgListGroup(children: [
            for (final e in colleges)
              CollegeSearchRow(
                entry: e,
                uploading: !e.isImported && e.catalog.refId == uploadingRef,
                progress: uploadProgress,
                onOpen: () => _openCollege(e),
                onImport: () => _importCollege(e),
              ),
          ]),
          ..._itemsSection(state),
        ],
      );
    } else if ((state.isLoading || state.isPending) && !state.hasResults) {
      body = const Padding(padding: EdgeInsets.only(top: CgSpace.s4), child: CgSkeletonList(rows: 4));
    } else if (state.isOffline) {
      body = _centered(CgState.offline(
        title: 'La recherche a besoin d’une connexion',
        message: 'Tes collèges restent disponibles.',
        actionLabel: 'Aller à la Bibliothèque',
        onAction: () {
          final router = GoRouter.of(context);
          _close();
          router.go('/colleges');
        },
      ));
    } else if (state.hasError) {
      body = _centered(CgState.error(
        title: 'La recherche n’a pas abouti',
        message: 'Rien n’est perdu. Réessaie dans un instant.',
        actionLabel: 'Réessayer',
        onAction: () => ref.read(searchNotifierProvider.notifier).retry(),
      ));
    } else if (state.isEmpty) {
      body = _centered(CgState.empty(
        title: 'Aucun résultat pour « ${state.query} »',
        message: 'Essaie un autre mot : un signe, une dose, un nom d’item.',
        illustration: CgIllustration.search,
      ));
    } else {
      body = ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + CgSpace.s4),
        children: _itemsSection(state),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          // Lu « Rechercher » par VoiceOver (le placeholder seul ne dit pas le rôle).
          child: Semantics(
            label: 'Rechercher',
            child: CgField(
              kind: CgFieldKind.search,
              placeholder: 'Un collège, un item, un signe…',
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (q) => ref.read(searchNotifierProvider.notifier).onQueryChanged(q),
              onSubmitted: (q) {
                ref.read(searchNotifierProvider.notifier).submit(q);
                ref.read(searchRecentsProvider.notifier).add(q);
              },
            ),
          ),
        ),
        const SizedBox(width: CgSpace.s2),
        _CancelButton(onTap: _close),
      ]),
      Expanded(child: body),
    ]);
  }
}

Widget _centered(Widget state) => SingleChildScrollView(
      padding: const EdgeInsets.only(top: CgSpace.section),
      child: state,
    );

/// Accueil : récentes puis exemples.
class _Home extends ConsumerWidget {
  const _Home({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CgTheme.of(context).colors;
    final recents = ref.watch(searchRecentsProvider).valueOrNull ?? const [];
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + CgSpace.s4),
      children: [
        if (recents.isNotEmpty) ...[
          const CgSectionTitle('Récentes'),
          CgListGroup(children: [
            for (final q in recents)
              CgListRow(
                title: q,
                leading: CgIcon(CgIcons.clock, size: _iconSize, color: c.ink3),
                onTap: () => onPick(q),
              ),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: CgButton(
              label: 'Effacer',
              variant: CgButtonVariant.quiet,
              size: CgButtonSize.compact,
              expand: false,
              onPressed: () => ref.read(searchRecentsProvider.notifier).clear(),
            ),
          ),
        ],
        const SizedBox(height: CgSpace.section),
        Text('Cherche un collège, un item, un signe', style: CgType.head.copyWith(color: c.ink)),
        const SizedBox(height: CgSpace.s1),
        Text('Par exemple :', style: CgType.bodyS.copyWith(color: c.ink2)),
        const SizedBox(height: CgSpace.s2),
        CgListGroup(children: [
          for (final e in kSearchExamples)
            CgListRow(
              title: e,
              leading: CgIcon(CgIcons.search, size: _iconSize, color: c.ink3),
              onTap: () => onPick(e),
            ),
        ]),
      ],
    );
  }

  static const _iconSize = 20.0;
}

/// Résultat : la ligne ouvre l'item ; « Réviser » en action secondaire.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onOpen, required this.onRevise});

  final SearchResult result;
  final VoidCallback onOpen;
  final VoidCallback onRevise;

  static const _excerptLines = 3;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final college = collegeCatalogEntry(r.collegeRefId)?.name;
    return CgListRow(
      title: itemDisplayTitle(r.itemNumber, r.chapterTitle),
      // Sans titre, le titre est déjà « Item 203 » : le sous-titre ne le répète pas.
      subtitle: [
        if (hasItemTitle(r.chapterTitle)) 'Item ${r.itemNumber}',
        if (college != null) college,
      ].join(' · '),
      leading: const {'A', 'B', 'C'}.contains(r.rang) ? CgBadge.rank(r.rang, short: true) : null,
      progress: SearchExcerpt(excerpt: r.excerpt, maxLines: _excerptLines),
      trailing: CgRowTrailing.action,
      actionLabel: 'Réviser',
      onAction: onRevise,
      onTap: onOpen,
    );
  }
}

/// Extrait du serveur : `<mark>…</mark>` surligné en `accentSoft`.
class SearchExcerpt extends StatelessWidget {
  const SearchExcerpt({super.key, required this.excerpt, this.maxLines});

  final String excerpt;
  final int? maxLines;

  static final _mark = RegExp(r'<mark>(.*?)</mark>', dotAll: true);

  /// Le terme doit rester dans les premières lignes affichées : au-delà, on
  /// commence l'extrait peu avant lui, avec « … » (revue 8.10).
  static const _maxLead = 60;
  static const _keptBefore = 30;

  static String window(String excerpt) {
    final first = excerpt.indexOf('<mark>');
    if (first <= _maxLead) return excerpt;
    final from = excerpt.lastIndexOf(' ', first - _keptBefore);
    return from <= 0 ? excerpt : '…${excerpt.substring(from + 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final excerpt = window(this.excerpt);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _mark.allMatches(excerpt)) {
      if (m.start > last) spans.add(TextSpan(text: excerpt.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(1),
        style: TextStyle(backgroundColor: c.accentSoft, color: c.ink, fontWeight: FontWeight.w600),
      ));
      last = m.end;
    }
    if (last < excerpt.length) spans.add(TextSpan(text: excerpt.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: CgType.bodyS.copyWith(color: c.ink2),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label: 'Annuler',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CgSpace.tapTarget, minWidth: CgSpace.tapTarget),
          child: Center(child: Text('Annuler', style: CgType.body.copyWith(color: c.accent))),
        ),
      ),
    );
  }
}
