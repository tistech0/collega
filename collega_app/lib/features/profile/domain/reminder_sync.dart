import 'package:collega_app/core/notifications/notifications_service.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/profile/domain/reminder_time.dart';

/// Le serveur garde une heure UTC : au changement d'heure, le rappel choisi à
/// 08:00 tomberait à 07:00. Recale l'heure UTC sur l'heure locale choisie.
Future<void> resyncReminderOffset({
  required AuthUser user,
  required NotificationsService notifications,
  required AuthNotifier auth,
  required DateTime now,
}) async {
  final utc = user.reminderHourUtc;
  final local = user.reminderLocalHour;
  if (utc == null || local == null) return;
  final expected = reminderUtcHour(local, now);
  if (expected == utc) return;
  try {
    await notifications.setReminder(expected);
    await auth.setReminderHour(expected, localHour: local);
  } catch (e) {
    AppLogger.warning('Rappel non recalé (changement d’heure)', tag: 'ReminderSync', error: e);
  }
}
