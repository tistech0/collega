import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/gallery/cg_tab_bar_gallery.dart';

final WidgetbookComponent cgTabBarComponent = WidgetbookComponent(
  name: 'CgTabBar',
  useCases: [
    WidgetbookUseCase(name: 'Planche (écran Bibliothèque)', builder: (_) => const CgTabBarGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) => CgTabBarGallery(
        initialIndex: context.knobs.list(
          label: 'Onglet actif',
          options: const [0, 1, 2, 3],
          labelBuilder: (i) => CgTabBar.mainItems[i].label,
        ),
        collapsed: context.knobs.boolean(label: 'Réduite (défilement vers le bas)'),
      ),
    ),
  ],
);
