/// Type d'une fiche (`card_type` du serveur, chantier 4) : seule source de son
/// libellé et de son rang dans les listes.
enum CardType {
  classique,
  casClinique,
  definition;

  /// Valeur du serveur → type ; inconnue ou absente : classique (elle se révise comme telle).
  static CardType parse(String? value) => switch (value) {
        'cas_clinique' => CardType.casClinique,
        'definition' => CardType.definition,
        _ => CardType.classique,
      };

  /// Libellé de l'étiquette ; null pour la fiche classique (aucune étiquette).
  String? get label => switch (this) {
        CardType.classique => null,
        CardType.casClinique => 'Cas clinique',
        CardType.definition => 'Définition',
      };

  /// Ordre des listes de fiches : classique, cas clinique, définition.
  int get sortOrder => index;
}
