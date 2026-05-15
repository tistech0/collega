import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/home/home_providers.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';
import 'package:collega_app/features/home/domain/home_session_config.dart';

void main() {
  group('HomeReady — intégration planning', () {
    const sessionConfig = HomeSessionConfig(
      collegeId: 'c1',
      collegeName: 'Cardiologie',
    );

    test('hasPlanningConfig = false si pas de config planning', () {
      const state = HomeReady(
        sessionConfig: sessionConfig,
        recentColleges: [],
        totalCards: 10,
        hasPlanningConfig: false,
      );
      expect(state.hasPlanningConfig, isFalse);
      expect(state.todaySession, isNull);
    });

    test('hasPlanningConfig = true si planning actif', () {
      const state = HomeReady(
        sessionConfig: sessionConfig,
        recentColleges: [],
        totalCards: 10,
        hasPlanningConfig: true,
      );
      expect(state.hasPlanningConfig, isTrue);
    });

    test('todaySession non-null si planning actif avec session du jour', () {
      final session = PlannedSession(
        id: 's1',
        planningConfigId: 'cfg1',
        sessionDate: DateTime.utc(2026, 1, 1),
        collegeId: 'c1',
        maxCards: 100,
        status: 'pending',
      );
      final state = HomeReady(
        sessionConfig: sessionConfig,
        recentColleges: [],
        totalCards: 10,
        hasPlanningConfig: true,
        todaySession: session,
      );
      expect(state.todaySession, isNotNull);
      expect(state.todaySession!.isPending, isTrue);
    });

    test('estimatedDuration reste fonctionnel avec planning', () {
      const state = HomeReady(
        sessionConfig: sessionConfig,
        recentColleges: [],
        totalCards: 25,
        hasPlanningConfig: true,
      );
      expect(state.estimatedDuration, '5 min');
    });
  });
}
