import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_illustrations.dart';
import 'package:collega_app/core/ui/components/cg_state.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche de [CgState] (Widgetbook + goldens) : vide, erreur, hors-ligne avec
/// les copies du spec v2, puis les cinq illustrations.
class CgStateGallery extends StatelessWidget {
  const CgStateGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    final divider = ColoredBox(color: c.line, child: const SizedBox(height: 1, width: double.infinity));

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CgState.empty(
          title: 'Importe ton premier collège',
          message: 'Tes fiches et tes sessions apparaîtront ici.',
          actionLabel: 'Importer',
          onAction: noop,
        ),
        divider,
        CgState.error(
          title: 'Tes fiches sont là',
          message: 'Impossible de joindre le serveur.',
          actionLabel: 'Réessayer',
          onAction: noop,
        ),
        divider,
        CgState.offline(
          title: 'Hors connexion',
          message: 'La recherche a besoin d\'une connexion. Tes collèges restent disponibles.',
          actionLabel: 'Réessayer',
          onAction: noop,
        ),
        divider,
        Padding(
          padding: const EdgeInsets.all(CgSpace.gutter),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: CgSpace.s4,
            runSpacing: CgSpace.s4,
            children: [
              for (final illustration in CgIllustration.values)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  CgIllustrationArt(illustration),
                  const SizedBox(height: CgSpace.s1),
                  Text(illustration.name, style: CgType.label.copyWith(color: c.ink3)),
                ]),
            ],
          ),
        ),
      ]),
    );
  }
}
