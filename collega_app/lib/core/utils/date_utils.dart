extension DateTimeISO on DateTime {
  /// Formate la date en ISO 8601 UTC — format standard de toute l'API
  String toIso8601Utc() => toUtc().toIso8601String();
}

DateTime parseIso8601(String value) => DateTime.parse(value).toLocal();
