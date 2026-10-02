import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/pdf/domain/pdf_labels.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';

/// Copie absente ou périmée : choisir sur le téléphone le PDF importé (le
/// serveur ne le garde pas après la génération), ou le télécharger pour les
/// imports d'avant ce changement, tant que le serveur l'a encore.
class PdfMissingView extends StatelessWidget {
  const PdfMissingView({
    super.key,
    required this.collegeName,
    required this.sizeBytes,
    required this.outdated,
    this.available = true,
    required this.download,
    required this.onDownload,
    this.attach = const PdfAttachIdle(),
    this.onAttach,
  });

  final String collegeName;
  final int? sizeBytes;
  final bool outdated;

  /// Faux quand le serveur n'annonce aucun PDF (backend ancien, fichier
  /// absent) : rien à télécharger, on le dit sans bouton.
  final bool available;
  final PdfDownloadState download;
  final VoidCallback onDownload;
  final PdfAttachState attach;
  final VoidCallback? onAttach;

  /// Le serveur a encore le fichier (taille annoncée) : téléchargement ; sinon
  /// le fichier se choisit sur le téléphone.
  bool get _canDownload => sizeBytes != null;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final size = sizeBytes == null ? null : megabytesLabel(sizeBytes!);
    final title = !available
        ? 'Ton PDF n’est pas disponible pour l’instant'
        : outdated
            ? 'Une nouvelle version de ton PDF est disponible'
            : 'Ton PDF n’est pas sur ce téléphone';
    final d = download;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s4),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: CgRowIcon(CgIcons.document)),
            const SizedBox(height: CgSpace.s4),
            Semantics(
                header: true,
                child: Text(title, textAlign: TextAlign.center, style: CgType.head.copyWith(color: c.ink))),
            const SizedBox(height: CgSpace.s2),
            Text(
              !available
                  ? '$collegeName. Réessaie plus tard : il sera téléchargeable depuis cet écran.'
                  : _canDownload
                      ? '${[collegeName, if (size != null) size].join(' · ')}. '
                          'Une fois téléchargé, il reste disponible hors connexion.'
                      : '$collegeName. Collega ne garde pas tes PDF sur ses serveurs : '
                          'choisis le fichier que tu as importé pour le relire ici.',
              textAlign: TextAlign.center,
              style: CgType.bodyS.copyWith(color: c.ink2),
            ),
            if (available && !_canDownload) ..._attachControls(c),
            if (available && _canDownload) ...[
              const SizedBox(height: CgSpace.s4),
              switch (d) {
                PdfDownloading(:final progress) => Semantics(
                    label: 'Téléchargement, ${(progress * 100).round()} %',
                    child: _ProgressLine(value: progress),
                  ),
                PdfDownloadFailedState() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Le téléchargement n’a pas abouti',
                        textAlign: TextAlign.center, style: CgType.bodyS.copyWith(color: c.ink2)),
                    const SizedBox(height: CgSpace.s2),
                    CgButton(label: 'Réessayer', variant: CgButtonVariant.secondary, onPressed: onDownload),
                  ]),
                _ => CgButton(label: size == null ? 'Télécharger' : 'Télécharger ($size)', onPressed: onDownload),
              },
              const SizedBox(height: CgSpace.s2),
              Text('Le Wi-Fi est conseillé. Tu peux quitter cet écran pendant le téléchargement.',
                  textAlign: TextAlign.center, style: CgType.meta.copyWith(color: c.ink3)),
            ],
          ]),
    );
  }

  List<Widget> _attachControls(CgColors c) {
    final message = switch (attach) {
      PdfAttachChecking() => 'Vérification du fichier…',
      PdfAttachMismatch() => 'Ce fichier n’est pas le PDF importé pour ce collège. '
          'Choisis le même fichier, ou réimporte ce PDF depuis la page du collège.',
      PdfAttachFailed() => 'La vérification n’a pas abouti. Vérifie ta connexion et réessaie.',
      _ => null,
    };
    final again = attach is PdfAttachMismatch || attach is PdfAttachFailed;
    return [
      const SizedBox(height: CgSpace.s4),
      if (message != null) ...[
        Text(message, textAlign: TextAlign.center, style: CgType.bodyS.copyWith(color: c.ink2)),
        const SizedBox(height: CgSpace.s2),
      ],
      CgButton(
        label: again ? 'Choisir un autre fichier' : 'Choisir mon PDF',
        variant: again ? CgButtonVariant.secondary : CgButtonVariant.primary,
        onPressed: attach is PdfAttachChecking ? null : onAttach,
      ),
    ];
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ClipRRect(
      borderRadius: CgRadius.pill,
      child: SizedBox(
        height: 6,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: c.line)),
          FractionallySizedBox(widthFactor: value.clamp(0, 1), child: ColoredBox(color: c.accent)),
        ]),
      ),
    );
  }
}
