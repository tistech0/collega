import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_state.dart';
import 'package:collega_app/core/ui/gallery/cg_state_gallery.dart';

enum _Variant { empty, error, offline }

final WidgetbookComponent cgStateComponent = WidgetbookComponent(
  name: 'CgState',
  useCases: [
    WidgetbookUseCase(name: 'Planche (vide, erreur, hors-ligne, illustrations)', builder: (_) => const CgStateGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final variant = context.knobs.list(
          label: 'Variante',
          options: _Variant.values,
          labelBuilder: (v) => v.name,
        );
        final illustration = context.knobs.listOrNull(
          label: 'Illustration (défaut si vide)',
          options: CgIllustration.values,
          labelBuilder: (v) => v?.name ?? 'défaut',
        );
        final title = context.knobs.string(label: 'Titre', initialValue: 'Importe ton premier collège');
        final message = context.knobs.string(
          label: 'Message',
          initialValue: 'Tes fiches et tes sessions apparaîtront ici.',
        );
        final action = context.knobs.string(label: 'Action', initialValue: 'Importer');
        final actionLabel = action.isEmpty ? null : action;
        void onAction() {}
        return switch (variant) {
          _Variant.empty => CgState.empty(
              title: title,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
              illustration: illustration ?? CgIllustration.sheets,
            ),
          _Variant.error => CgState.error(
              title: title,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
              illustration: illustration ?? CgIllustration.broken,
            ),
          _Variant.offline => CgState.offline(
              title: title,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
              illustration: illustration ?? CgIllustration.offline,
            ),
        };
      },
    ),
  ],
);
