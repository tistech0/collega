import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_field.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche de toutes les variantes et états de [CgField] (Widgetbook + goldens).
/// Le focus (contour `accent` 2 pt) n'y figure pas : un champ focalisé fait
/// clignoter son curseur (golden instable) et volerait le focus du catalogue.
/// Il est couvert par un test de widget et par l'use case interactive.
class CgFieldGallery extends StatefulWidget {
  const CgFieldGallery({super.key});

  @override
  State<CgFieldGallery> createState() => _CgFieldGalleryState();
}

class _CgFieldGalleryState extends State<CgFieldGallery> {
  final _password = TextEditingController(text: 'motdepasse');
  final _error = TextEditingController(text: 'camille@');
  final _disabled = TextEditingController(text: 'camille@exemple.fr');
  final _search = TextEditingController(text: 'cancer du rein');
  final _definition = TextEditingController(
    text: 'Tumeur maligne développée aux dépens de l\'épithélium tubulaire rénal.',
  );

  @override
  void dispose() {
    for (final controller in [_password, _error, _disabled, _search, _definition]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(top: CgSpace.s6, bottom: CgSpace.related),
          child: Text(text, style: CgType.label.copyWith(color: c.ink3)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        caption('Email · repos, aide'),
        const CgField(
          label: 'Email',
          placeholder: 'prenom@exemple.fr',
          kind: CgFieldKind.email,
          helper: 'Celui de ton compte Collega',
        ),
        caption('Mot de passe · masqué, bouton œil'),
        CgField(label: 'Mot de passe', kind: CgFieldKind.password, controller: _password),
        caption('Erreur'),
        CgField(
          label: 'Email',
          kind: CgFieldKind.email,
          controller: _error,
          helper: 'Celui de ton compte Collega',
          error: 'Email ou mot de passe incorrect',
        ),
        caption('Désactivé'),
        CgField(label: 'Email', kind: CgFieldKind.email, controller: _disabled, enabled: false),
        caption('Recherche · vide, remplie (effacer)'),
        const CgField(placeholder: 'Un item, un signe, une dose…', kind: CgFieldKind.search),
        const SizedBox(height: CgSpace.s3),
        CgField(placeholder: 'Un item, un signe, une dose…', kind: CgFieldKind.search, controller: _search),
        caption('Multiligne · définition'),
        const CgField(label: 'Ta définition', placeholder: 'Écris ta réponse…', kind: CgFieldKind.multiline),
        const SizedBox(height: CgSpace.s3),
        CgField(label: 'Ta définition', kind: CgFieldKind.multiline, controller: _definition),
      ]),
    );
  }
}
