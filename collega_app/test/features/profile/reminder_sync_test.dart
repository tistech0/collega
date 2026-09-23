import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/profile/domain/reminder_sync.dart';
import 'package:collega_app/features/profile/domain/reminder_time.dart';

class _Notifications extends NotificationsService {
  _Notifications() : super(dio: Dio(), router: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())]));
  final sent = <int>[];
  @override
  Future<void> setReminder(int hourUtc) async => sent.add(hourUtc);
}

class _Auth extends AuthNotifier {
  final saved = <(int?, int?)>[];
  @override
  Future<AuthState> build() async => const AuthState();
  @override
  Future<void> setReminderHour(int? hourUtc, {int? localHour}) async => saved.add((hourUtc, localHour));
}

void main() {
  final now = DateTime(2026, 11, 2); // après le passage à l'heure d'hiver
  late ProviderContainer container;
  late _Auth auth;
  late _Notifications notifications;

  setUp(() async {
    container = ProviderContainer(overrides: [authProvider.overrideWith(_Auth.new)]);
    await container.read(authProvider.future);
    auth = container.read(authProvider.notifier) as _Auth;
    notifications = _Notifications();
  });
  tearDown(() => container.dispose());

  AuthUser user({int? utc, int? local}) =>
      AuthUser(id: 'u', email: 'a@b.fr', isBeta: true, isSubscribed: false, reminderHourUtc: utc, reminderLocalHour: local);

  test('décalage changé : l’heure UTC est recalée sur l’heure locale choisie', () async {
    final expected = reminderUtcHour(8, now);
    await resyncReminderOffset(
        user: user(utc: (expected + 1) % 24, local: 8), notifications: notifications, auth: auth, now: now);
    expect(notifications.sent, [expected]);
    expect(auth.saved, [(expected, 8)]);
  });

  test('même décalage, rappel éteint ou heure locale inconnue : rien n’est envoyé', () async {
    await resyncReminderOffset(
        user: user(utc: reminderUtcHour(8, now), local: 8), notifications: notifications, auth: auth, now: now);
    await resyncReminderOffset(user: user(), notifications: notifications, auth: auth, now: now);
    await resyncReminderOffset(user: user(utc: 6), notifications: notifications, auth: auth, now: now);
    expect(notifications.sent, isEmpty);
  });
}
