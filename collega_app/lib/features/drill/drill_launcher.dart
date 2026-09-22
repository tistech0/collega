import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

/// Ce que reçoit la route `/drill` (story 8.4).
@immutable
class DrillLaunch {
  const DrillLaunch({required this.params, this.timerOn = false});

  final DrillSessionParams params;

  /// Chronomètre actif au démarrage (modifiable pendant le drill).
  final bool timerOn;
}

/// Seul point d'entrée du drill (Aujourd'hui, détail d'item, recherche) :
/// - chronomètre selon le réglage ; en mode « Demander », une sheet pose la
///   question (la fermer annule le lancement) ;
/// - l'état du drill repart toujours de la base (jamais un écran de fin
///   resté en mémoire d'un lancement précédent).
Future<void> launchDrill(BuildContext context, WidgetRef ref, DrillSessionParams params) async {
  // Un seul lancement à la fois : un double tap pendant la lecture des réglages
  // ouvrirait deux drills (ou deux sheets) empilés.
  if (_launching) return;
  _launching = true;
  ({Future<void> closed})? drill;
  try {
    drill = await _launch(context, ref, params);
  } finally {
    // Le verrou tombe une frame après l'ouverture (la page du drill recouvre alors
    // le bouton) ; l'appelant, lui, attend la fin du drill (Aujourd'hui se
    // recalcule au retour).
    if (drill == null) {
      _launching = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _launching = false);
      WidgetsBinding.instance.scheduleFrame();
    }
  }
  await drill?.closed;
}

bool _launching = false;

/// Prépare puis ouvre le drill ; renvoie la fermeture du drill (null si annulé).
/// Dans un record : une fonction async qui renvoie un Future l'attendrait, et le
/// verrou resterait posé pendant tout le drill.
Future<({Future<void> closed})?> _launch(BuildContext context, WidgetRef ref, DrillSessionParams params) async {
  RevisionPrefs prefs;
  try {
    // Trousseau lent ou bloqué : la session démarre quand même, sans chrono.
    prefs = await ref.read(revisionPrefsProvider.future).timeout(const Duration(seconds: 2));
  } catch (_) {
    prefs = RevisionPrefs.defaults;
  }
  if (!context.mounted) return null;

  var timerOn = prefs.timerEnabled && prefs.timerDurationSeconds > 0;
  if (prefs.timerMode == TimerMode.ask) {
    final choice = await showCgSheet<bool>(
      context,
      title: 'Chronomètre pour cette session ?',
      builder: (sheetContext) => _TimerChoice(seconds: prefs.timerDurationSeconds),
    );
    if (choice == null || !context.mounted) return null;
    timerOn = choice;
  }

  ref.invalidate(drillSessionProvider(params));
  return (closed: context.push('/drill', extra: DrillLaunch(params: params, timerOn: timerOn)));
}

class _TimerChoice extends StatelessWidget {
  const _TimerChoice({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void choose(bool on) => Navigator.of(context, rootNavigator: true).pop(on);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
        child: Text(
          'Tu pourras l’activer ou le couper à tout moment pendant la session.',
          style: CgType.bodyS.copyWith(color: c.ink2),
        ),
      ),
      CgSheetFooter(
        primary: CgButton(label: 'Avec chrono · $seconds s', onPressed: () => choose(true)),
        secondary: CgButton(
          label: 'Sans chrono',
          variant: CgButtonVariant.secondary,
          onPressed: () => choose(false),
        ),
      ),
    ]);
  }
}
