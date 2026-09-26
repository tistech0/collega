# Recherche en sections, PDF sur le téléphone, avis pendant le drill, Accueil « session faite »

Date : 2026-09-26 · Branche de départ : `feat/beta-testflight` · Maquettes : `.superpowers/brainstorm/78852-1790420001/content/` (non versionnées)

## Contexte et objectifs

Quatre améliorations demandées pendant la beta, toutes validées sur maquettes :

1. **Recherche** : trouver un collège par son nom (pour l'ouvrir ou l'importer) au lieu de parcourir les 39 du catalogue.
2. **PDF** : relire le PDF importé, depuis la vue collège (tout le PDF) et depuis un item (à la page de l'item), hors connexion.
3. **Drill** : donner son avis sur une fiche (utile / à corriger) au moment où on la voit en révision.
4. **Accueil** : rendre la « session du jour faite » plus visible et encourager la régularité (série de jours).

Hors périmètre : annotations dans le PDF, recherche plein texte dans le PDF, série synchronisée entre appareils, raccourci « Mes collèges » dans l'accueil de la recherche.

Ordre de livraison : **C (drill) et A (recherche)**, puis **D (Accueil)**, puis **B (PDF)**. Chaque partie est livrable seule.

---

## A. Recherche en sections

**App seulement, aucun changement serveur.**

- La sheet de recherche (`features/search/presentation/search_sheet.dart`) affiche deux sections empilées :
  - **Collèges** (en haut) : correspondances dans `kCollegeCatalog` (`college_catalog.dart`), dès **1 caractère**, sans délai (local).
  - **Items** (en dessous) : la recherche serveur actuelle, inchangée (2 caractères, 300 ms, `/v1/search`).
- Correspondance collège : sans accents ni casse, sur le **nom** et l'**éditeur** (« gyneco » → Gynécologie-Obstétrique, « cngof » aussi). Une fonction pure `matchColleges(query)` dans `features/search/domain/`, testée seule.
- Ligne collège :
  - importé (présent dans `collegesProvider` avec un `userStatus`) → sous-titre « éditeur · N fiches », chevron, ouvre `'${origin.base}/<refId>'` ;
  - non importé → sous-titre « éditeur · pas encore importé », action **« Importer »** → `/colleges/<refId>/import` ;
  - envoi en cours → même rendu que la Bibliothèque (« en cours d'envoi »), ouvre l'écran d'import.
  - Le terme est surligné comme les extraits (`accentSoft`).
- Pas de plafond de lignes collèges (le catalogue en compte 39, une requête courte en montre peu).
- États : la section Collèges ne dépend pas du réseau. Hors ligne ou en erreur, seule la section Items montre l'état offline/erreur (en dessous de la section Collèges, qui reste). « Aucun résultat » seulement si les deux sections sont vides.
- Ouvrir un collège ferme la sheet comme l'ouverture d'un item (même règle GoRouter / sheets, voir mémoire « Sheets et GoRouter »). La requête est ajoutée aux récentes.
- Placeholder du champ : « Un collège, un item, un signe… ».

**Tests** (`test/features/search`) : `matchColleges` (accents, casse, éditeur, vide) ; widget : sections présentes/absentes, ligne importée vs « Importer », section Collèges visible hors ligne, « Aucun résultat » seulement si tout est vide, navigation.

---

## B. Le PDF sur le téléphone

### Principe

À l'import, l'app **garde une copie locale** du PDF. Le lecteur lit toujours cette copie. Si elle manque (collèges importés avant cette fonction, nouveau téléphone, réinstallation), l'app propose de la **retélécharger depuis le serveur**, qui conserve déjà le dernier PDF de chaque collège (`stale_pdfs` dans `services/generation/publish.py` ne supprime que les anciens ; politique de confidentialité : « conservés tant que le collège associé est dans ton compte »).

### Serveur

1. **Pages des items** : `start_page` / `end_page` (déjà en base sur `items`, index **base 0** issu de `item_detector`) ajoutés aux réponses item de `api/v1/colleges/cards.py` (liste des items/fiches d'un collège). Nullable.
2. **Route PDF** : `GET /v1/colleges/{college_id}/pdf` dans `api/v1/colleges/` (nouveau fichier `pdf.py` ou `imports.py`, domaine colleges).
   - Réservée au propriétaire du collège (sinon `AppError` 404 via les fabriques de `core/errors.py`, pas de fuite d'existence).
   - Sert le fichier `{college_id}_{job_id}.pdf` du dernier import publié. Si le fichier manque : 404 `PDF_NOT_FOUND`.
   - `FileResponse` avec prise en charge des requêtes `Range` (reprise), `Content-Length`, et un **`ETag` = empreinte du PDF** (`pdf_hash` du job publié).
   - Logique (trouver le PDF courant) dans `app/services/imports.py` ; la route reste HTTP seulement.
3. **Version du PDF** : l'empreinte courante (`pdf_hash`) est exposée dans les données du collège déjà lues par l'app (statut ou liste des collèges de l'utilisatrice), pour que l'app sache si sa copie est à jour.

**Tests backend** : propriétaire → 200 + octets ; autre compte → 404 ; fichier absent → 404 `PDF_NOT_FOUND` ; requête `Range` → 206 ; `start_page`/`end_page` présents dans la réponse des items.

### App : stockage local

- Nouveau service `core/pdf/local_pdf_store.dart` (ou `features/colleges/data/`) :
  - emplacement : `Application Support/pdfs/<collegeId>.pdf` + métadonnée de version (empreinte serveur) ;
  - fichier **exclu de la sauvegarde iCloud** (attribut `NSURLIsExcludedFromBackupKey`) ;
  - `status(collegeId)` → `absent | aJour | périmé` (comparaison avec l'empreinte serveur).
- **À l'import** : avant que l'envoi par morceaux ne supprime son cache (`core/upload/chunked_upload_service.dart`), le PDF choisi est copié dans le store. En cas de réimport, la copie remplace l'ancienne une fois l'import publié. Une copie qui échoue n'empêche jamais l'import (au pire, on retéléchargera).
- **Suppression** : quand la synchro retire un collège (`college_cards_sync.dart`, collèges disparus) et quand **un autre compte** se connecte (`auth/data/local_data_owner.dart`, même règle que la base : la simple déconnexion ne supprime rien).
- Numéros de page : colonnes `startPage` / `endPage` ajoutées à la table drift `Items` (migration de schéma 8 → 9), remplies par la synchro.

### App : téléchargement

- Écran d'état « Ton PDF n'est pas sur ce téléphone » (maquette validée) : taille annoncée, bouton « Télécharger (N Mo) », avertissement si données mobiles, progression.
- Téléchargement via `background_downloader` (déjà utilisé pour l'envoi) : continue si on quitte l'écran ou l'app, reprise par `Range`. Fichier écrit dans le store une fois complet et vérifié (taille).
- Copie périmée (réimport depuis un autre appareil) : même écran avec « Une nouvelle version de ton PDF est disponible ».

### App : lecteur

- Paquet **`pdfrx`** (rendu PDFium, gros fichiers, navigation par page). Compatibilité avec Flutter 3.27.1 à vérifier au début du plan ; si incompatible, repli sur une version antérieure compatible ou sur PDFKit natif via un petit canal de plateforme.
- Écran plein écran, route `…/<refId>/pdf?page=<n>&item=<itemId>` :
  - **tout le PDF**, ouvert à la page demandée (défilement libre) ;
  - barre du haut : retour · « p. 112 / 480 » · partager (feuille système iOS) ;
  - depuis un item : bandeau « Item 340 · p. 112–118 » avec « ↑ Début » (revient à `start_page`) ;
  - depuis la vue collège : ouvre à la **dernière page lue** de ce collège (mémorisée localement), sinon p. 1.
- Affichage des pages en base 1 (`start_page + 1`).

### Points d'accès

- **Vue collège** (`college_detail_screen.dart`) : ligne « Mon PDF du collège » sous la barre de progression, sous-titre « N pages · sur ce téléphone » ou « à télécharger · N Mo ».
- **Fiche d'item** (`item_detail_screen.dart`) : lien « Lire dans le PDF · p. X–Y » sous le titre. Absent si l'item n'a pas de `start_page`.
- **Feuille « Source à vérifier »** (badge OCR d'une fiche) : bouton « Vérifier dans le PDF », ouvre à la page de l'item.

**Tests app** : store (statuts, remplacement, suppression par synchro et changement de compte) ; migration drift 8 → 9 ; widget : ligne PDF selon statut, lien d'item présent/absent, bouton de la feuille OCR, écran de téléchargement (Wi-Fi / cellulaire), bandeau et « ↑ Début » du lecteur (lecteur PDF simulé).

---

## C. Avis sur une fiche pendant le drill

**App seulement, aucun changement serveur.**

- Au **verso** de `CgDrillCard`, dans l'en-tête de la feuille de réponse, à droite de « Réponse » : deux **icônes seules** `CgIcons.thumbUp` / `CgIcons.thumbDown` (cibles 44 pt). État choisi : icône `accent` sur fond `accentSoft` (comme la pastille cochée de la vue item). VoiceOver : « Fiche utile » / « Signaler la fiche », état sélectionné annoncé.
- L'avis déjà donné (`flash_cards.userFeedback` local) s'affiche.
- Ce sont des touchers : ils ne déclenchent jamais un geste de jugement (glissés gauche/haut/droite de la feuille).
- **Utile** : même appel que la vue item (`submitFeedback(cardId, 'positive')`), mise à jour de la base locale ; échec → toast « non enregistré, réessaie ».
- **À corriger** : même feuille que la vue item (remarque facultative) avec « **Régénérer et continuer** » / « **Continuer sans régénérer** ». La régénération (`POST /v1/flash-cards/{id}/regenerate`, appel de quelques secondes) part **sans bloquer** : le drill reste sur la fiche courante, qu'on juge normalement ; au retour, la nouvelle fiche remplace l'ancienne dans la base locale pour les sessions suivantes. Échec → toast.
- Chrono : en pause pendant que la feuille est ouverte.
- **Refacto** : le signalement (feuille + envoi + régénération) sort de `item_detail_screen.dart` dans un morceau partagé (`features/colleges/presentation/card_report.dart` ou équivalent) utilisé par les deux écrans, au lieu d'être copié. La régénération et le feedback passent par un service qui met à jour la base locale, utilisable hors de l'`ItemDetailNotifier`.
- `CgDrillCard` reçoit un emplacement optionnel pour ces actions (le composant du design system reste générique).

**Tests** (`test/features/drill`, `test/core`) : icônes absentes au recto, présentes au verso ; état choisi ; toucher ≠ geste de jugement ; feuille ouverte sur « À corriger » ; régénération non bloquante et fiche remplacée localement ; vue item toujours verte après la refacto.

---

## D. Accueil : session faite et série

**App seulement.**

### Visuel (option B validée)

- Bloc « Session faite » (`today_screen.dart`, `_Done`) : **grand rond coché** `accent` à gauche du titre, sous-titre « N fiches » ; barre et répartition des verdicts inchangées.
- Ronds de la semaine (`_Week`) : chaque jour fait porte une **coche blanche**.
- **Animation unique** au retour sur l'Accueil juste après avoir terminé la session : le rond du jour et le grand rond « rebondissent », la coche se dessine, retour haptique léger. Jamais rejouée ensuite ; désactivée si « Réduire les animations » (`MediaQuery.disableAnimations`).

### Série (sur le téléphone uniquement)

- Badge sous « Session faite » (et dans l'état « à faire ») : « **N jours d'affilée** », affiché à partir de **2**.
- Règles :
  - un jour compte s'il a une session du jour terminée (`daily_sessions.completedAtMs`) ;
  - **aujourd'hui non terminé ne casse pas** la série (on compte depuis hier) ;
  - **ne cassent pas** : les jours décalés (`postponedDays` du planning) et les jours « rien à réviser » ;
  - la série casse s'il existe un jour passé sans session terminée et sans excuse ; le badge disparaît simplement, sans message négatif.
- Jours « rien à réviser » : aujourd'hui, ce cas **supprime** la ligne du jour (`daily_session_repository.dart`, `plan.isEmpty`), il ne laisse donc aucune trace. Il faut l'enregistrer : petite table drift `quiet_days (day)` (dans la même migration 8 → 9 que B, ou sa propre migration si D est livré avant).
- Calcul : fonction pure `streakLength(today, completedDays, excusedDays)`, testée seule.
- Limite assumée : la série ne suit pas un changement de téléphone ni une réinstallation.

**Tests** (`test/features/today`) : `streakLength` (aujourd'hui fait / pas fait, jour décalé, jour calme, trou, série de 1 non affichée) ; widget : coches de la semaine, grand rond, badge ; animation jouée une seule fois et absente avec réduction des animations.

---

## Qualité et livraison

- Backend : `pytest`, `ruff check`, `ruff format --check`, `mypy app/core app/services` à 0, `alembic check` (aucune migration serveur prévue).
- App : `flutter test` **par dossier** (`test/core`, puis chaque `test/features/<dossier>`).
- Déploiement serveur (partie B) uniquement par `collega_backend/scripts/deploy.sh <sha>`.
- Validation sur iPhone (build TestFlight) de chaque partie, en particulier le téléchargement du PDF en 4G et hors ligne.
