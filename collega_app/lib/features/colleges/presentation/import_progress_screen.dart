import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/import_messages.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

enum _Step { done, active, pending }

/// Import en cours (story 8.13, spec v2 § Parcours 4) : les étapes, les fiches
/// qui arrivent, « tu peux fermer » ; à la fin, le collège prêt s'ouvre.
class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({super.key, required this.collegeId, required this.refId, this.reimport = false});

  final String collegeId;
  final int refId;

  /// Réimport : toute erreur commence par « Tes fiches restent ».
  final bool reimport;

  @override
  ConsumerState<ImportProgressScreen> createState() => _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _resync);
  bool _finished = false;

  /// Reprise lancée et terminée sans rien savoir de l'import (serveur injoignable,
  /// statut inattendu) : on le dit, avec « Réessayer ».
  bool _resyncFailed = false;

  @override
  void initState() {
    super.initState();
    _lifecycle; // retour au premier plan : resynchronise l'import
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(collegeImportProvider).valueOrNull;
      if (state is ImportComplete) {
        _openCollege();
      } else if (state is! ImportStreaming && state is! ImportError) {
        // Ouvert sans import suivi (app relancée, lien) : le serveur dit où il en est.
        _resync();
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _resync() async {
    if (mounted && _resyncFailed) setState(() => _resyncFailed = false);
    await ref.read(collegeImportProvider.notifier).reconnectIfActive(widget.collegeId);
    if (!mounted) return;
    final state = ref.read(collegeImportProvider).valueOrNull;
    if (state is! ImportStreaming && state is! ImportError && state is! ImportComplete) {
      setState(() => _resyncFailed = true);
    }
  }

  /// Fin d'import : le collège prêt, pas le catalogue (spec v2 § Parcours 1).
  void _openCollege() {
    if (_finished || !mounted) return;
    _finished = true;
    CgHaptics.success();
    context.go('/colleges/${widget.refId}');
  }

  /// L'import continue : le collège dit « Les fiches arrivent » (l'écran d'import
  /// dessous proposerait à tort de choisir un autre PDF).
  void _close() => context.go('/colleges/${widget.refId}');

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final name = collegeCatalogEntry(widget.refId)?.name ?? 'Import';
    final state = ref.watch(collegeImportProvider).valueOrNull;
    ref.listen<AsyncValue<CollegeImportState>>(collegeImportProvider, (_, next) {
      if (next.valueOrNull is ImportComplete) _openCollege();
    });

    final List<Widget> children;
    if (state is ImportError) {
      children = [
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
          child: CgState.error(
            title: 'L’import n’a pas abouti',
            message: importErrorMessage(state.message, reimport: widget.reimport),
            actionLabel: 'Relancer l’import',
            onAction: () => context.go('/colleges/${widget.refId}/import'),
          ),
        ),
      ];
    } else if (state is ImportStreaming) {
      children = _progress(c, state);
    } else if (_resyncFailed) {
      children = [
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
          child: CgState.error(
            title: 'L’import n’a pas pu reprendre',
            message: 'Rien n’est perdu : le serveur continue l’import. Vérifie ta connexion et réessaie.',
            actionLabel: 'Réessayer',
            onAction: _resync,
          ),
        ),
      ];
    } else {
      children = [
        const SizedBox(height: CgSpace.s5),
        Text('Reprise de l’import…', style: CgType.body.copyWith(color: c.ink2)),
        const SizedBox(height: CgSpace.s4),
        const CgSkeletonList(rows: 4),
      ];
    }

    return ColoredBox(
      color: c.ground,
      child: CgPage(
        title: name,
        subtitle: 'Import en cours',
        bottomAction: CgButton(label: 'Fermer', variant: CgButtonVariant.quiet, onPressed: _close),
        children: children,
      ),
    );
  }

  List<Widget> _progress(CgColors c, ImportStreaming s) {
    final generating = s.status == 'ocr_complete';
    final reading = !generating;
    final pages = s.totalPages;
    final readingDetail = pages != null && pages > 0 && s.ocrProgress > 0
        ? 'Page ${s.ocrProgress} sur $pages'
        : 'Analyse du document';
    final total = s.itemsTotal;
    final generatingDetail = total != null && total > 0 ? 'Item ${s.itemsDone} sur $total' : 'Démarrage';
    return [
      if (generating) ...[
        const SizedBox(height: CgSpace.s5),
        Semantics(
          liveRegion: true,
          container: true,
          label: '${s.cards} ${s.cards > 1 ? 'fiches prêtes' : 'fiche prête'}',
          excludeSemantics: true,
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: CgSpace.s2, children: [
            CgTextScaleCap(child: Text('${s.cards}', style: CgType.numeral.copyWith(color: c.ink))),
            Padding(
              padding: const EdgeInsets.only(bottom: CgSpace.s2),
              child: Text(s.cards > 1 ? 'fiches prêtes' : 'fiche prête', style: CgType.body.copyWith(color: c.ink2)),
            ),
          ]),
        ),
      ],
      if (generating && s.preview.isNotEmpty) ...[
        const SizedBox(height: CgSpace.s3),
        Text('Dernières fiches', style: CgType.label.copyWith(color: c.ink3, fontWeight: FontWeight.w600)),
        const SizedBox(height: CgSpace.s1),
        for (final q in s.preview.take(_previewMax))
          Padding(
            padding: const EdgeInsets.only(top: CgSpace.s1),
            child: Text(q, maxLines: 2, overflow: TextOverflow.ellipsis, style: CgType.bodyS.copyWith(color: c.ink2)),
          ),
      ],
      const SizedBox(height: CgSpace.section),
      const _StepRow(label: 'Envoi du PDF', step: _Step.done, last: false),
      _StepRow(label: 'Lecture du PDF', step: reading ? _Step.active : _Step.done, detail: reading ? readingDetail : null, last: false),
      _StepRow(
        label: 'Génération des fiches',
        step: generating ? _Step.active : _Step.pending,
        detail: generating ? generatingDetail : null,
        last: false,
      ),
      const _StepRow(label: 'Classement', step: _Step.pending, last: true),
      const SizedBox(height: CgSpace.section),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CgIcon(CgIcons.bell, size: _iconSize, color: c.accent),
        const SizedBox(width: CgSpace.s3),
        Expanded(
          child: Text(
            'Tu peux fermer Collega : on te prévient quand les fiches sont prêtes.',
            style: CgType.bodyS.copyWith(color: c.ink2),
          ),
        ),
      ]),
    ];
  }

  static const _iconSize = 20.0;
  static const _previewMax = 3;
}

/// Étape : pastille (cochée / anneau / creux), libellé, détail ; lue en entier.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.step, required this.last, this.detail});

  final String label;
  final _Step step;
  final String? detail;
  final bool last;

  static const _dot = 28.0;
  static const _rail = 2.0;
  static const _gap = CgSpace.s5;
  static const _checkSize = 16.0;
  static const _ring = 2.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final status = switch (step) {
      _Step.done => 'fait',
      _Step.active => 'en cours',
      _Step.pending => 'à venir',
    };
    return Semantics(
      container: true,
      label: [label, status, if (detail != null) detail!.toLowerCase()].join(', '),
      excludeSemantics: true,
      // Le trait descend jusqu'à l'étape suivante, quelle que soit la hauteur du texte.
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step == _Step.done ? c.accent : c.surface,
                border: Border.all(color: step == _Step.pending ? c.line : c.accent, width: _ring),
              ),
              child: step == _Step.done
                  ? Center(child: CgIcon(CgIcons.check, size: _checkSize, color: c.accentInk))
                  : null,
            ),
            if (!last) Expanded(child: Container(width: _rail, color: step == _Step.done ? c.accent : c.line)),
          ]),
          const SizedBox(width: CgSpace.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: CgSpace.s1, bottom: last ? 0 : _gap),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  label,
                  style: CgType.body.copyWith(
                    color: step == _Step.pending ? c.ink3 : c.ink,
                    fontWeight: step == _Step.active ? FontWeight.w600 : null,
                  ),
                ),
                if (detail != null) Text(detail!, style: CgType.bodyS.copyWith(color: c.ink2)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
