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
