import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/import_messages.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

/// Quota de réimport (null : premier import, ou limites injoignables).
final _reloadLimitsProvider = FutureProvider.autoDispose.family<ReloadLimits?, int>((ref, refId) async {
  final entries = await ref.watch(collegesProvider.future);
  final imported = entries.any((e) => e.catalog.refId == refId && e.isImported);
  if (!imported) return null;
  try {
    return await ref.read(collegeImportRepositoryProvider).getReloadLimits(refId);
  } catch (_) {
    return null;
  }
});

/// Écran d'import (story 8.13, spec v2 § Parcours 4) : tout ce qu'il faut savoir
/// avant de choisir le PDF ; l'envoi et ses erreurs restent à l'écran.
class CollegeImportScreen extends ConsumerStatefulWidget {
  const CollegeImportScreen({super.key, required this.refId});

  final int refId;

  @override
  ConsumerState<CollegeImportScreen> createState() => _CollegeImportScreenState();
}

class _CollegeImportScreenState extends ConsumerState<CollegeImportScreen> {
  static const _maxPdfBytes = 500 * 1024 * 1024;

  /// Erreur affichée sous le bloc d'information (taille, envoi, quota).
  String? _error;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // Chaque ouverture repart d'un état propre (un envoi en cours est conservé).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(collegeImportProvider.notifier).reset();
    });
  }

  bool get _isReimport =>
      ref.read(collegesProvider).valueOrNull?.any((e) => e.catalog.refId == widget.refId && e.isImported) ?? false;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final PickedPdf? picked;
      try {
        picked = await ref.read(pdfPickerProvider)();
      } catch (_) {
        if (mounted) setState(() => _error = 'Le fichier n’a pas pu être ouvert. Réessaie.');
        return;
      }
      final pdf = picked;
      if (pdf == null || !mounted) return;
      if (pdf.size > _maxPdfBytes) {
        setState(() => _error = tooLargeMessage(pdf.size));
        return;
      }
      await ref.read(collegeImportProvider.notifier).startImport(widget.refId, pdf.file);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/colleges');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final catalog = collegeCatalogEntry(widget.refId);
    final importState = ref.watch(collegeImportProvider).valueOrNull;
    final limits = ref.watch(_reloadLimitsProvider(widget.refId));
    final isReimport = _isReimport;

    ref.listen<AsyncValue<CollegeImportState>>(collegeImportProvider, (previous, next) {
      // Écran recouvert (import en cours ouvert par-dessus) : il ne réagit plus,
      // sinon une reprise après erreur ouvrirait un second écran de progression.
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final value = next.valueOrNull;
      // L'écran d'import en cours ne s'ouvre qu'à la TRANSITION vers le streaming
      // (chaque événement produit un nouvel état : régression prod 2026-09-21).
      if (value is ImportStreaming && previous?.valueOrNull is! ImportStreaming) {
        context.push(
          '/colleges/${widget.refId}/import/progress',
          extra: {'collegeId': value.collegeId, 'refId': widget.refId, 'reimport': isReimport},
        );
      } else if (value is ImportError && previous?.valueOrNull is! ImportError) {
        if (value.message == 'subscription_required') {
          context.push('/paywall');
        } else {
          CgHaptics.error();
          setState(() => _error = importErrorMessage(value.message, reimport: isReimport));
        }
      }
    });

    if (catalog == null) {
      return ColoredBox(
        color: c.ground,
        child: CgPage(
          title: 'Import',
          backLabel: 'Retour',
          onBack: _back,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
              child: CgState.error(
                title: 'Ce collège est introuvable',
                message: 'Le lien ne mène à aucun collège du catalogue.',
                actionLabel: 'Retour',
                onAction: _back,
              ),
            ),
          ],
        ),
      );
    }

    final limitsValue = limits.valueOrNull;
    final blocked = limitsValue != null && (limitsValue.isCollegeLimitReached || limitsValue.isMonthlyLimitReached);
    // Envoi en cours : celui de ce collège (barre) ou d'un autre (bouton inactif).
    final uploadingRef = importState is ImportUploading ? importState.refId : null;
    final uploading = importState is ImportUploading && (uploadingRef == null || uploadingRef == widget.refId);
    final otherUpload = importState is ImportUploading && !uploading;
    final progress = importState is ImportUploading ? importState.progress : null;

    final quota = !isReimport
        ? 'Premier import de ce collège'
        : limitsValue == null
            ? 'Réimport : remplace les fiches actuelles'
            : 'Réimport ${limitsValue.collegeReloadCount + 1}/${limitsValue.collegeReloadMax} · '
                '${limitsValue.monthlyReloads + 1}/${limitsValue.monthlyMax} ce mois';
    final blockedMessage = limitsValue == null
        ? null
        : limitsValue.isCollegeLimitReached
            ? importErrorMessage('college_reload_limit', reimport: true)
            : limitsValue.isMonthlyLimitReached
                ? importErrorMessage('monthly_reload_limit:${limitsValue.monthlyResetAt}', reimport: true)
                : null;
    final shownError = _error ?? blockedMessage ?? (otherUpload ? importErrorMessage('upload_in_progress') : null);

    return ColoredBox(
      color: c.ground,
      child: CgPage(
        title: catalog.name,
        subtitle: isReimport ? 'Réimporter le PDF' : 'Importer le PDF',
        backLabel: 'Retour',
        onBack: _back,
        bottomAction: CgButton(
          label: 'Choisir le PDF',
          loading: uploading || _picking,
          onPressed: blocked || uploading || otherUpload ? null : _pick,
        ),
        children: [
          const SizedBox(height: CgSpace.s5),
          Row(children: [
            CgRowIcon(catalog.icon),
            const SizedBox(width: CgSpace.s3),
            Expanded(child: Text(catalog.editor, style: CgType.body.copyWith(color: c.ink2))),
          ]),
          const SizedBox(height: CgSpace.s5),
          _InfoBlock(lines: [
            (CgIcons.document, 'Le PDF officiel du collège (${catalog.editor})'),
            (CgIcons.upload, '500 Mo au plus'),
            (CgIcons.clock, '3 à 10 minutes selon la taille'),
            (CgIcons.refresh, quota),
            (CgIcons.bell, 'Tu peux fermer Collega pendant l’import : on te prévient quand les fiches sont prêtes.'),
          ]),
          if (uploading) ...[
            const SizedBox(height: CgSpace.s5),
            _UploadProgress(progress: progress),
          ],
          if (shownError != null) ...[
            const SizedBox(height: CgSpace.s5),
            Semantics(
              liveRegion: true,
              container: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CgIcon(CgIcons.warning, size: _iconSize, color: c.warningInk),
                const SizedBox(width: CgSpace.s2),
                Expanded(child: Text(shownError, style: CgType.bodyS.copyWith(color: c.warningInk))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  static const _iconSize = 18.0;
}

/// Ce qu'il faut savoir avant d'importer.
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.lines});

  final List<(String, String)> lines;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.all(CgSpace.s4),
      decoration: BoxDecoration(color: c.surface, borderRadius: CgRadius.lAll),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, (icon, text)) in lines.indexed) ...[
          if (i > 0) const SizedBox(height: CgSpace.s3),
          MergeSemantics(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CgIcon(icon, size: _iconSize, color: c.accent),
              const SizedBox(width: CgSpace.s3),
              Expanded(child: Text(text, style: CgType.body.copyWith(color: c.ink))),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Barre d'envoi (upload par morceaux, story 7.11).
class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});

  /// 0..1 ; null : envoi en une fois (pas de pourcentage).
  final double? progress;

  static const _barHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final p = progress;
    final label = p == null ? 'Envoi en cours…' : 'Envoi ${(p * 100).round()} % · continue en arrière-plan';
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: CgRadius.pill,
          child: SizedBox(
            height: _barHeight,
            child: ColoredBox(
              color: c.unseen,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (p ?? 0).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: ColoredBox(color: c.accent),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CgSpace.s2),
        Text(label, style: CgType.bodyS.copyWith(color: c.ink2)),
      ]),
    );
  }
}
