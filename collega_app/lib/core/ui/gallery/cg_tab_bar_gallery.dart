import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_header.dart';
import 'package:collega_app/core/ui/components/cg_list_row.dart';
import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';

/// Écran complet d'exemple pour [CgTabBar] (Widgetbook + goldens) : la
/// Bibliothèque (collèges importés + catalogue) sous la tab bar flottante.
/// La liste réserve la place de la barre : rien n'est masqué en fin de liste.
class CgTabBarGallery extends StatefulWidget {
  const CgTabBarGallery({super.key, this.initialIndex = 1, this.collapsed = false});

  final int initialIndex;
  final bool collapsed;

  static const catalog = [
    ('Anatomie pathologique', 'CoPath'),
    ('Anesthésie-Réanimation', 'SFAR'),
    ('Cardiologie', 'SFC'),
    ('Chirurgie générale, viscérale et digestive', 'CFCVD'),
    ('Dermatologie', 'CEDEF'),
    ('Endocrinologie', 'CEEDMM'),
    ('Gériatrie', 'CNEG'),
    ('Hématologie', 'SFH'),
  ];

  @override
  State<CgTabBarGallery> createState() => _CgTabBarGalleryState();
}

class _CgTabBarGalleryState extends State<CgTabBarGallery> {
  late int _index = widget.initialIndex;

  @override
  void didUpdateWidget(CgTabBarGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    return Stack(children: [
      Positioned.fill(
        child: CgPage(
          title: CgTabBar.mainItems[_index].label,
          trailing: CgIcon(CgIcons.search, color: c.accent, semanticLabel: 'Rechercher'),
          reserveTabBar: true,
          children: [
            CgListGroup(header: 'Mes collèges', children: [
              CgListRow(
                leading: const CgRowIcon(CgIcons.document),
                title: 'Cancérologie',
                subtitle: 'CNEC · 177 fiches · 32 items',
                trailing: CgRowTrailing.chevron,
                onTap: noop,
              ),
              CgListRow(
                leading: const CgRowIcon(CgIcons.document),
                title: 'Pneumologie',
                subtitle: 'CEP · 164 fiches · 28 items',
                trailing: CgRowTrailing.chevron,
                onTap: noop,
              ),
            ]),
            CgListGroup(header: 'Catalogue · 38 collèges', children: [
              for (final (title, society) in CgTabBarGallery.catalog)
                CgListRow(
                  leading: const CgRowIcon(CgIcons.document, muted: true),
                  title: title,
                  subtitle: society,
                  enabled: false,
                  trailing: CgRowTrailing.action,
                  actionLabel: 'Importer',
                  onAction: noop,
                ),
            ]),
          ],
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: CgTabBar(
          items: CgTabBar.mainItems,
          currentIndex: _index,
          collapsed: widget.collapsed,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    ]);
  }
}
