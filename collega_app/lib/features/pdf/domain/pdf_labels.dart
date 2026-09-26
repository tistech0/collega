/// « p. 112–118 » : pages de l'item (base 0 en base) affichées en base 1.
String pageRangeLabel(int start0, int? end0) {
  final start = start0 + 1;
  final end = (end0 ?? start0) + 1;
  return end > start ? 'p. $start–$end' : 'p. $start';
}

/// « 380 Mo » (1 Mo = 1 048 576 octets), jamais « 0 Mo ».
String megabytesLabel(int bytes) {
  final mb = (bytes / (1024 * 1024)).round();
  return '${mb < 1 ? 1 : mb} Mo';
}

/// Route du lecteur ; [page] en base 1.
String pdfReaderPath(int refId, {int? page, String? itemId}) {
  final query = [if (page != null) 'page=$page', if (itemId != null) 'item=$itemId'];
  return '/colleges/$refId/pdf${query.isEmpty ? '' : '?${query.join('&')}'}';
}
