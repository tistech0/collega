import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_card_type_tag.dart';
import 'package:collega_app/core/ui/components/cg_verdict_bar.dart';
import 'package:collega_app/core/ui/foundation/cg_haptics.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

export 'package:collega_app/core/ui/components/cg_verdict_bar.dart' show CgVerdict;

/// L'écran de drill d'UNE fiche (spec v2 § Expérience définissante,
/// § CgDrillCard ; maquette `direction-d-fusion.html`, variante 2a « La réponse
/// glisse par le bas »).
///
/// Recto plein écran `accent` : ✕ · compteur · barre de session, rang +
/// collège, question centrée. Tap → verso : la question remonte en bandeau, la
/// feuille `ground` de la réponse monte depuis le bas avec la [CgVerdictBar].
///
/// Gestes du verso (sur la feuille seulement) : gauche = à revoir, droite =
/// maîtrisé, haut = bien ; bas = rien. Voir [CgDrillCardState] pour la
/// géométrie. Le recto ne se juge jamais : il résiste (8 pt) et l'invite se
/// renforce.
///
/// Conflit défilement / geste vertical (règle retenue) : quand la réponse
/// déborde de la feuille, un glissé VERTICAL qui commence sur le texte de la
/// réponse le fait défiler et ne donne jamais « bien » ; « bien » se fait alors
/// depuis le reste de la feuille (en-tête, invite de geste, marges) ou par le
/// bouton. Un glissé HORIZONTAL juge partout, texte compris. Une réponse qui
/// tient sans défiler accepte les trois gestes partout.
///
/// La carte ne gère qu'une fiche : [onVerdict] est appelé à la fin de
/// l'animation de sortie, et c'est l'écran qui passe à la suivante. Si l'écran
/// réutilise la même carte avec une autre question (ou un autre index), elle
/// revient d'elle-même au recto.
class CgDrillCard extends StatefulWidget {
  const CgDrillCard({
    super.key,
    required this.question,
    required this.answer,
    required this.rank,
    this.typeLabel,
    required this.collegeName,
    required this.index,
    required this.total,
    required this.onVerdict,
    required this.onClose,
    this.contextLabel = 'Session du jour',
    this.showFlipHint = true,
    this.answerHeader,
    this.frontInput,
    this.canFlip = true,
    this.onFlip,
    this.cardKey,
    this.trailing,
    this.initiallyFlipped = false,
    this.debugDragOffset,
  });

  final String question;
  final String answer;

  /// Rang de la fiche : `A`, `B` ou `C` (badge « Rang A »).
  final String rank;

  /// Type de la fiche : « Cas clinique » / « Définition » à côté du rang ; null
  /// (classique) : rien.
  final String? typeLabel;
  final String collegeName;

  /// Position de la fiche dans la session, à partir de 1 (« 3 / 24 »).
  final int index;
  final int total;

  /// Appelé une fois, à la fin de la sortie de la carte.
  final ValueChanged<CgVerdict> onVerdict;

  /// ✕ : l'écran demande confirmation (« Quitter ? »).
  final VoidCallback onClose;
  final String contextLabel;

  /// Invite « Touche pour voir la réponse » (première session seulement).
  final bool showFlipHint;

  /// Au-dessus de la réponse, dans la feuille (feedback du mode définition).
  final Widget? answerHeader;

  /// Mode définition : champ intégré au recto, sous la question.
  final Widget? frontInput;

  /// `false` : le tap ne retourne pas (saisie non validée). [CgDrillCardState.flip]
  /// reste disponible pour le parent.
  final bool canFlip;
  final VoidCallback? onFlip;

  /// Identité de l'instance de fiche dans la file (ex. `'<id>#<passage>'`) : quand elle
  /// change, la carte repart au recto — même si la question est identique (fiche
  /// « à revoir » réinsérée juste derrière elle-même, nouvel essai).
  final Object? cardKey;

  /// Emplacement droit de l'en-tête (44 pt), en miroir du ✕ : chronomètre (8.4).
  final Widget? trailing;

  /// Ouvre directement au verso, sans animation (reprise, planches).
  final bool initiallyFlipped;

  /// Fige un geste en cours sur le verso (planches et goldens) : décalage de la
  /// feuille, avec étiquette et rotation correspondantes.
  final Offset? debugDragOffset;

  /// Clés des parties observables (tests, écrans).
  static const progressKey = ValueKey('cg-drill-progress');
  static const sheetKey = ValueKey('cg-drill-sheet');
  static const answerKey = ValueKey('cg-drill-answer');
  static const closeKey = ValueKey('cg-drill-close');
  static Key previewKey(CgVerdict verdict) => ValueKey('cg-drill-preview-${verdict.name}');

  @override
  State<CgDrillCard> createState() => CgDrillCardState();
}

enum _Axis { horizontal, vertical, scroll }

/// État public : [flip] pour le mode définition (via `GlobalKey<CgDrillCardState>`).
class CgDrillCardState extends State<CgDrillCard> with TickerProviderStateMixin {
  // — Géométrie du geste (spec v2 § Critères de succès) —

  /// La direction dominante (horizontale / verticale) est verrouillée après 12 pt.
  static const lockDistance = 12.0;

  /// Bande du bord gauche réservée au balayage retour iOS : un glissé qui y commence
  /// ne juge jamais la fiche ; au-delà de [edgeCloseDistance] il appelle `onClose`
  /// (l'écran propose « Quitter ? », spec § Mécanique — Interruption).
  static const edgeSwipeWidth = 20.0;
  static const edgeCloseDistance = 60.0;

  /// L'étiquette de verdict apparaît à 40 pt de déplacement…
  static const previewStart = 40.0;

  /// … et atteint sa pleine opacité 80 pt plus loin.
  static const previewRamp = 80.0;

  /// Seuil horizontal : 35 % de la largeur de la carte.
  static const horizontalThreshold = 0.35;

  /// Seuil vers le haut : 25 % de la hauteur de la carte.
  static const upThreshold = 0.25;

  /// Résistance du recto (et du verso tiré vers le bas) : 8 pt au plus.
  static const resistance = 8.0;

  /// Rotation pendant le swipe : x / largeur × 6°.
  static const rotationDegrees = 6.0;

  /// Sortie horizontale : la feuille part à 1,3 × la largeur (maquette).
  static const exitWidthFactor = 1.3;

  // — Géométrie de l'écran (maquette 2a) — tokens manquants, constantes nommées —

  /// Haut de la feuille ouverte : 31 % de la hauteur.
  static const _sheetTopFraction = 0.31;

  /// Feuille fermée : translatée de 105 % de sa hauteur (sous l'écran).
  static const _sheetHiddenFraction = 1.05;

  /// Question du recto 30/600 (26 sous 390 pt de large), interligne 1,15, −2 %.
  static const _questionSize = 30.0;
  static const _questionSizeNarrow = 26.0;
  static const _narrowWidth = 390.0;
  static const _questionHeight = 1.15;
  static const _questionTracking = -0.02;

  /// Bandeau du verso 17/500 (taille de `head`), interligne 1,35.
  static const _bannerHeight = 1.35;

  /// Réponse 20/400 (interligne de `body`).
  static const _answerSize = 20.0;

  /// Fondu du bas de la réponse quand elle défile (indice « il y a une suite »).
  static const _answerFade = CgSpace.s8;

  /// Barre de session : segments de 4 pt espacés de 3 ; continue au-delà de 40 fiches.
  static const _progressHeight = 4.0;
  static const _segmentGap = 3.0;
  static const _maxSegments = 40;

  /// Badge de rang (hauteur du `CgBadge`).
  static const _badgeHeight = 22.0;

  /// Opacités du blanc sur `accent` (maquette) : rail et fond de badge.
  /// Textes secondaires : 0,75 au minimum (4,6:1, AA) — la maquette met
  /// l'invite à 0,7 (4,2:1).
  static const _railAlpha = 0.22;
  static const _badgeAlpha = 0.18;
  static const _secondaryTextAlpha = 0.75;
  static const _metaTextAlpha = 0.85;
  static const _bannerTextAlpha = 0.9;

  /// Ombre douce de la feuille (la seule autorisée, spec § Élévation).
  static const _shadowAlpha = 0.18;
  static const _shadowBlur = 40.0;
  static const _shadowOffset = Offset(0, -10);

  late final AnimationController _flip = AnimationController(vsync: this)..addListener(_tick);
  late final AnimationController _settle = AnimationController(vsync: this)..addListener(_onSettleTick);
  late final AnimationController _exit = AnimationController(vsync: this)
    ..addListener(_onExitTick)
    ..addStatusListener(_onExitStatus);

  final _questionScroll = ScrollController();
  final _answerScroll = ScrollController();
  final _progressLink = LayerLink();

  bool _open = false;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;

  Offset _settleFrom = Offset.zero;
  Offset _exitFrom = Offset.zero;
  Offset _exitTo = Offset.zero;
  CgVerdict? _exitVerdict;

  // Suivi du pointeur (un seul doigt).
  int? _pointer;
  Offset _start = Offset.zero;
  Offset _base = Offset.zero;
  _Axis? _axis;
  bool _answerCanScroll = false;

  /// Reste-t-il de la réponse sous le bord de la feuille ? (fondu en bas)
  bool _answerMoreBelow = false;
  bool _downOnSheet = false;
  bool _downOnAnswer = false;

  /// Le verso est-il affiché (ou en train de l'être) ?
  bool get isFlipped => _open;

  /// Décalage courant de la partie qui bouge (question au recto, feuille au verso).
  @visibleForTesting
  Offset get dragOffset => _offset;

  /// Rotation courante de la feuille (radians) ; 0 au recto et en mouvement réduit.
  @visibleForTesting
  double get dragRotation {
    if (!_open || _reduced || _size.width == 0) return 0;
    return _offset.dx / _size.width * rotationDegrees * math.pi / 180;
  }

  bool get _exiting => _exitVerdict != null;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    if (widget.initiallyFlipped) {
      _open = true;
      _flip.value = 1;
      _offset = widget.debugDragOffset ?? Offset.zero;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = CgMotion.reduced(context);
    // Mouvement réduit : fondus de 150 ms à la place des glissements (spec § Accessibilité).
    _flip.duration = _reduced ? CgMotion.fast : CgMotion.sheetRise;
    _settle.duration = CgMotion.resolve(context, CgMotion.base);
    _exit.duration = _reduced ? CgMotion.fast : CgMotion.base;
  }

  @override
  void didUpdateWidget(CgDrillCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nouvelle fiche, ou la même repassée après une sortie terminée : retour au recto
    // (sinon la carte resterait sortie, invisible et inerte).
    if (oldWidget.cardKey != widget.cardKey ||
        oldWidget.question != widget.question ||
        oldWidget.answer != widget.answer ||
        oldWidget.index != widget.index ||
        _exit.isCompleted) {
      _reset();
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _settle.dispose();
    _exit.dispose();
    _questionScroll.dispose();
    _answerScroll.dispose();
    super.dispose();
  }

  /// Retourne la fiche (recto → verso). Sans effet si elle l'est déjà ou sort.
  /// Ignore [CgDrillCard.canFlip] : c'est le chemin du parent (mode définition).
  void flip() {
    if (_open || _exiting) return;
    // Mode définition : le clavier ne doit pas recouvrir la feuille et les verdicts.
    FocusScope.of(context).unfocus();
    CgHaptics.flip();
    setState(() {
      _open = true;
      _settle.stop();
      _offset = Offset.zero;
      // Un doigt posé sur le recto (glissé en cours) ne jugera pas la réponse
      // ouverte sous lui (chrono expiré, définition validée) : il doit se relever.
      _pointer = null;
      _axis = null;
    });
    if (_questionScroll.hasClients) _questionScroll.jumpTo(0);
    _flip.forward();
    // VoiceOver : le focus reste sur la question ; la réponse est dite tout de suite.
    SemanticsService.announce('Réponse : ${widget.answer}', Directionality.of(context));
    widget.onFlip?.call();
  }

  /// Retour au recto, appelé pendant `didUpdateWidget` : les écouteurs des
  /// contrôleurs se taisent (pas de setState en plein build). Les zones
  /// défilables sont recréées par clé (fiche suivante = défilement à zéro).
  void _reset() {
    _quiet = true;
    _open = false;
    _exitVerdict = null;
    _offset = Offset.zero;
    _flip.value = 0;
    _settle.stop();
    _exit.value = 0;
    _quiet = false;
    _open = false;
    _offset = Offset.zero;
    _exitVerdict = null;
    _pointer = null;
    _axis = null;
  }

  bool _quiet = false;

  /// Identité de la fiche affichée : change → widgets recréés, sans animation résiduelle.
  ValueKey<Object> get _cardKey => ValueKey((widget.index, widget.question, widget.answer));

  void _tick() {
    if (!_quiet) setState(() {});
  }

  void _onSettleTick() {
    if (_quiet) return;
    setState(() => _offset = _settleFrom * (1 - CgMotion.elastic.transform(_settle.value)));
  }

  void _onExitTick() {
    if (_quiet) return;
    setState(() => _offset = Offset.lerp(_exitFrom, _exitTo, CgMotion.out.transform(_exit.value))!);
  }

  void _onExitStatus(AnimationStatus status) {
    final verdict = _exitVerdict;
    if (status == AnimationStatus.completed && verdict != null && mounted) widget.onVerdict(verdict);
  }

  // — Geste —

  int? _edgePointer;
  double _edgeStartX = 0;

  void _onPointerDown(PointerDownEvent e) {
    if (e.localPosition.dx < edgeSwipeWidth && _pointer == null) {
      _edgePointer = e.pointer;
      _edgeStartX = e.position.dx;
      _downOnSheet = _downOnAnswer = false;
      return;
    }
    final onSheet = _downOnSheet;
    final onAnswer = _downOnAnswer;
    _downOnSheet = _downOnAnswer = false;
    if (_pointer != null || _exiting || _size.isEmpty) return;
    // Au verso, seule la feuille se manipule (le bandeau de question est fixe).
    if (_open && !onSheet) return;
    _pointer = e.pointer;
    _start = e.position;
    _axis = null;
    _answerCanScroll = _open &&
        onAnswer &&
        _answerScroll.hasClients &&
        _answerScroll.position.maxScrollExtent > 0;
    _settle.stop();
    _base = _offset;
  }

  _Axis _axisFor(Offset d) {
    if (d.dx.abs() >= d.dy.abs()) return _Axis.horizontal;
    return _answerCanScroll ? _Axis.scroll : _Axis.vertical;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final d = e.position - _start;
    if (_axis == null && d.distance >= lockDistance) _axis = _axisFor(d);
    final axis = _axis ?? _axisFor(d);
    final raw = _base + d;
    var next = switch (axis) {
      _Axis.horizontal => Offset(raw.dx, 0),
      _Axis.vertical => Offset(0, raw.dy),
      _Axis.scroll => Offset.zero,
    };
    if (!_open) {
      // Recto : la carte résiste, jamais de verdict.
      next = Offset(next.dx.clamp(-resistance, resistance), next.dy.clamp(-resistance, resistance));
    } else if (next.dy > resistance) {
      // Verso tiré vers le bas : aucun verdict, même résistance.
      next = Offset(0, resistance);
    }
    setState(() => _offset = next);
  }

  void _onPointerUp(PointerEvent e) {
    if (e.pointer == _edgePointer) {
      _edgePointer = null;
      if (e is PointerUpEvent && e.position.dx - _edgeStartX >= edgeCloseDistance && !_exiting) {
        widget.onClose();
      }
      return;
    }
    if (e.pointer != _pointer) return;
    final axis = _axis;
    setState(() {
      _pointer = null;
      _axis = null;
    });
    if (_open && e is PointerUpEvent) {
      if (axis == _Axis.horizontal && _offset.dx.abs() > _size.width * horizontalThreshold) {
        return _exitWith(_offset.dx < 0 ? CgVerdict.review : CgVerdict.mastered, haptic: true);
      }
      if (axis == _Axis.vertical && -_offset.dy > _size.height * upThreshold) {
        return _exitWith(CgVerdict.good, haptic: true);
      }
    }
    _settleBack();
  }

  void _settleBack() {
    if (_offset == Offset.zero) return;
    _settleFrom = _offset;
    _settle.forward(from: 0);
  }

  /// Sortie dans la direction du verdict, puis [CgDrillCard.onVerdict].
  /// [haptic] : faux quand la [CgVerdictBar] a déjà joué la sienne.
  void _exitWith(CgVerdict verdict, {required bool haptic}) {
    if (_exiting) return;
    if (haptic) {
      switch (verdict) {
        case CgVerdict.review:
          CgHaptics.review();
        case CgVerdict.good:
          CgHaptics.good();
        case CgVerdict.mastered:
          CgHaptics.mastered();
      }
    }
    _settle.stop();
    _pointer = null;
    _exitVerdict = verdict;
    _exitFrom = _offset;
    // Mouvement réduit : la feuille s'efface sur place.
    _exitTo = _reduced
        ? _offset
        : switch (verdict) {
            CgVerdict.review => Offset(-_size.width * exitWidthFactor, 0),
            CgVerdict.mastered => Offset(_size.width * exitWidthFactor, 0),
            CgVerdict.good => Offset(0, -_size.height),
          };
    _exit.forward(from: 0);
  }

  double get _strongestPreview => CgVerdict.values.map(_previewOpacity).reduce(math.max);

  double _ramp(double distance) => ((distance - previewStart) / previewRamp).clamp(0.0, 1.0);

  double _previewOpacity(CgVerdict v) {
    if (!_open) return 0;
    final fade = 1 - _exit.value;
    return fade *
        switch (v) {
          CgVerdict.review => _ramp(-_offset.dx),
          CgVerdict.mastered => _ramp(_offset.dx),
          CgVerdict.good => _ramp(-_offset.dy),
        };
  }

  // — Rendu —

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final sheetTop = box.maxHeight * _sheetTopFraction;
      // Clavier ouvert (mode définition) : le recto remonte au-dessus de lui.
      final frontBottom = math.max(padding.bottom + CgSpace.s5, keyboard + CgSpace.s3);
      // Au verso, la zone de la question s'arrête au-dessus de la feuille.
      final bannerInset = math.max(0.0, box.maxHeight - frontBottom - sheetTop + CgSpace.s3);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !_open && widget.canFlip ? flip : null,
          child: ColoredBox(
            color: c.accent,
            child: DefaultTextStyle(
              style: CgType.body.copyWith(color: c.accentInk),
              child: Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(CgSpace.gutter, padding.top, CgSpace.gutter, frontBottom),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _header(c),
                      const SizedBox(height: CgSpace.s3),
                      CompositedTransformTarget(link: _progressLink, child: _progress(c)),
                      Expanded(
                        child: Opacity(
                          opacity: 1 - _exit.value,
                          child: Transform.translate(
                            offset: _open ? Offset.zero : _offset,
                            child: KeyedSubtree(
                              key: _cardKey,
                              child: _front(c, box.maxWidth < _narrowWidth, bannerInset),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                Positioned(
                  top: sheetTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _sheet(c, padding.bottom, box.maxHeight - sheetTop),
                ),
                Positioned(
                  top: 0,
                  left: CgSpace.gutter,
                  right: CgSpace.gutter,
                  child: _previews(c),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _header(CgColors c) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
      child: Row(children: [
        Semantics(
          button: true,
          label: 'Quitter la session',
          excludeSemantics: true,
          onTap: widget.onClose,
          child: GestureDetector(
            key: CgDrillCard.closeKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: SizedBox.square(
              dimension: CgSpace.tapTarget,
              child: Center(
                child: CgIcon(CgIcons.close, color: c.accentInk.withValues(alpha: _metaTextAlpha)),
              ),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            label: 'Fiche ${widget.index} sur ${widget.total}, ${widget.contextLabel}',
            excludeSemantics: true,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${widget.index} / ${widget.total}',
                textAlign: TextAlign.center,
                style: CgType.bodyS.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.accentInk,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                widget.contextLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CgType.meta.copyWith(color: c.accentInk.withValues(alpha: _secondaryTextAlpha)),
              ),
            ]),
          ),
        ),
        SizedBox.square(dimension: CgSpace.tapTarget, child: Center(child: widget.trailing)),
      ]),
    );
  }

  Widget _progress(CgColors c) {
    final total = math.max(widget.total, 1);
    // La barre avance avec la sortie de la carte, pas après (spec § Critères de succès).
    final done = (widget.index - 1 + (_exiting ? 1 : 0)).clamp(0, total);
    final on = c.accentInk;
    final off = c.accentInk.withValues(alpha: _railAlpha);
    const radius = BorderRadius.all(Radius.circular(_progressHeight / 2));
    final duration = CgMotion.resolve(context, CgMotion.base);
    final Widget bar;
    if (total > _maxSegments) {
      bar = Stack(children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: off, borderRadius: radius))),
        TweenAnimationBuilder<double>(
          tween: Tween(end: done / total),
          duration: duration,
          curve: CgMotion.out,
          builder: (context, value, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: DecoratedBox(decoration: BoxDecoration(color: on, borderRadius: radius)),
          ),
        ),
      ]);
    } else {
      bar = Row(children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: _segmentGap),
          Expanded(
            child: AnimatedContainer(
              duration: duration,
              curve: CgMotion.out,
              decoration: BoxDecoration(color: i < done ? on : off, borderRadius: radius),
            ),
          ),
        ],
      ]);
    }
    return ExcludeSemantics(
      child: SizedBox(key: CgDrillCard.progressKey, height: _progressHeight, child: bar),
    );
  }

  Widget _front(CgColors c, bool narrow, double bannerInset) {
    final lift = CgMotion.resolve(context, CgMotion.questionLift);
    final size = narrow ? _questionSizeNarrow : _questionSize;
    final big = CgType.titleL.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: _questionHeight,
      letterSpacing: size * _questionTracking,
      color: c.accentInk,
    );
    final banner = CgType.head.copyWith(
      fontWeight: FontWeight.w500,
      height: _bannerHeight,
      letterSpacing: 0,
      color: c.accentInk.withValues(alpha: _bannerTextAlpha),
    );
    final dragging = _pointer != null && _axis != null && !_open;
    final hintOpacity = !widget.canFlip || _open
        ? 0.0
        : dragging
            ? 1.0
            : widget.showFlipHint
                ? _secondaryTextAlpha
                : 0.0;

    // Question : plafonnée à 1,3× (comme les grands titres), défilable au recto
    // si elle ne tient pas, tronquée au nombre de lignes qui tiennent au verso.
    final question = CgTextScaleCap(
      child: LayoutBuilder(builder: (context, area) {
        final scaler = MediaQuery.textScalerOf(context);
        final bannerLine = scaler.scale(banner.fontSize!) * _bannerHeight;
        final bannerLines = math.max(1, (area.maxHeight / bannerLine).floor());
        return SingleChildScrollView(
          controller: _questionScroll,
          physics: _open ? const NeverScrollableScrollPhysics() : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: area.maxHeight),
            child: AnimatedAlign(
              alignment: _open ? Alignment.topLeft : Alignment.centerLeft,
              duration: lift,
              curve: CgMotion.out,
              child: AnimatedDefaultTextStyle(
                style: _open ? banner : big,
                duration: lift,
                curve: CgMotion.out,
                child: Text(
                  widget.question,
                  maxLines: _open ? bannerLines : null,
                  overflow: _open ? TextOverflow.ellipsis : TextOverflow.clip,
                ),
              ),
            ),
          ),
        );
      }),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: AnimatedPadding(
          padding: EdgeInsets.only(bottom: _open ? bannerInset : 0),
          duration: lift,
          curve: CgMotion.out,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: CgSpace.s8),
            Expanded(
              child: Semantics(
                container: true,
                label: '${_frontLabel()}. Question : ${widget.question}',
                hint: !_open && widget.canFlip ? 'Touche pour voir la réponse' : null,
                onTap: !_open && widget.canFlip ? flip : null,
                excludeSemantics: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // L'étiquette de verdict prend la place de la ligne rang · collège.
                  Opacity(opacity: 1 - _strongestPreview, child: _meta(c)),
                  const SizedBox(height: CgSpace.s6),
                  Expanded(child: question),
                ]),
              ),
            ),
            if (widget.frontInput != null)
              _collapse(
                open: !_open,
                // Replié au verso : hors de l'arbre de VoiceOver.
                child: ExcludeSemantics(
                  excluding: _open,
                  child: Padding(padding: const EdgeInsets.only(top: CgSpace.s4), child: widget.frontInput),
                ),
              ),
          ]),
        ),
      ),
      _collapse(
        open: !_open,
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: hintOpacity,
            duration: CgMotion.resolve(context, CgMotion.fast),
            child: Padding(
              padding: const EdgeInsets.only(top: CgSpace.s3, bottom: CgSpace.s2),
              child: Text(
                'Touche pour voir la réponse',
                textAlign: TextAlign.center,
                style: CgType.label.copyWith(fontWeight: FontWeight.w400, letterSpacing: 0, color: c.accentInk),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  /// Replie un élément du recto (invite, champ) quand la fiche se retourne.
  Widget _collapse({required bool open, required Widget child}) => ClipRect(
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: open ? 1 : 0,
          duration: CgMotion.resolve(context, CgMotion.questionLift),
          curve: CgMotion.out,
          child: child,
        ),
      );

  /// « Fiche rang A, cas clinique, Cancérologie » (le type seulement s'il est affiché).
  String _frontLabel() => [
        'Fiche rang ${widget.rank}',
        if (widget.typeLabel case final type?) type.toLowerCase(),
        widget.collegeName,
      ].join(', ');

  Widget _meta(CgColors c) {
    return Row(children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _badgeHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.accentInk.withValues(alpha: _badgeAlpha),
            borderRadius: CgRadius.badgeAll,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CgSpace.s2),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                'Rang ${widget.rank}',
                style: CgType.label.copyWith(fontWeight: FontWeight.w600, color: c.accentInk),
              ),
            ),
          ),
        ),
      ),
      if (widget.typeLabel != null) ...[
        const SizedBox(width: CgSpace.s2),
        CgCardTypeTag(widget.typeLabel, onAccent: true),
      ],
      const SizedBox(width: CgSpace.s2),
      Flexible(
        child: Text(
          widget.collegeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CgType.meta.copyWith(color: c.accentInk.withValues(alpha: _metaTextAlpha)),
        ),
      ),
    ]);
  }

  Widget _sheet(CgColors c, double bottomPadding, double height) {
    final t = CgMotion.out.transform(_flip.value);
    final slide = _reduced ? 0.0 : (1 - t) * height * _sheetHiddenFraction;
    final opacity = (_reduced ? _flip.value : 1.0) * (1 - _exit.value);
    final transform = Matrix4.translationValues(_offset.dx, _offset.dy + slide, 0)..rotateZ(dragRotation);

    return IgnorePointer(
      ignoring: !_open || _exiting,
      child: ExcludeSemantics(
        excluding: !_open,
        child: Listener(
          onPointerDown: (_) => _downOnSheet = true,
          child: Opacity(
            key: CgDrillCard.sheetKey,
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.ground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(CgRadius.l)),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: _shadowAlpha),
                      blurRadius: _shadowBlur,
                      offset: _shadowOffset,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.s5, CgSpace.gutter, CgSpace.s5 + bottomPadding),
                  child: DefaultTextStyle(
                    style: CgType.body.copyWith(color: c.ink),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (widget.answerHeader != null) ...[
                        widget.answerHeader!,
                        const SizedBox(height: CgSpace.s3),
                      ],
                      Expanded(child: _answer(c)),
                      const SizedBox(height: CgSpace.s3),
                      Text(
                        "Glisse à droite si tu maîtrises, à gauche pour revoir, vers le haut si c'est bien",
                        textAlign: TextAlign.center,
                        // `ink2` et non `ink3` (maquette) : consigne lue, 13 pt → contraste AA.
                        style: CgType.label.copyWith(fontWeight: FontWeight.w400, letterSpacing: 0, color: c.ink2),
                      ),
                      const SizedBox(height: CgSpace.s3),
                      CgVerdictBar(onVerdict: (v) => _exitWith(v, haptic: false)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _answer(CgColors c) {
    final scroll = LayoutBuilder(builder: (context, area) {
        return SingleChildScrollView(
          key: CgDrillCard.answerKey,
          controller: _answerScroll,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: area.maxHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.answer,
                style: CgType.body.copyWith(fontSize: _answerSize, color: c.ink),
              ),
            ),
          ),
        );
      });
    return Listener(
      key: _cardKey,
      onPointerDown: (_) => _downOnAnswer = true,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _onAnswerMetrics(n.metrics),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) => _onAnswerMetrics(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [1 - _answerFade / math.max(rect.height, _answerFade), 1],
              colors: [c.ink, c.ink.withValues(alpha: _answerMoreBelow ? 0 : 1)],
            ).createShader(rect),
            // Barre native, visible dès que la réponse défile : la suite existe.
            child: CupertinoScrollbar(controller: _answerScroll, thumbVisibility: true, child: scroll),
          ),
        ),
      ),
    );
  }

  bool _onAnswerMetrics(ScrollMetrics m) {
    final more = m.extentAfter > 0;
    if (more != _answerMoreBelow && mounted) setState(() => _answerMoreBelow = more);
    return false;
  }

  Widget _previews(CgColors c) {
    Widget label(CgVerdict v, Color fill, Color text, Alignment alignment) => Align(
          alignment: alignment,
          child: Opacity(
            key: CgDrillCard.previewKey(v),
            opacity: _previewOpacity(v),
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, borderRadius: CgRadius.badgeAll),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3, vertical: CgSpace.s1),
                child: Text(v.label, style: CgType.bodyS.copyWith(fontWeight: FontWeight.w700, color: text)),
              ),
            ),
          ),
        );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CompositedTransformFollower(
          link: _progressLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          // Même hauteur que la ligne rang · collège (qu'elle remplace).
          offset: const Offset(0, CgSpace.s8),
          child: Stack(children: [
            label(CgVerdict.review, c.review, c.onReview, Alignment.topLeft),
            label(CgVerdict.good, c.good, c.ink, Alignment.topCenter),
            label(CgVerdict.mastered, c.ink, c.ground, Alignment.topRight),
          ]),
        ),
      ),
    );
  }
}
