/// Dates en français sans dépendance (l'app n'est localisée qu'en français).
const kFrWeekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const kFrMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String frWeekday(DateTime d) => kFrWeekdays[d.weekday - 1];
String frMonth(DateTime d) => kFrMonths[d.month - 1];

/// « Lundi 21 » (large title d'Aujourd'hui).
String frDayTitle(DateTime d) {
  final w = frWeekday(d);
  return '${w[0].toUpperCase()}${w.substring(1)} ${d.day}';
}

/// Initiale du jour (« L », « M »…), pour la semaine.
String frWeekdayInitial(DateTime d) => frWeekday(d)[0].toUpperCase();

const kFrMonthsShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _frDay(DateTime d) => d.day == 1 ? '1er' : '${d.day}';

/// « 21 sept. », « 1er mai » (bornes du planning).
String frShortDate(DateTime d) => '${_frDay(d)} ${kFrMonthsShort[d.month - 1]}';

/// « jeudi 1er octobre ».
String frLongDate(DateTime d) => '${frWeekday(d)} ${_frDay(d)} ${frMonth(d)}';

/// « 1er octobre » (renouvellements, échéances).
String frDayMonth(DateTime d) => '${_frDay(d)} ${frMonth(d)}';
