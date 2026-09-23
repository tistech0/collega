import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Planche de toutes les variantes et états de [CgButton] (Widgetbook + goldens).
class CgButtonGallery extends StatelessWidget {
  const CgButtonGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    const gap = SizedBox(height: CgSpace.s3);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CgButton(label: 'Commencer', onPressed: noop),
        gap,
        CgButton(label: 'Personnaliser', onPressed: noop, variant: CgButtonVariant.secondary),
        gap,
        CgButton(label: 'Personnaliser la session', onPressed: noop, variant: CgButtonVariant.quiet),
        gap,
        CgButton(label: 'Supprimer la fiche', onPressed: noop, variant: CgButtonVariant.destructive),
        gap,
        const CgButton(label: 'Enregistrer', onPressed: null),
        gap,
        CgButton(label: 'Se connecter', onPressed: noop, loading: true),
        gap,
        CgButton(label: 'Importer', onPressed: noop, icon: CgIcons.upload),
        gap,
        Wrap(spacing: CgSpace.s3, runSpacing: CgSpace.s3, children: [
          CgButton(label: 'Réessayer', onPressed: noop, size: CgButtonSize.compact, expand: false, variant: CgButtonVariant.secondary),
          CgButton(label: 'Importer', onPressed: noop, size: CgButtonSize.compact, expand: false, variant: CgButtonVariant.quiet),
        ]),
        gap,
        ColoredBox(
          color: c.accent,
          child: Padding(
            padding: const EdgeInsets.all(CgSpace.gutter),
            child: CgButton(label: 'Terminer', onPressed: noop, variant: CgButtonVariant.inverse),
          ),
        ),
      ]),
    );
  }
}
