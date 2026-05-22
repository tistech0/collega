import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

/// Type de document légal affiché.
///
/// Story 7.4 AC #9 — Option B (bundle Flutter) : les CGU et la politique de
/// confidentialité sont embarquées dans `assets/legal/` et rendues via
/// `flutter_markdown`.
enum LegalDocument {
  cgu(
    title: "Conditions générales d'utilisation",
    assetPath: 'assets/legal/cgu.md',
  ),
  privacy(
    title: 'Politique de confidentialité',
    assetPath: 'assets/legal/privacy.md',
  );

  const LegalDocument({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  // Future cachée pour éviter de relire l'asset à chaque rebuild
  // (rotation, text-scale, rebuild parent) — sinon flicker du loader.
  late final Future<String> _document =
      rootBundle.loadString(widget.document.assetPath);

  void _handleBack() {
    // Si entrée via deep-link (cold start, stack vide), context.pop()
    // crasherait — fallback vers /profile (utilisateur authentifié) ou /demo.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossible de charger le document : ${snapshot.error}',
                  ),
                ),
              );
            }
            return Markdown(
              data: snapshot.data ?? '',
              padding: const EdgeInsets.all(16),
              selectable: true,
            );
          },
        ),
      ),
    );
  }
}
