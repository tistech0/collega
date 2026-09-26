import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Texte d'une sheet, avec une note facultative (le champ gère son texte : rien
/// à libérer pendant l'animation de fermeture).
class CardNoteBody extends StatelessWidget {
  const CardNoteBody({super.key, required this.message, this.onNote});

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

enum CardReportChoice { regenerate, later }

class CardReportResult {
  const CardReportResult(this.choice, this.note);

  final CardReportChoice choice;

  /// Remarque rognée ; null si vide.
  final String? note;
}

/// Feuille « Signaler cette fiche » (vue item et drill) : remarque facultative,
/// régénérer ou non. Jamais de suppression ici. Fermée sans choix = plus tard.
Future<CardReportResult> showCardReportSheet(
  BuildContext context, {
  required String message,
  required String regenerateLabel,
  required String laterLabel,
}) async {
  var note = '';
  final choice = await showCgSheet<CardReportChoice>(
    context,
    title: 'Signaler cette fiche',
    builder: (_) => CardNoteBody(message: message, onNote: (v) => note = v),
    primary: Builder(
      builder: (s) => CgButton(
        label: regenerateLabel,
        onPressed: () => Navigator.of(s, rootNavigator: true).pop(CardReportChoice.regenerate),
      ),
    ),
    secondary: Builder(
      builder: (s) => CgButton(
        label: laterLabel,
        variant: CgButtonVariant.quiet,
        onPressed: () => Navigator.of(s, rootNavigator: true).pop(CardReportChoice.later),
      ),
    ),
  );
  final text = note.trim();
  return CardReportResult(choice ?? CardReportChoice.later, text.isEmpty ? null : text);
}
