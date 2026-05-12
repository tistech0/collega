import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

class _FakeCollegeImportRepository extends CollegeImportRepository {
  _FakeCollegeImportRepository({
    this.importResult,
    this.throwOnImport,
  }) : super(dio: Dio());

  final ImportStartResponse? importResult;
  final Exception? throwOnImport;

  @override
  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async {
    if (throwOnImport != null) throw throwOnImport!;
    return importResult!;
  }

  @override
  Future<CollegeStatusResponse> getStatus(String collegeId) async {
    return CollegeStatusResponse(
      collegeId: collegeId,
      refId: 15,
      status: 'pending',
      ocrProgress: 0,
    );
  }
}

AppDatabase _makeInMemoryDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

ProviderContainer _makeContainer(_FakeCollegeImportRepository repo) {
  return ProviderContainer(
    overrides: [
      collegeImportRepositoryProvider.overrideWithValue(repo),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
      databaseProvider.overrideWithValue(_makeInMemoryDb()),
    ],
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Stub du channel flutter_secure_storage pour éviter les appels plateforme en test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('CollegeImportNotifier', () {
    test('startImport success → passe par ImportUploading puis ImportStreaming', () async {
      final repo = _FakeCollegeImportRepository(
        importResult: const ImportStartResponse(
          collegeId: 'college-uuid-15',
          jobId: 'job-uuid-1',
          status: 'pending',
        ),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final states = <CollegeImportState>[];
      container.listen<AsyncValue<CollegeImportState>>(
        collegeImportProvider,
        (_, next) {
          if (next.valueOrNull != null) states.add(next.value!);
        },
      );

      final tmpFile = File('${Directory.systemTemp.path}/test.pdf');
      tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

      await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

      expect(states.any((s) => s is ImportUploading), isTrue);
      final lastState = states.last;
      expect(lastState, isA<ImportStreaming>());
      if (lastState is ImportStreaming) {
        expect(lastState.collegeId, 'college-uuid-15');
        expect(lastState.jobId, 'job-uuid-1');
      }

      tmpFile.deleteSync();
    });

    test('startImport avec 403 → état ImportError subscription_required', () async {
      final repo = _FakeCollegeImportRepository(
        throwOnImport: const SubscriptionRequiredException(),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final tmpFile = File('${Directory.systemTemp.path}/test403.pdf');
      tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

      await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

      final state = container.read(collegeImportProvider).valueOrNull;
      expect(state, isA<ImportError>());
      if (state is ImportError) {
        expect(state.message, 'subscription_required');
      }

      tmpFile.deleteSync();
    });

    test('startImport avec 409 → état ImportError job_in_progress', () async {
      final repo = _FakeCollegeImportRepository(
        throwOnImport: const JobInProgressException(),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final tmpFile = File('${Directory.systemTemp.path}/test409.pdf');
      tmpFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D]);

      await container.read(collegeImportProvider.notifier).startImport(15, tmpFile);

      final state = container.read(collegeImportProvider).valueOrNull;
      expect(state, isA<ImportError>());
      if (state is ImportError) {
        expect(state.message, 'job_in_progress');
      }

      tmpFile.deleteSync();
    });
  });
}
