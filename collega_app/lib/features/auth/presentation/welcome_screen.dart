import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Écran de marque (story 8.12, spec v2 § Parcours 1) : l'entrée des non
/// connectés. Wordmark qui apparaît, « Se connecter » en primaire, la démo en
/// second, la beta privée dite.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _wordmarkHeight = 56.0;
  static const _rise = 12.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: c.ground,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CgSpace.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(CgSpace.gutter, 0, CgSpace.gutter, bottom + CgSpace.s4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Le wordmark monte et apparaît, une fois ; direct en mouvement réduit.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: CgMotion.resolve(context, CgMotion.ringFill),
                          curve: CgMotion.out,
                          builder: (context, t, child) => Opacity(
                            opacity: t,
                            child: Transform.translate(offset: Offset(0, (1 - t) * _rise), child: child),
                          ),
                          child: const CgWordmark(height: _wordmarkHeight),
                        ),
                        const SizedBox(height: CgSpace.s4),
                        Text(
                          'Tes fiches de révision, item par item.\nUne session prête chaque jour.',
                          textAlign: TextAlign.center,
                          style: CgType.body.copyWith(color: c.ink2),
                        ),
                      ]),
                    ),
                  ),
                ),
                CgButton(label: 'Se connecter', onPressed: () => context.push('/auth/login')),
                CgButton(
                  label: 'Essayer la démo',
                  variant: CgButtonVariant.quiet,
                  onPressed: () => context.push('/demo'),
                ),
                const SizedBox(height: CgSpace.s2),
                Text(
                  'Beta privée · accès sur invitation',
                  textAlign: TextAlign.center,
                  style: CgType.meta.copyWith(color: c.ink3),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
