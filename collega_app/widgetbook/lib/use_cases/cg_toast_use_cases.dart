import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_toast.dart';
import 'package:collega_app/core/ui/gallery/cg_toast_gallery.dart';

final WidgetbookComponent cgToastComponent = WidgetbookComponent(
  name: 'CgToast',
  useCases: [
    WidgetbookUseCase(name: 'Planche (capsule statique)', builder: (_) => const CgToastGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final message = context.knobs.string(label: 'Message', initialValue: 'Elle reviendra dans quelques questions');
        final aboveTabBar = context.knobs.boolean(label: 'Au-dessus de la tab bar', initialValue: true);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            // Chaque tap remplace le toast affiché.
            child: Builder(
              builder: (context) => CgButton(
                label: 'Afficher le toast',
                onPressed: () => showCgToast(context, message, aboveTabBar: aboveTabBar),
              ),
            ),
          ),
        );
      },
    ),
  ],
);
