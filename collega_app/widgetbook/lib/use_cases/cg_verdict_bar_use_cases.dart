import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_verdict_bar.dart';
import 'package:collega_app/core/ui/gallery/cg_verdict_bar_gallery.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

final WidgetbookComponent cgVerdictBarComponent = WidgetbookComponent(
  name: 'CgVerdictBar',
  useCases: [
    WidgetbookUseCase(name: 'Planche (active, désactivée, empilée)', builder: (_) => const CgVerdictBarGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) => _VerdictBarPlayground(enabled: !context.knobs.boolean(label: 'Désactivée')),
    ),
  ],
);

/// Affiche le dernier verdict reçu sous la barre.
class _VerdictBarPlayground extends StatefulWidget {
  const _VerdictBarPlayground({required this.enabled});

  final bool enabled;

  @override
  State<_VerdictBarPlayground> createState() => _VerdictBarPlaygroundState();
}

class _VerdictBarPlaygroundState extends State<_VerdictBarPlayground> {
  CgVerdict? _last;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CgSpace.gutter),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CgVerdictBar(enabled: widget.enabled, onVerdict: (v) => setState(() => _last = v)),
          const SizedBox(height: CgSpace.s4),
          Text(
            _last == null ? 'Aucun verdict' : 'Dernier verdict : ${_last!.label}',
            textAlign: TextAlign.center,
            style: CgType.bodyS.copyWith(color: c.ink2),
          ),
        ]),
      ),
    );
  }
}
