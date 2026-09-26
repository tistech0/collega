// collega_app/lib/features/search/presentation/college_search_row.dart
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

/// Collège trouvé par la recherche : même rendu que la Bibliothèque (importé,
/// en cours d'envoi, ou à importer).
class CollegeSearchRow extends StatelessWidget {
  const CollegeSearchRow({
    super.key,
    required this.entry,
    this.uploading = false,
    this.progress,
    required this.onOpen,
    required this.onImport,
  });

  final CollegeListEntry entry;

  /// PDF en cours d'envoi : le collège n'est pas encore connu du serveur.
  final bool uploading;
  final double? progress;
  final VoidCallback onOpen;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final catalog = entry.catalog;
    final editor = catalog.editor;
    final status = entry.userStatus;
    if (status != null) {
      final n = status.totalCards;
      final detail = switch (status.status) {
        'generation_complete' => '$n ${n > 1 ? 'fiches' : 'fiche'}',
        'failed' => 'l’import n’a pas abouti',
        _ => 'import en cours',
      };
      return CgListRow(
        title: catalog.name,
        subtitle: '$editor · $detail',
        leading: CgRowIcon(catalog.icon),
        trailing: CgRowTrailing.chevron,
        onTap: onOpen,
      );
    }
    if (uploading) {
      final p = progress;
      final sent = p == null ? 'envoi du PDF en cours' : 'envoi du PDF : ${(p.clamp(0.0, 1.0) * 100).floor()} %';
      return CgListRow(
        title: catalog.name,
        subtitle: '$editor · $sent',
        leading: CgRowIcon(catalog.icon),
        trailing: CgRowTrailing.chevron,
        onTap: onImport,
      );
    }
    return CgListRow(
      title: catalog.name,
      subtitle: '$editor · pas encore importé',
      leading: CgRowIcon(catalog.icon, muted: true),
      enabled: false,
      trailing: CgRowTrailing.action,
      actionLabel: 'Importer',
      onAction: onImport,
    );
  }
}
