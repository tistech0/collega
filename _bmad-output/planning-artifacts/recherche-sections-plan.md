# Partie A — Recherche en sections : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dans la sheet de recherche, une section « Collèges » (catalogue local, dès 1 caractère) au-dessus de la section « Items » (recherche serveur actuelle), pour ouvrir ou importer un collège sans parcourir la Bibliothèque.

**Architecture:** Correspondance pure et locale (`matchColleges`) sur les `CollegeListEntry` déjà fournies par `collegesProvider` (catalogue + statut). Une ligne dédiée (`CollegeSearchRow`) reprend le rendu de la Bibliothèque (importé / en cours d'envoi / à importer). `SearchPanel` compose les deux sections ; les états réseau (hors ligne, erreur, vide) ne concernent que la section Items dès qu'au moins un collège correspond.

**Tech Stack:** Flutter 3.27.1, Riverpod 2.6, go_router 14, Collega UI (`core/ui`), flutter_test + goldens (tag `golden`, macOS seulement).

**Spec:** `_bmad-output/planning-artifacts/recherche-pdf-avis-drill-accueil-spec.md`, section **A** (lire la section A en entier avant de commencer).

## Global Constraints

- **Aucun changement serveur** ; `/v1/search` et `SearchNotifier` (2 caractères, 300 ms) restent tels quels.
- Tests **par dossier**, jamais toute la suite : `cd collega_app && flutter test test/features/search`, puis `flutter test test/features/colleges`.
- Goldens : régénérés en local sur macOS avec `--update-goldens` ; **regarder chaque PNG modifié** avant de commiter.
- Pas de widget Material dans `search_sheet.dart` (test « aucun widget Material ni shadcn ») : uniquement `package:flutter/widgets.dart` + Collega UI.
- Textes en français, tutoiement, apostrophe typographique `’`.
- Libellés exacts : section `Collèges` ; section `Items · N` ; sous-titre non importé `<éditeur> · pas encore importé` ; action `Importer` ; placeholder `Un collège, un item, un signe…`.
- Branche : partir de `main` à jour (ou de la branche d'intégration indiquée), branche `feat/recherche-sections`.
- Commits en français, préfixe `feat(recherche)` / `test(recherche)`, terminés par `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **`collegesProvider` pas encore chargé ou en erreur** (sheet ouverte depuis Aujourd'hui juste après le lancement) : la section Collèges est simplement absente, la recherche d'items marche ; jamais de ligne « Importer » sur un collège déjà importé. → test Task 3 « liste des collèges indisponible ».
2. **Requête d'un seul caractère sans collège correspondant** (« x ») : l'accueil (récentes + exemples) reste affiché, pas de « Aucun résultat » prématuré. → test Task 3 « 1 caractère ».
3. **Accents, casse, apostrophes et tirets** (« MEDECINE d urgence », « gyneco obstetrique », « orl ») : trouvés. → tests Task 1.
4. **Collège en cours d'envoi** (reprise d'upload) : affiché « envoi du PDF en cours », ouvre l'écran d'import, jamais « Importer ». → tests Task 2 et Task 3.
5. **Hors ligne avec un collège correspondant** : la section Collèges reste, l'état hors ligne s'affiche seulement sous « Items », pas en pleine page. → test Task 3 « hors ligne ».

---

## File Structure

- Créer `collega_app/lib/features/search/domain/college_match.dart` — `foldForSearch`, `matchColleges` (pur, sans Flutter).
- Créer `collega_app/lib/features/search/presentation/college_search_row.dart` — `CollegeSearchRow` (une ligne collège).
- Modifier `collega_app/lib/features/search/presentation/search_sheet.dart` — sections, états, navigation, placeholder, titre de l'accueil.
- Modifier `collega_app/lib/features/colleges/presentation/colleges_screen.dart` — placeholder et libellé VoiceOver du champ de la Bibliothèque.
- Tests : créer `collega_app/test/features/search/college_match_test.dart`, `collega_app/test/features/search/college_search_row_test.dart` ; modifier `collega_app/test/features/search/search_sheet_test.dart`, `collega_app/test/features/colleges/colleges_screen_test.dart` ; goldens `test/features/search/goldens/search_*`, `test/features/colleges/goldens/library_*`.

---

### Task 1: Correspondance locale des collèges

**Files:**
- Create: `collega_app/lib/features/search/domain/college_match.dart`
- Test: `collega_app/test/features/search/college_match_test.dart`

**Interfaces:**
- Consumes: `CollegeListEntry` (`features/colleges/domain/college_models.dart` : `catalog`, `userStatus`), `kCollegeCatalog` (`features/colleges/domain/college_catalog.dart`).
- Produces:
  - `String foldForSearch(String s)` — minuscules, sans accents (œ→oe, æ→ae), apostrophes/tirets/ponctuation → espace, espaces fusionnés, rogné.
  - `List<CollegeListEntry> matchColleges(String query, List<CollegeListEntry> entries)` — chaque mot de la requête doit apparaître dans « nom éditeur » ; d'abord les noms qui **commencent** par le premier mot, puis les autres, ordre d'entrée conservé dans chaque groupe ; requête vide → `[]`.

- [ ] **Step 1: Écrire les tests (qui échouent)**

```dart
// collega_app/test/features/search/college_match_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/search/domain/college_match.dart';

final _all = [for (final c in kCollegeCatalog) CollegeListEntry(catalog: c)];

List<String> _names(String q) => matchColleges(q, _all).map((e) => e.catalog.name).toList();

void main() {
  group('foldForSearch', () {
    test('minuscules, sans accents, ligatures', () {
      expect(foldForSearch('Gynécologie-Obstétrique'), 'gynecologie obstetrique');
      expect(foldForSearch('Cœur ÆTHER'), 'coeur aether');
    });

    test('apostrophes, tirets et espaces multiples → un espace', () {
      expect(foldForSearch("  Médecine d'urgence "), 'medecine d urgence');
      expect(foldForSearch('Médecine d’urgence'), 'medecine d urgence');
      expect(foldForSearch('Médecine intensive – Réanimation'), 'medecine intensive reanimation');
    });
  });

  group('matchColleges', () {
    test('préfixe du nom', () {
      expect(_names('neuro'), ['Neurochirurgie', 'Neurologie']);
    });

    test('sans accents ni casse', () {
      expect(_names('GYNECO'), ['Gynécologie-Obstétrique']);
      expect(_names('gyneco obstetrique'), ['Gynécologie-Obstétrique']);
      expect(_names('MEDECINE d urgence'), ["Médecine d'urgence"]);
    });

    test('par éditeur', () {
      expect(_names('cngof'), ['Gynécologie-Obstétrique']);
    });

    test('les noms qui commencent par le terme d’abord, puis ceux qui le contiennent', () {
      final names = _names('chirurgie');
      expect(names.take(2), ['Chirurgie générale, viscérale et digestive', 'Chirurgie maxillo-faciale et stomatologie']);
      expect(names.skip(2), containsAll(['Médecine et chirurgie vasculaire', 'Neurochirurgie', 'ORL et chirurgie cervico-faciale']));
    });

    test('un nom court en majuscules', () {
      expect(_names('orl'), ['ORL et chirurgie cervico-faciale']);
    });

    test('vide, espaces ou rien de trouvé → liste vide', () {
      expect(_names(''), isEmpty);
      expect(_names('   '), isEmpty);
      expect(_names('xyz'), isEmpty);
    });

    test('garde le statut de l’entrée', () {
      const status = UserCollegeStatus(
        refId: 26, collegeId: 'c26', status: 'generation_complete', cardCountA: 1, cardCountB: 0, cardCountC: 0,
      );
      final entries = [
        for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: c.refId == 26 ? status : null),
      ];
      final neuro = matchColleges('neurologie', entries).single;
      expect(neuro.userStatus, same(status));
    });
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd collega_app && flutter test test/features/search/college_match_test.dart`
Expected: FAIL (fichier `college_match.dart` introuvable).

- [ ] **Step 3: Implémenter**

```dart
// collega_app/lib/features/search/domain/college_match.dart
import 'package:collega_app/features/colleges/domain/college_models.dart';

/// Recherche de collèges dans le catalogue (spec « Recherche en sections ») :
/// locale, dès 1 caractère, sur le nom et l'éditeur.

const _plain = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

final _separators = RegExp(r"[\s'’\-–—,.]+");

/// « Médecine d’urgence » → « medecine d urgence ».
String foldForSearch(String s) {
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    out.write(_plain[ch] ?? ch);
  }
  return out.toString().replaceAll(_separators, ' ').trim();
}

/// Collèges dont « nom éditeur » contient chaque mot de [query] ; ceux dont le
/// nom commence par le premier mot passent devant. Ordre de [entries] conservé.
List<CollegeListEntry> matchColleges(String query, List<CollegeListEntry> entries) {
  final words = foldForSearch(query).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final first = <CollegeListEntry>[];
  final rest = <CollegeListEntry>[];
  for (final e in entries) {
    final name = foldForSearch(e.catalog.name);
    final haystack = '$name ${foldForSearch(e.catalog.editor)}';
    if (!words.every(haystack.contains)) continue;
    (name.startsWith(words.first) ? first : rest).add(e);
  }
  return [...first, ...rest];
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd collega_app && flutter test test/features/search/college_match_test.dart`
Expected: PASS (tous les tests).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/search/domain/college_match.dart collega_app/test/features/search/college_match_test.dart
git commit -m "feat(recherche): correspondance locale des collèges (nom, éditeur, sans accents)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Ligne collège de la recherche

**Files:**
- Create: `collega_app/lib/features/search/presentation/college_search_row.dart`
- Test: `collega_app/test/features/search/college_search_row_test.dart`

**Interfaces:**
- Consumes: `CollegeListEntry` (`isImported`, `isGenerationComplete`, `userStatus.totalCards`, `userStatus.status`), `CgListRow`, `CgRowIcon`, `CgRowTrailing` (`core/ui/collega_ui.dart`).
- Produces: `CollegeSearchRow({Key? key, required CollegeListEntry entry, bool uploading = false, double? progress, required VoidCallback onOpen, required VoidCallback onImport})`
  - importé → titre = nom, sous-titre `<éditeur> · N fiches` (complet), `<éditeur> · l’import n’a pas abouti` (`failed`), sinon `<éditeur> · import en cours` ; chevron ; toucher → `onOpen`.
  - `uploading` (et non importé) → sous-titre `<éditeur> · envoi du PDF en cours` ou `<éditeur> · envoi du PDF : 42 %` ; chevron ; toucher → `onImport`.
  - sinon → sous-titre `<éditeur> · pas encore importé`, icône atténuée, ligne désactivée, action `Importer` → `onImport` (même rendu que le catalogue de la Bibliothèque).

- [ ] **Step 1: Écrire les tests (qui échouent)**

```dart
// collega_app/test/features/search/college_search_row_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/search/presentation/college_search_row.dart';

final _neuro = collegeCatalogEntry(26)!;

CollegeListEntry _entry({String? status, int cards = 0}) => CollegeListEntry(
      catalog: _neuro,
      userStatus: status == null
          ? null
          : UserCollegeStatus(refId: 26, collegeId: 'c26', status: status, cardCountA: cards, cardCountB: 0, cardCountC: 0),
    );

Widget _host(Widget row) => CgTheme(
      data: CgThemeData.light,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: const MediaQueryData(size: Size(393, 852)), child: Center(child: row)),
      ),
    );

void main() {
  testWidgets('importé et prêt : « éditeur · N fiches », toucher ouvre', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(status: 'generation_complete', cards: 412),
      onOpen: () => opened++,
      onImport: () => fail('pas d’import'),
    )));
    expect(find.text('Neurologie'), findsOneWidget);
    expect(find.text('CEN · 412 fiches'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    await tester.tap(find.text('Neurologie'));
    expect(opened, 1);
  });

  testWidgets('importé, 1 fiche : singulier', (tester) async {
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(status: 'generation_complete', cards: 1),
      onOpen: () {},
      onImport: () {},
    )));
    expect(find.text('CEN · 1 fiche'), findsOneWidget);
  });

  testWidgets('import échoué ou en cours : sous-titre dédié', (tester) async {
    await tester.pumpWidget(_host(CollegeSearchRow(entry: _entry(status: 'failed'), onOpen: () {}, onImport: () {})));
    expect(find.text('CEN · l’import n’a pas abouti'), findsOneWidget);
    await tester.pumpWidget(_host(CollegeSearchRow(entry: _entry(status: 'processing'), onOpen: () {}, onImport: () {})));
    expect(find.text('CEN · import en cours'), findsOneWidget);
  });

  testWidgets('non importé : « pas encore importé » + « Importer »', (tester) async {
    var imported = 0;
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(),
      onOpen: () => fail('pas d’ouverture'),
      onImport: () => imported++,
    )));
    expect(find.text('CEN · pas encore importé'), findsOneWidget);
    await tester.tap(find.text('Importer'));
    expect(imported, 1);
  });

  testWidgets('en cours d’envoi : progression, toucher mène à l’import, jamais « Importer »', (tester) async {
    var imported = 0;
    await tester.pumpWidget(_host(CollegeSearchRow(
      entry: _entry(),
      uploading: true,
      progress: 0.42,
      onOpen: () => fail('pas d’ouverture'),
      onImport: () => imported++,
    )));
    expect(find.text('CEN · envoi du PDF : 42 %'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    await tester.tap(find.text('Neurologie'));
    expect(imported, 1);
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd collega_app && flutter test test/features/search/college_search_row_test.dart`
Expected: FAIL (fichier `college_search_row.dart` introuvable).

- [ ] **Step 3: Implémenter**

```dart
// collega_app/lib/features/search/presentation/college_search_row.dart
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

/// Collège trouvé par la recherche : même rendu que la Bibliothèque (importé,
/// en cours d'envoi, ou à importer).
class CollegeSearchRow extends StatelessWidget {
  const CollegeSearchRow({
    super.key,
    required this.entry,
    this.uploading = false,
    this.progress,
    required this.onOpen,
    required this.onImport,
  });

  final CollegeListEntry entry;

  /// PDF en cours d'envoi : le collège n'est pas encore connu du serveur.
  final bool uploading;
  final double? progress;
  final VoidCallback onOpen;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final catalog = entry.catalog;
    final editor = catalog.editor;
    final status = entry.userStatus;
    if (status != null) {
      final n = status.totalCards;
      final detail = switch (status.status) {
        'generation_complete' => '$n ${n > 1 ? 'fiches' : 'fiche'}',
        'failed' => 'l’import n’a pas abouti',
        _ => 'import en cours',
      };
      return CgListRow(
        title: catalog.name,
        subtitle: '$editor · $detail',
        leading: CgRowIcon(catalog.icon),
        trailing: CgRowTrailing.chevron,
        onTap: onOpen,
      );
    }
    if (uploading) {
      final p = progress;
      final sent = p == null ? 'envoi du PDF en cours' : 'envoi du PDF : ${(p.clamp(0.0, 1.0) * 100).floor()} %';
      return CgListRow(
        title: catalog.name,
        subtitle: '$editor · $sent',
        leading: CgRowIcon(catalog.icon),
        trailing: CgRowTrailing.chevron,
        onTap: onImport,
      );
    }
    return CgListRow(
      title: catalog.name,
      subtitle: '$editor · pas encore importé',
      leading: CgRowIcon(catalog.icon, muted: true),
      enabled: false,
      trailing: CgRowTrailing.action,
      actionLabel: 'Importer',
      onAction: onImport,
    );
  }
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd collega_app && flutter test test/features/search/college_search_row_test.dart`
Expected: PASS. Si le test « non importé » échoue parce que `enabled: false` bloque aussi l'action, vérifier dans `core/ui/components/cg_list_row.dart` comment la Bibliothèque obtient une action active sur une ligne désactivée (même combinaison que `colleges_screen.dart:141-150`) et s'y aligner.

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/search/presentation/college_search_row.dart collega_app/test/features/search/college_search_row_test.dart
git commit -m "feat(recherche): ligne collège (importé, envoi en cours, à importer)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Sections « Collèges » et « Items » dans la sheet

**Files:**
- Modify: `collega_app/lib/features/search/presentation/search_sheet.dart` (`_SearchPanelState.build`, nouvelles méthodes `_openCollege`, `_importCollege`, `_itemsSection` ; placeholder ; titre de `_Home`)
- Test: `collega_app/test/features/search/search_sheet_test.dart`
- Goldens: `collega_app/test/features/search/goldens/search_*.png` (+ nouveaux `search_colleges_*.png`)

**Interfaces:**
- Consumes: `matchColleges` (Task 1), `CollegeSearchRow` (Task 2), `collegesProvider` (`features/colleges/colleges_providers.dart`, `AsyncNotifierProvider<CollegesNotifier, List<CollegeListEntry>>`), `collegeImportProvider` + `ImportUploading` (`features/colleges/colleges_import_providers.dart`, `features/colleges/domain/import_models.dart`), `CollegeDetailOrigin.base`.
- Produces: comportement de la sheet (aucune API nouvelle). Routes poussées : `'${origin.base}/<refId>'` (ouvrir), `'/colleges/<refId>/import'` (importer / envoi en cours).

Règles d'affichage (requête = `state.query`, déjà rognée par `SearchNotifier`) :

| Cas | Corps |
|---|---|
| requête vide, ou 1 caractère sans collège correspondant | `_Home` (inchangé) |
| aucun collège + recherche d'items vide / hors ligne / erreur / en chargement | états pleine page actuels (inchangés) |
| au moins un collège | `ListView` : `Collèges` + lignes, puis la section Items selon l'état |

Section Items quand au moins un collège correspond : trop court → rien ; chargement sans résultat → titre `Items` + `CgSkeletonList(rows: 2)` ; hors ligne → titre `Items` + `CgState.offline(title: 'Les items ont besoin d’une connexion', message: 'Les collèges restent accessibles.')` ; erreur → titre `Items` + `CgState.error(... 'Réessayer' → retry)` ; vide → titre `Items` + texte `Aucun item pour « q »` ; résultats → titre `Items · N` (région live) + lignes.

- [ ] **Step 1: Adapter le banc de test**

Dans `search_sheet_test.dart`, ajouter les imports et les faux fournisseurs, et les brancher dans `_app` :

```dart
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

/// Neurologie (26) importée ; le reste du catalogue à importer.
class _Colleges extends CollegesNotifier {
  static bool fails = false;
  @override
  Future<List<CollegeListEntry>> build() async {
    if (fails) throw StateError('liste indisponible');
    return [
      for (final c in kCollegeCatalog)
        CollegeListEntry(
          catalog: c,
          userStatus: c.refId == 26
              ? const UserCollegeStatus(
                  refId: 26, collegeId: 'c26', status: 'generation_complete', cardCountA: 412, cardCountB: 0, cardCountC: 0)
              : null,
        ),
    ];
  }
}

class _Import extends CollegeImportNotifier {
  static CollegeImportState value = const ImportIdle();
  @override
  Future<CollegeImportState> build() async => value;
  @override
  Future<void> resumePendingUpload() async {}
}
```

Dans `_app`, compléter la liste des routes et les overrides :

```dart
    for (final path in [
      '/colleges',
      '/colleges/:ref',
      '/home/colleges/:ref',
      '/colleges/:ref/import',
      '/colleges/:ref/items/:item',
      '/home/colleges/:ref/items/:item',
      '/drill',
    ])
```

```dart
    overrides: [
      searchRepositoryProvider.overrideWithValue(_repo),
      searchRecentsStoreProvider.overrideWithValue(_recents),
      revisionPrefsProvider.overrideWith(_Prefs.new),
      collegesProvider.overrideWith(_Colleges.new),
      collegeImportProvider.overrideWith(_Import.new),
    ],
```

Et dans `setUp` : `_Colleges.fails = false; _Import.value = const ImportIdle();`.

Remplacer partout `find.text('2 résultats')` par `find.text('Items · 2')` :

```bash
cd collega_app && sed -i '' "s/find.text('2 résultats')/find.text('Items · 2')/g" test/features/search/search_sheet_test.dart
```

Remplacer dans le test « clavier ouvert, récentes puis exemples » :
`expect(find.text('Cherche un item, un signe, une dose'), findsOneWidget);` → `expect(find.text('Cherche un collège, un item, un signe'), findsOneWidget);`

- [ ] **Step 2: Écrire les nouveaux tests (qui échouent)**

Ajouter un groupe dans `search_sheet_test.dart` :

```dart
  group('collèges', () {
    testWidgets('« neuro » : section Collèges puis Items', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'neuro');
      expect(find.text('Collèges'), findsOneWidget);
      expect(find.text('Neurochirurgie'), findsOneWidget);
      expect(find.text('CN · pas encore importé'), findsOneWidget);
      expect(find.text('Neurologie'), findsOneWidget);
      expect(find.text('CEN · 412 fiches'), findsOneWidget);
      expect(find.text('Items · 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Collèges')).dy,
        lessThan(tester.getTopLeft(find.text('Items · 2')).dy),
      );
    });

    testWidgets('dès 1 caractère, sans attendre ni appeler le serveur', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await tester.enterText(find.byType(EditableText), 'u');
      await tester.pump();
      expect(find.text('Urologie'), findsOneWidget);
      expect(find.textContaining('Items'), findsNothing, reason: 'moins de 2 caractères : pas de recherche d’items');
    });

    testWidgets('1 caractère sans collège : l’accueil reste', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _open(tester);
      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(find.text('Cherche un collège, un item, un signe'), findsOneWidget);
      expect(find.textContaining('Aucun résultat'), findsNothing);
    });

    testWidgets('collège importé : la sheet se ferme et le collège s’ouvre dans l’onglet d’origine, récente ajoutée',
        (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit, initial: '/today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir depuis Aujourd’hui'));
      await tester.pumpAndSettle();
      await _type(tester, 'neurologie');
      await tester.tap(find.text('Neurologie'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/home/colleges/26']);
      expect(find.byType(EditableText), findsNothing);
      expect(_recents.saved, ['neurologie']);
    });

    testWidgets('« Importer » : la sheet se ferme sur l’écran d’import', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await _open(tester);
      await _type(tester, 'neurochir');
      await tester.tap(find.text('Importer'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/25/import']);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('envoi en cours : « envoi du PDF », mène à l’import', (tester) async {
      _phone(tester);
      _Import.value = const ImportUploading(refId: 25, progress: 0.5);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await _open(tester);
      await _type(tester, 'neurochir');
      expect(find.text('CN · envoi du PDF : 50 %'), findsOneWidget);
      expect(find.text('Importer'), findsNothing);
      await tester.tap(find.text('Neurochirurgie'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/25/import']);
    });

    testWidgets('hors ligne : les collèges restent, l’état hors ligne est sous « Items »', (tester) async {
      _phone(tester);
      _repo.error = DioException(requestOptions: RequestOptions(path: '/s'), type: DioExceptionType.connectionError);
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'neuro');
      expect(find.text('Neurologie'), findsOneWidget);
      expect(find.text('Les items ont besoin d’une connexion'), findsOneWidget);
      expect(find.text('La recherche a besoin d’une connexion'), findsNothing);
    });

    testWidgets('erreur serveur avec collèges : « Réessayer » sous Items relance', (tester) async {
      _phone(tester);
      _repo.error = DioException(requestOptions: RequestOptions(path: '/s'), type: DioExceptionType.badResponse);
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'neuro');
      expect(find.text('Neurologie'), findsOneWidget);
      _repo.error = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Items · 2'), findsOneWidget);
    });

    testWidgets('collèges trouvés, aucun item : pas de « Aucun résultat » pleine page', (tester) async {
      _phone(tester);
      _repo.results = const [];
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'neuro');
      expect(find.text('Neurologie'), findsOneWidget);
      expect(find.text('Aucun item pour « neuro »'), findsOneWidget);
      expect(find.text('Aucun résultat pour « neuro »'), findsNothing);
    });

    testWidgets('liste des collèges indisponible : pas de section Collèges, les items marchent', (tester) async {
      _phone(tester);
      _Colleges.fails = true;
      await tester.pumpWidget(_app());
      await _open(tester);
      await _type(tester, 'neuro');
      expect(find.text('Collèges'), findsNothing);
      expect(find.text('Importer'), findsNothing);
      expect(find.text('Items · 2'), findsOneWidget);
    });

    testWidgets('Dynamic Type 1,6 sur 375 avec les deux sections : aucun débordement', (tester) async {
      _phone(tester, width: 375, height: 812);
      await tester.pumpWidget(_app(textScale: 1.6));
      await _open(tester);
      await _type(tester, 'neuro');
      expect(tester.takeException(), isNull);
    });
  });
```

Ajouter le cas golden `('colleges', 'neuro')` à la boucle existante :

```dart
    for (final (name, query) in [('home', null), ('results', 'BNP'), ('colleges', 'neuro')]) {
```

- [ ] **Step 3: Lancer, vérifier l'échec**

Run: `cd collega_app && flutter test test/features/search/search_sheet_test.dart --exclude-tags golden`
Expected: FAIL (textes « Collèges », « Items · 2 », « Cherche un collège, un item, un signe » introuvables).

- [ ] **Step 4: Implémenter dans `search_sheet.dart`**

Imports à ajouter :

```dart
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/search/domain/college_match.dart';
import 'package:collega_app/features/search/presentation/college_search_row.dart';
```

Dans `_SearchPanelState`, à côté de `_open` / `_revise` :

```dart
  /// Collège importé : s'ouvre dans l'onglet d'origine, la sheet se ferme.
  void _openCollege(CollegeListEntry e) {
    final router = GoRouter.of(context);
    ref.read(searchRecentsProvider.notifier).add(ref.read(searchNotifierProvider).query);
    _close();
    router.push('${widget.origin.base}/${e.catalog.refId}');
  }

  /// À importer (ou envoi en cours) : l'écran d'import dit où on en est.
  void _importCollege(CollegeListEntry e) {
    final router = GoRouter.of(context);
    _close();
    router.push('/colleges/${e.catalog.refId}/import');
  }

  /// Section Items quand des collèges sont affichés au-dessus : les états
  /// réseau ne concernent qu'elle.
  List<Widget> _itemsSection(SearchState state) {
    if (state.isTooShort) return const [];
    if ((state.isLoading || state.isPending) && !state.hasResults) {
      return const [CgSectionTitle('Items'), CgSkeletonList(rows: 2)];
    }
    if (state.isOffline) {
      return const [
        CgSectionTitle('Items'),
        CgState.offline(title: 'Les items ont besoin d’une connexion', message: 'Les collèges restent accessibles.'),
      ];
    }
    if (state.hasError) {
      return [
        const CgSectionTitle('Items'),
        CgState.error(
          title: 'La recherche n’a pas abouti',
          message: 'Rien n’est perdu. Réessaie dans un instant.',
          actionLabel: 'Réessayer',
          onAction: () => ref.read(searchNotifierProvider.notifier).retry(),
        ),
      ];
    }
    final c = CgTheme.of(context).colors;
    if (state.results.isEmpty) {
      return [
        const CgSectionTitle('Items'),
        Text('Aucun item pour « ${state.query} »', style: CgType.bodyS.copyWith(color: c.ink2)),
      ];
    }
    return [
      Semantics(liveRegion: true, child: CgSectionTitle('Items · ${state.results.length}')),
      CgListGroup(children: [
        for (final r in state.results) _ResultRow(result: r, onOpen: () => _open(r), onRevise: () => _revise(r)),
      ]),
    ];
  }
```

Dans `build`, remplacer le calcul de `body` par :

```dart
    final query = state.query;
    // Liste pas encore là (ou en erreur) : pas de section Collèges plutôt
    // qu'un « Importer » sur un collège peut-être déjà importé.
    final colleges = query.isEmpty
        ? const <CollegeListEntry>[]
        : matchColleges(query, ref.watch(collegesProvider).valueOrNull ?? const []);
    final upload = ref.watch(collegeImportProvider).valueOrNull;
    final uploadingRef = upload is ImportUploading ? upload.refId : null;
    final uploadProgress = upload is ImportUploading ? upload.progress : null;

    final Widget body;
    if (query.isEmpty || (state.isTooShort && colleges.isEmpty)) {
      body = _Home(onPick: _search);
    } else if (colleges.isNotEmpty) {
      body = ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + CgSpace.s4),
        children: [
          const CgSectionTitle('Collèges'),
          CgListGroup(children: [
            for (final e in colleges)
              CollegeSearchRow(
                entry: e,
                uploading: !e.isImported && e.catalog.refId == uploadingRef,
                progress: uploadProgress,
                onOpen: () => _openCollege(e),
                onImport: () => _importCollege(e),
              ),
          ]),
          ..._itemsSection(state),
        ],
      );
    } else if ((state.isLoading || state.isPending) && !state.hasResults) {
```

puis garder **à l'identique** les branches existantes à partir du squelette (`CgSkeletonList(rows: 4)`, hors ligne pleine page, erreur, `Aucun résultat pour « … »`), et remplacer la dernière branche (liste de résultats) par :

```dart
    } else {
      body = ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + CgSpace.s4),
        children: _itemsSection(state),
      );
    }
```

(Le texte « N résultats » disparaît au profit du titre de section `Items · N`, qui garde la région live.)

Placeholder du champ : `placeholder: 'Un collège, un item, un signe…',`.

Dans `_Home` : `Text('Cherche un collège, un item, un signe', ...)`.

- [ ] **Step 5: Lancer, vérifier le succès**

Run: `cd collega_app && flutter test test/features/search --exclude-tags golden`
Expected: PASS (anciens et nouveaux tests).

- [ ] **Step 6: Régénérer et vérifier les goldens**

Run: `cd collega_app && flutter test test/features/search/search_sheet_test.dart --tags golden --update-goldens`
Puis ouvrir `test/features/search/goldens/search_colleges_393_10.png`, `search_colleges_375_16.png`, `search_results_393_10.png`, `search_home_393_10.png` : section « Collèges » au-dessus de « Items · 2 », « Importer » sur Neurochirurgie, pas de texte coupé à 1,6. Relancer sans `--update-goldens` : PASS.

- [ ] **Step 7: Commit**

```bash
git add collega_app/lib/features/search/presentation/search_sheet.dart collega_app/test/features/search/search_sheet_test.dart collega_app/test/features/search/goldens
git commit -m "feat(recherche): sections Collèges et Items dans la recherche

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Champ de la Bibliothèque

**Files:**
- Modify: `collega_app/lib/features/colleges/presentation/colleges_screen.dart:247` (placeholder) et `:256` (libellé VoiceOver)
- Test: `collega_app/test/features/colleges/colleges_screen_test.dart:241` et `:338`
- Goldens: `collega_app/test/features/colleges/goldens/library_*.png`

**Interfaces:**
- Consumes: rien de nouveau.
- Produces: placeholder `Un collège, un item, un signe…`, libellé `Rechercher un collège, un item, un signe`.

- [ ] **Step 1: Mettre les tests à jour (qui échouent)**

Dans `colleges_screen_test.dart` :
- ligne 241 : `await tester.tap(find.text('Un collège, un item, un signe…'));`
- ligne 338 : `matchesSemantics(label: 'Rechercher un collège, un item, un signe', isButton: true, hasTapAction: true),`

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd collega_app && flutter test test/features/colleges/colleges_screen_test.dart --exclude-tags golden`
Expected: FAIL (texte et libellé introuvables).

- [ ] **Step 3: Implémenter**

Dans `_SearchField` de `colleges_screen.dart` :

```dart
  static const _placeholder = 'Un collège, un item, un signe…';
```

```dart
      label: 'Rechercher un collège, un item, un signe',
```

- [ ] **Step 4: Lancer, vérifier le succès, régénérer les goldens**

Run: `cd collega_app && flutter test test/features/colleges --exclude-tags golden` → PASS.
Run: `cd collega_app && flutter test test/features/colleges/colleges_screen_test.dart --tags golden --update-goldens`, ouvrir `goldens/library_mine_393_10.png` et `library_mine_375_16.png` (placeholder entier, non coupé), puis relancer `flutter test test/features/colleges` → PASS.

- [ ] **Step 5: Vérification finale du dossier recherche et commit**

Run: `cd collega_app && flutter test test/features/search && flutter analyze lib/features/search lib/features/colleges`
Expected: PASS, aucune nouvelle issue.

```bash
git add collega_app/lib/features/colleges/presentation/colleges_screen.dart collega_app/test/features/colleges/colleges_screen_test.dart collega_app/test/features/colleges/goldens
git commit -m "feat(recherche): la Bibliothèque annonce la recherche de collèges

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Auto-revue (faite)

- Couverture de la spec A : sections empilées (T3), 1 caractère sans délai (T1/T3), accents/casse/nom+éditeur (T1), importé / non importé / envoi en cours (T2/T3), états réseau limités à Items (T3), « Aucun résultat » seulement si tout est vide (T3), fermeture de la sheet + récente (T3), placeholder (T3/T4).
- Écart assumé avec la spec : le **surlignage du terme dans le nom du collège** n'est pas fait — `CgListRow.title` est un `String`. Le nom seul suffit (la requête est courte et visible juste au-dessus) ; à rouvrir si demandé.
- Noms cohérents : `foldForSearch`, `matchColleges`, `CollegeSearchRow(entry, uploading, progress, onOpen, onImport)`, `_openCollege`, `_importCollege`, `_itemsSection`.
