import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/fr_dates.dart';
import 'package:collega_app/features/planning/planning_providers.dart';

/// « 30 min par jour · jour 3 sur 30 » (+ « · aujourd'hui décalé »), ou la date
/// de début / « terminé » hors période.
String planningSummary(PlanningConfig config, PlanningState p, {required int today}) {
  final start = epochDayOf(config.startDate);
  final end = epochDayOf(config.endDate);
  final parts = ['${config.dailyMinutes} min par jour'];
  if (today < start) {
    parts.add('commence le ${frShortDate(config.startDate)}');
  } else if (today > end) {
    parts.add('terminé');
  } else {
    parts.add('jour ${today - start + 1} sur ${end - start + 1}');
    if (p.postponedDays.contains(today)) parts.add('aujourd’hui décalé');
  }
  return parts.join(' · ');
}

