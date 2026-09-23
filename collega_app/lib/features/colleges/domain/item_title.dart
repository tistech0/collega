import 'package:flutter/foundation.dart';

/// Titres d'items (story 8.0) : un seul endroit décide du libellé affiché.
///
/// Le backend renvoie `chapter_title` nul quand ni l'en-tête du PDF ni le
/// référentiel partagé n'ont fourni de titre ; les anciennes données peuvent
/// encore contenir `""`. Dans les deux cas l'app replie sur « Item N ».

bool hasItemTitle(String? title) => title != null && title.trim().isNotEmpty;

/// Titre de l'item, ou « Item N » s'il n'en a pas.
String itemDisplayTitle(int itemNumber, String? title) {
  if (hasItemTitle(title)) return title!.trim();
  debugPrint('Item $itemNumber sans titre — repli « Item $itemNumber »');
  return 'Item $itemNumber';
}

/// « Item 310 · Tumeurs du testicule », ou « Item 310 » sans séparateur pendant.
String itemFullLabel(int itemNumber, String? title) =>
    hasItemTitle(title) ? 'Item $itemNumber · ${title!.trim()}' : 'Item $itemNumber';
