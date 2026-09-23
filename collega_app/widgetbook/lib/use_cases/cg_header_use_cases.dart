import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_header.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_header_gallery.dart';

final WidgetbookComponent cgHeaderComponent = WidgetbookComponent(
  name: 'CgHeader / CgPage',
  useCases: [
    WidgetbookUseCase(name: 'Planche (large, inline)', builder: (_) => const CgHeaderGallery()),
    WidgetbookUseCase(
      name: 'Page (défiler : le titre se réduit)',
      builder: (context) => CgPageGallery(
        reserveTabBar: context.knobs.boolean(label: 'Réserver la tab bar'),
        onRefresh: context.knobs.boolean(label: 'Tirer pour rafraîchir', initialValue: true)
            ? () => Future<void>.delayed(const Duration(seconds: 1))
            : null,
      ),
    ),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final large = context.knobs.boolean(label: 'Large title', initialValue: true);
        final title = context.knobs.string(label: 'Titre', initialValue: 'Cancérologie');
        final trailing = context.knobs.boolean(label: 'Action à droite')
            ? const CgIcon(CgIcons.more, semanticLabel: 'Plus d’actions')
            : null;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: large
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CgHeader.large(
                      title: title,
                      subtitle: context.knobs.stringOrNull(label: 'Sous-titre', initialValue: 'CNEC · 177 fiches'),
                      trailing: trailing,
                    ),
                  )
                : CgHeader.inline(
                    title: title,
                    backLabel: context.knobs.stringOrNull(label: 'Retour', initialValue: 'Bibliothèque'),
                    onBack: () {},
                    trailing: trailing,
                  ),
          ),
        );
      },
    ),
  ],
);
