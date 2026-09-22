import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_segmented.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_segmented_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;
const _ranks = ['Tous', 'A', 'B', 'C'];

/// Hôte à état : le parent tient la valeur, comme un écran réel.
class _Host extends StatefulWidget {
  const _Host({this.onChanged});

  final ValueChanged<String>? onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String selected = 'Tous';

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(CgSpace.gutter),
        child: CgSegmented<String>(
          values: _ranks,
          labelOf: (v) => v,
          selected: selected,
          onChanged: (v) {
            widget.onChanged?.call(v);
            setState(() => selected = v);
          },
        ),
      );
}

Rect _pill(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('cg-segmented-pill')));

void main() {
  group('rail et pastille', () {
    testWidgets('rail soft rayon s, pastille surface sous la valeur sélectionnée', (tester) async {
      await tester.pumpWidget(cgTestApp(const _Host()));
      final rail = tester.widget<DecoratedBox>(find.byKey(const ValueKey('cg-segmented-rail')));
      final railDeco = rail.decoration as BoxDecoration;
      expect(railDeco.color, c.soft);
      expect(railDeco.borderRadius, CgRadius.sAll);
      final pill = tester.widget<DecoratedBox>(
        find.descendant(of: find.byKey(const ValueKey('cg-segmented-pill')), matching: find.byType(DecoratedBox)),
      );
      final pillDeco = pill.decoration as BoxDecoration;
      expect(pillDeco.color, c.surface);
      expect(pillDeco.boxShadow, isNotEmpty);
      expect(_pill(tester).center.dx, closeTo(tester.getCenter(find.text('Tous')).dx, 1));
    });

    testWidgets('texte : ink 600 sélectionné, ink2 sinon', (tester) async {
      await tester.pumpWidget(cgTestApp(const _Host()));
      final on = tester.widget<Text>(find.text('Tous')).style!;
      final off = tester.widget<Text>(find.text('A')).style!;
      expect(on.color, c.ink);
      expect(on.fontWeight, FontWeight.w600);
      expect(off.color, c.ink2);
    });

    testWidgets('cibles ≥ 44 pt, segments de largeur égale', (tester) async {
      await tester.pumpWidget(cgTestApp(const _Host()));
      final segments = find.byKey(const ValueKey('cg-segmented-segment'));
      expect(segments, findsNWidgets(4));
      final widths = <double>{};
      for (var i = 0; i < 4; i++) {
        final size = tester.getSize(segments.at(i));
        widths.add(size.width.roundToDouble());
        expect(size.height, greaterThanOrEqualTo(CgSpace.tapTarget));
      }
      expect(widths, hasLength(1));
    });

    test('2 à 4 valeurs (assert)', () {
      expect(
        () => CgSegmented<int>(values: const [1], labelOf: (v) => '$v', selected: 1, onChanged: (_) {}),
        throwsAssertionError,
      );
      expect(
        () => CgSegmented<int>(values: const [1, 2, 3, 4, 5], labelOf: (v) => '$v', selected: 1, onChanged: (_) {}),
        throwsAssertionError,
      );
    });
  });

  group('sélection', () {
    testWidgets('tap : onChanged, haptique selection, la pastille glisse en CgMotion.base', (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        haptics.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final changes = <String>[];
      await tester.pumpWidget(cgTestApp(_Host(onChanged: changes.add)));
      final start = _pill(tester).left;
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(changes, ['B']);
      expect(
        haptics.where((m) => m.method == 'HapticFeedback.vibrate' && m.arguments == 'HapticFeedbackType.selectionClick'),
        hasLength(1),
      );
      await tester.pump(CgMotion.base ~/ 2);
      final mid = _pill(tester).left;
      expect(mid, greaterThan(start));
      await tester.pumpAndSettle();
      expect(_pill(tester).center.dx, closeTo(tester.getCenter(find.text('B')).dx, 1));
      expect(_pill(tester).left, greaterThan(mid));
    });

    testWidgets('tap sur la valeur déjà sélectionnée : rien', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(cgTestApp(_Host(onChanged: changes.add)));
      await tester.tap(find.text('Tous'));
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('mouvement réduit : la pastille saute directement', (tester) async {
      await tester.pumpWidget(cgTestApp(const _Host(), disableAnimations: true));
      await tester.tap(find.text('C'));
      await tester.pump();
      await tester.pump();
      expect(_pill(tester).center.dx, closeTo(tester.getCenter(find.text('C')).dx, 1));
    });
  });

  group('Dynamic Type', () {
    testWidgets('1,6 : reste un segmented, sans débordement', (tester) async {
      await tester.pumpWidget(cgTestApp(const _Host(), textScale: 1.6));
      expect(find.byKey(const ValueKey('cg-segmented-pill')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('> 1,6 : liste de lignes à coche', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(cgTestApp(SingleChildScrollView(child: _Host(onChanged: changes.add)), textScale: 2));
      expect(find.byKey(const ValueKey('cg-segmented-pill')), findsNothing);
      final rows = find.byKey(const ValueKey('cg-segmented-row'));
      expect(rows, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(rows.at(i)).height, greaterThanOrEqualTo(CgSpace.tapTarget));
      }
      // Coche accent sur la seule valeur sélectionnée.
      final checks = tester.widgetList<CgIcon>(find.byType(CgIcon)).where((i) => i.svg == CgIcons.check);
      expect(checks, hasLength(1));
      expect(checks.single.color, c.accent);
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(changes, ['A']);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Semantics : groupe exclusif, bouton, sélectionné', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(cgTestApp(const _Host()));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('cg-segmented-segment')).first),
      matchesSemantics(
        label: 'Tous',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('cg-segmented-segment')).at(1)),
      matchesSemantics(
        label: 'A',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  group('goldens', () {
    cgGoldenMatrix('cg_segmented', () => const CgSegmentedGallery(), height: 760);
  });
}
