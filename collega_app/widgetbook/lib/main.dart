import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/gallery/cg_tokens_page.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';

import 'use_cases/cg_badge_use_cases.dart';
import 'use_cases/cg_button_use_cases.dart';
import 'use_cases/cg_card_type_tag_use_cases.dart';
import 'use_cases/cg_drill_card_use_cases.dart';
import 'use_cases/cg_field_use_cases.dart';
import 'use_cases/cg_header_use_cases.dart';
import 'use_cases/cg_list_row_use_cases.dart';
import 'use_cases/cg_rank_bar_use_cases.dart';
import 'use_cases/cg_ring_use_cases.dart';
import 'use_cases/cg_segmented_use_cases.dart';
import 'use_cases/cg_sheet_use_cases.dart';
import 'use_cases/cg_skeleton_use_cases.dart';
import 'use_cases/cg_state_use_cases.dart';
import 'use_cases/cg_tab_bar_use_cases.dart';
import 'use_cases/cg_toast_use_cases.dart';
import 'use_cases/cg_verdict_bar_use_cases.dart';

void main() => runApp(const CollegaWidgetbook());

/// Catalogue Collega UI : chaque composant y a une entrée couvrant ses variantes
/// et états (spec v2 § Fondation du design system). Lancer : `flutter run -d chrome` (web : les plugins iOS de l'app ne s'y chargent pas).
class CollegaWidgetbook extends StatelessWidget {
  const CollegaWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      lightTheme: buildCgMaterialTheme(CgThemeData.light),
      appBuilder: (context, child) => CgTheme(data: CgThemeData.light, child: child),
      addons: [
        // Dynamic Type : 1,0 à 2,0 par pas de 0,2 (le spec vise 1,6× au minimum).
        TextScaleAddon(min: 1.0, max: 2.0, divisions: 5),
      ],
      directories: [
        WidgetbookFolder(
          name: 'Fondation',
          children: [
            WidgetbookComponent(
              name: 'Tokens',
              useCases: [
                WidgetbookUseCase(
                  name: 'Palette, typographie, espaces, rayons, mouvement',
                  builder: (context) => const CgTokensPage(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Composants',
          children: [
            cgBadgeComponent,
            cgButtonComponent,
            cgCardTypeTagComponent,
            cgDrillCardComponent,
            cgFieldComponent,
            cgHeaderComponent,
            cgListRowComponent,
            cgRankBarComponent,
            cgRingComponent,
            cgSegmentedComponent,
            cgSheetComponent,
            cgSkeletonComponent,
            cgStateComponent,
            cgTabBarComponent,
            cgToastComponent,
            cgVerdictBarComponent,
          ],
        ),
      ],
    );
  }
}
