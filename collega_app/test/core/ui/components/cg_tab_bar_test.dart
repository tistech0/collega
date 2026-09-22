import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_tab_bar_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;
const _screen = Size(393, 852);
const _labels = ['Aujourd’hui', 'Bibliothèque', 'Progression', 'Profil'];

Finder _cell(int i) => find.byKey(ValueKey('cg-tab-$i'));
final _capsule = find.byKey(const ValueKey('cg-tab-capsule'));
final _pill = find.byKey(const ValueKey('cg-tab-pill'));

/// Tab bar posée en bas d'un écran iPhone (safe area basse 34).
Future<void> _pumpBar(
  WidgetTester tester, {
  int current = 0,
  ValueChanged<int>? onTap,
  bool collapsed = false,
  double textScale = 1,
  bool disableAnimations = false,
  double safeBottom = 34,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(cgTestApp(
    Builder(builder: (context) {
      final padding = EdgeInsets.only(bottom: safeBottom);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding, viewPadding: padding),
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CgTabBar(
              items: CgTabBar.mainItems,
              currentIndex: current,
              onTap: onTap ?? (_) {},
              collapsed: collapsed,
            ),
          ),
        ]),
      );
    }),
    textScale: textScale,
    disableAnimations: disableAnimations,
  ));
}

void main() {
  test('onglets de l’app : Aujourd’hui, Bibliothèque, Progression, Profil', () {
    expect(CgTabBar.mainItems.map((i) => i.label), _labels);
    expect(CgTabBar.mainItems.map((i) => i.icon), [CgIcons.today, CgIcons.library, CgIcons.progress, CgIcons.profile]);
  });

  group('anatomie', () {
    testWidgets('capsule 64 pt, 24 pt des bords, 22 pt + safe area du bas', (tester) async {
      await _pumpBar(tester);
      final rect = tester.getRect(_capsule);
      expect(rect.height, CgSpace.tabBarHeight);
      expect(rect.left, CgSpace.tabBarInset);
      expect(rect.right, _screen.width - CgSpace.tabBarInset);
      expect(rect.bottom, _screen.height - CgSpace.tabBarBottom - 34);
    });

    testWidgets('fond surface à 78 % + flou σ 24 + ombre douce', (tester) async {
      await _pumpBar(tester);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: _capsule, matching: find.byKey(const ValueKey('cg-tab-fill'))),
      );
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, c.surface.withValues(alpha: 0.78));
      final shadowBox = tester.widget<DecoratedBox>(_capsule);
      expect((shadowBox.decoration as BoxDecoration).boxShadow, isNotEmpty);
      final blur = tester.widget<BackdropFilter>(find.descendant(of: _capsule, matching: find.byType(BackdropFilter)));
      expect(blur.filter, ImageFilter.blur(sigmaX: 24, sigmaY: 24));
    });

    testWidgets('4 cellules : icône 22 + libellé tab ; actif accent, inactifs ink3', (tester) async {
      await _pumpBar(tester, current: 1);
      for (var i = 0; i < 4; i++) {
        final label = tester.widget<Text>(find.text(_labels[i]));
        expect(label.style!.fontSize, CgType.tab.fontSize);
        expect(label.style!.color, i == 1 ? c.accent : c.ink3, reason: _labels[i]);
        final icon = tester.widget<CgIcon>(find.descendant(of: _cell(i), matching: find.byType(CgIcon)));
        expect(icon.size, 22);
        expect(icon.color, i == 1 ? c.accent : c.ink3);
      }
    });

    testWidgets('pastille accentSoft sous l’onglet actif', (tester) async {
      await _pumpBar(tester, current: 2);
      final pill = tester.widget<DecoratedBox>(_pill);
      expect((pill.decoration as BoxDecoration).color, c.accentSoft);
      expect(tester.getCenter(_pill).dx, closeTo(tester.getCenter(_cell(2)).dx, 0.5));
    });

    testWidgets('cibles ≥ 44 pt', (tester) async {
      await _pumpBar(tester);
      for (var i = 0; i < 4; i++) {
        final size = tester.getSize(_cell(i));
        expect(size.width, greaterThanOrEqualTo(CgSpace.tapTarget));
        expect(size.height, greaterThanOrEqualTo(CgSpace.tapTarget));
      }
    });

    testWidgets('reservedHeight = 64 + 22 + safe area', (tester) async {
      await _pumpBar(tester);
      expect(CgTabBar.reservedHeight(tester.element(find.byType(CgTabBar))), 64 + 22 + 34);
      expect(tester.getSize(find.byType(CgTabBar)).height, 64 + 22 + 34);
    });
  });

  group('comportement', () {
    late List<String> haptics;
    setUp(() {
      haptics = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('changement d’onglet : onTap + haptique sélection', (tester) async {
      final taps = <int>[];
      await _pumpBar(tester, onTap: taps.add);
      await tester.tap(_cell(2));
      expect(taps, [2]);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('onglet déjà actif : onTap appelé (remonter en haut), sans haptique', (tester) async {
      final taps = <int>[];
      await _pumpBar(tester, current: 1, onTap: taps.add);
      await tester.tap(_cell(1));
      expect(taps, [1]);
      expect(haptics, isEmpty);
    });

    testWidgets('la pastille glisse en CgMotion.fast vers le nouvel onglet', (tester) async {
      await _pumpBar(tester, current: 0);
      final from = tester.getCenter(_pill).dx;
      await _pumpBar(tester, current: 3);
      await tester.pump(CgMotion.fast ~/ 2);
      final mid = tester.getCenter(_pill).dx;
      expect(mid, greaterThan(from));
      expect(mid, lessThan(tester.getCenter(_cell(3)).dx));
      await tester.pumpAndSettle();
      expect(tester.getCenter(_pill).dx, closeTo(tester.getCenter(_cell(3)).dx, 0.5));
    });

    testWidgets('mouvement réduit : la pastille saute sans glisser', (tester) async {
      await _pumpBar(tester, current: 0, disableAnimations: true);
      await _pumpBar(tester, current: 3, disableAnimations: true);
      await tester.pump();
      expect(tester.getCenter(_pill).dx, closeTo(tester.getCenter(_cell(3)).dx, 0.5));
    });

    testWidgets('collapsed : pastille d’icônes seules, plus étroite, centrée (transition base)', (tester) async {
      await _pumpBar(tester, current: 1);
      final full = tester.getRect(_capsule);
      await _pumpBar(tester, current: 1, collapsed: true);
      await tester.pump(CgMotion.base ~/ 2);
      expect(tester.getRect(_capsule).width, lessThan(full.width));
      await tester.pumpAndSettle();
      final small = tester.getRect(_capsule);
      expect(small.width, lessThan(full.width));
      expect(small.center.dx, closeTo(_screen.width / 2, 0.5));
      expect(find.text('Bibliothèque'), findsNothing);
      expect(find.byType(CgIcon), findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(_cell(i)).width, greaterThanOrEqualTo(CgSpace.tapTarget));
        expect(tester.getSize(_cell(i)).height, greaterThanOrEqualTo(CgSpace.tapTarget));
      }
      expect(tester.getCenter(_pill).dx, closeTo(tester.getCenter(_cell(1)).dx, 0.5));
    });
  });

  testWidgets('Semantics : chaque cellule est un bouton, sélection annoncée, libellé lu (même réduite)', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpBar(tester, current: 1, collapsed: true);
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(
        tester.getSemantics(_cell(i)),
        matchesSemantics(
          label: _labels[i],
          isButton: true,
          isSelected: i == 1,
          hasTapAction: true,
        ),
      );
    }
    handle.dispose();
  });

  testWidgets('Dynamic Type 1,6 et 2 : libellés plafonnés, aucun débordement', (tester) async {
    for (final scale in [1.6, 2.0]) {
      await _pumpBar(tester, textScale: scale, safeBottom: 0);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_capsule).height, CgSpace.tabBarHeight);
    }
  });

  testWidgets('écran d’exemple : en fin de liste, la dernière ligne reste au-dessus de la tab bar', (tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(cgTestApp(const CgTabBarGallery()));
    await tester.fling(find.byType(CustomScrollView), const Offset(0, -8000), 4000);
    await tester.pumpAndSettle();
    final last = find.text(CgTabBarGallery.catalog.last.$1);
    expect(tester.getBottomLeft(last).dy, lessThan(tester.getRect(_capsule).top));
  });

  group('goldens', () {
    cgGoldenMatrix('cg_tab_bar', () => const CgTabBarGallery(), height: 844);
    cgGoldenMatrix('cg_tab_bar_collapsed', () => const CgTabBarGallery(initialIndex: 2, collapsed: true), height: 844);
  });
}
