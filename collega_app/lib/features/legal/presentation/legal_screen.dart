import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Document légal affiché (story 7.4 : embarqué dans `assets/legal/`, rendu en Markdown).
enum LegalDocument {
  cgu(title: 'Conditions d’utilisation', assetPath: 'assets/legal/cgu.md'),
  privacy(title: 'Confidentialité', assetPath: 'assets/legal/privacy.md');

  const LegalDocument({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}

/// CGU / Confidentialité (story 8.14) : page Collega, texte aux styles du spec.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  /// Gardé entre deux rebuilds (Dynamic Type, rotation) : pas de rechargement visible.
  Future<String>? _text;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= _load();
  }

  Future<String> _load() => DefaultAssetBundle.of(context).loadString(widget.document.assetPath);

  void _retry() {
    setState(() {
      _text = _load();
    });
  }

  void _back() {
    // Lien direct (pile vide) : retour au Profil, qui renvoie à l'accueil si déconnectée.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _text,
      builder: (context, snapshot) {
        final List<Widget> children;
        if (snapshot.hasError) {
          children = [
            Padding(
              padding: const EdgeInsets.only(top: CgSpace.beforeLargeTitle),
              child: CgState.error(
                title: 'Le document n’a pas pu s’ouvrir',
                message: 'Rien n’est perdu. Réessaie dans un instant.',
                actionLabel: 'Réessayer',
                onAction: _retry,
              ),
            ),
          ];
        } else if (!snapshot.hasData) {
          children = const [SizedBox(height: CgSpace.section), CgSkeletonList(rows: 6)];
        } else {
          children = [
            const SizedBox(height: CgSpace.s4),
            MarkdownBody(data: _withoutTitle(snapshot.data!), styleSheet: _styleSheet(context)),
            const SizedBox(height: CgSpace.section),
          ];
        }
        // Hors onglets : rien ne peint le fond sous la page (sinon noir sur iPhone).
        return ColoredBox(
          color: CgTheme.of(context).colors.ground,
          child: CgPage(
            title: widget.document.title,
            backLabel: 'Retour',
            onBack: _back,
            children: children,
          ),
        );
      },
    );
  }

  /// Le titre `# …` du fichier est déjà celui de la page.
  static String _withoutTitle(String markdown) =>
      markdown.replaceFirst(RegExp(r'^\s*# [^\n]*\n'), '');

  static MarkdownStyleSheet _styleSheet(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final body = CgType.body.copyWith(color: c.ink);
    return MarkdownStyleSheet(
      p: body,
      a: body.copyWith(color: c.accent, decoration: TextDecoration.underline),
      strong: const TextStyle(fontWeight: FontWeight.w600),
      em: const TextStyle(fontStyle: FontStyle.italic),
      code: CgType.bodyS.copyWith(color: c.ink, backgroundColor: c.soft),
      h1: CgType.title.copyWith(color: c.ink),
      h2: CgType.head.copyWith(color: c.ink),
      h2Padding: const EdgeInsets.only(top: CgSpace.s5),
      h3: body.copyWith(fontWeight: FontWeight.w600),
      h3Padding: const EdgeInsets.only(top: CgSpace.s3),
      listBullet: body.copyWith(color: c.ink2),
      listIndent: CgSpace.s5,
      blockSpacing: CgSpace.s3,
      horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      tableHead: CgType.bodyS.copyWith(color: c.ink, fontWeight: FontWeight.w600),
      tableBody: CgType.bodyS.copyWith(color: c.ink),
      tableBorder: TableBorder.all(color: c.line),
      tableCellsPadding: const EdgeInsets.all(CgSpace.s2),
      blockquote: body.copyWith(color: c.ink2),
      blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: c.line, width: 3))),
      blockquotePadding: const EdgeInsets.only(left: CgSpace.s3),
    );
  }
}
