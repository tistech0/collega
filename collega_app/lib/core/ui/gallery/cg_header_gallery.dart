import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_header.dart';
import 'package:collega_app/core/ui/components/cg_list_row.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Planche de [CgHeader] (Widgetbook + goldens) : large (sous-titre, action,
/// titre long) et inline (seul, avec retour, avec action).
class CgHeaderGallery extends StatelessWidget {
  const CgHeaderGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    const gap = SizedBox(height: CgSpace.s6);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: CgSpace.s4, bottom: CgSpace.section),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CgHeader.large(title: 'Aujourd’hui', subtitle: 'Lundi 21 septembre'),
            gap,
            CgHeader.large(
              title: 'Bibliothèque',
              trailing: CgIcon(CgIcons.search, color: c.accent, semanticLabel: 'Rechercher'),
            ),
            gap,
            const CgHeader.large(
              title: 'Chirurgie générale, viscérale et digestive',
              subtitle: 'CFCVD · 94 fiches · 21 items',
            ),
          ]),
        ),
        gap,
        const CgHeader.inline(title: 'Importer un collège'),
        gap,
        CgHeader.inline(title: 'Cancérologie', backLabel: 'Bibliothèque', onBack: noop),
        gap,
        CgHeader.inline(
          title: 'Tumeurs du testicule',
          backLabel: 'Cancérologie',
          onBack: noop,
          trailing: CgIcon(CgIcons.more, color: c.accent, semanticLabel: 'Plus d’actions'),
        ),
      ]),
    );
  }
}

/// Écran complet d'exemple pour [CgPage] : détail de collège poussé depuis la
/// Bibliothèque, action primaire ancrée en bas.
class CgPageGallery extends StatelessWidget {
  const CgPageGallery({super.key, this.reserveTabBar = false, this.onRefresh});

  final bool reserveTabBar;
  final Future<void> Function()? onRefresh;

  static const _items = [
    ('Tumeurs du testicule', 'Item 310 · 6 fiches'),
    ('Tumeurs vésicales', 'Item 311 · 5 fiches'),
    ('Tumeurs du rein', 'Item 312 · 4 fiches'),
    ('Tumeurs de la prostate', 'Item 314 · 7 fiches'),
    ('Cancer du col utérin', 'Item 300 · 5 fiches'),
    ('Cancer de l’ovaire', 'Item 302 · 6 fiches'),
    ('Tumeurs du sein', 'Item 309 · 8 fiches'),
    ('Tumeurs cutanées', 'Item 299 · 4 fiches'),
    ('Leucémies aiguës', 'Item 316 · 5 fiches'),
    ('Lymphomes', 'Item 317 · 6 fiches'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    return CgPage(
      title: 'Cancérologie',
      subtitle: 'CNEC · 177 fiches · 32 items',
      backLabel: 'Bibliothèque',
      onBack: noop,
      trailing: CgIcon(CgIcons.more, color: c.accent, semanticLabel: 'Plus d’actions'),
      reserveTabBar: reserveTabBar,
      onRefresh: onRefresh,
      bottomAction: CgButton(label: 'Réviser ce collège', onPressed: noop),
      children: [
        CgListGroup(header: 'Items · rang A', children: [
          for (final (title, meta) in _items)
            CgListRow(
              leading: const CgRowIcon(CgIcons.document),
              title: title,
              subtitle: meta,
              trailing: CgRowTrailing.chevron,
              onTap: noop,
            ),
        ]),
      ],
    );
  }
}
