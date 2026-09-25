import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/presentation/pending_upload_resumer.dart';

class _Counting extends CollegeImportNotifier {
  static int resumes = 0;
  @override
  Future<CollegeImportState> build() async => const ImportIdle();
  @override
  Future<void> resumePendingUpload() async => resumes++;
}

void main() {
  testWidgets('reprend l’envoi en attente au démarrage et à chaque retour au premier plan, quel que soit l’onglet',
      (tester) async {
    _Counting.resumes = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [collegeImportProvider.overrideWith(_Counting.new)],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: PendingUploadResumer(child: Text('onglet Aujourd’hui')),
      ),
    ));
    await tester.pump();
    expect(find.text('onglet Aujourd’hui'), findsOneWidget);
    expect(_Counting.resumes, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_Counting.resumes, 2);
  });
}
