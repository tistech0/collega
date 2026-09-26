import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/presentation/card_report.dart';

import '../../support/cg_golden.dart';

void main() {
  Future<CardReportResult?> open(WidgetTester tester, Future<void> Function() act) async {
    CardReportResult? result;
    await tester.pumpWidget(cgTestApp(Builder(
      builder: (context) => GestureDetector(
        onTap: () async => result = await showCardReportSheet(
          context,
          message: 'Message.',
          regenerateLabel: 'Régénérer et continuer',
          laterLabel: 'Continuer sans régénérer',
        ),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('titre, message, note facultative ; « Régénérer » renvoie la note rognée', (tester) async {
    final result = await open(tester, () async {
      expect(find.text('Signaler cette fiche'), findsOneWidget);
      expect(find.text('Message.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '  Réponse fausse  ');
      await tester.tap(find.text('Régénérer et continuer'));
    });
    expect(result?.choice, CardReportChoice.regenerate);
    expect(result?.note, 'Réponse fausse');
  });

  testWidgets('« Continuer sans régénérer » → later, note vide → null', (tester) async {
    final result = await open(tester, () => tester.tap(find.text('Continuer sans régénérer')));
    expect(result?.choice, CardReportChoice.later);
    expect(result?.note, isNull);
  });
}
