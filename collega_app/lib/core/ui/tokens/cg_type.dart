import 'package:flutter/widgets.dart';

/// Typographie Collega UI : Instrument Sans seule, chiffres tabulaires sur les
/// valeurs (spec v2 § Système typographique). Police embarquée
/// (`assets/fonts`, OFL) : rendu identique hors-ligne et dans les goldens.
abstract final class CgType {
  static const family = 'InstrumentSans';
  static const _tabular = [FontFeature.tabularFigures()];

  /// Grand nombre (« 24 fiches »), score.
  static const display = TextStyle(
    fontFamily: family, fontSize: 40, fontWeight: FontWeight.w700,
    letterSpacing: -0.8, height: 1.05, fontFeatures: _tabular,
  );

  /// Large title des onglets (34 pt, comme la maquette et `CgHeader`).
  static const titleL = TextStyle(
    fontFamily: family, fontSize: 34, fontWeight: FontWeight.w700,
    letterSpacing: -0.85, height: 1.05,
  );

  /// Titre de section, nom de collège, titre de sheet.
  static const title = TextStyle(
    fontFamily: family, fontSize: 22, fontWeight: FontWeight.w600, height: 1.2,
  );

  /// Titre de ligne, question de fiche courte.
  static const head = TextStyle(
    fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3,
  );

  /// Réponse de fiche, contenu.
  static const body = TextStyle(
    fontFamily: family, fontSize: 17, fontWeight: FontWeight.w400, height: 1.45,
  );

  /// Sous-titres, métadonnées longues.
  static const bodyS = TextStyle(
    fontFamily: family, fontSize: 15, fontWeight: FontWeight.w400, height: 1.4,
  );

  /// Sous-titre de ligne (« 177 fiches · 42 % maîtrisées »).
  static const meta = TextStyle(
    fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400, height: 1.35,
    fontFeatures: _tabular,
  );

  /// Badges, rangs, compteurs, intertitres de section.
  static const label = TextStyle(
    fontFamily: family, fontSize: 13, fontWeight: FontWeight.w500,
    letterSpacing: 0.26, height: 1.3, fontFeatures: _tabular,
  );

  /// Libellés de la tab bar.
  static const tab = TextStyle(
    fontFamily: family, fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.2,
  );

  /// Grand nombre d'Aujourd'hui (64 pt, 52 sur écran compact).
  static const numeral = TextStyle(
    fontFamily: family, fontSize: 64, fontWeight: FontWeight.w700,
    letterSpacing: -2.24, height: 1, fontFeatures: _tabular,
  );

  /// Score de fin de session.
  static const score = TextStyle(
    fontFamily: family, fontSize: 96, fontWeight: FontWeight.w700,
    letterSpacing: -4.8, height: 1, fontFeatures: _tabular,
  );

  static const all = <String, TextStyle>{
    'display': display, 'numeral': numeral, 'score': score, 'titleL': titleL,
    'title': title, 'head': head, 'body': body, 'bodyS': bodyS, 'meta': meta,
    'label': label, 'tab': tab,
  };

  /// Plafond Dynamic Type des grands styles (sinon « 24 fiches » déborde).
  static const displayMaxScale = 1.3;
}

/// Plafonne l'échelle de texte du sous-arbre (styles `display`, `titleL`, `numeral`, `score`).
class CgTextScaleCap extends StatelessWidget {
  const CgTextScaleCap({super.key, required this.child, this.maxScale = CgType.displayMaxScale});

  final Widget child;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: child,
    );
  }
}
