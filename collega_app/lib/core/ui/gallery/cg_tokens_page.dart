import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/brand/cg_wordmark.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';
import 'package:collega_app/core/ui/tokens/contrast.dart';

/// Page « Tokens » du catalogue (Widgetbook + goldens) : la source unique de
/// vérité visuelle rendue lisible. Outil de développement, jamais routé dans l'app.
class CgTokensPage extends StatelessWidget {
  const CgTokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.beforeLargeTitle, CgSpace.gutter, CgSpace.section),
      child: DefaultTextStyle(
        style: CgType.body.copyWith(color: c.ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CgWordmark(height: 36),
            const SizedBox(height: CgSpace.related),
            Text('Collega UI · tokens v2', style: CgType.bodyS.copyWith(color: c.ink2)),
            _Section('Palette', children: [
              for (final s in _swatches(c)) _SwatchRow(s, ground: c.ground),
            ]),
            _Section('Typographie', children: [
              for (final e in CgType.all.entries) _TypeRow(e.key, e.value),
            ]),
            _Section('Espaces', children: [
              for (final e in _spaces.entries) _SpaceRow(e.key, e.value),
            ]),
            _Section('Rayons', children: [
              Wrap(spacing: CgSpace.s4, runSpacing: CgSpace.s4, children: [
                for (final e in _radii.entries) _RadiusSample(e.key, e.value),
              ]),
            ]),
            _Section('Mouvement', children: [
              for (final e in _durations.entries)
                _KeyValue(e.key, '${e.value.inMilliseconds} ms'),
            ]),
          ],
        ),
      ),
    );
  }
}

typedef _Swatch = (String name, Color color);

List<_Swatch> _swatches(CgColors c) => [
      ('ground', c.ground), ('surface', c.surface), ('soft', c.soft),
      ('ink', c.ink), ('ink2', c.ink2), ('ink3', c.ink3), ('line', c.line),
      ('accent', c.accent), ('accentSoft', c.accentSoft), ('accentInk', c.accentInk),
      ('rankB', c.rankB), ('rankBSoft', c.rankBSoft), ('rankC', c.rankC),
      ('mastered', c.mastered), ('good', c.good), ('review', c.review),
      ('reviewInk', c.reviewInk), ('unseen', c.unseen), ('danger', c.danger),
    ];

const _spaces = {
  'related 8': CgSpace.related, 'row 16': CgSpace.row, 'gutter 20': CgSpace.gutter,
  'section 32': CgSpace.section, 'beforeLargeTitle 48': CgSpace.beforeLargeTitle,
  'tapTarget 44': CgSpace.tapTarget, 'button 54': CgSpace.buttonHeight,
};

const _radii = {
  'r-s 10': CgRadius.s, 'bouton 14': CgRadius.button, 'r-l 20': CgRadius.l, 'badge 6': CgRadius.badge,
};

const _durations = {
  'fast': CgMotion.fast, 'base': CgMotion.base, 'slow': CgMotion.slow,
  'sheetRise': CgMotion.sheetRise, 'ringFill': CgMotion.ringFill, 'toast': CgMotion.toast,
};

String _hex(Color color) {
  String channel(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'.toUpperCase();
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(top: CgSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CgType.title.copyWith(color: c.ink)),
          const SizedBox(height: CgSpace.related),
          ...children,
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow(this.swatch, {required this.ground});

  final _Swatch swatch;
  final Color ground;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final (name, color) = swatch;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CgSpace.s1),
      child: Row(children: [
        Container(
          width: CgSpace.tapTarget,
          height: CgSpace.tapTarget,
          decoration: BoxDecoration(
            color: color,
            borderRadius: CgRadius.sAll,
            border: Border.all(color: c.line),
          ),
        ),
        const SizedBox(width: CgSpace.s3),
        // Deux niveaux (nom puis valeur) : lisible jusqu'à 1,6× sans couper les mots.
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: CgType.head.copyWith(color: c.ink)),
            Text(
              '${_hex(color)} · ${contrastRatio(color, ground).toStringAsFixed(1)}:1 sur ground',
              style: CgType.meta.copyWith(color: c.ink2),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow(this.name, this.style);

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final isNumeric = style.fontSize! > CgType.titleL.fontSize!;
    final sample = Text(isNumeric ? '18/24' : 'Tumeurs 24', style: style.copyWith(color: c.ink), maxLines: 1, overflow: TextOverflow.ellipsis);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CgSpace.s1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$name · ${style.fontSize!.toStringAsFixed(style.fontSize! % 1 == 0 ? 0 : 1)} / ${style.fontWeight!.value}',
            style: CgType.label.copyWith(color: c.ink3)),
        // Les grands styles sont plafonnés à 1,3× (Dynamic Type), comme dans les écrans.
        if (style.fontSize! >= CgType.titleL.fontSize!) CgTextScaleCap(child: sample) else sample,
      ]),
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow(this.name, this.value);

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CgSpace.s1),
      child: Row(children: [
        Container(width: value, height: CgSpace.s3, color: c.accent),
        const SizedBox(width: CgSpace.s3),
        Expanded(child: Text(name, style: CgType.meta.copyWith(color: c.ink2))),
      ]),
    );
  }
}

class _RadiusSample extends StatelessWidget {
  const _RadiusSample(this.name, this.radius);

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Column(children: [
      Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: c.line),
        ),
      ),
      const SizedBox(height: CgSpace.s1),
      Text(name, style: CgType.label.copyWith(color: c.ink2)),
    ]);
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CgSpace.s1),
      child: Row(children: [
        Expanded(child: Text(name, style: CgType.bodyS.copyWith(color: c.ink))),
        Text(value, style: CgType.meta.copyWith(color: c.ink2)),
      ]),
    );
  }
}
