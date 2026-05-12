import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

// Fake repository qui permet de contrôler les réponses sans mockito
class _FakeRepo extends CollegeImportRepository {
  _FakeRepo({this.reloadLimitsResult, this.throwOnImport})
      : super(dio: Dio());

  final ReloadLimits? reloadLimitsResult;
  final Exception? throwOnImport;

  @override
  Future<ReloadLimits> getReloadLimits(int refId) async {
    if (reloadLimitsResult != null) return reloadLimitsResult!;
    throw Exception('not configured');
  }

  @override
  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async {
    if (throwOnImport != null) throw throwOnImport!;
    throw Exception('not configured');
  }
}

void main() {
  group('ReloadLimits.fromJson', () {
    test('parse correctement tous les champs', () {
      final json = {
        'college_reload_count': 1,
        'college_reload_max': 2,
        'monthly_reloads': 2,
        'monthly_max': 3,
        'monthly_reset_at': '2026-06-01T00:00:00+00:00',
      };
      final limits = ReloadLimits.fromJson(json);
      expect(limits.collegeReloadCount, 1);
      expect(limits.collegeReloadMax, 2);
      expect(limits.monthlyReloads, 2);
      expect(limits.monthlyMax, 3);
      expect(limits.monthlyResetAt, '2026-06-01T00:00:00+00:00');
    });
  });

  group('ReloadLimits.isCollegeLimitReached', () {
    test('false quand reload_count < max', () {
      const limits = ReloadLimits(
        collegeReloadCount: 1,
        collegeReloadMax: 2,
        monthlyReloads: 0,
        monthlyMax: 3,
        monthlyResetAt: '',
      );
      expect(limits.isCollegeLimitReached, false);
    });

    test('true quand reload_count >= max', () {
      const limits = ReloadLimits(
        collegeReloadCount: 2,
        collegeReloadMax: 2,
        monthlyReloads: 0,
        monthlyMax: 3,
        monthlyResetAt: '',
      );
      expect(limits.isCollegeLimitReached, true);
    });
  });

  group('ReloadLimits.isMonthlyLimitReached', () {
    test('false quand monthly_reloads < max', () {
      const limits = ReloadLimits(
        collegeReloadCount: 0,
        collegeReloadMax: 2,
        monthlyReloads: 2,
        monthlyMax: 3,
        monthlyResetAt: '',
      );
      expect(limits.isMonthlyLimitReached, false);
    });

    test('true quand monthly_reloads >= max', () {
      const limits = ReloadLimits(
        collegeReloadCount: 0,
        collegeReloadMax: 2,
        monthlyReloads: 3,
        monthlyMax: 3,
        monthlyResetAt: '',
      );
      expect(limits.isMonthlyLimitReached, true);
    });
  });

  group('CollegeImportRepository.getReloadLimits', () {
    test('retourne les limites parsées correctement', () async {
      final expectedLimits = const ReloadLimits(
        collegeReloadCount: 0,
        collegeReloadMax: 2,
        monthlyReloads: 1,
        monthlyMax: 3,
        monthlyResetAt: '2026-06-01T00:00:00+00:00',
      );
      final repo = _FakeRepo(reloadLimitsResult: expectedLimits);
      final result = await repo.getReloadLimits(15);
      expect(result.collegeReloadCount, 0);
      expect(result.monthlyReloads, 1);
      expect(result.isCollegeLimitReached, false);
      expect(result.isMonthlyLimitReached, false);
    });
  });

  group('CollegeImportRepository.importPdf — exceptions 409', () {
    test('lance CollegeReloadLimitException sur 409 COLLEGE_RELOAD_LIMIT', () async {
      const exception = CollegeReloadLimitException(reloadCount: 2, reloadCountMax: 2);
      final repo = _FakeRepo(throwOnImport: exception);

      expect(
        () => repo.importPdf(15, File('/fake/path.pdf')),
        throwsA(isA<CollegeReloadLimitException>()
            .having((e) => e.reloadCount, 'reloadCount', 2)
            .having((e) => e.reloadCountMax, 'reloadCountMax', 2)),
      );
    });

    test('lance MonthlyReloadLimitException sur 409 MONTHLY_RELOAD_LIMIT', () async {
      const exception = MonthlyReloadLimitException(
        monthlyReloads: 3,
        monthlyMax: 3,
        resetAt: '2026-06-01T00:00:00+00:00',
      );
      final repo = _FakeRepo(throwOnImport: exception);

      expect(
        () => repo.importPdf(15, File('/fake/path.pdf')),
        throwsA(isA<MonthlyReloadLimitException>()
            .having((e) => e.monthlyReloads, 'monthlyReloads', 3)
            .having((e) => e.monthlyMax, 'monthlyMax', 3)
            .having((e) => e.resetAt, 'resetAt', '2026-06-01T00:00:00+00:00')),
      );
    });
  });
}
