/// Jour civil local exprimé en jours depuis l'epoch (même convention que le planning :
/// la date locale lue comme minuit UTC). Deux instants du même jour local → même valeur.
int epochDayOf(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// Inverse de [epochDayOf] : minuit local du jour.
DateTime dateOfEpochDay(int day) {
  final utc = DateTime.fromMillisecondsSinceEpoch(day * Duration.millisecondsPerDay, isUtc: true);
  return DateTime(utc.year, utc.month, utc.day);
}
