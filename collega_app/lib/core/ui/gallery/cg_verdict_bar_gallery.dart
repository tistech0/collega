import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_verdict_bar.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche de [CgVerdictBar] (Widgetbook + goldens) : active, désactivée, et
/// empilée (Dynamic Type 2,0 forcé localement, au-delà du seuil de 1,6).
class CgVerdictBarGallery extends StatelessWidget {
  const CgVerdictBarGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop(CgVerdict _) {}
    final caption = CgType.label.copyWith(color: c.ink3);
    const gap = SizedBox(height: CgSpace.s3);
    const section = SizedBox(height: CgSpace.s6);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Active', style: caption),
        gap,
        CgVerdictBar(onVerdict: noop),
        section,
        Text('Désactivée', style: caption),
        gap,
        CgVerdictBar(onVerdict: noop, enabled: false),
        section,
        Text('Dynamic Type 2,0 : empilée', style: caption),
        gap,
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: CgVerdictBar(onVerdict: noop),
        ),
      ]),
    );
  }
}
