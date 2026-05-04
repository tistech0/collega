enum DemoCardType { classic, definition }

class DemoFlashCard {
  const DemoFlashCard({
    required this.id,
    required this.front,
    required this.back,
    required this.rang,
    required this.type,
  });
  final String id;
  final String front;
  final String back;
  final String rang; // 'A' ou 'B'
  final DemoCardType type;
}

class DemoItem {
  const DemoItem({
    required this.number,
    required this.title,
    required this.rang,
    required this.cards,
  });
  final int number;
  final String title;
  final String rang;
  final List<DemoFlashCard> cards;
}

class DemoCollege {
  const DemoCollege({required this.name, required this.item});
  final String name;
  final DemoItem item;
}

const demoCollege = DemoCollege(
  name: 'Cardiologie Exemple',
  item: DemoItem(
    number: 1,
    title: 'Insuffisance Cardiaque',
    rang: 'A',
    cards: [
      DemoFlashCard(
        id: 'demo-1',
        front: 'Quels sont les signes cliniques de l\'insuffisance cardiaque gauche ?',
        back:
            'Dyspnée d\'effort → de repos, orthopnée, crépitants bilatéraux, toux nocturne, expectorations rosées mousseuses.',
        rang: 'A',
        type: DemoCardType.classic,
      ),
      DemoFlashCard(
        id: 'demo-2',
        front: 'Définition : Insuffisance cardiaque',
        back:
            'Incapacité du cœur à assurer un débit adapté aux besoins métaboliques, malgré des pressions de remplissage normales ou élevées.',
        rang: 'A',
        type: DemoCardType.definition,
      ),
      DemoFlashCard(
        id: 'demo-3',
        front: 'Quel biomarqueur clé pour le diagnostic de l\'insuffisance cardiaque ?',
        back:
            'BNP (> 100 pg/mL) ou NT-proBNP (> 300 pg/mL en urgence) — marqueur de surcharge de pression/volume ventriculaire.',
        rang: 'B',
        type: DemoCardType.classic,
      ),
    ],
  ),
);
