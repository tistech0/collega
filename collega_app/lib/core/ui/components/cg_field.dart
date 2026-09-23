import 'package:flutter/cupertino.dart';

import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

enum CgFieldKind { text, email, password, search, multiline }

/// Champ de saisie (spec v2 § CgField) : login, recherche, mode définition,
/// feedback. Un `CupertinoTextField` natif (curseur, sélection, autofill,
/// clavier) habillé aux tokens Collega.
///
/// Libellé au-dessus, aide dessous, erreur à la place de l'aide. Le composant
/// ne valide rien : l'écran calcule [error] (au blur, puis à chaque frappe).
class CgField extends StatefulWidget {
  const CgField({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.focusNode,
    this.kind = CgFieldKind.text,
    this.helper,
    this.error,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.minLines = 3,
  });

  /// Libellé au-dessus du champ, aussi lu par VoiceOver sur le champ.
  final String? label;
  final String? placeholder;

  /// Optionnels : sans eux, le composant gère les siens.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  final CgFieldKind kind;

  /// Aide sous le champ (`ink2`), masquée quand [error] est présent.
  final String? helper;

  /// Message d'erreur (`danger`) : contour rouge + message annoncé.
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Par défaut : email pour `email`, mot de passe pour `password`.
  final Iterable<String>? autofillHints;
  final bool autofocus;

  /// Lignes visibles au minimum en `multiline` (ignoré sinon).
  final int minLines;

  @override
  State<CgField> createState() => _CgFieldState();
}

class _CgFieldState extends State<CgField> {
  /// Hauteurs minimales (le champ grandit avec le Dynamic Type).
  static const _fieldHeight = 50.0;
  static const _searchHeight = 40.0;

  static const _borderWidth = 1.0;
  static const _focusBorderWidth = 2.0;
  static const _searchIconSize = 18.0;
  static const _actionIconSize = 20.0;

  /// Les icônes suivent le Dynamic Type, plafonnées (comme les SF Symbols).
  static const _iconMaxScale = 1.3;

  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _revealed = false;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  bool get _hasError => widget.error != null && widget.error!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(CgField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  /// Focus (contour) et texte (bouton effacer) pilotent l'habillage.
  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final kind = widget.kind;
    final search = kind == CgFieldKind.search;
    final multiline = kind == CgFieldKind.multiline;
    final password = kind == CgFieldKind.password;
    final focused = _focusNode.hasFocus;
    final iconScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _iconMaxScale);

    final textStyle = (search ? CgType.bodyS : CgType.body).copyWith(color: widget.enabled ? c.ink : c.ink3);
    final placeholderStyle = textStyle.copyWith(color: c.ink3, overflow: TextOverflow.ellipsis);
    final padding = search
        ? const EdgeInsets.symmetric(horizontal: CgSpace.s2, vertical: CgSpace.s2)
        : const EdgeInsets.symmetric(horizontal: CgSpace.s4, vertical: CgSpace.s3);
    // Recherche : fond `soft` sans contour, même au focus (champ iOS natif).
    final Color? borderColor = _hasError
        ? c.danger
        : search
            // Recherche : sans contour au repos (maquette), contour accent au focus
            // pour que le focus reste visible au clavier externe (spec § Accessibilité).
            ? (focused ? c.accent : null)
            : (focused ? c.accent : c.line);

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      // Décoration vide (pas `null`) : sinon, désactivé, Cupertino peint son
      // propre fond gris carré par-dessus notre habillage.
      decoration: const BoxDecoration(),
      padding: padding,
      style: textStyle,
      // Multiligne : Cupertino centre le placeholder verticalement dans les
      // `minLines` lignes ; on le dessine nous-mêmes, en haut (voir plus bas).
      placeholder: multiline ? null : widget.placeholder,
      placeholderStyle: placeholderStyle,
      cursorColor: c.accent,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: switch (kind) {
        CgFieldKind.email => TextInputType.emailAddress,
        CgFieldKind.multiline => TextInputType.multiline,
        CgFieldKind.password => TextInputType.visiblePassword,
        _ => TextInputType.text,
      },
      textCapitalization: multiline ? TextCapitalization.sentences : TextCapitalization.none,
      obscureText: password && !_revealed,
      autocorrect: !(kind == CgFieldKind.email || password),
      enableSuggestions: !(kind == CgFieldKind.email || password),
      autofillHints: widget.autofillHints ??
          switch (kind) {
            CgFieldKind.email => const [AutofillHints.email],
            CgFieldKind.password => const [AutofillHints.password],
            _ => null,
          },
      textInputAction: widget.textInputAction ?? (search ? TextInputAction.search : null),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      minLines: multiline ? widget.minLines : null,
      maxLines: multiline ? null : 1,
      textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
    );

    // La recherche reste visuellement à 40 pt, mais la ligne fait 44 pt pour que
    // le bouton effacer ait une vraie cible tactile : le fond est inscrit dedans.
    final boxInset = search ? (CgSpace.tapTarget - _searchHeight) / 2 : 0.0;
    final field = Stack(children: [
      Positioned.fill(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: boxInset),
          child: DecoratedBox(
            key: const ValueKey('cg-field-box'),
            decoration: BoxDecoration(
              color: search ? c.soft : c.surface,
              borderRadius: CgRadius.sAll,
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor, width: focused ? _focusBorderWidth : _borderWidth),
            ),
          ),
        ),
      ),
      ConstrainedBox(
        constraints: BoxConstraints(minHeight: search ? CgSpace.tapTarget : _fieldHeight),
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (search)
              Padding(
                padding: const EdgeInsets.only(left: CgSpace.s3),
                child: CgIcon(CgIcons.search, size: iconScaler.scale(_searchIconSize), color: c.ink3),
              ),
            Expanded(
              // Multiligne : toujours un Stack (le champ garde sa place dans
              // l'arbre, donc son focus, quand le placeholder disparaît).
              child: multiline
                  ? Stack(children: [
                      _semantics(input),
                      if (widget.placeholder != null && _controller.text.isEmpty)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: padding,
                                child: Text(widget.placeholder!, style: placeholderStyle, maxLines: widget.minLines),
                              ),
                            ),
                          ),
                        ),
                    ])
                  : _semantics(input),
            ),
            if (password)
              _FieldAction(
                key: const ValueKey('cg-field-reveal'),
                icon: _revealed ? CgIcons.eyeOff : CgIcons.eye,
                color: c.ink2,
                size: iconScaler.scale(_actionIconSize),
                semanticLabel: _revealed ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
                onTap: widget.enabled ? () => setState(() => _revealed = !_revealed) : null,
              ),
            if (search && widget.enabled && _controller.text.isNotEmpty)
              _FieldAction(
                key: const ValueKey('cg-field-clear'),
                icon: CgIcons.clear,
                color: c.ink3,
                size: iconScaler.scale(_searchIconSize),
                semanticLabel: 'Effacer la recherche',
                onTap: _clear,
              ),
          ],
        ),
      ),
    ]);

    final message = _hasError ? widget.error : widget.helper;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          // Lu sur le champ lui-même (voir `_semantics`) : pas de doublon.
          ExcludeSemantics(
            child: Text(
              widget.label!,
              style: CgType.bodyS.copyWith(
                fontWeight: FontWeight.w500,
                color: widget.enabled ? c.ink : c.ink3,
              ),
            ),
          ),
          const SizedBox(height: CgSpace.related),
        ],
        field,
        if (message != null && message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: CgSpace.related),
            child: _hasError
                ? Semantics(
                    container: true,
                    liveRegion: true,
                    child: Text(message, style: CgType.meta.copyWith(color: c.danger)),
                  )
                : Text(message, style: CgType.meta.copyWith(color: c.ink2)),
          ),
      ],
    );
  }

  /// Le libellé visible devient le libellé du nœud « champ de texte ».
  Widget _semantics(Widget input) {
    final label = widget.label ?? widget.placeholder;
    if (label == null) return input;
    return Semantics(label: label, child: input);
  }
}

/// Bouton d'icône 44 × 44 dans le champ (œil, effacer).
class _FieldAction extends StatelessWidget {
  const _FieldAction({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
  });

  final String icon;
  final Color color;
  final double size;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CgSpace.tapTarget,
          child: Center(child: CgIcon(icon, size: size, color: color)),
        ),
      ),
    );
  }
}
