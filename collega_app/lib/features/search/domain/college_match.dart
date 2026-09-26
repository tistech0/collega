// collega_app/lib/features/search/domain/college_match.dart
import 'package:collega_app/features/colleges/domain/college_models.dart';

/// Recherche de collèges dans le catalogue (spec « Recherche en sections ») :
/// locale, dès 1 caractère, sur le nom et l'éditeur.

const _plain = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

final _separators = RegExp(r"[\s'’\-–—,.]+");

/// « Médecine d’urgence » → « medecine d urgence ».
String foldForSearch(String s) {
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    out.write(_plain[ch] ?? ch);
  }
  return out.toString().replaceAll(_separators, ' ').trim();
}

/// Collèges dont « nom éditeur » contient chaque mot de [query] ; ceux dont le
/// nom commence par le premier mot passent devant. Ordre de [entries] conservé.
List<CollegeListEntry> matchColleges(String query, List<CollegeListEntry> entries) {
  final words = foldForSearch(query).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final first = <CollegeListEntry>[];
  final rest = <CollegeListEntry>[];
  for (final e in entries) {
    final name = foldForSearch(e.catalog.name);
    final haystack = '$name ${foldForSearch(e.catalog.editor)}';
    if (!words.every(haystack.contains)) continue;
    (name.startsWith(words.first) ? first : rest).add(e);
  }
  return [...first, ...rest];
}
