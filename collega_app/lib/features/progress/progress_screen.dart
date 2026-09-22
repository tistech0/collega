import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Onglet Progression. Contenu complet en story 8.8 ; d'ici là, l'état vide du spec.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CgPage(
      title: 'Progression',
      reserveTabBar: true,
      children: [
        Padding(
          padding: EdgeInsets.only(top: CgSpace.beforeLargeTitle),
          child: CgState.empty(
            title: 'Ta première session remplira cette page',
            message: 'Tes collèges, tes rangs et ta semaine apparaîtront ici au fil de tes révisions.',
            illustration: CgIllustration.done,
          ),
        ),
      ],
    );
  }
}
