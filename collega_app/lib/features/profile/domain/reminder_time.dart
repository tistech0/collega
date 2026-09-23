/// Heure du rappel quotidien : le serveur la garde en UTC, l'étudiante la choisit
/// et la lit en heure locale (décalage du jour : heure d'été comprise).
int reminderUtcHour(int localHour, DateTime today) =>
    DateTime(today.year, today.month, today.day, localHour).toUtc().hour;

int reminderLocalHour(int utcHour, DateTime today) =>
    DateTime.utc(today.year, today.month, today.day, utcHour).toLocal().hour;

/// « 08:00 ».
String reminderLabel(int localHour) => '${localHour.toString().padLeft(2, '0')}:00';
