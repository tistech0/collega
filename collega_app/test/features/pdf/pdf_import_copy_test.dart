import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_client.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';

/// Dépôt d'import qui accepte tout de suite (202) : collège c26, job j1.
class _AcceptingRepo extends CollegeImportRepository {
  _AcceptingRepo() : super(dio: Dio());

  @override
  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async =>
      const ImportStartResponse(collegeId: 'c26', jobId: 'j1', status: 'pending');

  @override
  Future<CollegeStatusResponse> getStatus(String collegeId) async =>
      CollegeStatusResponse(collegeId: collegeId, refId: 26, status: 'pending', ocrProgress: 0);
}

class _FreshApiClient extends ApiClient {
  _FreshApiClient() : super(const FlutterSecureStorage());

  @override
  Future<bool> ensureFreshAccessToken() async => true;
}

ProviderContainer _container(List<Override> extra) {
  final c = ProviderContainer(overrides: [
    collegeImportRepositoryProvider.overrideWithValue(_AcceptingRepo()),
    secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
    databaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
    apiClientProvider.overrideWithValue(_FreshApiClient()),
    ...extra,
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late Directory tmp;
  late File picked;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfimport');
    picked = File('${tmp.path}/picked.pdf')..writeAsStringSync('%PDF-1.7');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('import accepté : le PDF choisi est gardé sous <collegeId>_<jobId>.pdf', () async {
    final store = LocalPdfStore(Directory('${tmp.path}/pdfs'));
    final container = _container([localPdfStoreProvider.overrideWith((ref) async => store)]);

    await container.read(collegeImportProvider.notifier).startImport(26, picked);

    expect(store.fileFor('c26', 'j1').existsSync(), isTrue);
    expect(picked.existsSync(), isTrue);
  });

  test('copie impossible : l’import continue quand même', () async {
    final container = _container([
      localPdfStoreProvider.overrideWith((ref) async => throw const FileSystemException('plein')),
    ]);

    await container.read(collegeImportProvider.notifier).startImport(26, picked);

    expect(container.read(collegeImportProvider).valueOrNull, isA<ImportStreaming>());
  });
}
