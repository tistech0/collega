import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_end_screen.dart';
import 'package:collega_app/features/drill/presentation/drill_timer_slot.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

/// Drill plein écran (story 8.4, maquette `direction-d-fusion.html` 2a) :
/// toucher pour voir la réponse, glisser ou choisir un verdict, fiche suivante.
/// Pas de tab bar, pas de retour par balayage natif : quitter passe par
/// « Quitter ? » (✕ ou balayage depuis le bord gauche).
class DrillScreen extends ConsumerWidget {
  const DrillScreen({super.key, required this.launch});

  final DrillLaunch launch;

  DrillSessionParams get params => launch.params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(drillSessionProvider(params));
    final session = async.valueOrNull;
    if (session == null && async.hasError) {
      return _DrillError(
        onRetry: () => ref.invalidate(drillSessionProvider(params)),
        onQuit: () => leaveDrill(context),
      );
    }
    if (session == null) return const _DrillLoading();
    if (session.isComplete) {
      return DrillEndScreen(
        session: session,
        notifier: ref.read(drillSessionProvider(params).notifier),
        params: params,
      );
    }
    return _DrillActive(launch: launch, session: session);
  }
}

/// Conséquence écrite de « Quitter ? » (spec § Feedback — Décision).
String quitMessage({required bool isDaily, required int judged, bool replaying = false}) {
  // « Refaire les à revoir » : la session du jour est close, rien n'est à reprendre.
  if (replaying) return 'Ta session du jour est déjà enregistrée.';
  if (isDaily) return 'Ta session reprendra là où tu l’as laissée.';
  if (judged == 0) return 'Aucune fiche n’a encore été jugée.';
  if (judged == 1) return '1 fiche jugée est enregistrée.';
  return '$judged fiches jugées sont enregistrées.';
}

/// Sort du drill vers l'écran d'origine (Aujourd'hui se recalcule au retour).
void leaveDrill(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

const _verdictResult = {
  CgVerdict.review: DrillEvaluationResult.aRevoir,
  CgVerdict.good: DrillEvaluationResult.bien,
  CgVerdict.mastered: DrillEvaluationResult.maitrise,
};

class _DrillActive extends ConsumerStatefulWidget {
  const _DrillActive({required this.launch, required this.session});

  final DrillLaunch launch;
  final DrillSessionState session;

  @override
  ConsumerState<_DrillActive> createState() => _DrillActiveState();
}

class _DrillActiveState extends ConsumerState<_DrillActive> {
  final _card = GlobalKey<CgDrillCardState>();
  final _answer = TextEditingController();
  late bool _timerOn = widget.launch.timerOn;
  bool _timerPaused = false;
  bool _submitting = false;

  DrillSessionParams get _params => widget.launch.params;
  DrillSessionNotifier get _notifier => ref.read(drillSessionProvider(_params).notifier);

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _onVerdict(CgVerdict verdict) async {
    final requeued = await _notifier.evaluate(_verdictResult[verdict]!);
    _notifier.advanceToNext();
    _answer.clear();
    if (requeued && mounted) showCgToast(context, 'Elle reviendra dans quelques questions');
  }

  void _onFlip() {
    final current = ref.read(drillSessionProvider(_params)).valueOrNull;
    if (current != null && !current.isFlipped) _notifier.flip();
  }

  Future<void> _submitDefinition(FlashCardModel card) async {
    final text = _answer.text.trim();
    if (text.isEmpty || _submitting) return;
    final position = widget.session.currentQueuePos;
    setState(() => _submitting = true);
    try {
      final feedback = await ref.read(drillRepositoryProvider).evaluateSemantic(card.id, text);
      _notifier.setSemanticFeedback(feedback, cardId: card.id);
    } catch (_) {
      // Évaluation indisponible (réseau) : la réponse s'ouvre quand même.
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    // Réponse arrivée après le passage à la fiche suivante : on n'ouvre rien.
    final now = ref.read(drillSessionProvider(_params)).valueOrNull;
    if (now == null || now.currentQueuePos != position || now.currentCard?.id != card.id) return;
    _card.currentState?.flip();
  }

  void _onTimerExpired() {
    // D'abord l'état (timerExpired), ensuite l'ouverture (qui passe isFlipped à vrai).
    _notifier.handleTimerExpiry();
    _card.currentState?.flip();
    if (mounted) showCgToast(context, 'Temps écoulé');
  }

  Future<void> _confirmQuit() async {
    // Le chrono s'arrête pendant la question : « Continuer » retrouve la fiche intacte.
    final wasPaused = _timerPaused;
    setState(() => _timerPaused = true);
    final quit = await showCgDialogSheet(
      context,
      title: 'Quitter ?',
      message: quitMessage(
        isDaily: _params.isDailySession,
        judged: widget.session.evaluatedCount,
        replaying: widget.session.replayingErrors,
      ),
      confirmLabel: 'Quitter',
      cancelLabel: 'Continuer',
    );
    if (!mounted) return;
    if (quit) {
      leaveDrill(context);
    } else {
      setState(() => _timerPaused = wasPaused);
    }
  }

  String _contextLabel(String collegeName) {
    if (_params.isDailySession) return 'Session du jour';
    if (_params.fromSearch) return 'Recherche';
    return _params.itemName ?? collegeName;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final card = session.currentCard!;
    final prefs = ref.watch(revisionPrefsProvider).valueOrNull ?? RevisionPrefs.defaults;
    final names = {
      for (final e in ref.watch(collegesProvider).valueOrNull ?? const [])
        if (e.userStatus != null) e.userStatus!.collegeId: e.catalog.name,
    };
    final collegeName = names[card.collegeId] ?? '';
    final isDefinition = card.cardType == 'definition';
    final feedback = session.semanticFeedback;
    final canFlip = !isDefinition || feedback != null || session.timerExpired;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: CgDrillCard(
        key: _card,
        cardKey: '${card.id}#${session.currentQueuePos}',
        question: card.recto,
        answer: card.verso,
        rank: card.rang,
        // Cas clinique : se révise comme une classique (retournement), seule l'étiquette change.
        cardType: CgCardType.parse(card.cardType),
        collegeName: collegeName,
        index: session.currentQueuePos + 1,
        total: session.queue.length,
        contextLabel: _contextLabel(collegeName),
        // Invite de retournement : tant que la première fiche n'est pas jugée.
        showFlipHint: session.evaluatedCount == 0 && !isDefinition,
        canFlip: canFlip,
        onFlip: _onFlip,
        onVerdict: _onVerdict,
        onClose: _confirmQuit,
        trailing: DrillTimerSlot(
          enabled: _timerOn && prefs.timerDurationSeconds > 0,
          paused: _timerPaused,
          running: !session.isFlipped,
          durationSeconds: prefs.timerDurationSeconds,
          cardKey: '${card.id}#${session.currentQueuePos}',
          onToggle: () => setState(() {
            _timerOn = !_timerOn;
            _timerPaused = false;
          }),
          onTogglePause: () => setState(() => _timerPaused = !_timerPaused),
          onExpired: _onTimerExpired,
        ),
        frontInput: isDefinition
            ? _DefinitionInput(
                controller: _answer,
                submitting: _submitting,
                onSubmit: () => _submitDefinition(card),
              )
            : null,
        answerHeader: feedback == null ? null : _SemanticFeedback(feedback: feedback),
      ),
    );
  }
}

/// Mode définition : l'étudiante écrit sa réponse avant de la voir (spec § Établi vs nouveau).
class _DefinitionInput extends StatelessWidget {
  const _DefinitionInput({required this.controller, required this.submitting, required this.onSubmit});

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CgField(
        controller: controller,
        kind: CgFieldKind.multiline,
        placeholder: 'Ta définition…',
        minLines: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
      ),
      const SizedBox(height: CgSpace.s3),
      CgButton(
        label: 'Valider',
        variant: CgButtonVariant.inverse,
        size: CgButtonSize.compact,
        loading: submitting,
        onPressed: onSubmit,
      ),
    ]);
  }
}

/// Retour de l'évaluation sémantique, en tête de la feuille réponse : un mot + le détail.
class _SemanticFeedback extends StatelessWidget {
  const _SemanticFeedback({required this.feedback});

  final SemanticFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final (label, color) = switch (feedback.result) {
      'correct' => ('Correct', c.mastered),
      'partial' => ('Partiel', c.ink2),
      _ => ('À revoir', c.reviewInk),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: CgSpace.s4),
      child: MergeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: CgType.head.copyWith(color: color)),
          const SizedBox(height: CgSpace.s1),
          Text(feedback.feedback, style: CgType.bodyS.copyWith(color: c.ink2)),
        ]),
      ),
    );
  }
}

class _DrillLoading extends StatelessWidget {
  const _DrillLoading();

  static const _blockAlpha = 0.14;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ColoredBox(
      key: const Key('drill-loading'),
      color: c.accent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CgSpace.gutter),
          child: Semantics(
            label: 'Chargement de la session',
            child: CgSkeletonPulse(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: CgSpace.section),
                for (final width in const [0.4, 0.9, 0.7])
                  Padding(
                    padding: const EdgeInsets.only(bottom: CgSpace.s3),
                    child: FractionallySizedBox(
                      widthFactor: width,
                      child: Container(
                        height: CgSpace.s6,
                        decoration: BoxDecoration(
                          color: c.accentInk.withValues(alpha: _blockAlpha),
                          borderRadius: CgRadius.sAll,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrillError extends StatelessWidget {
  const _DrillError({required this.onRetry, required this.onQuit});

  final VoidCallback onRetry;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ColoredBox(
      color: c.ground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CgSpace.gutter),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CgState.error(
              title: 'Tes fiches sont là',
              message: 'La session n’a pas pu s’ouvrir. Réessaie dans un instant.',
              actionLabel: 'Réessayer',
              onAction: onRetry,
            ),
            const SizedBox(height: CgSpace.s3),
            CgButton(label: 'Quitter', variant: CgButtonVariant.quiet, expand: false, onPressed: onQuit),
          ]),
        ),
      ),
    );
  }
}
