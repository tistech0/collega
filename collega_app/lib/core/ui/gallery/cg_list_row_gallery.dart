import 'package:flutter/cupertino.dart';

import 'package:collega_app/core/ui/components/cg_list_row.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Planche de [CgListRow] / [CgListGroup] / [CgSectionTitle] (Widgetbook + goldens) :
/// collèges importés avec progression, catalogue désactivé + « Importer »,
/// valeurs, coches, switch en groupe `inset`, titre long.
class CgListRowGallery extends StatelessWidget {
  const CgListRowGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CgListGroup(header: 'Mes collèges', children: [
          CgListRow(
            leading: const CgRowIcon(CgIcons.document),
            title: 'Cancérologie',
            subtitle: '177 fiches · 42 % maîtrisées',
            trailing: CgRowTrailing.chevron,
            progress: const GalleryProgress(mastered: 0.42, good: 0.14, review: 0.06),
            onTap: noop,
          ),
          CgListRow(
            leading: const CgRowIcon(CgIcons.document),
            title: 'Pneumologie',
            subtitle: '164 fiches · 18 % maîtrisées',
            trailing: CgRowTrailing.chevron,
            progress: const GalleryProgress(mastered: 0.18, good: 0.09, review: 0.04),
            onTap: noop,
          ),
        ]),
        CgListGroup(header: 'Catalogue · 38 collèges', children: [
          CgListRow(
            leading: const CgRowIcon(CgIcons.search, muted: true),
            title: 'Anatomie pathologique',
            subtitle: 'CoPath',
            enabled: false,
            trailing: CgRowTrailing.action,
            actionLabel: 'Importer',
            onAction: noop,
          ),
          CgListRow(
            leading: const CgRowIcon(CgIcons.document, muted: true),
            title: 'Chirurgie générale, viscérale et digestive',
            subtitle: 'CFCVD',
            enabled: false,
            trailing: CgRowTrailing.action,
            actionLabel: 'Importer',
            onAction: noop,
          ),
        ]),
        CgListGroup(header: 'Par rang', children: [
          CgListRow(title: 'Rang A', trailing: CgRowTrailing.value, value: '48 %', onTap: noop),
          CgListRow(title: 'Rang B', trailing: CgRowTrailing.value, value: '22 %', onTap: noop),
          const CgListRow(title: 'Rang C', subtitle: 'Aucune fiche vue', trailing: CgRowTrailing.value, value: '0 %'),
        ]),
        const CgSectionTitle('Durée par jour'),
        CgListGroup(variant: CgListVariant.inset, children: [
          CgListRow(title: '15 min', trailing: CgRowTrailing.check, onTap: noop),
          CgListRow(title: '30 min', trailing: CgRowTrailing.check, selected: true, onTap: noop),
          CgListRow(title: '45 min', trailing: CgRowTrailing.check, onTap: noop),
        ]),
        CgListGroup(variant: CgListVariant.inset, header: 'Rappels', children: [
          CgListRow(
            leading: const CgRowIcon(CgIcons.bell),
            title: 'Rappel quotidien',
            trailing: CgRowTrailing.custom,
            trailingWidget: CupertinoSwitch(value: true, activeTrackColor: c.accent, onChanged: (_) {}),
          ),
          CgListRow(
            leading: const CgRowIcon(CgIcons.clock),
            title: 'Heure',
            trailing: CgRowTrailing.value,
            value: '19:30',
            onTap: noop,
          ),
          CgListRow(
            leading: const CgRowIcon(CgIcons.lock),
            title: 'Confidentialité',
            trailing: CgRowTrailing.chevron,
            onTap: noop,
          ),
        ]),
        const SizedBox(height: CgSpace.section),
      ]),
    );
  }
}

/// Barre de progression de démonstration (6 pt, couleurs de verdict) : la planche
/// ne dépend pas de `CgRankBar`, qui vit dans son propre composant.
class GalleryProgress extends StatelessWidget {
  const GalleryProgress({super.key, required this.mastered, required this.good, required this.review});

  final double mastered;
  final double good;
  final double review;

  static const _height = 6.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final rest = (1 - mastered - good - review).clamp(0.0, 1.0);
    int flex(double v) => (v * 1000).round();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(_height / 2)),
        child: SizedBox(
          height: _height,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: flex(mastered), child: ColoredBox(color: c.mastered)),
            Expanded(flex: flex(good), child: ColoredBox(color: c.good)),
            Expanded(flex: flex(review), child: ColoredBox(color: c.review)),
            Expanded(flex: flex(rest), child: ColoredBox(color: c.unseen)),
          ]),
        ),
      ),
    );
  }
}
