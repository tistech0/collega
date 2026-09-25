class ImportStartResponse {
  const ImportStartResponse({
    required this.collegeId,
    required this.jobId,
    required this.status,
  });

  final String collegeId;
  final String jobId;
  final String status;

  factory ImportStartResponse.fromJson(Map<String, dynamic> json) =>
      ImportStartResponse(
        collegeId: json['college_id'] as String,
        jobId: json['job_id'] as String,
        status: json['status'] as String,
      );
}

/// Ce qu'un réimport a changé (chantier 1) : le serveur ne régénère que les items
/// dont le contenu a changé, et rend le quota si rien n'a nécessité Claude.
/// Chantier 4 : aussi les items sans contenu suffisant (0 fiche), listés même au
/// premier import — seul cas où un premier import porte un résumé.
class ImportSummary {
  const ImportSummary({
    required this.changed,
    required this.added,
    required this.removed,
    required this.unchanged,
    required this.quotaRefunded,
    this.reimport = true,
    this.insufficientItems = const [],
  });

  factory ImportSummary.fromJson(Map<String, dynamic> json) => ImportSummary(
        changed: json['changed'] as int? ?? 0,
        added: json['added'] as int? ?? 0,
        removed: json['removed'] as int? ?? 0,
        unchanged: json['unchanged'] as int? ?? 0,
        quotaRefunded: json['quota_refunded'] as bool? ?? false,
        // Serveur antérieur au chantier 4 : un résumé n'existait qu'après un réimport.
        reimport: json['reimport'] as bool? ?? true,
        insufficientItems: (json['insufficient_items'] as List?)?.whereType<int>().toList() ?? const [],
      );

  static ImportSummary? maybeFromJson(Object? json) =>
      json is Map<String, dynamic> ? ImportSummary.fromJson(json) : null;

  final int changed;
  final int added;
  final int removed;
  final int unchanged;
  final bool quotaRefunded;

  /// Faux : premier import (ses compteurs ne décrivent aucun changement).
  final bool reimport;

  /// Numéros des items où Claude n'a trouvé pas assez de contenu : à vérifier dans le PDF.
  final List<int> insufficientItems;

  bool get nothingChanged => changed == 0 && added == 0 && removed == 0;
}

/// Items listés au plus dans le résumé ; au-delà : « … et N autres ».
const _maxListedItems = 8;

/// « Pas assez de contenu : items 215, 216 » ; null si aucun item n'est concerné.
String? insufficientItemsText(List<int> items) {
  if (items.isEmpty) return null;
  final shown = items.take(_maxListedItems).join(', ');
  final rest = items.length - _maxListedItems;
  final more = rest > 0 ? ' et ${rest == 1 ? '1 autre' : '$rest autres'}' : '';
  return 'Pas assez de contenu : item${items.length == 1 ? '' : 's'} $shown$more';
}

/// Toast de fin d'import. Réimport : « 3 items mis à jour, 1 nouveau, 20 inchangés » ;
/// « Aucun changement dans ce PDF : réimport non décompté » (mêmes règles que la
/// notification du serveur). Puis, premier import compris, les items sans contenu
/// suffisant. Null : rien à dire (premier import complet).
String? importSummaryText(ImportSummary s) {
  final insufficient = insufficientItemsText(s.insufficientItems);
  if (!s.reimport) return insufficient;
  final changes = _changesText(s);
  return insufficient == null ? changes : '$changes. $insufficient';
}

String _changesText(ImportSummary s) {
  if (s.nothingChanged) {
    return s.quotaRefunded ? 'Aucun changement dans ce PDF : réimport non décompté' : 'Aucun changement dans ce PDF';
  }
  String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  return [
    if (s.changed > 0) plural(s.changed, 'item mis à jour', 'items mis à jour'),
    if (s.added > 0) plural(s.added, 'nouveau', 'nouveaux'),
    if (s.removed > 0) plural(s.removed, 'supprimé', 'supprimés'),
    if (s.unchanged > 0) plural(s.unchanged, 'inchangé', 'inchangés'),
  ].join(', ');
}

class CollegeStatusResponse {
  const CollegeStatusResponse({
    required this.collegeId,
    required this.refId,
    required this.status,
    required this.ocrProgress,
    this.totalPages,
    this.jobId,
    this.summary,
    this.reimport = false,
  });

  final String collegeId;
  final int refId;
  /// Statut de l'import en cours ou du dernier import (le collège, lui, reste prêt
  /// pendant un réimport).
  final String status;
  final int ocrProgress;
  final int? totalPages;
  final String? jobId;
  final ImportSummary? summary;
  /// Échec d'un réimport : les fiches actuelles sont intactes.
  final bool reimport;

  factory CollegeStatusResponse.fromJson(Map<String, dynamic> json) =>
      CollegeStatusResponse(
        collegeId: json['college_id'] as String,
        refId: json['ref_id'] as int,
        status: json['status'] as String,
        ocrProgress: json['ocr_page_progress'] as int? ?? 0,
        totalPages: json['total_pages'] as int?,
        jobId: json['job_id'] as String?,
        summary: ImportSummary.maybeFromJson(json['summary']),
        reimport: json['reimport'] as bool? ?? false,
      );
}

sealed class CollegeImportState {
  const CollegeImportState();
}

class ImportIdle extends CollegeImportState {
  const ImportIdle();
}

class ImportUploading extends CollegeImportState {
  const ImportUploading({this.refId, this.progress});

  /// Collège en cours d'envoi (null : inconnu, envoi repris sans contexte).
  final int? refId;

  /// Progression 0..1 de l'upload par morceaux (Story 7.11) ; null pour l'upload mono-requête.
  final double? progress;
}

class ImportStreaming extends CollegeImportState {
  const ImportStreaming({
    required this.collegeId,
    required this.jobId,
    required this.ocrProgress,
    required this.status,
    this.totalPages,
    this.itemsDone = 0,
    this.itemsTotal,
    this.cards = 0,
    this.preview = const [],
  });

  final String collegeId;
  final String jobId;
  final int ocrProgress;
  final int? totalPages;
  final String status;

  /// Génération (story 8.13) : items traités / total, fiches prêtes.
  final int itemsDone;
  final int? itemsTotal;
  final int cards;

  /// Questions des dernières fiches générées (aperçu, 3 au plus).
  final List<String> preview;

  ImportStreaming copyWith({
    String? collegeId,
    String? jobId,
    int? ocrProgress,
    int? totalPages,
    String? status,
    int? itemsDone,
    int? itemsTotal,
    int? cards,
    List<String>? preview,
  }) =>
      ImportStreaming(
        collegeId: collegeId ?? this.collegeId,
        jobId: jobId ?? this.jobId,
        ocrProgress: ocrProgress ?? this.ocrProgress,
        totalPages: totalPages ?? this.totalPages,
        status: status ?? this.status,
        itemsDone: itemsDone ?? this.itemsDone,
        itemsTotal: itemsTotal ?? this.itemsTotal,
        cards: cards ?? this.cards,
        preview: preview ?? this.preview,
      );
}

class ImportComplete extends CollegeImportState {
  const ImportComplete({required this.collegeId, this.summary});
  final String collegeId;
  /// Présent après un réimport (ce qui a changé) ou quand des items n'avaient pas
  /// assez de contenu (premier import compris).
  final ImportSummary? summary;
}

class ImportError extends CollegeImportState {
  const ImportError({required this.message});
  final String message;
}

class ReloadLimits {
  const ReloadLimits({
    required this.collegeReloadCount,
    required this.collegeReloadMax,
    required this.monthlyReloads,
    required this.monthlyMax,
    required this.monthlyResetAt,
  });

  final int collegeReloadCount;
  final int collegeReloadMax;
  final int monthlyReloads;
  final int monthlyMax;
  final String monthlyResetAt; // ISO 8601 UTC

  bool get isCollegeLimitReached => collegeReloadCount >= collegeReloadMax;
  bool get isMonthlyLimitReached => monthlyReloads >= monthlyMax;

  factory ReloadLimits.fromJson(Map<String, dynamic> json) => ReloadLimits(
        collegeReloadCount: json['college_reload_count'] as int,
        collegeReloadMax: json['college_reload_max'] as int,
        monthlyReloads: json['monthly_reloads'] as int,
        monthlyMax: json['monthly_max'] as int,
        monthlyResetAt: json['monthly_reset_at'] as String,
      );
}
